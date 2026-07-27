const User = require('../models/User');

exports.getProfileData = async (req, res) => {
  const userId = req.userId;
  console.log('User id: ' + userId);
  try {
    const profile = await User.getProfileData(userId);
    res.json(profile);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.updateProfileData = async (req, res) => {
  const userId = req.userId;
  const name = req.body.name;

  let avatar_url;
  if (req.file) {
    avatar_url = `uploads/${req.file.filename}`;
  }
  try {
    const updatedProfile = await User.updateProfileData({ userId, name, avatarUrl: avatar_url });
    res.json(updatedProfile);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};