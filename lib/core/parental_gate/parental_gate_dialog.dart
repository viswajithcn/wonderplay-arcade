import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ParentalGateDialog extends StatefulWidget {
  const ParentalGateDialog({super.key});

  static Future<bool> verify(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ParentalGateDialog(),
    );
    return result ?? false;
  }

  @override
  State<ParentalGateDialog> createState() => _ParentalGateDialogState();
}

class _ParentalGateDialogState extends State<ParentalGateDialog> {
  late final int _num1;
  late final int _num2;
  late final int _correctAnswer;
  final TextEditingController _controller = TextEditingController();
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    final random = Random();
    _num1 = random.nextInt(6) + 4; // 4 to 9
    _num2 = random.nextInt(7) + 3; // 3 to 9
    _correctAnswer = _num1 * _num2;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final input = int.tryParse(_controller.text.trim());
    if (input == _correctAnswer) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _hasError = true;
        _controller.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          const Icon(Icons.lock_rounded, color: AppTheme.amberOrange, size: 28),
          const SizedBox(width: 8),
          Text('Grown-Ups Only', style: AppTheme.headingFont),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Please solve this problem to access settings:',
            style: AppTheme.bodyFont.copyWith(color: Colors.black87),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.sunnyYellow.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '$_num1  ×  $_num2  =  ?',
              style: AppTheme.titleFont.copyWith(
                fontSize: 28,
                color: AppTheme.darkText,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            textAlign: TextAlign.center,
            style: AppTheme.titleFont.copyWith(fontSize: 24),
            decoration: InputDecoration(
              hintText: 'Enter answer',
              errorText: _hasError ? 'Incorrect, please try again!' : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancel', style: AppTheme.bodyFont),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.mintGreen,
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
          child: Text('Confirm', style: AppTheme.bodyFont.copyWith(color: Colors.white)),
        ),
      ],
    );
  }
}
