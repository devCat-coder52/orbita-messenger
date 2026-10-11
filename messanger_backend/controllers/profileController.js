const profileService = require('../services/profileService');
const logger = require('../utils/logger');
const asyncHandler = require('../utils/asyncHandler');

exports.getProfileData = asyncHandler(async (req, res) => {
  const { userId } = req.params;
  const profile = await profileService.getProfile(userId);
  logger.info('Get profile', { userId });
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

  logger.info('Profile updated', { userId, name, location });
  return res.status(200).json({ success: true, data: updatedProfile });
});

exports.deleteAccount = asyncHandler(async (req, res) => {
  const myId = req.userId;

  await profileService.deleteAccount(myId);
  logger.info('User account deleted successfully', { myId });
  return res.status(200).json({ success: true, message: 'Аккаунт успешно удален' });
});