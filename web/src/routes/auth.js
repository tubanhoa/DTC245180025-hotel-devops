const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const db = require('../db');
const { logLoginAttempt } = require('../middleware/auth');

router.get('/login', (req, res) => {
  if (req.session.user) {
    return res.redirect('/');
  }
  res.render('login', { title: 'Đăng nhập - Khách Sạn', error: null, redirect: req.query.redirect || '' });
});

router.post('/login', async (req, res) => {
  const { username, password, redirect } = req.body;
  if (!username || !password) {
    logLoginAttempt(req, 'FAILED', username || 'empty', 'wrong_password');
    return res.render('login', { title: 'Đăng nhập', error: 'Vui lòng nhập đầy đủ tên đăng nhập và mật khẩu.', redirect });
  }

  try {
    const result = await db.query('SELECT * FROM users WHERE username = $1', [username.trim()]);
    if (result.rows.length === 0) {
      logLoginAttempt(req, 'FAILED', username.trim(), 'unknown_user');
      return res.render('login', { title: 'Đăng nhập', error: 'Tên đăng nhập hoặc mật khẩu không đúng.', redirect });
    }

    const user = result.rows[0];
    if (!user.is_active) {
      logLoginAttempt(req, 'FAILED', username.trim(), 'inactive');
      return res.render('login', { title: 'Đăng nhập', error: 'Tài khoản của bạn đã bị khóa. Vui lòng liên hệ quản lý.', redirect });
    }

    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      logLoginAttempt(req, 'FAILED', username.trim(), 'wrong_password');
      return res.render('login', { title: 'Đăng nhập', error: 'Tên đăng nhập hoặc mật khẩu không đúng.', redirect });
    }

    // Đăng nhập thành công
    logLoginAttempt(req, 'SUCCESS', user.username);
    req.session.user = {
      id: user.id,
      username: user.username,
      full_name: user.full_name,
      email: user.email,
      role: user.role
    };

    if (redirect && redirect.startsWith('/')) {
      return res.redirect(redirect);
    }
    if (user.role === 'manager') return res.redirect('/manager/dashboard');
    if (user.role === 'staff') return res.redirect('/reception');
    return res.redirect('/rooms');
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).render('error', { title: 'Lỗi', message: 'Lỗi hệ thống khi đăng nhập.' });
  }
});

router.get('/register', (req, res) => {
  if (req.session.user) {
    return res.redirect('/');
  }
  res.render('register', { title: 'Đăng ký tài khoản khách hàng', error: null });
});

router.post('/register', async (req, res) => {
  const { username, email, password, full_name, phone } = req.body;
  if (!username || !email || !password || !full_name) {
    return res.render('register', { title: 'Đăng ký', error: 'Vui lòng điền đầy đủ các thông tin bắt buộc.' });
  }

  if (password.length < 6) {
    return res.render('register', { title: 'Đăng ký', error: 'Mật khẩu phải có tối thiểu 6 ký tự.' });
  }

  try {
    const existing = await db.query('SELECT id FROM users WHERE username = $1 OR email = $2', [username.trim(), email.trim()]);
    if (existing.rows.length > 0) {
      return res.render('register', { title: 'Đăng ký', error: 'Tên đăng nhập hoặc email đã được sử dụng.' });
    }

    const passwordHash = await bcrypt.hash(password, 10);
    await db.query(
      `INSERT INTO users (username, email, password_hash, full_name, phone, role)
       VALUES ($1, $2, $3, $4, $5, 'customer')`,
      [username.trim(), email.trim(), passwordHash, full_name.trim(), phone?.trim() || null]
    );

    res.redirect('/login?registered=1');
  } catch (err) {
    console.error('Register error:', err);
    res.status(500).render('error', { title: 'Lỗi', message: 'Lỗi hệ thống khi tạo tài khoản.' });
  }
});

router.get('/logout', (req, res) => {
  req.session.destroy(() => {
    res.redirect('/login');
  });
});

module.exports = router;
