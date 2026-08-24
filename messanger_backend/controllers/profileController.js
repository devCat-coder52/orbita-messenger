const User = require('../models/User');

exports.getProfileData = async (req, res) => {
  const { userId } = req.params;
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
  const { name, location, birth_date, bio, gender } = req.body;
  const avatar_url = req.file ? `uploads/${req.file.filename}` : null;
  if (name && (name.length < 2 || name.length > 50)) {
    return res.json({ success: false, error: 'Имя должно быть от 2 до 25 символов' });
  }
  if (req.file) {
    const allowedTypes = ['image/jpeg', 'image/png', 'image/webp'];
    if (!allowedTypes.includes(req.file.mimetype)) {
      return res.json({ success: false, error: 'Разрешены только изображения (JPEG, PNG, GIF, WebP)' });
    }
    if (req.file.size > 5 * 1024 * 1024) {
      return res.json({ success: false, error: 'Размер файла не должен превышать 5MB' });
    }
  }
  try {
    const updatedProfile = await User.update({ userId, name, avatarUrl: avatar_url, location, birth_date, bio, gender });
    res.status(201).json( { success: true, data: updatedProfile });
  } catch (error) {
    console.error('Ошибка обновления профиля:', error);
    res.status(500).json({ error: 'Ошибка обновления профиля' });
  }
};