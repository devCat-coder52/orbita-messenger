const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const emailService = require('../services/emailService');

const pendingRegistrations = new Map();

exports.register = async (req, res) => {
  const { login, email, password, code } = req.body;

  try {
    if (!code) {
      return res.json({ success: false, error: 'Требуется код подтверждения email' });
    }
    const codeResult = await emailService.verifyCode(email, code);
    if (!codeResult.valid) {
      return res.json({ success: false, error: codeResult.message });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const newUser = await User.create({ login, email, password: hashedPassword });
    const token = jwt.sign({ userId: newUser.id }, process.env.JWT_SECRET || 'your-local-dev-secret-key');

    return res.json({
      success: true,
      token,
      user: { id: newUser.id, login: newUser.login, email: newUser.email }
    });
  } catch (error) {
    console.error('Ошибка регистрации:', error);
    return res.status(500).json({ success: false, error: 'Ошибка сервера при регистрации' });
  }
};

exports.login = async (req, res) => {
  const { login, password } = req.body;

  if (!login || !password) {
    return res.json({ success: false, error: 'Логин и пароль обязательны' });
  }
  try {
    const user = await User.findByLogin(login);
    if (!user) {
      return res.json({ success: false, error: 'Неверный логин или пароль' });
    }
    const cryptPassword = await bcrypt.compare(password, user.password);
    if (!cryptPassword)
      return res.json({ success: false, error: 'Неверный логин или пароль' });

    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET || 'your-local-dev-secret-key');

    return res.status(201).json({ success: true, token, user: { id: user.id, login: user.login, email: user.email } });
  } catch (error) {
    console.error('Ошибка входа:', error);
    return res.status(500).json({ success: false, error: 'Ошибка сервера при входе' });
  }
};

exports.sendVerificationCode = async (req, res) => {
  const { email, login } = req.body;

  if (!email || !/\S+@\S+\.\S+/.test(email)) {
    return res.json({ success: false, error: 'Некорректный email' });
  }

  try {
    const isMailExists = await User.findByEmail(email);
    if (isMailExists) {
      return res.json({ success: false, error: 'Этот email уже зарегистрирован' });
    }

    const isUserExists = await User.findByLogin(login);
    if (isUserExists) {
      return res.json({ success: false, error: 'Логин уже используется' });
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return res.json({ success: false, error: 'Некорректный email' });
    }

    const success = await emailService.sendVerificationCode(email);

    if (success) {
      res.status(201).json({ success: true, message: 'Код подтверждения отправлен на email' });
    } else {
      res.json({ success: false, error: 'Ошибка отправки письма' });
    }
  } catch (error) {
    console.error('Ошибка при отправке кода:', error);
    return res.status(500).json({ error: 'Ошибка сервера' });
  }
};

exports.verifyEmailCode = async (req, res) => {
  const { email, code } = req.body;

  try {
    if (!email || !code) {
      return res.json({ success: false, error: 'Требуется email и код подтверждения' });
    }
    const result = await emailService.verifyCode(email, code);
    if (!result.valid) {
      return res.json({ success: false, error: result.message });
    }
    return res.status(201).json({ success: true, message: 'Email успешно подтвержден' });
  } catch(error) {
    console.error('Ошибка при проверке кода:', error);
    return res.status(500).json({ error: 'Ошибка сервера' });
  }
};