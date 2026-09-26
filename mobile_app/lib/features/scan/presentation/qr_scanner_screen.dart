import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/app_router.dart';

/// QR Scanner screen — camera viewfinder with overlay and URL extraction
class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;
  bool _flashOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    final url = barcode?.rawValue;

    if (url == null || url.isEmpty) return;
    _scanned = true;
    await _controller.stop();

    if (!mounted) return;
    // Show extracted URL bottom sheet, then proceed to scan
    _showUrlBottomSheet(url);
  }

  void _showUrlBottomSheet(String url) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? AppColors.cardBorderDark : AppColors.cardBorderLight),
      ),
      builder: (_) => _QrResultSheet(
        url: url,
        onScan: () {
          Navigator.pop(context);
          context.push(AppRoutes.analysis, extra: {
            'type': 'qr',
            'value': url,
          });
        },
        onDismiss: () {
          Navigator.pop(context);
          setState(() => _scanned = false);
          _controller.start();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.primaryLight;
    final warning = isDark ? AppColors.warning : AppColors.warningLight;
    final background = isDark ? Colors.black : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        title: Text('QR Scanner',
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 20)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _flashOn ? warning : textSecondary,
            ),
            onPressed: () {
              _controller.toggleTorch();
              setState(() => _flashOn = !_flashOn);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Camera view
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Scanning overlay
          _QrScanOverlay(isDark: isDark, primary: primary),

          // Instructions
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Point camera at a QR code',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 500.ms),
          ),
        ],
      ),
    );
  }
}

/// Viewfinder overlay with animated corner brackets
class _QrScanOverlay extends StatelessWidget {
  final bool isDark;
  final Color primary;
  
  const _QrScanOverlay({required this.isDark, required this.primary});
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dimmed surround
        ColorFiltered(
          colorFilter: const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
          child: CustomPaint(
            painter: _OverlayPainter(),
            child: const SizedBox.expand(),
          ),
        ),
        // Corner brackets
        Center(
          child: SizedBox(
            width: 240,
            height: 240,
            child: CustomPaint(painter: _CornerPainter(primary: primary)),
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true))
            .custom(
              duration: 1200.ms,
              builder: (_, value, child) => Opacity(opacity: 0.7 + value * 0.3, child: child),
            ),
      ],
    );
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cut = 240.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: cut, height: cut);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.55));
  }

  @override
  bool shouldRepaint(_) => false;
}

class _CornerPainter extends CustomPainter {
  final Color primary;
  
  _CornerPainter({required this.primary});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 24.0;
    const r = 12.0;

    // Top-left
    canvas.drawLine(const Offset(r, 0), const Offset(r + len, 0), paint);
    canvas.drawLine(const Offset(0, r), const Offset(0, r + len), paint);
    canvas.drawArc(const Rect.fromLTWH(0, 0, r * 2, r * 2), 3.14, 1.57, false, paint);

    // Top-right
    canvas.drawLine(Offset(size.width - r - len, 0), Offset(size.width - r, 0), paint);
    canvas.drawLine(Offset(size.width, r), Offset(size.width, r + len), paint);
    canvas.drawArc(Rect.fromLTWH(size.width - r * 2, 0, r * 2, r * 2), -1.57, 1.57, false, paint);

    // Bottom-left
    canvas.drawLine(const Offset(0, 0), Offset(0, size.height - r - len), paint);
    canvas.drawLine(const Offset(r, 0), const Offset(r + len, 0), paint);
    canvas.drawLine(Offset(0, size.height - r), Offset(0, size.height - r - len), paint);
    canvas.drawLine(Offset(r, size.height), Offset(r + len, size.height), paint);
    canvas.drawArc(Rect.fromLTWH(0, size.height - r * 2, r * 2, r * 2), 1.57, 1.57, false, paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width - r - len, size.height), Offset(size.width - r, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height - r), Offset(size.width, size.height - r - len), paint);
    canvas.drawArc(Rect.fromLTWH(size.width - r * 2, size.height - r * 2, r * 2, r * 2), 0, 1.57, false, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Bottom sheet shown after QR detection
class _QrResultSheet extends StatelessWidget {
  final String url;
  final VoidCallback onScan;
  final VoidCallback onDismiss;

  const _QrResultSheet({required this.url, required this.onScan, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final divider = isDark ? AppColors.dividerDark : AppColors.dividerLight;
    final primaryContainer = isDark ? AppColors.primaryContainer : AppColors.primaryContainerLight;
    final primary = isDark ? AppColors.primary : AppColors.primaryLight;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final cardBorder = isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.qr_code_rounded, color: primary),
              ),
              const SizedBox(width: 14),
              Text('QR Code Detected',
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorder),
            ),
            child: Text(
              url,
              style: TextStyle(
                  color: textSecondary, fontSize: 13, fontFamily: 'monospace'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDismiss,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: cardBorder),
                    foregroundColor: textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Scan Again'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onScan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: isDark ? const Color(0xFF001A1F) : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Check URL', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 16),
        ],
      ),
    );
  }
}
