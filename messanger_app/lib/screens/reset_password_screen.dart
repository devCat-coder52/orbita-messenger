import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isSendingCode = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;
  String? _error;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = AuthService.resendCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    final emailError = Validators.email(email);
    if (emailError != null) {
      setState(() => _error = emailError);
      return;
    }

    setState(() {
      _isSendingCode = true;
      _error = null;
    });

    final result = await AuthService.sendPasswordResetCode(email);
    if (!mounted) return;

    setState(() => _isSendingCode = false);
    if (!result.success) {
      setState(() => _error = result.message);
      return;
    }

    _startCooldown();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.message.isEmpty ? 'Код отправлен' : result.message,
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await AuthService.resetPassword(
      _emailController.text.trim(),
      _codeController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;

    setState(() => _isLoading = false);
    if (!result.success) {
      setState(() => _error = result.message);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Пароль изменён. Войдите с новым паролем.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.app;

    return Scaffold(
      appBar: AppBar(title: const Text('Восстановление пароля')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Укажите email, на который зарегистрирован аккаунт. Мы отправим '
                  'код подтверждения.',
                  style: TextStyle(fontSize: 14, color: t.textSecondary),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  inputFormatters: [Validators.emailFormatter],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  validator: Validators.email,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: (_isSendingCode || _cooldown > 0)
                      ? null
                      : _sendCode,
                  icon: _isSendingCode
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.mail_outline, size: 18),
                  label: Text(
                    _cooldown > 0
                        ? 'Отправить код повторно через $_cooldown с'
                        : 'Получить код',
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: Validators.verificationCodeLength,
                  inputFormatters: [Validators.digitsFormatter],
                  decoration: const InputDecoration(
                    labelText: 'Код из письма',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  validator: Validators.verificationCode,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  inputFormatters: [Validators.noSpacesFormatter],
                  decoration: const InputDecoration(
                    labelText: 'Новый пароль',
                    border: OutlineInputBorder(),
                  ),
                  validator: Validators.password,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: t.errorBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!, style: TextStyle(color: t.error)),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Сменить пароль'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
