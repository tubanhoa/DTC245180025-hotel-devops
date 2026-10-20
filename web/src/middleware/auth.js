const crypto = require('crypto');

function getClientIp(req) {
  const forwarded = req.headers['x-forwarded-for'];
  if (forwarded) {
    return forwarded.split(',')[0].trim();
  }
  return req.socket.remoteAddress || '127.0.0.1';
}

function logLoginAttempt(req, status, username, reason = '') {
  const ip = getClientIp(req);
  if (status === 'SUCCESS') {
    console.log(`LOGIN_SUCCESS ip=${ip} user=${username}`);
  } else {
    console.warn(`LOGIN_FAILED ip=${ip} user=${username} reason=${reason}`);
  }
}

function csrfProtection(req, res, next) {
  if (!req.session) {
    return next();
  }
  if (!req.session.csrfToken) {
    req.session.csrfToken = crypto.randomBytes(24).toString('hex');
  }
  
  // Gửi token vào cookie để client đọc được nếu cần
  res.cookie('XSRF-TOKEN', req.session.csrfToken, {
    httpOnly: false,
    sameSite: 'strict',
    secure: process.env.NODE_ENV === 'production' && req.secure
  });
  res.locals.csrfToken = req.session.csrfToken;

  if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) {
    return next();
  }

  const token = req.headers['x-csrf-token'] || (req.body && req.body._csrf) || (req.query && req.query._csrf);
  if (!token || token !== req.session.csrfToken) {
    return res.status(403).render('error', {
      title: 'Lỗi 403 - CSRF Token không hợp lệ',
      message: 'Yêu cầu của bạn bị từ chối do thiếu hoặc sai mã bảo mật CSRF token. Vui lòng tải lại trang và thử lại.'
    });
  }
  next();
}

function requireAuth(req, res, next) {
  if (!req.session || !req.session.user) {
    if (req.xhr || req.headers.accept?.includes('json')) {
      return res.status(401).json({ error: 'Chưa đăng nhập' });
    }
    return res.redirect(`/login?redirect=${encodeURIComponent(req.originalUrl)}`);
  }
  next();
}

function requireRole(...allowedRoles) {
  return (req, res, next) => {
    if (!req.session || !req.session.user) {
      return res.redirect('/login');
    }
    const userRole = req.session.user.role;
    if (allowedRoles.includes(userRole)) {
      return next();
    }
    res.status(403).render('error', {
      title: 'Lỗi 403 - Không có quyền truy cập',
      message: `Tài khoản vai trò '${userRole}' không được phép truy cập chức năng này.`
    });
  };
}

module.exports = {
  getClientIp,
  logLoginAttempt,
  csrfProtection,
  requireAuth,
  requireRole,
};
