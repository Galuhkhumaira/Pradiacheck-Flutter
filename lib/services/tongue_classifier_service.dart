import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Membungkus TFLite Interpreter untuk model YOLO **detection**.
///
/// PENTING — ini BUKAN classifier gambar biasa. Output model berbentuk
/// [1, 4 + jumlahKelas, jumlahAnchor] (mis. [1, 7, 8400] untuk 3 kelas),
/// bukan [1, jumlahKelas] seperti asumsi sebelumnya. Setiap salah satu
/// dari 8400 "anchor" adalah kandidat lokasi objek; 4 angka pertama di
/// tiap anchor adalah box (x, y, w, h), sisanya adalah skor per kelas.
///
/// Karena model betulan men-scan lokasi, kalau TIDAK ADA anchor mana pun
/// yang skornya di atas threshold, itu artinya model tidak menemukan
/// lidah di gambar sama sekali — inilah mekanisme untuk menolak gambar
/// yang bukan citra lidah.
class TongueClassifierService {
  TongueClassifierService._();
  static final TongueClassifierService instance = TongueClassifierService._();

  static const String modelAssetPath = 'assets/Model/YOLOv11n_best.tflite';
  static const String labelsAssetPath = 'assets/Model/labels.txt';

  /// Skor kelas (setelah sigmoid, kalau perlu) minimum supaya sebuah
  /// anchor dianggap deteksi valid. Ini beda konsepnya dari threshold
  /// classifier biasa — di YOLO ini disebut "confidence threshold".
  /// Mulai dari 0.5, bisa disetel ulang setelah lihat distribusi skor
  /// asli lewat debugPrint di bawah.
  static const double confidenceThreshold = 0.5;

  Interpreter? _interpreter;
  List<String>? _labels;

  Future<void> _ensureLoaded() async {
    if (_interpreter != null && _labels != null) return;

    _interpreter = await Interpreter.fromAsset(modelAssetPath);

    final rawLabels = await rootBundle.loadString(labelsAssetPath);
    _labels = rawLabels
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<ClassifierRawResult> classify(File imageFile) async {
    await _ensureLoaded();
    final interpreter = _interpreter!;
    final labels = _labels!;

    final inputTensor = interpreter.getInputTensor(0);
    final inputShape = inputTensor.shape;

    // --- DEBUG: tipe & parameter tensor, buat cek apakah modelnya
    // quantized (int8/uint8) — kalau iya, cara baca raw pixel & output
    // di bawah ini SALAH TOTAL dan perlu dequantize pakai scale/zeroPoint.
    debugPrint('[TongueClassifier] inputTensor type=${inputTensor.type} '
        'shape=$inputShape params=${inputTensor.params}');

    // PENTING: model ini ternyata NCHW ([1, 3, H, W]), bukan NHWC standar
    // ([1, H, W, 3]) — terkonfirmasi dari shape=[1, 3, 640, 640]. Kalau
    // dibaca dengan asumsi NHWC, inputHeight ke-ambil = 3 (channel count!)
    // dan gambar hancur total pas di-resize. Deteksi otomatis di sini:
    // dim channel (3) ada di index 1 (NCHW) atau index 3 (NHWC).
    final bool isNCHW = inputShape[1] == 3 || inputShape[1] == 1;
    final int inputHeight = isNCHW ? inputShape[2] : inputShape[1];
    final int inputWidth = isNCHW ? inputShape[3] : inputShape[2];

    debugPrint('[TongueClassifier] layout=${isNCHW ? "NCHW" : "NHWC"} '
        'inputHeight=$inputHeight inputWidth=$inputWidth');

    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Gagal membaca file gambar untuk inferensi.');
    }
    final resized = img.copyResize(
      decoded,
      width: inputWidth,
      height: inputHeight,
    );

    // Sample pixel dari gambar hasil resize, buat pastikan nilai warnanya
    // masuk akal (bukan semuanya sama gara-gara bug decode/resize).
    final samplePixel1 = resized.getPixel(0, 0);
    final samplePixel2 = resized.getPixel(inputWidth ~/ 2, inputHeight ~/ 2);
    debugPrint('[TongueClassifier] sample pixel (0,0) r,g,b='
        '${samplePixel1.r},${samplePixel1.g},${samplePixel1.b}');
    debugPrint('[TongueClassifier] sample pixel (tengah) r,g,b='
        '${samplePixel2.r},${samplePixel2.g},${samplePixel2.b}');

    // Susun tensor input SESUAI layout yang terdeteksi. Untuk NCHW, urutan
    // dimensinya [1][channel][y][x] — beda dari NHWC [1][y][x][channel].
    final dynamic input;
    if (isNCHW) {
      input = [
        List.generate(
          3,
          (c) => List.generate(
            inputHeight,
            (y) => List.generate(inputWidth, (x) {
              final pixel = resized.getPixel(x, y);
              switch (c) {
                case 0:
                  return pixel.r / 255.0;
                case 1:
                  return pixel.g / 255.0;
                default:
                  return pixel.b / 255.0;
              }
            }),
          ),
        ),
      ];
    } else {
      input = [
        List.generate(
          inputHeight,
          (y) => List.generate(inputWidth, (x) {
            final pixel = resized.getPixel(x, y);
            return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
          }),
        ),
      ];
    }

    // Output YOLO detection: [1, 4 + jumlahKelas, jumlahAnchor]
    final outputTensor = interpreter.getOutputTensor(0);
    final outputShape = outputTensor.shape;
    final numChannels = outputShape[1]; // 4 + jumlahKelas
    final numAnchors = outputShape[2];
    final numClasses = numChannels - 4;

    debugPrint('[TongueClassifier] outputTensor type=${outputTensor.type} '
        'shape=$outputShape params=${outputTensor.params}');

    if (numClasses != labels.length) {
      debugPrint(
          '[TongueClassifier] PERINGATAN: jumlah kelas di output model '
          '($numClasses) tidak sama dengan jumlah baris labels.txt '
          '(${labels.length}). Cek urutan/isi labels.txt.');
    }

    final output = [
      List.generate(numChannels, (_) => List.filled(numAnchors, 0.0))
    ];

    interpreter.run(input, output);
    final raw = output[0]; // [numChannels][numAnchors]

    // Cari anchor dengan skor kelas tertinggi di seluruh 8400 titik.
    var bestAnchor = -1;
    var bestClassIdx = -1;
    var bestScore = -1.0;
    var sampleMin = double.infinity;
    var sampleMax = -double.infinity;

    for (var a = 0; a < numAnchors; a++) {
      for (var c = 0; c < numClasses; c++) {
        final score = raw[4 + c][a];
        if (score < sampleMin) sampleMin = score;
        if (score > sampleMax) sampleMax = score;
        if (score > bestScore) {
          bestScore = score;
          bestAnchor = a;
          bestClassIdx = c;
        }
      }
    }

    // Kalau nilai mentahnya di luar rentang 0..1, berarti model belum
    // di-sigmoid saat export — terapkan sigmoid manual di sini.
    final looksLikeLogits = sampleMin < -0.01 || sampleMax > 1.01;
    final finalScore =
        looksLikeLogits ? _sigmoid(bestScore) : bestScore.clamp(0.0, 1.0);

    debugPrint('[TongueClassifier] outputShape=$outputShape '
        '(numChannels=$numChannels, numAnchors=$numAnchors, numClasses=$numClasses)');
    debugPrint('[TongueClassifier] rentang skor mentah kelas: '
        '$sampleMin .. $sampleMax (looksLikeLogits=$looksLikeLogits)');
    debugPrint('[TongueClassifier] anchor terbaik=$bestAnchor '
        'kelas=$bestClassIdx skorMentah=$bestScore skorFinal=$finalScore');

    final isRecognized =
        bestAnchor != -1 && finalScore >= confidenceThreshold;
    final label = (bestClassIdx >= 0 && bestClassIdx < labels.length)
        ? labels[bestClassIdx]
        : 'Unknown';

    return ClassifierRawResult(
      label: label,
      confidence: finalScore,
      isRecognized: isRecognized,
    );
  }

  double _sigmoid(double x) => 1 / (1 + math.exp(-x));

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _labels = null;
  }
}

class ClassifierRawResult {
  final String label;
  final double confidence; // 0.0 - 1.0
  final bool isRecognized; // false kalau tidak ada anchor lolos threshold

  const ClassifierRawResult({
    required this.label,
    required this.confidence,
    required this.isRecognized,
  });
}