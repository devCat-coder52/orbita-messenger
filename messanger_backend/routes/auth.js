const express = require('express');
const router = express.Router();
const { register, login, sendVerificationCode, verifyEmailCode } = require('../controllers/authController');
const rateLimit = require('express-rate-limit');

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: { error: 'Слишком много попыток входа, попробуйте позже' },
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: false,
});

router.post('/register', authLimiter, register);
router.post('/login', authLimiter, login);
router.post('/send-code', sendVerificationCode);
router.post('/verify-code', verifyEmailCode);

module.exports = router;