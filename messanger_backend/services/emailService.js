const nodemailer = require('nodemailer');
const crypto = require('crypto');
const redisClient = require('../config/redis');
const config = require('../config/env');
const { VERIFY_CODE_TTL_SECONDS } = require('../config/constants');
const logger = require('../utils/logger');

const SEND_COOLDOWN_SECONDS = 60;

const transporter = nodemailer.createTransport({
  host: config.smtp.host,
  port: config.smtp.port,
  secure: false,
  auth: {
    user: config.smtp.user,
    pass: config.smtp.pass,
  },
});

const verifyCodeKey = (email) => `verify_code:${email}`;

const setVerifyCode = (key, seconds, value) => {
  return new Promise((resolve, reject) => {
    redisClient.setex(key, seconds, value, (err, reply) => {
      if (err) reject(err);
      else resolve(reply);
    });
  });
};

const getVerifyCode = (email) => {
  return new Promise((resolve, reject) => {
    redisClient.get(verifyCodeKey(email), (err, reply) => {
      if (err) {
        reject(err);
      } else {
        resolve(reply);
      }
    });
  });
};

function generateCode() {
  return crypto.randomInt(100000, 999999).toString();
}

const MAX_CODE_ATTEMPTS = 5;
const attemptsKey = (email) => `verify_attempts:${email}`;

const getAttempts = (email) =>
  new Promise((resolve, reject) => {
    redisClient.get(attemptsKey(email), (err, reply) =>
      err ? reject(err) : resolve(Number(reply) || 0)
    );
  });

const bumpAttempts = (email) =>
  new Promise((resolve, reject) => {
    redisClient
      .multi()
      .incr(attemptsKey(email))
      .expire(attemptsKey(email), VERIFY_CODE_TTL_SECONDS)
      .exec((err, replies) => {
        if (err) return reject(err);
        return resolve(Number(replies && replies[0]) || 0);
      });
  });

const resetAttempts = (email) =>
  new Promise((resolve) => {
    redisClient.del(attemptsKey(email), () => resolve());
  });

const PURPOSES = {
  registration: {
    subject: 'Код подтверждения для регистрации в Orbita',
    intro: 'Ваш код для регистрации:',
  },
  password_reset: {
    subject: 'Восстановление пароля в Orbita',
    intro: 'Ваш код для восстановления пароля:',
  },
  password_change: {
    subject: 'Смена пароля в Orbita',
    intro: 'Ваш код для смены пароля:',
  },
  account_deletion: {
    subject: 'Удаление аккаунта Orbita',
    intro: 'Ваш код для удаления аккаунта:',
  },
};

async function sendVerificationCode(email, purpose = 'registration') {
  const cooldownKey = `verify_cooldown:${email}`;
  const coolingDown = await new Promise((resolve, reject) => {
    redisClient.get(cooldownKey, (err, reply) => (err ? reject(err) : resolve(reply)));
  });
  if (coolingDown) {
    const error = new Error('Слишком часто. Попробуйте через минуту');
    error.statusCode = 429;
    throw error;
  }

  const code = generateCode();
  await setVerifyCode(verifyCodeKey(email), VERIFY_CODE_TTL_SECONDS, code);
  await setVerifyCode(cooldownKey, SEND_COOLDOWN_SECONDS, '1');
  await resetAttempts(email);

  const purposeText = PURPOSES[purpose] || PURPOSES.registration;

  const mailOptions = {
    from: `"Orbita Messenger" <${config.smtp.fromEmail}>`,
    to: email,
    subject: purposeText.subject,
    text: `${purposeText.intro} ${code}\n\nКод действителен в течение 10 минут.`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #4A90E2;">Orbita Messenger</h2>
        <p>${purposeText.intro}</p>
        <div style="background-color: #f5f5f5; padding: 20px; text-align: center; border-radius: 5px; margin: 20px 0;">
          <span style="font-size: 32px; font-weight: bold; color: #4A90E2; letter-spacing: 5px;">${code}</span>
        </div>
        <p>Код действителен в течение 10 минут.</p>
        <p style="color: #888; font-size: 12px;">Если вы не запрашивали этот код, просто проигнорируйте это письмо.</p>
      </div>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    logger.debug('Код подтверждения отправлен', { email });
    return true;
  } catch (error) {
    logger.error('Ошибка отправки письма', { error: error.message, email });
    return false;
  }
}

async function verifyCode(email, code) {
  const attempts = await getAttempts(email);
  if (attempts >= MAX_CODE_ATTEMPTS) {
    return {
      valid: false,
      message: 'Слишком много попыток ввода кода. Запросите новый код.',
    };
  }

  const codeString = await getVerifyCode(email);

  if (!codeString) {
    return { valid: false, message: 'Код не найден или истекло время ожидания' };
  }
  if (String(codeString) !== String(code).trim()) {
    await bumpAttempts(email).catch(() => {});
    return { valid: false, message: 'Неверный код подтверждения' };
  }

  return { valid: true, message: 'Код подтвержден успешно' };
}

async function consumeCode(email) {
  try {
    await new Promise((resolve, reject) => {
      redisClient.del(verifyCodeKey(email), (err) => (err ? reject(err) : resolve()));
    });
  } catch (error) {
    logger.warn('Не удалось удалить код подтверждения', {
      error: error.message,
      email,
    });
  }
}

module.exports = {
  sendVerificationCode,
  verifyCode,
  consumeCode,
};
