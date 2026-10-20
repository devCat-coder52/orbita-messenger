const fs = require('fs').promises;
const path = require('path');
const { UPLOADS_DIR } = require('../config/constants');
const logger = require('../utils/logger');

class MediaService {

  async deleteMediaFiles(mediaUrls) {

    if (!Array.isArray(mediaUrls) || mediaUrls.length === 0) {
      return;
    }

    for (const url of mediaUrls) {
      try {
        await deleteMediaFile(url);
      } catch (err) {
        logger.error(err);
      }
    }
  }
}

module.exports = new MediaService();

const resolveFilePath = async (mediaUrl) => {
    if (!mediaUrl || typeof mediaUrl !== 'string') {
      return null;
    }

    let urlPath = mediaUrl;
    try {
      if (/^https?:\/\//i.test(urlPath)) {
        urlPath = new URL(urlPath).pathname;
      }
    } catch {
      return null;
    }
    urlPath = urlPath.split('?')[0].split('#')[0];

    const normalized = path.normalize(decodeURIComponent(urlPath));
    const uploadsRel = path.relative(UPLOADS_DIR, path.join(__dirname, '..', normalized));

    if (!uploadsRel || uploadsRel.startsWith('..') || path.isAbsolute(uploadsRel)) {
      logger.warn(`mediaService: отклонён некорректный медиа URL: ${mediaUrl}`);
      return null;
    }

    return path.join(UPLOADS_DIR, uploadsRel);
  }

  const deleteMediaFile = async (mediaUrl) => {
    const filePath = await resolveFilePath(mediaUrl);
    if (!filePath) {
      return false;
    }

    try {
      await fs.unlink(filePath);
      return true;
    } catch (err) {
      if (err.code === 'ENOENT') {
        return false;
      }
      logger.error(`mediaService: ошибка удаления ${filePath}: ${err.message}`);
      throw err;
    }
  }