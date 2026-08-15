const nodemailer = require('nodemailer');
const redisClient = require('../config/redis'); 
const crypto = require('crypto');
require('dotenv').config();

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || 'smtp.gmail.com',
  port: parseInt(process.env.SMTP_PORT) || 587,
  secure: false,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

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
    redisClient.get(`verify_code:${email}`, (err, reply) => {
      if (err) {
        reject(err);
      } else {
        resolve(reply);
      }
    });
  });
}

const verificationCodes = new Map();

async function generateCode() {
  return crypto.randomInt(100000, 999999).toString();
}

async function sendVerificationCode(email) {
  const code = await generateCode();
  setVerifyCode(`verify_code:${email}`, 600, code);

  const mailOptions = {
    from: `"Orbita Messenger" <${process.env.SMTP_FROM_EMAIL || process.env.SMTP_USER}>`,
    to: email,
    subject: 'Код подтверждения для регистрации в Orbita',
    text: `Ваш код подтверждения: ${code}\n\nКод действителен в течение 10 минут.`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #4A90E2;">Orbita Messenger</h2>
        <p>Ваш код подтверждения:</p>
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
    console.log(`Код подтверждения отправлен на ${email}`);
    return true;
  } catch (error) {
    console.error('Ошибка отправки письма:', error);
    return false;
  }
}

async function verifyCode(email, code) {
  const codeString = await getVerifyCode(email);
  if (!codeString) {
    return { valid: false, message: 'Код не найден или истекло время ожидания' };
  }
  if (codeString !== code) {
    return { valid: false, message: 'Неверный код подтверждения' };
  }

  return { valid: true, message: 'Код подтвержден успешно' };
}

module.exports = {
  sendVerificationCode,
  verifyCode,
};