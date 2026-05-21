import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:developer' as dev;
import 'qr_scanner_overlay_painter.dart';

/// All the visible UI for the QR scanner:
/// - idle state with glowing pulse button
/// - active scanning state (camera + animated overlay)
/// - "Scan Again" button after a scan
/// - floating toast message
class QrScanBody extends StatefulWidget {
  final bool isScanning;
  final bool hasScanned;
  final String? centerMessage;
  final VoidCallback onStartScanning;
  final void Function(String qrData) onQrDetected;

  const QrScanBody({
    super.key,
    required this.isScanning,
    required this.hasScanned,
    required this.centerMessage,
    required this.onStartScanning,
    required this.onQrDetected,
  });

  @override
  State<QrScanBody> createState() => _QrScanBodyState();
}

class _QrScanBodyState extends State<QrScanBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Background gradient ──────────────────────────────────────
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),

        // ── Idle: glowing pulse scan button ─────────────────────────
        if (!widget.isScanning)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Outer pulse ring
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulse glow ring
                      Container(
                        width: 90 + 48 * _pulse.value,
                        height: 90 + 48 * _pulse.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF6C63FF)
                              .withOpacity(0.12 * (1 - _pulse.value)),
                        ),
                      ),
                      // Second ring
                      Container(
                        width: 90 + 24 * _pulse.value,
                        height: 90 + 24 * _pulse.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF6C63FF)
                              .withOpacity(0.18 * (1 - _pulse.value)),
                        ),
                      ),
                      // Core button
                      GestureDetector(
                        onTap: widget.onStartScanning,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6C63FF), Color(0xFF48CAE4)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6C63FF).withOpacity(0.5),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.qr_code_scanner,
                              size: 42, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Tap to Scan QR Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hold the QR code in front of the camera',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

        // ── Scanning: camera + animated overlay ──────────────────────
        if (widget.isScanning)
          Positioned.fill(
            child: Stack(
              children: [
                MobileScanner(
                  onDetect: (result) {
                    final qrData = result.barcodes.first.rawValue;
                    if (qrData != null) {
                      dev.log('Scanned QR Code: $qrData');
                      widget.onQrDetected(qrData);
                    }
                  },
                ),
                // Animated overlay
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _ctrl,
                    builder: (_, __) => CustomPaint(
                      painter: QrScannerOverlayPainter(
                        animationValue: _ctrl.value,
                      ),
                    ),
                  ),
                ),
                // Bottom hint
                Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Text(
                          'Align QR code within the frame',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // ── Post-scan: "Scan Again" button ───────────────────────────
        if (widget.hasScanned && !widget.isScanning)
          Positioned(
            bottom: 48,
            left: 40,
            right: 40,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Scan Again'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onPressed: widget.onStartScanning,
            ),
          ),

        // ── Floating toast message ────────────────────────────────────
        if (widget.centerMessage != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: AnimatedOpacity(
                  opacity: widget.centerMessage != null ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E1E2E), Color(0xFF2A2A3E)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Text(
                      widget.centerMessage ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
