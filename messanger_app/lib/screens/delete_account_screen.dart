import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/socket_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';

/// Удаление аккаунта: пароль + код из письма, как при смене пароля.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();

  bool _isDeleting = false;
  bool _isSendingCode = false;
  bool _passwordVisible = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;
  String? _error;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _isSendingCode = true;
      _error = null;
    });

    final result = await ProfileService.requestDeleteAccountCode();
    if (!mounted) return;

    setState(() => _isSendingCode = false);

    if (!result.success) {
      setState(() {
        _error = result.message.isEmpty
            ? 'Не удалось отправить код'
            : result.message;
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Код отправлен на почту')),
    );
    _startCooldown();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = 60);

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldown -= 1);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  Future<bool?> _confirm() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content: const Text(
          'Это действие нельзя отменить: чаты, сообщения и профиль будут '
          'удалены безвозвратно.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: AppTokens.of(ctx).error,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final confirmed = await _confirm();
    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
      _error = null;
    });

    try {
      final result = await ProfileService.removeAccount(
        password: _passwordController.text,
        code: _codeController.text.trim(),
      );
      if (!mounted) return;

      if (!result.success) {
        setState(() {
          _isDeleting = false;
          _error = result.message.isEmpty
              ? 'Не удалось удалить аккаунт'
              : result.message;
        });
        return;
      }

      // Аккаунта больше нет: сбрасываем локальное состояние и уходим на вход.
      SocketService.disconnect();
      SocketService.clearOutbox();
      UserService().clearCache();
      await AuthService.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _error = 'Не удалось удалить аккаунт: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.app;

    return Scaffold(
      appBar: AppBar(title: const Text('Удаление аккаунта')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.errorBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: t.error, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Аккаунт удаляется навсегда вместе с чатами и '
                      'сообщениями. Восстановить его не получится.',
                      style: TextStyle(fontSize: 13, color: t.error),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: !_passwordVisible,
              decoration: InputDecoration(
                labelText: 'Текущий пароль',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _passwordVisible ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: t.hint,
                  ),
                  onPressed: () =>
                      setState(() => _passwordVisible = !_passwordVisible),
                ),
              ),
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Введите пароль' : null,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Код из письма',
                      helperText: 'Код придёт на вашу почту',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    validator: (value) {
                      final code = (value ?? '').trim();
                      if (code.length != 6) return 'Введите 6-значный код';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextButton(
                    onPressed: _isSendingCode || _cooldown > 0
                        ? null
                        : _sendCode,
                    child: Text(
                      _cooldown > 0 ? 'Через $_cooldown с' : 'Отправить код',
                    ),
                  ),
                ),
              ],
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
              onPressed: _isDeleting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: t.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Удалить аккаунт'),
            ),
          ],
        ),
      ),
    );
  }
}
