const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');

exports.register = async (req, res) => {
  const { login, email, password } = req.body;
  try {
    const existingUser = await User.findByEmail(email);
    if (existingUser) return res.status(400).json({ error: 'Email уже используется' });

    const existingUserByLogin = await User.findByLogin(login);
    if (existingUserByLogin) return res.status(400).json({ error: 'Логин уже используется' });

    const hashedPassword = await bcrypt.hash(password, 10);
    const newUser = await User.create({ login, email, password: hashedPassword });
    const token = jwt.sign({ userId: newUser.id }, process.env.JWT_SECRET || 'secretkey');

    res.status(201).json({ token, user: { id: newUser.id, login: newUser.login, email: newUser.email } });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.login = async (req, res) => {
  const { login, password } = req.body;
  try {
    const user = await User.findByLogin(login);
    const cryptPassword = await bcrypt.compare(password, user.password);

    /*if (!user || !bcrypt.compareSync(password, user.password)) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }*/
    if (!user || !cryptPassword)
      return res.status(400).json({ error: 'Неверный логин или пароль' });

    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET || 'secretkey');

    res.json({ token, user: { id: user.id, login: user.login, email: user.email } });
  } catch (error) {
    console.log(error.message)
    res.status(500).json({ error: error.message });
  }
};