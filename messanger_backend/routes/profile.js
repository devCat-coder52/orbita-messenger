const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const { UPLOADS_DIR, IMAGE_MAX_SIZE } = require('../config/constants');
const { imageFilter } = require('../middleware/upload');
const validateId = require('../middleware/validateId');

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, UPLOADS_DIR),
  filename: (req, file, cb) => {
    const uniqueName = `${Date.now()}-${Math.round(Math.random() * 1e9)}${path.extname(file.originalname)}`;
    cb(null, uniqueName);
  },
});

const upload = multer({
  storage,
  fileFilter: imageFilter,
  limits: { fileSize: IMAGE_MAX_SIZE },
});

const {
  getProfileData,
  updateProfileData,
  deleteAccount,
  sendDeleteAccountCode,
  changePassword,
  sendPasswordChangeCode,
  updatePrivacy,
} = require('../controllers/profileController');

router.get('/:userId', validateId('userId', { allowService: true }), getProfileData);
router.put('/', upload.single('avatar'), updateProfileData);
router.post('/password-code', sendPasswordChangeCode);
router.post('/change-password', changePassword);
router.post('/privacy', updatePrivacy);
router.post('/delete-code', sendDeleteAccountCode);
router.post('/delete', deleteAccount);

module.exports = router;
