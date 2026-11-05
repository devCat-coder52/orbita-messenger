const express = require('express');
const router = express.Router();
const { sendImage, sendFile, sendVoice } = require('../controllers/mediaController');
const { uploadImage, uploadFile, uploadVoice } = require('../middleware/upload');
const requireChatAccess = require('../middleware/requireChatAccess');

router.post('/:chatId/image', requireChatAccess, uploadImage.single('image'), sendImage);
router.post('/:chatId/file', requireChatAccess, uploadFile.single('file'), sendFile);
router.post('/:chatId/voice', requireChatAccess, uploadVoice.single('voice'), sendVoice);

module.exports = router;
