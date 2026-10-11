import 'package:flutter/services.dart';

abstract final class Validators {
  static final RegExp _loginPattern = RegExp(r'^[a-zA-Z0-9]+$');
  static final RegExp _emailPattern = RegExp(r'^[^@]+@[^@]+\.[^@]+');

  const Validators._();

  static int get minLoginLength => 4;
  static int get minPasswordLength => 6;
  static int get verificationCodeLength => 6;

  static final FilteringTextInputFormatter loginFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]'));

  static final FilteringTextInputFormatter emailFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9@._+-]'));

  static final FilteringTextInputFormatter noSpacesFormatter =
      FilteringTextInputFormatter.deny(RegExp(r'\s'));

  static final TextInputFormatter digitsFormatter =
      FilteringTextInputFormatter.digitsOnly;

  static String? login(String? value) {
    if (value == null || value.isEmpty) return 'Введите логин';
    if (!_loginPattern.hasMatch(value)) {
      return 'Логин может содержать только буквы и цифры';
    }
    if (value.trim().length < minLoginLength) {
      return 'Логин должен быть не менее $minLoginLength символов';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'Введите email';
    if (!_emailPattern.hasMatch(value)) return 'Некорректный email';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Введите пароль';
    if (value.length < minPasswordLength) {
      return 'Пароль должен быть не менее $minPasswordLength символов';
    }
    return null;
  }

  static String? verificationCode(String? value) {
    final code = value?.trim() ?? '';
    if (code.isEmpty) return 'Введите код';
    if (code.length != verificationCodeLength) {
      return 'Код должен содержать $verificationCodeLength цифр';
    }
    return null;
  }
}
