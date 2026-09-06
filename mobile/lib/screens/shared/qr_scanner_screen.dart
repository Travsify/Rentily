import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../constants/app_colors.dart';

enum QRScannerMode {
  any,
  gatePass,
  cryptoAddress,
  partnerId,
}

class QRScannerScreen extends StatefulWidget {
  final QRScannerMode mode;
  final String? title;
  final String? instruction;

  const QRScannerScreen({
    super.key,
    this.mode = QRScannerMode.any,
    this.title,
    this.instruction,
  });

  /// Helper static launcher to push scanner and get scanned string
  static Future<String?> startScan(
    BuildContext context, {
    QRScannerMode mode = QRScannerMode.any,
    String? title,
    String? instruction,
  }) async {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => QRScannerScreen(
          mode: mode,
          title: title,
          instruction: instruction,
        ),
      ),
    );
  }

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> with SingleTickerProviderStateMixin {
  late MobileScannerController _controller;
  late AnimationController _animController;
  bool _isProcessing = false;
  bool _torchEnabled = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue?.trim();
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => _isProcessing = true);

    // Audio & haptic feedback on successful scan
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);

    // Clean and extract code if inside a URL or JSON
    String extracted = rawValue;

    // Handle gate pass URL: https://myrentilly.com/gate-pass/123456 or /gp/123456
    final gpUrlMatch = RegExp(r'(?:gate-pass|gp|code)[=/]([A-Za-z0-9\-_]+)', caseSensitive: false).firstMatch(rawValue);
    if (gpUrlMatch != null) {
      extracted = gpUrlMatch.group(1) ?? rawValue;
    }

    // Handle partner verify URL: https://myrentilly.com/verify-partner/PTR-XXXX
    final ptrUrlMatch = RegExp(r'(?:verify-partner|partner)[=/]([A-Za-z0-9\-_]+)', caseSensitive: false).firstMatch(rawValue);
    if (ptrUrlMatch != null) {
      extracted = ptrUrlMatch.group(1) ?? rawValue;
    }

    // If looking for crypto, strip uri scheme like tron:T... or ethereum:0x...
    if (widget.mode == QRScannerMode.cryptoAddress || extracted.contains(':')) {
      final cryptoMatch = RegExp(r'^(?:tron|ethereum|bitcoin|usdt):([A-Za-z0-9]+)', caseSensitive: false).firstMatch(extracted);
      if (cryptoMatch != null) {
        extracted = cryptoMatch.group(1) ?? extracted;
      }
    }

    // Brief delay to allow feedback before popping
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        Navigator.of(context).pop(extracted);
      }
    });
  }

  void _toggleTorch() async {
    await _controller.toggleTorch();
    setState(() {
      _torchEnabled = !_torchEnabled;
    });
  }

  void _switchCamera() async {
    await _controller.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanBoxSize = size.width * 0.74;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera View
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // 2. Dark Mask Overlay with Transparent Viewfinder Hole
          CustomPaint(
            size: size,
            painter: _ScannerOverlayPainter(
              scanBoxSize: scanBoxSize,
              overlayColor: Colors.black.withValues(alpha: 0.65),
              borderColor: const Color(0xFF00E676),
            ),
          ),

          // 3. Animated Laser Beam
          Center(
            child: SizedBox(
              width: scanBoxSize - 20,
              height: scanBoxSize - 20,
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Stack(
                    children: [
                      Positioned(
                        top: (scanBoxSize - 24) * _animController.value,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2.5,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00E676).withValues(alpha: 0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                Color(0xFF00E676),
                                Colors.white,
                                Color(0xFF00E676),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // 4. Top AppBar & Controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    radius: 20,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Text(
                    widget.title ?? _defaultTitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.black.withValues(alpha: 0.5),
                        radius: 20,
                        child: IconButton(
                          icon: Icon(
                            _torchEnabled ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                            color: _torchEnabled ? const Color(0xFFFFD600) : Colors.white,
                            size: 20,
                          ),
                          onPressed: _toggleTorch,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: Colors.black.withValues(alpha: 0.5),
                        radius: 20,
                        child: IconButton(
                          icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 20),
                          onPressed: _switchCamera,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 5. Bottom Instructions & Manual Input Option
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.qr_code_scanner_rounded, size: 18, color: Color(0xFF00E676)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.instruction ?? _defaultInstruction,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _promptManualInput(context),
                  child: Text(
                    'Enter Code Manually ➔',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF00E676),
                      decoration: TextDecoration.underline,
                      decorationColor: const Color(0xFF00E676),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _defaultTitle {
    switch (widget.mode) {
      case QRScannerMode.gatePass:
        return 'Scan Gate Pass';
      case QRScannerMode.cryptoAddress:
        return 'Scan Crypto Address';
      case QRScannerMode.partnerId:
        return 'Verify Partner ID';
      case QRScannerMode.any:
        return 'Scan QR Code';
    }
  }

  String get _defaultInstruction {
    switch (widget.mode) {
      case QRScannerMode.gatePass:
        return 'Align visitor QR gate pass within the green box';
      case QRScannerMode.cryptoAddress:
        return 'Align USDT TRON (TRC20) QR address within the box';
      case QRScannerMode.partnerId:
        return 'Scan Partner ID card QR to verify legitimacy';
      case QRScannerMode.any:
        return 'Point camera at any QR code to scan';
    }
  }

  void _promptManualInput(BuildContext context) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Enter Code Manually',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: widget.mode == QRScannerMode.gatePass ? 'e.g. 849201 or RENT-GP-...' : 'Enter code or address',
            hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textMuted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = textController.text.trim();
              if (val.isNotEmpty) {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(val);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Submit', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// Custom painter that draws darkened outside area and neon corner brackets
class _ScannerOverlayPainter extends CustomPainter {
  final double scanBoxSize;
  final Color overlayColor;
  final Color borderColor;

  _ScannerOverlayPainter({
    required this.scanBoxSize,
    required this.overlayColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = overlayColor;
    final center = Offset(size.width / 2, size.height / 2);
    final scanRect = Rect.fromCenter(center: center, width: scanBoxSize, height: scanBoxSize);

    // 1. Draw darkened area outside scanRect
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(18)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, bgPaint);

    // 2. Draw 4 Corner Brackets
    final cornerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const cornerLen = 28.0;
    const r = 18.0;

    // Top-Left
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.left, scanRect.top + cornerLen)
        ..lineTo(scanRect.left, scanRect.top + r)
        ..arcToPoint(Offset(scanRect.left + r, scanRect.top), radius: const Radius.circular(r))
        ..lineTo(scanRect.left + cornerLen, scanRect.top),
      cornerPaint,
    );

    // Top-Right
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.right - cornerLen, scanRect.top)
        ..lineTo(scanRect.right - r, scanRect.top)
        ..arcToPoint(Offset(scanRect.right, scanRect.top + r), radius: const Radius.circular(r))
        ..lineTo(scanRect.right, scanRect.top + cornerLen),
      cornerPaint,
    );

    // Bottom-Left
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.left, scanRect.bottom - cornerLen)
        ..lineTo(scanRect.left, scanRect.bottom - r)
        ..arcToPoint(Offset(scanRect.left + r, scanRect.bottom), radius: const Radius.circular(r))
        ..lineTo(scanRect.left + cornerLen, scanRect.bottom),
      cornerPaint,
    );

    // Bottom-Right
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.right - cornerLen, scanRect.bottom)
        ..lineTo(scanRect.right - r, scanRect.bottom)
        ..arcToPoint(Offset(scanRect.right, scanRect.bottom - r), radius: const Radius.circular(r))
        ..lineTo(scanRect.right, scanRect.bottom - cornerLen),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
