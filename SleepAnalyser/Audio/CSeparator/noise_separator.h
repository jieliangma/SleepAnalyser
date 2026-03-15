#ifndef NOISE_SEPARATOR_H
#define NOISE_SEPARATOR_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define NS_MAX_FFT_SIZE 2048
#define NS_MAX_BANDS 8
#define NS_LABEL_LEN 32

typedef struct {
    float sub_bass;
    float bass;
    float low_mid;
    float mid;
    float high_mid;
    float presence;
    float brilliance;
    float total_rms;
} ns_band_energy_t;

typedef enum {
    NS_NOISE_QUIET = 0,
    NS_NOISE_WIND,
    NS_NOISE_TRAFFIC,
    NS_NOISE_MOTORCYCLE,
    NS_NOISE_HVAC,
    NS_NOISE_RAIN,
    NS_NOISE_SPEECH,
    NS_NOISE_UNKNOWN,
    NS_NOISE_COUNT
} ns_noise_type_t;

typedef struct {
    ns_noise_type_t type;
    float confidence;
    float energy_db;
    float duration_sec;
    double timestamp;
} ns_noise_segment_t;

typedef struct {
    int fft_size;
    float sample_rate;
    float noise_floor[NS_MAX_FFT_SIZE / 2];
    int noise_floor_initialized;
    float smoothing_alpha;
    int frame_count;
    float history_rms[64];
    int history_idx;
    int history_len;
} ns_state_t;

void ns_init(ns_state_t *state, int fft_size, float sample_rate);
void ns_reset(ns_state_t *state);

ns_band_energy_t ns_compute_band_energy(
    const float *samples, int count, float sample_rate);

void ns_update_noise_floor(
    ns_state_t *state, const float *samples, int count);

void ns_separate_noise(
    ns_state_t *state,
    const float *input, int count,
    float *foreground_out,
    float *background_out);

ns_noise_type_t ns_classify_noise(
    const ns_band_energy_t *bands, float crest_factor, int is_stationary);

float ns_compute_crest_factor(const float *samples, int count);

int ns_is_stationary(const ns_state_t *state);

void ns_extract_band(
    const float *input, int count, float sample_rate,
    float low_hz, float high_hz, float *output);

#ifdef __cplusplus
}
#endif

#endif
