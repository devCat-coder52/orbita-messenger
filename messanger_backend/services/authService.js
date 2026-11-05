const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const emailService = require('./emailService');
const { JWT_SECRET } = require('../config/constants');

class AuthService {

  async register(login, email, password, code) {
    if (!code) {
      const error = new Error('Требуется код подтверждения email');
      error.statusCode = 400;
      throw error;
    }

    const codeResult = await emailService.verifyCode(email, code);
    if (!codeResult.valid) {
      const error = new Error(codeResult.message);
      error.statusCode = 400;
      throw error;
    }

    const existingUserByEmail = await User.findByEmail(email);
    if (existingUserByEmail) {
      const error = new Error('Этот email уже зарегистрирован');
      error.statusCode = 409;
      throw error;
    }

    const existingUserByLogin = await User.findByLogin(login);
    if (existingUserByLogin) {
      const error = new Error('Логин уже используется');
      error.statusCode = 409;
      throw error;
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const newUser = await User.create({ login, email, password: hashedPassword });
    await emailService.consumeCode(email);
    const token = this.generateToken(newUser.id);

    return {
      token,
      user: {
        id: Number(newUser.id),
        login: newUser.login,
        email: newUser.email
      }
    };
  }

  async login(login, password) {
    if (!login || !password) {
      const error = new Error('Логин и пароль обязательны');
      error.statusCode = 400;
      throw error;
    }

    const user = await User.findByLogin(login);
    if (!user) {
      const error = new Error('Неверный логин или пароль');
      error.statusCode = 401;
      throw error;
    }

    const isValidPassword = await bcrypt.compare(password, user.password);
    if (!isValidPassword) {
      const error = new Error('Неверный логин или пароль');
      error.statusCode = 401;
      throw error;
    }

    const token = this.generateToken(user.id, user.token_version);

    return {
      token,
      user: {
        id: Number(user.id),
        login: user.login,
        email: user.email
      }
    };
  }

  async sendVerificationCode(email, login) {
    if (!email || !/^\S+@\S+\.\S+$/.test(email)) {
      const error = new Error('Некорректный email');
      error.statusCode = 400;
      throw error;
    }

    const isMailExists = await User.findByEmail(email);
    if (isMailExists) {
      const error = new Error('Этот email уже зарегистрирован');
      error.statusCode = 409;
      throw error;
    }

    const isUserExists = await User.findByLogin(login);
    if (isUserExists) {
      const error = new Error('Логин уже используется');
      error.statusCode = 409;
      throw error;
    }

    const success = await emailService.sendVerificationCode(email);

    if (!success) {
      const error = new Error('Ошибка отправки письма');
      error.statusCode = 500;
      throw error;
    }

    return { message: 'Код подтверждения отправлен на email' };
  }

  async verifyEmailCode(email, code) {
    if (!email || !code) {
      const error = new Error('Требуется email и код подтверждения');
      error.statusCode = 400;
      throw error;
    }

    const result = await emailService.verifyCode(email, code);
    if (!result.valid) {
      const error = new Error(result.message);
      error.statusCode = 400;
      throw error;
    }

    return { message: 'Email успешно подтвержден' };
  }

  /** Отправляет код подтверждения для сброса пароля. */
  async requestPasswordResetCode(email) {
    if (!email || !/^\S+@\S+\.\S+$/.test(email)) {
      const error = new Error('Некорректный email');
      error.statusCode = 400;
      throw error;
    }

    const user = await User.findByEmail(email);
    if (!user) {
      const error = new Error('Пользователь с таким email не найден');
      error.statusCode = 404;
      throw error;
    }

    const sent = await emailService.sendVerificationCode(email);
    if (!sent) {
      const error = new Error('Ошибка отправки письма');
      error.statusCode = 500;
      throw error;
    }

    return { message: 'Код отправлен на email' };
  }

  /** Меняет пароль по коду и инвалидирует все старые токены пользователя. */
  async resetPassword(email, code, newPassword) {
    if (!email || !code || !newPassword) {
      const error = new Error('Требуются email, код и новый пароль');
      error.statusCode = 400;
      throw error;
    }
    if (newPassword.length < 6) {
      const error = new Error('Пароль должен быть не менее 6 символов');
      error.statusCode = 400;
      throw error;
    }

    const codeResult = await emailService.verifyCode(email, code);
    if (!codeResult.valid) {
      const error = new Error(codeResult.message);
      error.statusCode = 400;
      throw error;
    }

    const hashedPassword = await bcrypt.hash(newPassword, 10);
    const updated = await User.updatePassword(email, hashedPassword);
    if (!updated) {
      const error = new Error('Пользователь с таким email не найден');
      error.statusCode = 404;
      throw error;
    }

    await emailService.consumeCode(email);
    return { message: 'Пароль изменён' };
  }

  generateToken(userId, tokenVersion = 0) {
    return jwt.sign(
      { userId: Number(userId), v: Number(tokenVersion) || 0 },
      JWT_SECRET,
      { expiresIn: '7d' }
    );
  }

}

module.exports = new AuthService();
