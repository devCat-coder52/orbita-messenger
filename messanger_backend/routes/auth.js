const express = require('express');
const router = express.Router();
const {
  register,
  login,
  sendVerificationCode,
  verifyEmailCode,
  registerValidation,
  loginValidation
} = require('../controllers/authController');
const handleValidationErrors = require('../middleware/validation');
const rateLimit = require('express-rate-limit');

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: { error: 'Слишком много попыток входа, попробуйте позже' },
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: false,
});

router.post('/register', authLimiter, registerValidation, handleValidationErrors, register);
router.post('/login', authLimiter, loginValidation, handleValidationErrors, login);
router.post('/send-code', sendVerificationCode);
router.post('/verify-code', verifyEmailCode);

module.exports = router;