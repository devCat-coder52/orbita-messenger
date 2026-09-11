const profileService = require('../services/profileService');
const logger = require('../utils/logger');

exports.getProfileData = async (req, res) => {
  const { userId } = req.params;
  try {
    const profile = await profileService.getProfile(userId);
    return res.status(201).json(profile);
  } catch (error) {
    logger.error('Get profile error', { error, userId });
    if (error.statusCode) {
      return res.status(error.statusCode).json({ error: `Ошибка получения данных профиля: ${error.message}` });
    }
    return res.status(500).json({ error: `Ошибка получения данных профиля: ${message}: ${error}` });
  }
};

exports.updateProfileData = async (req, res) => {
  const userId = req.userId;
  const { name, location, birth_date, bio, gender } = req.body;
  const avatarFile = req.file;
  try {
    const updatedProfile = await profileService.updateProfile(
      userId,
      { name, location, birth_date, bio, gender },
      avatarFile
    );
    logger.info('Profile updated', { userId, name, location });
    return res.status(201).json({ success: true, data: updatedProfile });
  } catch (error) {
    logger.error('Update profile error', { error, userId });
    if (error.statusCode) {
      return res.status(error.statusCode).json({ error: `Ошибка обновления профиля: ${error.message}` });
    }
    return res.status(500).json({ error: `Ошибка обновления профиля: ${message}: ${error}` });
  }
};