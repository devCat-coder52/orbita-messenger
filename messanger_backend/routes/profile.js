const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const { UPLOADS_DIR, IMAGE_MAX_SIZE } = require('../config/constants');

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, UPLOADS_DIR),
  filename: (req, file, cb) => {
    const uniqueName = `${Date.now()}-${Math.round(Math.random() * 1e9)}${path.extname(file.originalname)}`;
    cb(null, uniqueName);
  },
});

const upload = multer({ storage, limits: { fileSize: IMAGE_MAX_SIZE } });
const { getProfileData, updateProfileData, deleteAccount } = require('../controllers/profileController');

router.get('/:userId', getProfileData);
router.put('/', upload.single('avatar'), updateProfileData);
router.post('/delete', deleteAccount);

module.exports = router;