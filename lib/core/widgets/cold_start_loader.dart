import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Indicador visual de progreso temático con actualización automática
/// ante tiempos prolongados causados por arranques en frío (cold starts).
class ColdStartProgressIndicator extends StatefulWidget {
  final String initialMessage;
  final String coldStartMessage;
  final String prolongedMessage;
  final Color? spinnerColor;
  final TextStyle? textStyle;
  final Duration threshold1;
  final Duration threshold2;

  const ColdStartProgressIndicator({
    super.key,
    this.initialMessage = 'Generando vista try-on…',
    this.coldStartMessage = 'Despertando al vestidor inteligente... ✨',
    this.prolongedMessage = 'Preparando los percheros virtuales... 🦇',
    this.spinnerColor,
    this.textStyle,
    this.threshold1 = const Duration(milliseconds: 3500),
    this.threshold2 = const Duration(milliseconds: 7000),
  });

  @override
  State<ColdStartProgressIndicator> createState() => _ColdStartProgressIndicatorState();
}

class _ColdStartProgressIndicatorState extends State<ColdStartProgressIndicator> {
  late String _message;
  Timer? _timer1;
  Timer? _timer2;

  @override
  void initState() {
    super.initState();
    _message = widget.initialMessage;

    _timer1 = Timer(widget.threshold1, () {
      if (mounted) {
        setState(() => _message = widget.coldStartMessage);
      }
    });

    _timer2 = Timer(widget.threshold2, () {
      if (mounted) {
        setState(() => _message = widget.prolongedMessage);
      }
    });
  }

  @override
  void dispose() {
    _timer1?.cancel();
    _timer2?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(
            widget.spinnerColor ?? AppColors.neonMint,
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: Text(
            _message,
            key: ValueKey(_message),
            textAlign: TextAlign.center,
            style: widget.textStyle ??
                const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
          ),
        ),
      ],
    );
  }
}
