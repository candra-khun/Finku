import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/security_service.dart';
import 'pin_keypad.dart';

enum PinFlowMode {
  setup, // Buat PIN baru pertama kali
  change, // Ubah PIN (perlu PIN lama)
  verify, // Verifikasi PIN (misal untuk mematikan kunci)
}

class AturPinPage extends StatefulWidget {
  final PinFlowMode mode;

  const AturPinPage({
    super.key,
    this.mode = PinFlowMode.setup,
  });

  @override
  State<AturPinPage> createState() => _AturPinPageState();
}

class _AturPinPageState extends State<AturPinPage> with SingleTickerProviderStateMixin {
  int _step = 0; // Tergantung mode
  final List<String> _currentPin = [];
  String _firstNewPin = '';
  bool _hasError = false;
  String _errorMessage = '';

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  String get _title {
    if (widget.mode == PinFlowMode.verify) {
      return 'Verifikasi PIN';
    }
    if (widget.mode == PinFlowMode.setup) {
      return _step == 0 ? 'Buat PIN Baru' : 'Konfirmasi PIN';
    }
    // Mode change
    if (_step == 0) return 'Masukkan PIN Lama';
    if (_step == 1) return 'Buat PIN Baru';
    return 'Konfirmasi PIN Baru';
  }

  String get _subtitle {
    if (widget.mode == PinFlowMode.verify) {
      return 'Masukkan 6 digit PIN saat ini untuk melanjutkan';
    }
    if (widget.mode == PinFlowMode.setup) {
      return _step == 0
          ? 'Tentukan 6 digit angka untuk mengamankan data Anda'
          : 'Ketik ulang 6 digit PIN untuk konfirmasi';
    }
    // Mode change
    if (_step == 0) return 'Masukkan PIN Anda saat ini';
    if (_step == 1) return 'Masukkan 6 digit PIN baru yang Anda inginkan';
    return 'Ketik ulang 6 digit PIN baru untuk konfirmasi';
  }

  void _onDigitPressed(String digit) {
    if (_currentPin.length >= 6) return;
    setState(() {
      _hasError = false;
      _errorMessage = '';
      _currentPin.add(digit);
    });

    if (_currentPin.length == 6) {
      _handleCompletedPin();
    }
  }

  void _onDeletePressed() {
    if (_currentPin.isNotEmpty) {
      setState(() {
        _hasError = false;
        _errorMessage = '';
        _currentPin.removeLast();
      });
    }
  }

  void _showError(String message) {
    HapticFeedback.vibrate();
    setState(() {
      _hasError = true;
      _errorMessage = message;
    });
    _shakeCtrl.forward(from: 0.0).then((_) {
      setState(() {
        _currentPin.clear();
      });
    });
  }

  Future<void> _handleCompletedPin() async {
    final entered = _currentPin.join();
    final sec = SecurityService.instance;

    if (widget.mode == PinFlowMode.verify) {
      if (sec.verifyPin(entered)) {
        HapticFeedback.mediumImpact();
        if (mounted) Navigator.pop(context, true);
      } else {
        _showError('PIN salah. Silakan coba lagi.');
      }
      return;
    }

    if (widget.mode == PinFlowMode.setup) {
      if (_step == 0) {
        // Simpan input pertama, minta konfirmasi
        setState(() {
          _firstNewPin = entered;
          _step = 1;
          _currentPin.clear();
        });
      } else {
        // Konfirmasi
        if (entered == _firstNewPin) {
          await _finishSetup(entered);
        } else {
          _showError('PIN konfirmasi tidak cocok. Ulangi kembali.');
          setState(() {
            _step = 0;
            _firstNewPin = '';
          });
        }
      }
      return;
    }

    if (widget.mode == PinFlowMode.change) {
      if (_step == 0) {
        // Cek PIN lama
        if (sec.verifyPin(entered)) {
          setState(() {
            _step = 1;
            _currentPin.clear();
          });
        } else {
          _showError('PIN lama salah. Silakan coba lagi.');
        }
      } else if (_step == 1) {
        // PIN baru
        setState(() {
          _firstNewPin = entered;
          _step = 2;
          _currentPin.clear();
        });
      } else {
        // Konfirmasi PIN baru
        if (entered == _firstNewPin) {
          await sec.changePin(entered);
          HapticFeedback.mediumImpact();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('PIN keamanan berhasil diperbarui!'),
                backgroundColor: Colors.teal,
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.pop(context, true);
          }
        } else {
          _showError('PIN konfirmasi tidak cocok. Ulangi dari PIN baru.');
          setState(() {
            _step = 1;
            _firstNewPin = '';
          });
        }
      }
    }
  }

  Future<void> _finishSetup(String pin) async {
    final sec = SecurityService.instance;
    bool enableBio = sec.hasBiometrics;

    if (sec.hasBiometrics && mounted) {
      final bioChoice = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.fingerprint, size: 48, color: Colors.teal),
          title: const Text('Gunakan Sidik Jari?'),
          content: const Text(
            'Apakah Anda juga ingin menggunakan sensor sidik jari / biometrik ponsel untuk membuka aplikasi lebih cepat?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hanya PIN'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ya, Gunakan'),
            ),
          ],
        ),
      );
      enableBio = bioChoice ?? false;
    }

    await sec.setupPin(pin, enableBiometric: enableBio);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kunci aplikasi berhasil diaktifkan!'),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mode == PinFlowMode.change ? 'Ubah PIN' : 'Kunci Aplikasi'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.mode == PinFlowMode.change ? Icons.pin_outlined : Icons.shield_outlined,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Animasi Titik PIN
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: PinDots(
                          length: 6,
                          enteredLength: _currentPin.length,
                          hasError: _hasError,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),
                  SizedBox(
                    height: 22,
                    child: _hasError
                        ? Text(
                            _errorMessage,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 20),

                  // Keypad
                  PinKeypad(
                    onDigitPressed: _onDigitPressed,
                    onDeletePressed: _onDeletePressed,
                    showBiometric: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

