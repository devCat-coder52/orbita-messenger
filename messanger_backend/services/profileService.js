const User = require('../models/User');
const Chat = require('../models/Chat');
const { deleteMediaFiles } = require('./mediaService');
const chatService = require('./chatService');

class ProfileService {

  async getProfile(userId, viewerId) {
    const profile = await User.get(userId);

    if (!profile) {
      const error = new Error('Пользователь не найден');
      error.statusCode = 404;
      throw error;
    }

    if (Number(viewerId) !== Number(userId)) {
      delete profile.email;
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

    const previousAvatar = (await User.get(userId))?.avatar_url || null;

    const updatedProfile = await User.update({
      userId,
      name,
      avatarUrl,
      location,
      birth_date,
      bio,
      gender
    });

    if (avatarUrl && previousAvatar && previousAvatar !== avatarUrl) {
      await deleteMediaFiles([previousAvatar]);
    }

    return updatedProfile;
  }

  async deleteAccount(userId) {
    const chats = await Chat.getUserChatsList(userId);
    for (const chatId of chats) {
      const media = await chatService.leaveChat(chatId, userId);
      if (media.length > 0) {
        await deleteMediaFiles(media);
      }
    }
    await User.delete(userId);
  }

  async userExists(userId) {
    const user = await User.findById(userId);
    return !!user;
  }
}

module.exports = new ProfileService();
