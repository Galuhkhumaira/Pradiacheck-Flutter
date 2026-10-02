# Pradiacheck-Flutter

Flutter mobile app for diabetes risk detection from a tongue photo. The app classifies the photo into **Diabetes**, **Pradiabetes**, or **Nondiabetes** using a YOLO11n model that runs on-device (TFLite).

## Features

- **Diabetes Detection** — takes a tongue photo and classifies it as Diabetes / Pradiabetes / Nondiabetes
- **On-device inference** — the TFLite model is bundled in the app, so no backend or internet connection is needed for prediction
- **Reference image** — a tongue reference image to guide how the photo should be taken

> This app is a screening aid for a student/internship project, not a medical diagnosis. Consult a medical professional for any health decision.

## Folder Structure

Follows standard Flutter project conventions (`lib/` is Flutter's equivalent of `src/`):

```
Pradiacheck-Flutter/
├── lib/
│   ├── screens/        # one file per app screen (home_screen.dart, etc)
│   ├── services/       # tongue_classifier_service.dart, classification_result.dart
│   ├── widgets/        # shared/reusable UI components (app_theme.dart, etc)
│   └── main.dart
├── assets/             # images, models, logo
│   ├── Model/          # YOLOv11n_best.tflite, labels.txt
│   ├── images/
│   └── logo/
├── android/, ios/, linux/, macos/, windows/, web/   # per-platform build config (Flutter-generated)
├── test/
├── analysis_options.yaml
├── pubspec.yaml
└── README.md
```

## Running Locally

```bash
flutter pub get
flutter run
```

Build a release APK:

```bash
flutter build apk --release
```

## Model

| Item | Value |
|---|---|
| Architecture | YOLO11n (TFLite) |
| Model file | `assets/Model/YOLOv11n_best.tflite` |
| Labels file | `assets/Model/labels.txt` |
| Classes | Diabetes, Nondiabetes, Pradiabetes |

The model is loaded and run by `lib/services/tongue_classifier_service.dart`, and the output is wrapped in `lib/services/classification_result.dart`.

## Branching

- `main` — stable, submission/release-ready code
- `development` — active work, merged into `main` via PR once stable
- `feature/...`, `fix/...` — branched from `development`, deleted after merge
