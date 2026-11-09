import 'dart:async';

import 'package:flutter/material.dart';

import '../services/profile_service.dart';
import '../theme/app_theme.dart';

/// Смена пароля: текущий + новый + код из письма.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _nextController = TextEditingController();
  final _repeatController = TextEditingController();
  final _codeController = TextEditingController();

  bool _isSaving = false;
  bool _isSendingCode = false;
  bool _currentVisible = false;
  bool _nextVisible = false;
  bool _repeatVisible = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;
  String? _error;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _currentController.dispose();
    _nextController.dispose();
    _repeatController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _isSendingCode = true;
      _error = null;
    });

    final result = await ProfileService.requestPasswordChangeCode();
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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final result = await ProfileService.changePassword(
        currentPassword: _currentController.text,
        newPassword: _nextController.text,
        code: _codeController.text.trim(),
      );
      if (!mounted) return;

      if (!result.success) {
        setState(() {
          _isSaving = false;
          _error = result.message.isEmpty
              ? 'Не удалось сменить пароль'
              : result.message;
        });
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пароль изменён')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'Не удалось сменить пароль: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.app;

    return Scaffold(
      appBar: AppBar(title: const Text('Сменить пароль')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _currentController,
              obscureText: !_currentVisible,
              decoration: InputDecoration(
                labelText: 'Текущий пароль',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _currentVisible ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: t.hint,
                  ),
                  onPressed: () =>
                      setState(() => _currentVisible = !_currentVisible),
                ),
              ),
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Введите текущий пароль' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nextController,
              obscureText: !_nextVisible,
              decoration: InputDecoration(
                labelText: 'Новый пароль',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _nextVisible ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: t.hint,
                  ),
                  onPressed: () =>
                      setState(() => _nextVisible = !_nextVisible),
                ),
              ),
              validator: (value) =>
                  (value == null || value.length < 6) ? 'Минимум 6 символов' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _repeatController,
              obscureText: !_repeatVisible,
              decoration: InputDecoration(
                labelText: 'Повторите новый пароль',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _repeatVisible ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: t.hint,
                  ),
                  onPressed: () =>
                      setState(() => _repeatVisible = !_repeatVisible),
                ),
              ),
              validator: (value) =>
                  value != _nextController.text ? 'Пароли не совпадают' : null,
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
              onPressed: _isSaving ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Сменить пароль'),
            ),
            const SizedBox(height: 16),
            Text(
              'После смены пароля остальные устройства потребуют повторный вход.',
              style: TextStyle(fontSize: 12, color: t.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
