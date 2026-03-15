#!/usr/bin/env python3
"""
Train 3 Core ML models for SleepAnalyser:
1. SleepStageClassifier - predicts sleep stage from audio features
2. SnoreDetector - binary snore vs non-snore
3. NoiseContextClassifier - classifies noise environment

Uses synthetic data based on sleep science literature for breathing patterns.
"""
import numpy as np
from sklearn.ensemble import GradientBoostingClassifier, RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import Pipeline
import coremltools as ct
import os, json

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "SleepAnalyser", "Resources", "ML")
os.makedirs(OUT_DIR, exist_ok=True)

np.random.seed(42)

FEATURE_NAMES = [
    "mfcc_0", "mfcc_1", "mfcc_2", "mfcc_3", "mfcc_4", "mfcc_5",
    "mfcc_6", "mfcc_7", "mfcc_8", "mfcc_9", "mfcc_10", "mfcc_11", "mfcc_12",
    "spectral_centroid", "spectral_rolloff", "spectral_flatness",
    "zero_crossing_rate", "rms_energy",
    "breathing_periodicity", "breath_interval_variability"
]

# === Sleep Stage Classifier ===

def generate_sleep_stage_data(n_per_class=2000):
    X, y = [], []
    classes = {
        # stage: (resp_rate_mean, resp_rate_std, regularity_mean, reg_std, rms_mean, rms_std)
        "awake":  (17.0, 3.0, 0.3, 0.15, 0.15, 0.08),
        "n1":     (13.0, 2.0, 0.5, 0.12, 0.04, 0.02),
        "n2":     (12.0, 1.5, 0.7, 0.10, 0.03, 0.015),
        "n3":     (9.0,  1.0, 0.85, 0.08, 0.02, 0.01),
        "rem":    (16.0, 2.5, 0.35, 0.15, 0.05, 0.025),
    }
    for stage, (rr_m, rr_s, reg_m, reg_s, rms_m, rms_s) in classes.items():
        for _ in range(n_per_class):
            resp_rate = np.clip(np.random.normal(rr_m, rr_s), 5, 30)
            regularity = np.clip(np.random.normal(reg_m, reg_s), 0, 1)
            rms = np.clip(np.random.normal(rms_m, rms_s), 0.001, 0.5)
            variability = np.clip(1.0 - regularity + np.random.normal(0, 0.1), 0, 1)
            centroid = np.random.normal(400 if stage == "awake" else 250, 80)
            rolloff = np.random.normal(0.7, 0.15)
            flatness = np.random.normal(0.4 if stage in ("awake", "rem") else 0.25, 0.1)
            zcr = np.random.normal(0.08 if stage == "awake" else 0.04, 0.02)
            mfcc = np.random.normal(0, 1, 13)
            if stage == "n3":
                mfcc[0] += 2.0
            elif stage == "rem":
                mfcc[1] -= 1.5

            features = list(mfcc) + [centroid, rolloff, flatness, zcr, rms, resp_rate, variability]
            X.append(features)
            y.append(stage)
    return np.array(X, dtype=np.float32), np.array(y)


def train_sleep_stage_model():
    print("Training SleepStageClassifier...")
    X, y = generate_sleep_stage_data(2000)
    pipe = Pipeline([
        ("scaler", StandardScaler()),
        ("clf", RandomForestClassifier(
            n_estimators=200, max_depth=12,
            min_samples_leaf=5, random_state=42
        ))
    ])
    pipe.fit(X, y)

    from sklearn.metrics import classification_report
    pred = pipe.predict(X)
    print(classification_report(y, pred))

    model = ct.converters.sklearn.convert(
        pipe,
        input_features=FEATURE_NAMES,
        output_feature_names="predictedStage"
    )
    model.author = "SleepAnalyser"
    model.short_description = "Classifies sleep stage from 30-second audio features"
    model.input_description["mfcc_0"] = "MFCC coefficient 0"
    model.input_description["breathing_periodicity"] = "Estimated breathing rate (BPM)"
    model.input_description["breath_interval_variability"] = "Breath interval variability (0-1)"
    model.input_description["rms_energy"] = "RMS energy of audio frame"

    out_path = os.path.join(OUT_DIR, "SleepStageClassifier.mlmodel")
    model.save(out_path)
    print(f"Saved: {out_path}")
    return out_path


# === Snore Detector ===

def generate_snore_data(n_per_class=3000):
    X, y = [], []
    for _ in range(n_per_class):
        # Snore: low-freq harmonics, moderate energy, low ZCR
        centroid = np.random.normal(200, 50)
        rolloff = np.random.normal(0.4, 0.1)
        flatness = np.random.normal(0.15, 0.05)
        zcr = np.random.normal(0.03, 0.01)
        rms = np.random.normal(0.08, 0.03)
        mfcc = np.random.normal(0, 1, 13)
        mfcc[0] += 3.0
        mfcc[2] += 1.5
        features = list(mfcc) + [centroid, rolloff, flatness, zcr, rms, 0, 0]
        X.append(features)
        y.append(1)

    for _ in range(n_per_class):
        # Non-snore: varied
        centroid = np.random.normal(500, 200)
        rolloff = np.random.normal(0.7, 0.2)
        flatness = np.random.normal(0.5, 0.2)
        zcr = np.random.normal(0.08, 0.04)
        rms = np.random.normal(0.03, 0.02)
        mfcc = np.random.normal(0, 1, 13)
        features = list(mfcc) + [centroid, rolloff, flatness, zcr, rms, 0, 0]
        X.append(features)
        y.append(0)

    return np.array(X, dtype=np.float32), np.array(y)


def train_snore_model():
    print("Training SnoreDetector...")
    X, y = generate_snore_data(3000)
    pipe = Pipeline([
        ("scaler", StandardScaler()),
        ("clf", RandomForestClassifier(n_estimators=150, max_depth=8, random_state=42))
    ])
    pipe.fit(X, y)

    from sklearn.metrics import accuracy_score
    print(f"Accuracy: {accuracy_score(y, pipe.predict(X)):.3f}")

    model = ct.converters.sklearn.convert(
        pipe,
        input_features=FEATURE_NAMES,
        output_feature_names="isSnore"
    )
    model.author = "SleepAnalyser"
    model.short_description = "Detects snoring from audio features"

    out_path = os.path.join(OUT_DIR, "SnoreDetector.mlmodel")
    model.save(out_path)
    print(f"Saved: {out_path}")
    return out_path


# === Noise Context Classifier ===

def generate_noise_data(n_per_class=1500):
    X, y = [], []
    noise_profiles = {
        "quiet":    {"centroid": (150, 50), "rms": (0.005, 0.003), "flatness": (0.3, 0.1)},
        "traffic":  {"centroid": (180, 60), "rms": (0.08, 0.04),  "flatness": (0.5, 0.15)},
        "wind":     {"centroid": (80, 30),  "rms": (0.06, 0.03),  "flatness": (0.7, 0.1)},
        "speech":   {"centroid": (600, 150),"rms": (0.05, 0.02),  "flatness": (0.3, 0.1)},
        "hvac":     {"centroid": (250, 80), "rms": (0.04, 0.015), "flatness": (0.6, 0.1)},
    }
    for label, profile in noise_profiles.items():
        for _ in range(n_per_class):
            centroid = np.random.normal(*profile["centroid"])
            rms = np.clip(np.random.normal(*profile["rms"]), 0.001, 0.5)
            flatness = np.clip(np.random.normal(*profile["flatness"]), 0, 1)
            rolloff = np.random.normal(0.6, 0.15)
            zcr = np.random.normal(0.05, 0.02)
            mfcc = np.random.normal(0, 1, 13)
            features = list(mfcc) + [centroid, rolloff, flatness, zcr, rms, 0, 0]
            X.append(features)
            y.append(label)
    return np.array(X, dtype=np.float32), np.array(y)


def train_noise_model():
    print("Training NoiseContextClassifier...")
    X, y = generate_noise_data(1500)
    pipe = Pipeline([
        ("scaler", StandardScaler()),
        ("clf", RandomForestClassifier(
            n_estimators=150, max_depth=10, random_state=42
        ))
    ])
    pipe.fit(X, y)

    from sklearn.metrics import classification_report
    pred = pipe.predict(X)
    print(classification_report(y, pred))

    model = ct.converters.sklearn.convert(
        pipe,
        input_features=FEATURE_NAMES,
        output_feature_names="noiseContext"
    )
    model.author = "SleepAnalyser"
    model.short_description = "Classifies environmental noise context"

    out_path = os.path.join(OUT_DIR, "NoiseContextClassifier.mlmodel")
    model.save(out_path)
    print(f"Saved: {out_path}")
    return out_path


# === Compile to .mlmodelc ===

def compile_model(mlmodel_path):
    import subprocess
    name = os.path.splitext(os.path.basename(mlmodel_path))[0]
    mlmodelc_path = os.path.join(OUT_DIR, name + ".mlmodelc")
    if os.path.exists(mlmodelc_path):
        import shutil
        shutil.rmtree(mlmodelc_path)
    result = subprocess.run(
        ["xcrun", "coremlcompiler", "compile", mlmodel_path, OUT_DIR],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"Compile error for {name}: {result.stderr}")
    else:
        print(f"Compiled: {mlmodelc_path}")
    os.remove(mlmodel_path)


if __name__ == "__main__":
    paths = []
    paths.append(train_sleep_stage_model())
    paths.append(train_snore_model())
    paths.append(train_noise_model())

    print("\nCompiling models to .mlmodelc...")
    for p in paths:
        compile_model(p)

    print("\nDone! Models at:", OUT_DIR)
    for f in sorted(os.listdir(OUT_DIR)):
        full = os.path.join(OUT_DIR, f)
        if os.path.isdir(full):
            size = sum(os.path.getsize(os.path.join(dp, fn)) for dp, _, fns in os.walk(full) for fn in fns)
            print(f"  {f}: {size/1024:.0f} KB")
