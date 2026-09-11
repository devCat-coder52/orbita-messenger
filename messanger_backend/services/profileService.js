const User = require('../models/User');

class ProfileService {

  async getProfile(userId) {
    const profile = await User.get(userId);

    if (!profile) {
      const error = new Error('Пользователь не найден');
      error.statusCode = 404;
      throw error;
    }

    return profile;
  }

  async updateProfile(userId, updates, avatarFile = null) {
    const { name, location, birth_date, bio, gender } = updates;

    if (name && (name.length < 2 || name.length > 25)) {
      const error = new Error('Имя должно быть от 2 до 25 символов');
      error.statusCode = 400;
      throw error;
    }

    let avatarUrl = null;
    if (avatarFile) {
      const allowedTypes = ['image/jpeg', 'image/png', 'image/webp'];
      if (!allowedTypes.includes(avatarFile.mimetype)) {
        const error = new Error('Разрешены только изображения (JPEG, PNG, WebP)');
        error.statusCode = 400;
        throw error;
      }

      if (avatarFile.size > 5 * 1024 * 1024) {
        const error = new Error('Размер файла не должен превышать 5MB');
        error.statusCode = 400;
        throw error;
      }

      avatarUrl = `uploads/${avatarFile.filename}`;
    }

    const updatedProfile = await User.update({
      userId,
      name,
      avatarUrl,
      location,
      birth_date,
      bio,
      gender
    });

    return updatedProfile;
  }

  async userExists(userId) {
    const user = await User.findById(userId);
    return !!user;
  }
}

module.exports = new ProfileService();
