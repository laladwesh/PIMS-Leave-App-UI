import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as dev;
import '../helpers/qr_handler.dart';
import '../widgets/qr_scan_body.dart';

/// Thin screen shell: owns state, permission, and token loading only.
/// All UI lives in [QrScanBody]; all business logic lives in [QrHandler].
class QrScannerScreen extends StatefulWidget {
  final Function(String) onQrCodeScanned;
  final String tab;

  const QrScannerScreen(
      {super.key, required this.onQrCodeScanned, required this.tab});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  String? _jwtToken;
  bool _hasPermission = false;
  bool _isScanning = false;
  bool _hasScanned = false;
  String? _centerMessage;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
    _loadJwtToken();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() => _hasPermission = true);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Camera permission is required to scan QR codes.')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _loadJwtToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _jwtToken = prefs.getString('token'));
    dev.log('Loaded jwtToken: $_jwtToken');
  }

  void _startScanning() =>
      setState(() { _isScanning = true; _hasScanned = false; });

  void _stopScanning() =>
      setState(() { _isScanning = false; _hasScanned = true; });

  void _showCenterMessage(String message) {
    setState(() => _centerMessage = message);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _centerMessage = null);
    });
  }

  Future<void> _onQrDetected(String qrData) async {
    if (_jwtToken == null || _hasScanned) return;
    _stopScanning();

    final handler = QrHandler(
      jwtToken: _jwtToken!,
      context: context,
      onMessage: _showCenterMessage,
    );
    await handler.handleQrCode(qrData, widget.tab);
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: QrScanBody(
        isScanning: _isScanning,
        hasScanned: _hasScanned,
        centerMessage: _centerMessage,
        onStartScanning: _startScanning,
        onQrDetected: _onQrDetected,
      ),
    );
  }
}