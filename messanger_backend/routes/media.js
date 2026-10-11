const express = require('express');
const router = express.Router();
const { sendImage, sendFile, sendVoice } = require('../controllers/mediaController');
const { uploadImage, uploadFile, uploadVoice } = require('../middleware/upload');

router.post('/:chatId/image', uploadImage.single('image'), sendImage);
router.post('/:chatId/file', uploadFile.single('file'), sendFile);
router.post('/:chatId/voice', uploadVoice.single('voice'), sendVoice);

module.exports = router;