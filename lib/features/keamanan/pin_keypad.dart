import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PinDots extends StatelessWidget {
  final int length;
  final int enteredLength;
  final bool hasError;

  const PinDots({
    super.key,
    this.length = 6,
    required this.enteredLength,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (index) {
        final isFilled = index < enteredLength;
        Color color;
        if (hasError) {
          color = Colors.redAccent;
        } else if (isFilled) {
          color = theme.colorScheme.primary;
        } else {
          color = isDark ? Colors.white24 : Colors.black12;
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: isFilled ? 18 : 14,
          height: isFilled ? 18 : 14,
          decoration: BoxDecoration(
            color: isFilled ? color : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
            boxShadow: isFilled
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 6,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

class PinKeypad extends StatelessWidget {
  final ValueChanged<String> onDigitPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback? onBiometricPressed;
  final bool showBiometric;

  const PinKeypad({
    super.key,
    required this.onDigitPressed,
    required this.onDeletePressed,
    this.onBiometricPressed,
    this.showBiometric = false,
  });

  Widget _buildKey(BuildContext context, String text, {VoidCallback? onTap}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Material(
          color: isDark ? const Color(0xFF23272F) : Colors.grey.shade100,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              if (onTap != null) onTap();
            },
            child: SizedBox(
              height: 72,
              child: Center(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, {required Widget icon, required VoidCallback? onTap}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap != null
                ? () {
                    HapticFeedback.lightImpact();
                    onTap();
                  }
                : null,
            child: SizedBox(
              height: 72,
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildKey(context, '1', onTap: () => onDigitPressed('1')),
              _buildKey(context, '2', onTap: () => onDigitPressed('2')),
              _buildKey(context, '3', onTap: () => onDigitPressed('3')),
            ],
          ),
          Row(
            children: [
              _buildKey(context, '4', onTap: () => onDigitPressed('4')),
              _buildKey(context, '5', onTap: () => onDigitPressed('5')),
              _buildKey(context, '6', onTap: () => onDigitPressed('6')),
            ],
          ),
          Row(
            children: [
              _buildKey(context, '7', onTap: () => onDigitPressed('7')),
              _buildKey(context, '8', onTap: () => onDigitPressed('8')),
              _buildKey(context, '9', onTap: () => onDigitPressed('9')),
            ],
          ),
          Row(
            children: [
              if (showBiometric && onBiometricPressed != null)
                _buildActionButton(
                  context,
                  icon: Icon(Icons.fingerprint, size: 34, color: theme.colorScheme.primary),
                  onTap: onBiometricPressed,
                )
              else
                const Expanded(child: SizedBox(height: 72)),
              _buildKey(context, '0', onTap: () => onDigitPressed('0')),
              _buildActionButton(
                context,
                icon: const Icon(Icons.backspace_outlined, size: 26),
                onTap: onDeletePressed,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

