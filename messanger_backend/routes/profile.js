const express = require('express');
const router = express.Router();
const authenticateToken = require('../middleware/auth');
const multer = require('multer');
const path = require('path');

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/');
  },
  filename: (req, file, cb) => {
    cb(null, Date.now() + path.extname(file.originalname));
  }
});

const upload = multer({ storage: storage });
const { getProfileData, updateProfileData } = require('../controllers/profileController');

router.get('/:userId', authenticateToken, getProfileData);
router.put('/', authenticateToken, upload.single('avatar'), updateProfileData);

module.exports = router;