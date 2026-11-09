const profileService = require('../services/profileService');
const authService = require('../services/authService');
const emailService = require('../services/emailService');
const User = require('../models/User');
const logger = require('../utils/logger');
const asyncHandler = require('../utils/asyncHandler');

exports.getProfileData = asyncHandler(async (req, res) => {
  const { userId } = req.params;
  const profile = await profileService.getProfile(userId, req.userId);
  logger.debug('Get profile', { userId, viewerId: req.userId });
  return res.status(200).json(profile);
});

exports.updateProfileData = asyncHandler(async (req, res) => {
  const userId = req.userId;
  const { name, location, birth_date, bio, gender } = req.body;
  const avatarFile = req.file;

  const updatedProfile = await profileService.updateProfile(
    userId,
    { name, location, birth_date, bio, gender },
    avatarFile
  );

  logger.debug('Profile updated', { userId, name, location });
  return res.status(200).json({ success: true, data: updatedProfile });
});

exports.sendPasswordChangeCode = asyncHandler(async (req, res) => {
  const userId = req.userId;

  const profile = await User.get(userId);
  if (!profile || !profile.email) {
    return res
      .status(400)
      .json({ success: false, error: 'У аккаунта не указан email' });
  }

  await emailService.sendVerificationCode(profile.email, 'password_change');
  logger.debug('Password change code sent', { userId });

  return res
    .status(200)
    .json({ success: true, message: 'Код отправлен на email' });
});

exports.changePassword = asyncHandler(async (req, res) => {
  const userId = req.userId;
  const { current_password, new_password, code } = req.body;

  const result = await authService.changePassword(
    userId,
    current_password,
    new_password,
    code
  );

  logger.debug('Password changed', { userId });
  return res.status(200).json({
    success: true,
    message: result.message,
    token: result.token,
  });
});

exports.updatePrivacy = asyncHandler(async (req, res) => {
  const userId = req.userId;
  const { show_online, show_last_seen } = req.body;

  const updated = await User.updatePrivacy(userId, {
    showOnline: show_online !== false,
    showLastSeen: show_last_seen !== false,
  });

  if (!updated) {
    return res.status(404).json({ success: false, error: 'Пользователь не найден' });
  }

  logger.debug('Privacy updated', { userId });
  return res.status(200).json({
    success: true,
    show_online: updated.show_online,
    show_last_seen: updated.show_last_seen,
  });
});

exports.sendDeleteAccountCode = asyncHandler(async (req, res) => {
  const userId = req.userId;

  const profile = await User.get(userId);
  if (!profile || !profile.email) {
    return res
      .status(400)
      .json({ success: false, error: 'У аккаунта не указан email' });
  }

  await emailService.sendVerificationCode(profile.email, 'account_deletion');
  logger.debug('Account deletion code sent', { userId });

  return res
    .status(200)
    .json({ success: true, message: 'Код отправлен на email' });
});

exports.deleteAccount = asyncHandler(async (req, res) => {
  const myId = req.userId;
  const { password, code } = req.body;

  await profileService.deleteAccount(myId, password, code);
  logger.info('User account deleted successfully', { myId });
  return res.status(200).json({ success: true, message: 'Аккаунт успешно удален' });
});