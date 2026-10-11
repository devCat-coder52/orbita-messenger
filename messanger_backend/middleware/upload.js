const fs = require('fs');
const multer = require('multer');
const path = require('path');
const {
  UPLOADS_DIR,
  MESSAGES_DIR,
  FILES_DIR,
  VOICES_DIR,
  IMAGE_MAX_SIZE,
  FILE_MAX_SIZE,
  VOICE_MAX_SIZE,
} = require('../config/constants');

const ALLOWED_VOICE_TYPES = [
  'audio/mp4',
  'audio/mpeg4',
  'audio/x-m4a',
  'audio/aac',
  'audio/mp4a-latm',
  'audio/webm',
  'audio/ogg',
  'audio/opus',
  'audio/wav',
  'audio/x-wav',
  'audio/amr',
  'audio/3gpp',
];

const ALLOWED_VOICE_EXTENSIONS = ['.m4a', '.aac', '.webm', '.ogg', '.opus', '.wav', '.amr', '.mp3'];

const ensureDir = (dir) => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
};

[UPLOADS_DIR, MESSAGES_DIR, FILES_DIR, VOICES_DIR].forEach(ensureDir);

const diskStorageOptions = (dir) => ({
  destination: (req, file, cb) => cb(null, dir),
  filename: (req, file, cb) => {
    const uniqueName = `${Date.now()}-${Math.round(Math.random() * 1e9)}${path.extname(file.originalname)}`;
    cb(null, uniqueName);
  },
});

const imageFilter = (req, file, cb) => {
  if (file.mimetype.startsWith('image/')) {
    cb(null, true);
  } else {
    cb(new Error('Только изображения разрешены'), false);
  }
};

const anyFileFilter = (req, file, cb) => cb(null, true);

const voiceFilter = (req, file, cb) => {
  const ext = path.extname(file.originalname || '').toLowerCase();
  if (
    file.mimetype.startsWith('audio/') ||
    ALLOWED_VOICE_TYPES.includes(file.mimetype) ||
    ALLOWED_VOICE_EXTENSIONS.includes(ext)
  ) {
    cb(null, true);
  } else {
    cb(new Error('Разрешены только аудиофайлы'), false);
  }
};

const uploadImage = multer({
  storage: multer.diskStorage(diskStorageOptions(MESSAGES_DIR)),
  fileFilter: imageFilter,
  limits: { fileSize: IMAGE_MAX_SIZE },
});

const uploadFile = multer({
  storage: multer.diskStorage(diskStorageOptions(FILES_DIR)),
  fileFilter: anyFileFilter,
  limits: { fileSize: FILE_MAX_SIZE },
});

const uploadVoice = multer({
  storage: multer.diskStorage(diskStorageOptions(VOICES_DIR)),
  fileFilter: voiceFilter,
  limits: { fileSize: VOICE_MAX_SIZE },
});

module.exports = {
  uploadImage,
  uploadFile,
  uploadVoice,
};