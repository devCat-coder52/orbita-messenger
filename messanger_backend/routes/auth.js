const express = require('express');
const router = express.Router();
const {
  register,
  login,
  sendVerificationCode,
  verifyEmailCode,
  sendPasswordResetCode,
  resetPassword,
  registerValidation,
  loginValidation,
  resetPasswordValidation
} = require('../controllers/authController');
const handleValidationErrors = require('../middleware/validation');
const rateLimit = require('express-rate-limit');

// Лимит можно поднять окружением: интеграционные тесты регистрируют много
// пользователей с одного адреса.
const authMax = Number(process.env.AUTH_RATE_LIMIT_MAX) || 10;

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: authMax,
  message: { error: 'Слишком много попыток входа, попробуйте позже' },
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: false,
});

const sendCodeLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  message: { error: 'Слишком много запросов кода, попробуйте позже' },
  standardHeaders: true,
  legacyHeaders: false,
});

const verifyCodeLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 30,
  message: { error: 'Слишком много попыток проверки кода, попробуйте позже' },
  standardHeaders: true,
  legacyHeaders: false,
});

router.post('/register', authLimiter, registerValidation, handleValidationErrors, register);
router.post('/login', authLimiter, loginValidation, handleValidationErrors, login);
router.post('/send-code', sendCodeLimiter, sendVerificationCode);
router.post('/verify-code', verifyCodeLimiter, verifyEmailCode);
router.post('/send-reset-code', sendCodeLimiter, sendPasswordResetCode);
router.post(
  '/reset-password',
  verifyCodeLimiter,
  resetPasswordValidation,
  handleValidationErrors,
  resetPassword
);

module.exports = router;
