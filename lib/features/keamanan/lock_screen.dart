import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/security_service.dart';
import 'pin_keypad.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with SingleTickerProviderStateMixin {
  final List<String> _enteredPin = [];
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

    // Picu biometrik otomatis saat layar kunci muncul
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerBiometrics();
    });
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _triggerBiometrics() async {
    if (!mounted) return;
    final sec = SecurityService.instance;
    if (sec.isBiometricEnabled && sec.hasBiometrics && !sec.isAuthenticating) {
      await sec.authenticateBiometrics();
    }
  }

  void _onDigitPressed(String digit) {
    if (_enteredPin.length >= 6) return;
    setState(() {
      _hasError = false;
      _errorMessage = '';
      _enteredPin.add(digit);
    });

    if (_enteredPin.length == 6) {
      _verifyPin();
    }
  }

  void _onDeletePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _hasError = false;
        _errorMessage = '';
        _enteredPin.removeLast();
      });
    }
  }

  void _verifyPin() {
    final pin = _enteredPin.join();
    final sec = SecurityService.instance;

    if (sec.verifyPin(pin)) {
      HapticFeedback.mediumImpact();
      sec.unlock();
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _hasError = true;
        _errorMessage = 'PIN salah. Silakan coba lagi.';
      });
      _shakeCtrl.forward(from: 0.0).then((_) {
        setState(() {
          _enteredPin.clear();
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sec = SecurityService.instance;
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF13161A) : Colors.white,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Ikon Gembok / Logo
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_rounded,
                        size: 44,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Keuangan Saku',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Masukkan 6 digit PIN Anda',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Titik PIN Animasi
                    AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_shakeAnimation.value, 0),
                          child: PinDots(
                            length: 6,
                            enteredLength: _enteredPin.length,
                            hasError: _hasError,
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),
                    // Pesan Kesalahan
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
                      showBiometric: sec.isBiometricEnabled && sec.hasBiometrics,
                      onBiometricPressed: _triggerBiometrics,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

