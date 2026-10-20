const express = require('express');
const path = require('path');
const session = require('express-session');
const cookieParser = require('cookie-parser');
const { csrfProtection } = require('./middleware/auth');

const app = express();
const port = process.env.PORT || 3000;

// Security: An X-Powered-By
app.disable('x-powered-by');

app.set('trust proxy', 1);
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, '../views'));

// Body Parser và Cookie Parser
app.use(express.urlencoded({ extended: true, limit: '5mb' }));
app.use(express.json({ limit: '5mb' }));
app.use(cookieParser());

// Static Files
app.use(express.static(path.join(__dirname, '../public')));
app.use('/uploads', express.static(path.join(__dirname, '../public/uploads')));

// Session
app.use(session({
  name: 'hotel_sid',
  secret: process.env.SESSION_SECRET || 'hotel_default_session_secret_32_chars_long',
  resave: false,
  saveUninitialized: false,
  cookie: {
    httpOnly: true,
    sameSite: 'strict',
    secure: process.env.NODE_ENV === 'production',
    maxAge: 24 * 60 * 60 * 1000 // 24 giờ
  }
}));

// CSRF Protection
app.use(csrfProtection);

// Global view variables
app.use((req, res, next) => {
  res.locals.currentUser = req.session.user || null;
  res.locals.currentPath = req.path;
  next();
});

// Routes
app.use('/', require('./routes/health'));
app.use('/', require('./routes/auth'));
app.use('/', require('./routes/rooms'));
app.use('/', require('./routes/customer'));
app.use('/reception', require('./routes/reception'));
app.use('/manager', require('./routes/manager'));

// 404 Handler
app.use((req, res) => {
  res.status(404).render('error', {
    title: '404 - Không tìm thấy trang',
    message: 'Địa chỉ bạn truy cập không tồn tại hoặc đã được di dời.'
  });
});

// 500 Handler
app.use((err, req, res, next) => {
  console.error('Unhandled Server Error:', err);
  res.status(500).render('error', {
    title: '500 - Lỗi máy chủ',
    message: err.message || 'Đã có lỗi bất ngờ xảy ra trên máy chủ.'
  });
});

app.listen(port, () => {
  console.log(`Hotel Booking Web Server running on port ${port}`);
});
