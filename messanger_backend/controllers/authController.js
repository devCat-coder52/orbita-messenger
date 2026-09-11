const authService = require('../services/authService');
const emailService = require('../services/emailService');
const User = require('../models/User');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { body } = require('express-validator');
const logger = require('../utils/logger');

exports.registerValidation = [
  body('login')
    .trim()
    .isLength({ min: 4, max: 25 })
    .withMessage('Логин должен быть от 4 до 25 символов')
    .matches(/^[a-zA-Z0-9_]+$/)
    .withMessage('Логин может содержать только латинские буквы, цифры и подчеркивание'),
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Некорректный email'),
  body('password')
    .isLength({ min: 6 })
    .withMessage('Пароль должен быть не менее 6 символов'),
];

exports.loginValidation = [
  body('login').notEmpty().withMessage('Логин обязателен'),
  body('password').notEmpty().withMessage('Пароль обязателен'),
];

exports.register = async (req, res) => {
  const { login, email, password, code } = req.body;

  try {
    const result = await authService.register(login, email, password, code);
    logger.info('User registered successfully', { 
      userId: result.user.id, 
      login 
    });
    return res.status(201).json({
      success: true,
      token: result.token,
      user: result.user
    });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({ success: false, error: error.message });
    }
    logger.error('User registration error', { error, login, email });
    return res.status(500).json({ success: false, error: `Ошибка сервера при регистрации: ${error}` });
  }
};

exports.login = async (req, res) => {
  const { login, password } = req.body;
  
  try {
    const result = await authService.login(login, password);
    logger.info('User logged in successfully', { userId: result.user.id, login });
    return res.status(201).json({
      success: true,
      token: result.token,
      user: result.user
    });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({ success: false, error: error.message });
    }
    logger.error('User login error', { error, login });
    return res.status(500).json({ success: false, error: `Ошибка сервера при входе: ${error}` });
  }
};

exports.sendVerificationCode = async (req, res) => {
  const { email, login } = req.body;

  try {
    const result = await authService.sendVerificationCode(email, login);
    logger.info('Verifying code sent', { email });
    return res.status(201).json({ success: true, message: result.message });
  } catch (error) {
    logger.error('Verifying code send error', { error, email });
    if (error.statusCode) {
      return res.status(error.statusCode).json({ success: false, error: `Ошибка сервера при отправке кода: ${error.message}` });
    }
    return res.status(500).json({ success: false, error: error });
  }
};

exports.verifyEmailCode = async (req, res) => {
  const { email, code } = req.body;

  try {
    const result = await authService.verifyEmailCode(email, code);
    logger.info('Email verified successfully', { email });
    return res.status(201).json({ success: true, message: result.message });
  } catch(error) {
    logger.error('Email verifying error', { error, email });
    return res.status(500).json({ success: false, error: error.message });
  }
};