const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const multer = require('multer');
const db = require('../db');
const { requireRole } = require('../middleware/auth');

router.use(requireRole('manager'));

// Cấu hình Multer upload ảnh loại phòng
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = path.join(__dirname, '../../public/uploads');
    fs.mkdirSync(uploadDir, { recursive: true });
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    const randomName = crypto.randomBytes(16).toString('hex') + ext;
    cb(null, randomName);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 2 * 1024 * 1024 }, // Tối đa 2 MB
  fileFilter: (req, file, cb) => {
    const allowedExtensions = ['.png', '.jpg', '.jpeg', '.webp'];
    const allowedMimeTypes = ['image/png', 'image/jpeg', 'image/webp'];
    const ext = path.extname(file.originalname).toLowerCase();

    if (!allowedExtensions.includes(ext) || !allowedMimeTypes.includes(file.mimetype)) {
      return cb(new Error('Chỉ chấp nhận các tệp hình ảnh định dạng PNG, JPG, hoặc WEBP.'));
    }
    cb(null, true);
  }
});

// Middleware kiểm tra Magic Bytes thực tế của file ảnh
async function verifyMagicBytes(filePath) {
  const buffer = Buffer.alloc(12);
  const fd = await fs.promises.open(filePath, 'r');
  await fd.read(buffer, 0, 12, 0);
  await fd.close();

  // PNG: 89 50 4E 47 0D 0A 1A 0A
  const isPng = buffer[0] === 0x89 && buffer[1] === 0x50 && buffer[2] === 0x4E && buffer[3] === 0x47;
  // JPEG: FF D8 FF
  const isJpg = buffer[0] === 0xFF && buffer[1] === 0xD8 && buffer[2] === 0xFF;
  // WEBP: RIFF....WEBP (52 49 46 46 .... 57 45 42 50)
  const isWebp = buffer.toString('ascii', 0, 4) === 'RIFF' && buffer.toString('ascii', 8, 12) === 'WEBP';

  return isPng || isJpg || isWebp;
}

// 1. Dashboard KPI
router.get('/dashboard', async (req, res) => {
  try {
    const [kpiRes, topTypesRes, topServicesRes, revenueByDayRes] = await Promise.all([
      db.query(`
        SELECT
          (SELECT COALESCE(SUM(amount_due), 0) FROM payments WHERE paid_at >= CURRENT_DATE) AS revenue_today,
          (SELECT COUNT(id) FROM bookings WHERE checked_in_at >= CURRENT_DATE) AS checkins_today,
          (SELECT COUNT(id) FROM bookings WHERE status = 'confirmed' AND check_in_date >= CURRENT_DATE) AS upcoming_bookings,
          (SELECT COUNT(id) FROM rooms WHERE status = 'occupied' AND is_active = true) AS occupied_rooms,
          (SELECT COUNT(id) FROM rooms WHERE is_active = true) AS total_rooms
      `),
      db.query(`
        SELECT rt.name, COUNT(b.id) AS booking_count, COALESCE(SUM(b.total_amount), 0) AS total_revenue
        FROM room_types rt
        LEFT JOIN rooms r ON rt.id = r.room_type_id
        LEFT JOIN bookings b ON r.id = b.room_id AND b.status IN ('confirmed', 'checked_in', 'checked_out')
        GROUP BY rt.id, rt.name
        ORDER BY booking_count DESC
      `),
      db.query(`
        SELECT s.name, COALESCE(SUM(bs.quantity), 0) AS total_qty, COALESCE(SUM(bs.quantity * bs.unit_price), 0) AS total_revenue
        FROM services s
        LEFT JOIN booking_services bs ON s.id = bs.service_id
        GROUP BY s.id, s.name
        ORDER BY total_qty DESC
        LIMIT 5
      `),
      db.query(`
        SELECT TO_CHAR(paid_at, 'YYYY-MM-DD') AS pay_date, SUM(amount_due) AS daily_revenue, COUNT(id) AS tx_count
        FROM payments
        WHERE paid_at >= CURRENT_DATE - INTERVAL '7 days'
        GROUP BY TO_CHAR(paid_at, 'YYYY-MM-DD')
        ORDER BY pay_date ASC
      `)
    ]);

    const kpi = kpiRes.rows[0];
    const totalRooms = parseInt(kpi.total_rooms, 10) || 1;
    const occupiedRooms = parseInt(kpi.occupied_rooms, 10) || 0;
    const occupancyRate = ((occupiedRooms / totalRooms) * 100).toFixed(1);

    res.render('manager_dashboard', {
      title: 'Báo cáo Quản lý & KPI',
      kpi,
      occupancyRate,
      topTypes: topTypesRes.rows,
      topServices: topServicesRes.rows,
      revenueByDay: revenueByDayRes.rows
    });
  } catch (err) {
    console.error('KPI Dashboard error:', err);
    res.status(500).render('error', { title: 'Lỗi', message: 'Lỗi tải báo cáo KPI.' });
  }
});

// 2. Quản lý Loại phòng & Phòng
router.get('/rooms', async (req, res) => {
  try {
    const [typesRes, roomsRes] = await Promise.all([
      db.query('SELECT * FROM room_types ORDER BY id ASC'),
      db.query(`
        SELECT r.*, rt.name AS room_type_name
        FROM rooms r
        JOIN room_types rt ON r.room_type_id = rt.id
        ORDER BY r.floor ASC, r.room_number ASC
      `)
    ]);

    res.render('manager_rooms', {
      title: 'Quản lý Loại phòng & Danh sách phòng',
      roomTypes: typesRes.rows,
      rooms: roomsRes.rows,
      error: req.query.error || null,
      success: req.query.success || null
    });
  } catch (err) {
    console.error('Manager rooms error:', err);
    res.status(500).render('error', { title: 'Lỗi', message: 'Lỗi tải dữ liệu phòng.' });
  }
});

// Thêm loại phòng kèm Upload ảnh
router.post('/room-types', (req, res) => {
  upload.single('image')(req, res, async (err) => {
    if (err) {
      return res.redirect('/manager/rooms?error=' + encodeURIComponent(err.message));
    }

    const { name, description, base_price, capacity, amenities } = req.body;
    if (!name || !base_price || !capacity) {
      return res.redirect('/manager/rooms?error=' + encodeURIComponent('Vui lòng nhập đầy đủ tên, giá và sức chứa.'));
    }

    let imagePath = '/images/rooms/standard.svg';
    if (req.file) {
      const isValidImage = await verifyMagicBytes(req.file.path);
      if (!isValidImage) {
        fs.unlinkSync(req.file.path);
        return res.redirect('/manager/rooms?error=' + encodeURIComponent('Tệp tải lên không phải là hình ảnh hợp lệ (Magic bytes không khớp).'));
      }
      imagePath = '/uploads/' + req.file.filename;
    }

    try {
      await db.query(`
        INSERT INTO room_types (name, description, base_price, capacity, amenities, image_path)
        VALUES ($1, $2, $3, $4, $5, $6)
      `, [name.trim(), description || '', parseFloat(base_price), parseInt(capacity, 10), amenities || '', imagePath]);

      res.redirect('/manager/rooms?success=' + encodeURIComponent('Tạo loại phòng mới thành công.'));
    } catch (dbErr) {
      if (req.file) fs.unlinkSync(req.file.path);
      res.redirect('/manager/rooms?error=' + encodeURIComponent('Tên loại phòng đã tồn tại hoặc lỗi CSDL.'));
    }
  });
});

// Thêm phòng mới
router.post('/rooms', async (req, res) => {
  const { room_number, room_type_id, floor } = req.body;
  try {
    await db.query(`
      INSERT INTO rooms (room_number, room_type_id, floor, status)
      VALUES ($1, $2, $3, 'available')
    `, [room_number.trim(), room_type_id, parseInt(floor, 10)]);

    res.redirect('/manager/rooms?success=' + encodeURIComponent(`Đã thêm phòng ${room_number}.`));
  } catch (err) {
    res.redirect('/manager/rooms?error=' + encodeURIComponent('Số phòng đã tồn tại hoặc lỗi dữ liệu.'));
  }
});

// Cập nhật trạng thái bảo trì của phòng
router.post('/rooms/:id/toggle-maintenance', async (req, res) => {
  try {
    const rRes = await db.query('SELECT status FROM rooms WHERE id = $1', [req.params.id]);
    const currentStatus = rRes.rows[0].status;
    const newStatus = currentStatus === 'maintenance' ? 'available' : 'maintenance';
    await db.query('UPDATE rooms SET status = $1 WHERE id = $2', [newStatus, req.params.id]);
    res.redirect('/manager/rooms?success=' + encodeURIComponent(`Đã chuyển phòng sang trạng thái ${newStatus}.`));
  } catch (err) {
    res.redirect('/manager/rooms?error=' + encodeURIComponent('Lỗi chuyển trạng thái bảo trì.'));
  }
});

// 3. Quản lý Dịch vụ
router.get('/services', async (req, res) => {
  try {
    const result = await db.query('SELECT * FROM services ORDER BY id ASC');
    res.render('manager_services', {
      title: 'Quản lý Dịch vụ Khách sạn',
      services: result.rows,
      error: req.query.error || null,
      success: req.query.success || null
    });
  } catch (err) {
    res.status(500).render('error', { title: 'Lỗi', message: 'Lỗi tải danh sách dịch vụ.' });
  }
});

router.post('/services', async (req, res) => {
  const { name, price } = req.body;
  try {
    await db.query('INSERT INTO services (name, price) VALUES ($1, $2)', [name.trim(), parseFloat(price)]);
    res.redirect('/manager/services?success=' + encodeURIComponent('Thêm dịch vụ thành công.'));
  } catch (err) {
    res.redirect('/manager/services?error=' + encodeURIComponent('Tên dịch vụ đã tồn tại.'));
  }
});

router.post('/services/:id/toggle', async (req, res) => {
  try {
    await db.query('UPDATE services SET is_available = NOT is_available WHERE id = $1', [req.params.id]);
    res.redirect('/manager/services?success=' + encodeURIComponent('Cập nhật trạng thái dịch vụ thành công.'));
  } catch (err) {
    res.redirect('/manager/services?error=' + encodeURIComponent('Lỗi cập nhật dịch vụ.'));
  }
});

// 4. Quản lý Tài khoản Nhân viên
router.get('/staff', async (req, res) => {
  try {
    const result = await db.query("SELECT * FROM users WHERE role IN ('staff', 'manager') ORDER BY id ASC");
    res.render('manager_staff', {
      title: 'Quản lý Nhân sự & Phân quyền',
      staffList: result.rows,
      currentUserId: req.session.user.id,
      error: req.query.error || null,
      success: req.query.success || null
    });
  } catch (err) {
    res.status(500).render('error', { title: 'Lỗi', message: 'Lỗi tải danh sách nhân viên.' });
  }
});

router.post('/staff', async (req, res) => {
  const { username, email, full_name, phone, role, password } = req.body;
  try {
    const passwordHash = await bcrypt.hash(password || 'Staff123@', 10);
    await db.query(`
      INSERT INTO users (username, email, password_hash, full_name, phone, role)
      VALUES ($1, $2, $3, $4, $5, $6)
    `, [username.trim(), email.trim(), passwordHash, full_name.trim(), phone || null, role]);

    res.redirect('/manager/staff?success=' + encodeURIComponent(`Đã tạo tài khoản nhân viên ${username}.`));
  } catch (err) {
    res.redirect('/manager/staff?error=' + encodeURIComponent('Tên đăng nhập hoặc email đã tồn tại.'));
  }
});

router.post('/staff/:id/toggle-active', async (req, res) => {
  const targetId = parseInt(req.params.id, 10);
  if (targetId === req.session.user.id) {
    return res.redirect('/manager/staff?error=' + encodeURIComponent('Bạn không được phép tự khóa tài khoản của chính mình!'));
  }

  try {
    await db.query('UPDATE users SET is_active = NOT is_active WHERE id = $1', [targetId]);
    res.redirect('/manager/staff?success=' + encodeURIComponent('Cập nhật trạng thái tài khoản thành công.'));
  } catch (err) {
    res.redirect('/manager/staff?error=' + encodeURIComponent('Lỗi cập nhật tài khoản.'));
  }
});

module.exports = router;
