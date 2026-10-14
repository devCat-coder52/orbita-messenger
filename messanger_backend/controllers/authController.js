const authService = require('../services/authService');
const asyncHandler = require('../utils/asyncHandler');
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

exports.register = asyncHandler(async (req, res) => {
  const { login, email, password, code } = req.body;

  const result = await authService.register(login, email, password, code);
  logger.info('User registered successfully', { userId: result.user.id, login });
  return res.status(201).json({
    success: true,
    token: result.token,
    user: result.user,
  });
});

exports.login = asyncHandler(async (req, res) => {
  const { login, password } = req.body;

  const result = await authService.login(login, password);
  logger.info('User logged in successfully', { userId: result.user.id, login });
  return res.status(200).json({
    success: true,
    token: result.token,
    user: result.user,
  });
});

exports.sendVerificationCode = asyncHandler(async (req, res) => {
  const { email, login } = req.body;

  const result = await authService.sendVerificationCode(email, login);
  logger.info('Verifying code sent', { email });
  return res.status(200).json({ success: true, message: result.message });
});

exports.verifyEmailCode = asyncHandler(async (req, res) => {
  const { email, code } = req.body;

  const result = await authService.verifyEmailCode(email, code);
  logger.info('Email verified successfully', { email });
  return res.status(200).json({ success: true, message: result.message });
});