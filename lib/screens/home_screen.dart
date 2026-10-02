import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/classification_result.dart';
import '../theme/app_theme.dart';

/// Halaman utama — sekarang jadi satu-satunya halaman untuk fitur
/// Deteksi Diabetes: ambil/unggah gambar lidah, tekan Cek, lihat hasil,
/// semua tanpa pindah halaman (tidak lagi push ke CaptureScreen).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  bool _isChecking = false;
  ClassificationResult? _result;
  // Error teknis (gagal baca file, model gagal load, dll) — beda dari
  // kasus "bukan citra lidah" supaya UI bisa kasih pesan yang sesuai.
  String? _errorMessage;
  // Terisi kalau model TFLite yakin gambar yang diunggah bukan citra
  // lidah (lihat NotATongueImageException di models/classification_result.dart).
  String? _notTongueMessage;

  Future<void> _showImageSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.camera_alt_outlined,
                    color: AppColors.primary),
                title: Text(
                  'Ambil dari Kamera',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined,
                    color: AppColors.primary),
                title: Text(
                  'Pilih dari Galeri',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (source != null) {
      await _pickImage(source);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (picked == null) return;
      setState(() {
        _selectedImage = File(picked.path);
        _result = null;
        _errorMessage = null;
        _notTongueMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal mengambil gambar: $e';
      });
    }
  }

  Future<void> _checkImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isChecking = true;
      _errorMessage = null;
      _notTongueMessage = null;
      _result = null;
    });

    try {
      // Inferensi TFLite yang sesungguhnya lewat TongueClassifierService,
      // bukan mock lagi. Kalau modelnya kurang yakin ini citra lidah,
      // classifyTongueImage() melempar NotATongueImageException — ditangani
      // terpisah di bawah supaya UI-nya beda dari error teknis biasa.
      final result = await classifyTongueImage(_selectedImage!);

      if (!mounted) return;
      setState(() {
        _result = result;
        _isChecking = false;
      });
    } on NotATongueImageException catch (e) {
      if (!mounted) return;
      setState(() {
        _notTongueMessage =
            'Gambar tidak terdeteksi sebagai citra lidah (skor tertinggi: '
            '${(e.confidence * 100).toStringAsFixed(1)}%). Coba foto ulang '
            'dengan lidah terlihat jelas dan pencahayaan cukup.';
        _isChecking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memproses gambar: $e';
        _isChecking = false;
      });
    }
  }

  Color _colorForCategory(TongueCategory category) {
    switch (category) {
      case TongueCategory.nonDiabetes:
        return const Color(0xFF2E7D32); // hijau
      case TongueCategory.prediabetes:
        return const Color(0xFFE08A00); // oranye
      case TongueCategory.diabetes:
        return const Color(0xFFC62828); // merah
    }
  }

  IconData _iconForCategory(TongueCategory category) {
    switch (category) {
      case TongueCategory.nonDiabetes:
        return Icons.check_circle_outline_rounded;
      case TongueCategory.prediabetes:
        return Icons.warning_amber_rounded;
      case TongueCategory.diabetes:
        return Icons.error_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ============================================================
              // KARTU HIGHLIGHT — Cara Pakai (background gambar referensi lidah)
              // ============================================================
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: SizedBox(
                  width: double.infinity,
                  // Tinggi tetap — ini kuncinya supaya gambar di-crop rapi
                  // oleh BoxFit.cover dan tidak "bocor" keluar kartu.
                  height: 260,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/tongue_reference.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                      // Gradient gelap dari bawah ke atas supaya teks
                      // tetap terbaca tapi gambar tidak tertutup rata.
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.75),
                              Colors.black.withOpacity(0.45),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.info_outline_rounded,
                                      color: Colors.white, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Tata Cara Pemakaian',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Deteksi Diabetes dari Citra Lidah',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '1. Ambil atau unggah gambar lidahmu.\n'
                              '2. Pastikan lidah terlihat jelas dan pencahayaan cukup.\n'
                              '3. Tekan tombol "Cek" untuk melihat hasilnya.',
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ============================================================
              // AREA AMBIL / UNGGAH GAMBAR
              // ============================================================
              Text(
                'Deteksi Diabetes',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),

              GestureDetector(
                onTap: _showImageSourceSheet,
                child: Container(
                  width: double.infinity,
                  height: 220,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.divider),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _selectedImage != null
                      ? Image.file(_selectedImage!, fit: BoxFit.cover)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_outlined,
                                color: AppColors.textSecondary, size: 40),
                            const SizedBox(height: 10),
                            Text(
                              'Belum ada gambar dipilih',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ketuk untuk ambil foto atau unggah',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: AppColors.textSecondary.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_selectedImage == null || _isChecking)
                      ? null
                      : _checkImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isChecking
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Cek',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // ============================================================
              // AREA HASIL
              // ============================================================
              Text(
                'Hasil',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.divider),
                ),
                child: _buildResultContent(),
              ),

              const SizedBox(height: 20),
              Text(
                'Alat bantu skrining awal — bukan pengganti diagnosis medis.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultContent() {
    if (_errorMessage != null) {
      return Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.redAccent),
            ),
          ),
        ],
      );
    }

    if (_isChecking) {
      return Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'Memproses gambar...',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }

    if (_notTongueMessage != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE08A00).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.help_outline_rounded,
                color: Color(0xFFE08A00), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bukan Citra Lidah',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE08A00),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _notTongueMessage!,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_result == null) {
      return Text(
        'Hasil akan muncul di sini setelah kamu menekan tombol "Cek".',
        style: GoogleFonts.inter(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      );
    }

    final result = _result!;
    final classColor = _colorForCategory(result.category);
    final classIcon = _iconForCategory(result.category);
    final confidencePercent = result.confidence * 100;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: classColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(classIcon, color: classColor, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.label,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: classColor,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (confidencePercent / 100).clamp(0, 1),
                  minHeight: 6,
                  backgroundColor: classColor.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(classColor),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tingkat keyakinan: ${confidencePercent.toStringAsFixed(1)}%',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                result.description,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}