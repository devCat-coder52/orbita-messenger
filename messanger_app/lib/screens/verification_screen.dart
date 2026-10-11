import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';
import '../utils/validators.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class VerificationScreen extends StatefulWidget {
  final String email;
  final String login;
  final String password;

  const VerificationScreen({
    super.key,
    required this.email,
    required this.login,
    required this.password,
  });

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  int _resendCooldown = AuthService.resendCooldownSeconds;
  Timer? _cooldownTimer;

  bool get _canSubmit => !_isLoading;
  bool get _canResend => !(_resendCooldown > 0 || _isLoading);

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _resendCooldown--);
      if (_resendCooldown <= 0) timer.cancel();
    });
  }

  Future<void> _handleVerification() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final code = _codeController.text.trim();

      final verifyResult = await AuthService.verifyEmailCode(
        widget.email,
        code,
      );
      if (!verifyResult.success) {
        _showMessage(verifyResult.message, isError: true);
        return;
      }

      final registerResult = await AuthService.register(
        widget.login,
        widget.email,
        widget.password,
        code,
      );

      if (!registerResult.success) {
        _showMessage(registerResult.message, isError: true);
        return;
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      _showMessage('Ошибка подтверждения', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend) return;

    setState(() => _isLoading = true);

    try {
      final result = await AuthService.sendVerificationCode(
        widget.email,
        widget.login,
      );
      if (result.success) {
        _showMessage(
          result.message.isEmpty ? 'Код отправлен повторно' : result.message,
        );
        setState(() => _resendCooldown = AuthService.resendCooldownSeconds);
        _startCooldown();
      } else {
        _showMessage(result.message, isError: true);
      }
    } catch (e) {
      _showMessage('Ошибка отправки кода', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Подтверждение Email')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Введите код из письма',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Мы отправили 6-значный код на\n${widget.email}',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8),
                  maxLength: Validators.verificationCodeLength,
                  inputFormatters: [Validators.digitsFormatter],
                  decoration: const InputDecoration(
                    labelText: 'Код подтверждения',
                    border: OutlineInputBorder(),
                    hintText: '000000',
                  ),
                  validator: Validators.verificationCode,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _canSubmit ? _handleVerification : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Подтвердить'),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _canResend ? _resendCode : null,
                    child: Text(
                      _resendCooldown > 0
                          ? 'Отправить код повторно через $_resendCooldown с'
                          : 'Отправить код повторно',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  ),
                  child: const Text('Назад ко входу'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }
}
