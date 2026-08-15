const User = require('../models/User');

exports.getProfileData = async (req, res) => {
  const userId = req.userId;
  console.log('User id: ' + userId);
  try {
    const profile = await User.getProfileData(userId);
    if (!profile) {
      return res.status(404).json({ error: 'Пользователь не найден' });
    }
    res.json(profile);
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({ error: 'Ошибка получения профиля' });
  }
};

exports.updateProfileData = async (req, res) => {
  const userId = req.userId;
  const name = req.body.name;
  const avatar_url = req.file ? `uploads/${req.file.filename}` : null;
  if (name && (name.length < 2 || name.length > 50)) {
    return res.status(400).json({ error: 'Имя должно быть от 2 до 50 символов' });
  }
  if (req.file) {
    const allowedTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
    if (!allowedTypes.includes(req.file.mimetype)) {
      return res.status(400).json({ error: 'Разрешены только изображения (JPEG, PNG, GIF, WebP)' });
    }
    if (req.file.size > 5 * 1024 * 1024) {
      return res.status(400).json({ error: 'Размер файла не должен превышать 5MB' });
    }
  }
  try {
    const updatedProfile = await User.updateProfileData({ userId, name, avatarUrl: avatar_url });
    res.json(updatedProfile);
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ error: 'Ошибка обновления профиля' });
  }
};