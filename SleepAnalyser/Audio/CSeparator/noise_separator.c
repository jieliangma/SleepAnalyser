#include "noise_separator.h"
#include <math.h>
#include <string.h>
#include <stdlib.h>

static void simple_fft(const float *input, float *real, float *imag, int n) {
    for (int k = 0; k < n / 2; k++) {
        real[k] = 0.0f;
        imag[k] = 0.0f;
        for (int j = 0; j < n; j++) {
            float angle = 2.0f * (float)M_PI * (float)k * (float)j / (float)n;
            real[k] += input[j] * cosf(angle);
            imag[k] -= input[j] * sinf(angle);
        }
    }
}

static void simple_ifft(const float *real, const float *imag, float *output, int n) {
    for (int j = 0; j < n; j++) {
        output[j] = 0.0f;
        for (int k = 0; k < n / 2; k++) {
            float angle = 2.0f * (float)M_PI * (float)k * (float)j / (float)n;
            output[j] += real[k] * cosf(angle) - imag[k] * sinf(angle);
        }
        output[j] *= 2.0f / (float)n;
    }
}

void ns_init(ns_state_t *state, int fft_size, float sample_rate) {
    memset(state, 0, sizeof(ns_state_t));
    state->fft_size = fft_size > NS_MAX_FFT_SIZE ? NS_MAX_FFT_SIZE : fft_size;
    state->sample_rate = sample_rate;
    state->smoothing_alpha = 0.95f;
    state->noise_floor_initialized = 0;
    state->frame_count = 0;
    state->history_idx = 0;
    state->history_len = 0;
}

void ns_reset(ns_state_t *state) {
    state->noise_floor_initialized = 0;
    state->frame_count = 0;
    state->history_idx = 0;
    state->history_len = 0;
    memset(state->noise_floor, 0, sizeof(state->noise_floor));
    memset(state->history_rms, 0, sizeof(state->history_rms));
}

static float compute_rms(const float *samples, int count) {
    if (count <= 0) return 0.0f;
    float sum = 0.0f;
    for (int i = 0; i < count; i++) sum += samples[i] * samples[i];
    return sqrtf(sum / (float)count);
}

ns_band_energy_t ns_compute_band_energy(const float *samples, int count, float sample_rate) {
    ns_band_energy_t bands;
    memset(&bands, 0, sizeof(bands));
    if (count < 4) return bands;

    int half = count / 2;
    float *real = (float *)calloc(half, sizeof(float));
    float *imag = (float *)calloc(half, sizeof(float));
    if (!real || !imag) { free(real); free(imag); return bands; }

    int fft_n = count > NS_MAX_FFT_SIZE ? NS_MAX_FFT_SIZE : count;
    simple_fft(samples, real, imag, fft_n);

    float bin_width = sample_rate / (float)fft_n;
    int half_n = fft_n / 2;

    float *mag = (float *)calloc(half_n, sizeof(float));
    if (!mag) { free(real); free(imag); return bands; }
    for (int i = 0; i < half_n; i++)
        mag[i] = sqrtf(real[i] * real[i] + imag[i] * imag[i]);

    typedef struct { float lo; float hi; float *target; } BandDef;
    BandDef defs[] = {
        {20, 80, &bands.sub_bass},
        {80, 250, &bands.bass},
        {250, 500, &bands.low_mid},
        {500, 2000, &bands.mid},
        {2000, 4000, &bands.high_mid},
        {4000, 6000, &bands.presence},
        {6000, 8000, &bands.brilliance},
    };
    int n_bands = sizeof(defs) / sizeof(defs[0]);

    for (int b = 0; b < n_bands; b++) {
        int lo_bin = (int)(defs[b].lo / bin_width);
        int hi_bin = (int)(defs[b].hi / bin_width);
        if (lo_bin < 0) lo_bin = 0;
        if (hi_bin >= half_n) hi_bin = half_n - 1;
        if (lo_bin > hi_bin) continue;
        float sum = 0.0f;
        for (int i = lo_bin; i <= hi_bin; i++) sum += mag[i];
        *defs[b].target = sum / (float)(hi_bin - lo_bin + 1);
    }
    bands.total_rms = compute_rms(samples, count);

    free(real); free(imag); free(mag);
    return bands;
}

void ns_update_noise_floor(ns_state_t *state, const float *samples, int count) {
    int fft_n = count > state->fft_size ? state->fft_size : count;
    int half_n = fft_n / 2;
    float *real = (float *)calloc(half_n, sizeof(float));
    float *imag = (float *)calloc(half_n, sizeof(float));
    if (!real || !imag) { free(real); free(imag); return; }

    simple_fft(samples, real, imag, fft_n);

    float *mag = (float *)calloc(half_n, sizeof(float));
    if (!mag) { free(real); free(imag); return; }
    for (int i = 0; i < half_n; i++)
        mag[i] = sqrtf(real[i] * real[i] + imag[i] * imag[i]);

    if (!state->noise_floor_initialized) {
        memcpy(state->noise_floor, mag, sizeof(float) * half_n);
        state->noise_floor_initialized = 1;
    } else {
        float a = state->smoothing_alpha;
        for (int i = 0; i < half_n; i++) {
            float candidate = a * state->noise_floor[i] + (1.0f - a) * mag[i];
            if (candidate < state->noise_floor[i] * 3.0f)
                state->noise_floor[i] = candidate;
        }
    }

    float rms = compute_rms(samples, count);
    state->history_rms[state->history_idx] = rms;
    state->history_idx = (state->history_idx + 1) % 64;
    if (state->history_len < 64) state->history_len++;
    state->frame_count++;

    free(real); free(imag); free(mag);
}

void ns_separate_noise(
    ns_state_t *state,
    const float *input, int count,
    float *foreground_out,
    float *background_out)
{
    if (!state->noise_floor_initialized || count < 4) {
        if (foreground_out) memcpy(foreground_out, input, sizeof(float) * count);
        if (background_out) memset(background_out, 0, sizeof(float) * count);
        return;
    }

    int fft_n = count > state->fft_size ? state->fft_size : count;
    int half_n = fft_n / 2;
    float *real = (float *)calloc(half_n, sizeof(float));
    float *imag = (float *)calloc(half_n, sizeof(float));
    if (!real || !imag) {
        if (foreground_out) memcpy(foreground_out, input, sizeof(float) * count);
        if (background_out) memset(background_out, 0, sizeof(float) * count);
        free(real); free(imag);
        return;
    }

    simple_fft(input, real, imag, fft_n);

    float *fg_real = (float *)calloc(half_n, sizeof(float));
    float *fg_imag = (float *)calloc(half_n, sizeof(float));
    float *bg_real = (float *)calloc(half_n, sizeof(float));
    float *bg_imag = (float *)calloc(half_n, sizeof(float));
    if (!fg_real || !fg_imag || !bg_real || !bg_imag) {
        free(real); free(imag);
        free(fg_real); free(fg_imag); free(bg_real); free(bg_imag);
        return;
    }

    for (int i = 0; i < half_n; i++) {
        float mag = sqrtf(real[i] * real[i] + imag[i] * imag[i]);
        float phase_cos = mag > 0 ? real[i] / mag : 0;
        float phase_sin = mag > 0 ? imag[i] / mag : 0;
        float noise_est = state->noise_floor[i] * 2.0f;
        float fg_mag = mag > noise_est ? mag - noise_est : 0.01f * mag;
        float bg_mag = mag - fg_mag;

        fg_real[i] = fg_mag * phase_cos;
        fg_imag[i] = fg_mag * phase_sin;
        bg_real[i] = bg_mag * phase_cos;
        bg_imag[i] = bg_mag * phase_sin;
    }

    if (foreground_out) simple_ifft(fg_real, fg_imag, foreground_out, fft_n);
    if (background_out) simple_ifft(bg_real, bg_imag, background_out, fft_n);

    for (int i = fft_n; i < count; i++) {
        if (foreground_out) foreground_out[i] = input[i];
        if (background_out) background_out[i] = 0;
    }

    free(real); free(imag);
    free(fg_real); free(fg_imag); free(bg_real); free(bg_imag);
}

ns_noise_type_t ns_classify_noise(
    const ns_band_energy_t *bands, float crest_factor, int is_stationary)
{
    float total_low = bands->sub_bass + bands->bass;
    float total_mid = bands->low_mid + bands->mid;
    float total = total_low + total_mid + bands->high_mid + bands->presence + bands->brilliance;
    if (total < 1e-6f) return NS_NOISE_QUIET;
    float low_ratio = total_low / total;

    if (bands->sub_bass > bands->bass * 1.5f && low_ratio > 0.55f && crest_factor < 4.0f)
        return NS_NOISE_WIND;

    if (bands->low_mid > bands->mid && bands->bass > bands->high_mid * 1.5f && crest_factor > 3.0f)
        return NS_NOISE_MOTORCYCLE;

    if (bands->bass > bands->mid * 2.0f && low_ratio > 0.45f)
        return NS_NOISE_TRAFFIC;

    if (low_ratio > 0.4f && crest_factor < 3.0f && is_stationary)
        return NS_NOISE_HVAC;

    if (bands->mid > total_low && bands->high_mid > bands->bass)
        return NS_NOISE_SPEECH;

    if (bands->sub_bass > 0.01f && bands->total_rms > 0.02f && low_ratio > 0.5f)
        return NS_NOISE_RAIN;

    if (bands->total_rms < 0.005f)
        return NS_NOISE_QUIET;

    return NS_NOISE_UNKNOWN;
}

float ns_compute_crest_factor(const float *samples, int count) {
    if (count <= 0) return 0.0f;
    float peak = 0.0f;
    for (int i = 0; i < count; i++) {
        float a = fabsf(samples[i]);
        if (a > peak) peak = a;
    }
    float rms = compute_rms(samples, count);
    return rms > 0 ? peak / rms : 0.0f;
}

int ns_is_stationary(const ns_state_t *state) {
    if (state->history_len < 3) return 0;
    float min_v = 1e10f, max_v = 0.0f;
    for (int i = 0; i < state->history_len; i++) {
        if (state->history_rms[i] < min_v) min_v = state->history_rms[i];
        if (state->history_rms[i] > max_v) max_v = state->history_rms[i];
    }
    if (max_v <= 0) return 1;
    return ((max_v - min_v) / max_v) < 0.3f ? 1 : 0;
}

void ns_extract_band(
    const float *input, int count, float sample_rate,
    float low_hz, float high_hz, float *output)
{
    int fft_n = count > NS_MAX_FFT_SIZE ? NS_MAX_FFT_SIZE : count;
    int half_n = fft_n / 2;
    float *real = (float *)calloc(half_n, sizeof(float));
    float *imag = (float *)calloc(half_n, sizeof(float));
    if (!real || !imag) {
        memset(output, 0, sizeof(float) * count);
        free(real); free(imag);
        return;
    }

    simple_fft(input, real, imag, fft_n);

    float bin_width = sample_rate / (float)fft_n;
    int lo_bin = (int)(low_hz / bin_width);
    int hi_bin = (int)(high_hz / bin_width);
    for (int i = 0; i < half_n; i++) {
        if (i < lo_bin || i > hi_bin) {
            real[i] = 0;
            imag[i] = 0;
        }
    }

    simple_ifft(real, imag, output, fft_n);
    for (int i = fft_n; i < count; i++) output[i] = 0;

    free(real); free(imag);
}

ns_decomposition_t ns_decompose_multilayer(
    ns_state_t *state, const float *samples, int count, float sample_rate)
{
    ns_decomposition_t result;
    memset(&result, 0, sizeof(result));
    if (count < 4) return result;

    typedef struct { float lo; float hi; ns_noise_type_t primary; ns_noise_type_t secondary; } BandProfile;
    BandProfile profiles[] = {
        {20,   80,  NS_NOISE_WIND,       NS_NOISE_RAIN},
        {80,  250,  NS_NOISE_TRAFFIC,    NS_NOISE_MOTORCYCLE},
        {250, 500,  NS_NOISE_MOTORCYCLE, NS_NOISE_HVAC},
        {500, 4000, NS_NOISE_SPEECH,     NS_NOISE_UNKNOWN},
        {80,  2000, NS_NOISE_HVAC,       NS_NOISE_TRAFFIC},
    };
    int n_profiles = sizeof(profiles) / sizeof(profiles[0]);

    float *band_buf = (float *)calloc(count, sizeof(float));
    if (!band_buf) return result;

    float total_energy = 0;
    for (int i = 0; i < count; i++) total_energy += samples[i] * samples[i];
    total_energy = sqrtf(total_energy / (float)count);
    if (total_energy < 0.003f) { free(band_buf); return result; }

    int found_types[NS_NOISE_COUNT];
    float found_energy[NS_NOISE_COUNT];
    float found_conf[NS_NOISE_COUNT];
    memset(found_types, 0, sizeof(found_types));
    memset(found_energy, 0, sizeof(found_energy));
    memset(found_conf, 0, sizeof(found_conf));

    for (int p = 0; p < n_profiles; p++) {
        ns_extract_band(samples, count, sample_rate, profiles[p].lo, profiles[p].hi, band_buf);
        float band_rms = 0;
        for (int i = 0; i < count; i++) band_rms += band_buf[i] * band_buf[i];
        band_rms = sqrtf(band_rms / (float)count);

        float ratio = band_rms / total_energy;
        if (ratio < 0.15f) continue;

        ns_band_energy_t be = ns_compute_band_energy(band_buf, count, sample_rate);
        float crest = ns_compute_crest_factor(band_buf, count);
        int stationary = ns_is_stationary(state);
        ns_noise_type_t detected = ns_classify_noise(&be, crest, stationary);

        if (detected == NS_NOISE_QUIET || detected == NS_NOISE_UNKNOWN) {
            detected = profiles[p].primary;
        }

        if (band_rms > found_energy[detected]) {
            found_types[detected] = 1;
            found_energy[detected] = band_rms;
            found_conf[detected] = ratio > 0.4f ? 0.8f : (ratio > 0.25f ? 0.6f : 0.4f);
        }
    }

    for (int t = 0; t < NS_NOISE_COUNT && result.layer_count < NS_MAX_LAYERS; t++) {
        if (found_types[t] && t != NS_NOISE_QUIET) {
            result.layers[result.layer_count].type = (ns_noise_type_t)t;
            result.layers[result.layer_count].confidence = found_conf[t];
            result.layers[result.layer_count].energy = found_energy[t];
            result.layer_count++;
        }
    }

    for (int i = 0; i < result.layer_count - 1; i++) {
        for (int j = i + 1; j < result.layer_count; j++) {
            if (result.layers[j].energy > result.layers[i].energy) {
                ns_layer_t tmp = result.layers[i];
                result.layers[i] = result.layers[j];
                result.layers[j] = tmp;
            }
        }
    }

    free(band_buf);
    return result;
}
