import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../widgets/error_dialog.dart';
import '../utils/app_colors.dart';
import '../utils/validators.dart';

import 'verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _loginController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _errorMessage;

  void _submit() async {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = _isLogin
          ? await AuthService.login(
              _loginController.text,
              _passwordController.text,
            )
          : await AuthService.sendVerificationCode(
              _emailController.text,
              _loginController.text,
            );

      if (!mounted) return;

      if (result.success) {
        if (!mounted) return;
        if (_isLogin) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VerificationScreen(
                email: _emailController.text,
                login: _loginController.text,
                password: _passwordController.text,
              ),
            ),
          );
        }
      } else {
        setState(() => _errorMessage = result.message);
      }
    } catch (error) {
      if (!mounted) return;
      ErrorDialog.show(context, 'Ошибка входа: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleMode() {
    _formKey.currentState?.reset();
    setState(() => _isLogin = !_isLogin);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.gradientMiddle,
              AppColors.scaffoldBackground,
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  const SizedBox(height: 48),
                  _brandHeader(),
                  const SizedBox(height: 40),
                  _AuthCard(
                    child: Column(
                      children: [
                        _loginField(),
                        if (!_isLogin) ...[
                          const SizedBox(height: 16),
                          _emailField(),
                        ],
                        const SizedBox(height: 16),
                        _passwordField(),
                        const SizedBox(height: 24),
                        _errorBanner(),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? const _LoadingIndicator()
                              : Text(_isLogin ? 'Войти' : 'Зарегистрироваться'),
                        ),
                        TextButton(
                          onPressed: _toggleMode,
                          child: Text(
                            _isLogin
                                ? 'Нет аккаунта? Зарегистрироваться'
                                : 'Уже есть аккаунт? Войти',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brandHeader() => Column(
    children: [
      const Text(
        'Orbita',
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 2,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        _isLogin ? 'Добро пожаловать!' : 'Создать аккаунт',
        style: TextStyle(
          fontSize: 16,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    ],
  );

  Widget _loginField() => TextFormField(
    controller: _loginController,
    inputFormatters: [Validators.loginFormatter],
    decoration: const InputDecoration(labelText: 'Логин'),
    validator: Validators.login,
  );

  Widget _emailField() => TextFormField(
    controller: _emailController,
    keyboardType: TextInputType.emailAddress,
    inputFormatters: [Validators.emailFormatter],
    decoration: const InputDecoration(labelText: 'Email'),
    validator: Validators.email,
  );

  Widget _passwordField() => TextFormField(
    controller: _passwordController,
    obscureText: !_isPasswordVisible,
    inputFormatters: [Validators.noSpacesFormatter],
    decoration: InputDecoration(
      labelText: 'Пароль',
      suffixIcon: IconButton(
        icon: Icon(
          _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
          size: 20,
          color: Colors.grey.shade600,
        ),
        onPressed: () =>
            setState(() => _isPasswordVisible = !_isPasswordVisible),
      ),
    ),
    validator: Validators.password,
  );

  Widget _errorBanner() {
    if (_errorMessage == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.errorBackground,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: AppColors.error),
        ),
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
