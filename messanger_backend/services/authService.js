const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const emailService = require('./emailService');

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
    const token = this.generateToken(newUser.id);

    return {
      token,
      user: {
        id: newUser.id,
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

    const token = this.generateToken(user.id);

    return {
      token,
      user: {
        id: user.id,
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
      throw new Error('Требуется email и код подтверждения');
    }

    const result = await emailService.verifyCode(email, code);
    if (!result.valid) {
      throw new Error(result.message);
    }

    return { message: 'Email успешно подтвержден' };
  }

  generateToken(userId) {
    return jwt.sign(
      { userId },
      process.env.JWT_SECRET || 'your-local-dev-secret-key',
      { expiresIn: '7d' }
    );
  }

}

module.exports = new AuthService();
