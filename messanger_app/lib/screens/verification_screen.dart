import 'package:flutter/material.dart';
import '../services/auth_service.dart';
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
  int _resendCooldown = 30;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    Future.delayed(Duration(seconds: 1), () {
      if (mounted && _resendCooldown > 0) {
        setState(() => _resendCooldown--);
        _startCooldown();
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleVerification() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final verifyResult = await AuthService.verifyEmailCode(
        widget.email,
        _codeController.text.trim(),
      );

      if (!verifyResult['success']) {
        _showError(verifyResult['message']);
        return;
      }

      final registerResult = await AuthService.register(
        widget.login,
        widget.email,
        widget.password,
        _codeController.text.trim(),
      );

      if (!registerResult['success']) {
        _showError(registerResult['message']);
        return;
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      _showError('Ошибка подтверждения');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    if (_resendCooldown > 0) return;

    setState(() => _isLoading = true);

    try {
      final result = await AuthService.sendVerificationCode(
        widget.email,
        widget.login,
      );
      if (result['success']) {
        _showSuccess('Код отправлен повторно');
        setState(() => _resendCooldown = 30);
        _startCooldown();
      } else {
        _showError(result['message']);
      }
    } catch (e) {
      _showError('Ошибка отправки кода');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Подтверждение Email')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Введите код из письма',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Мы отправили 6-значный код на\n${widget.email}',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32),
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, letterSpacing: 8),
                  decoration: InputDecoration(
                    labelText: 'Код подтверждения',
                    border: OutlineInputBorder(),
                    hintText: '000000',
                  ),
                  maxLength: 6,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Введите код';
                    }
                    if (value.trim().length != 6) {
                      return 'Код должен содержать 6 цифр';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleVerification,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Подтвердить'),
                ),
                SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _resendCooldown > 0 || _isLoading
                        ? null
                        : _resendCode,
                    child: _resendCooldown > 0
                        ? Text(
                            'Отправить код повторно через $_resendCooldown с',
                          )
                        : Text('Отправить код повторно'),
                  ),
                ),
                SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                    );
                  },
                  child: Text('Назад ко входу'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
