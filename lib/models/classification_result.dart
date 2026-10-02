import 'dart:io';

import '../services/tongue_classifier_service.dart';

enum TongueCategory { nonDiabetes, prediabetes, diabetes }

class ClassificationResult {
  final TongueCategory category;
  final double confidence; // 0.0 - 1.0
  final int inferenceTimeMs;

  ClassificationResult({
    required this.category,
    required this.confidence,
    required this.inferenceTimeMs,
  });

  String get label {
    switch (category) {
      case TongueCategory.nonDiabetes:
        return 'Non-Diabetes';
      case TongueCategory.prediabetes:
        return 'Pradiabetes';
      case TongueCategory.diabetes:
        return 'Diabetes';
    }
  }

  String get description {
    switch (category) {
      case TongueCategory.nonDiabetes:
        return 'Tidak ditemukan indikasi risiko diabetes pada citra lidah.';
      case TongueCategory.prediabetes:
        return 'Terindikasi risiko pradiabetes. Disarankan konsultasi ke tenaga kesehatan untuk pemeriksaan lanjutan.';
      case TongueCategory.diabetes:
        return 'Terindikasi risiko diabetes. Segera lakukan pemeriksaan medis lebih lanjut.';
    }
  }
}

/// Dilempar oleh [classifyTongueImage] kalau skor tertinggi dari model
/// berada di bawah [TongueClassifierService.minConfidenceThreshold] —
/// artinya gambar yang diunggah kemungkinan besar BUKAN citra lidah.
class NotATongueImageException implements Exception {
  final double confidence;
  const NotATongueImageException(this.confidence);

  @override
  String toString() =>
      'Gambar tidak dikenali sebagai citra lidah (skor tertinggi: '
      '${(confidence * 100).toStringAsFixed(1)}%)';
}

/// Mengubah label mentah dari labels.txt (mis. "Non-Diabetes", "nondiabetes",
/// "Pradiabetes", "Diabetes") menjadi salah satu nilai [TongueCategory].
/// Dibuat fleksibel terhadap variasi spasi/strip/huruf besar-kecil supaya
/// tidak gampang patah kalau format labels.txt sedikit berubah.
TongueCategory _categoryFromLabel(String rawLabel) {
  final normalized = rawLabel.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
  if (normalized.contains('nondiabetes') || normalized == 'normal') {
    return TongueCategory.nonDiabetes;
  }
  if (normalized.contains('pradiabetes') || normalized.contains('prediabetes')) {
    return TongueCategory.prediabetes;
  }
  if (normalized.contains('diabetes')) {
    return TongueCategory.diabetes;
  }
  throw Exception('Label dari model tidak dikenali: "$rawLabel". '
      'Cek isi labels.txt, formatnya belum dikenali oleh _categoryFromLabel().');
}

/// Menjalankan inferensi TFLite yang sesungguhnya lewat
/// [TongueClassifierService], lalu membungkus hasilnya jadi
/// [ClassificationResult] yang dipakai di UI.
///
/// Melempar [NotATongueImageException] kalau model tidak cukup yakin
/// gambar yang diunggah adalah citra lidah (lihat isRecognized di
/// TongueClassifierService.classify()).
Future<ClassificationResult> classifyTongueImage(File imageFile) async {
  final stopwatch = Stopwatch()..start();

  final raw = await TongueClassifierService.instance.classify(imageFile);

  if (!raw.isRecognized) {
    stopwatch.stop();
    throw NotATongueImageException(raw.confidence);
  }

  stopwatch.stop();

  return ClassificationResult(
    category: _categoryFromLabel(raw.label),
    confidence: raw.confidence,
    inferenceTimeMs: stopwatch.elapsedMilliseconds,
  );
}