const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const db = require('../db');
const { requireRole } = require('../middleware/auth');

router.use(requireRole('staff', 'manager'));

// Trang chính Lễ tân
router.get('/', async (req, res) => {
  try {
    const [bookingsRes, roomsRes, servicesRes, usersRes, typesRes] = await Promise.all([
      db.query(`
        SELECT b.*, u.full_name AS customer_name, u.phone AS customer_phone,
               r.room_number, rt.name AS room_type_name
        FROM bookings b
        JOIN users u ON b.user_id = u.id
        JOIN rooms r ON b.room_id = r.id
        JOIN room_types rt ON r.room_type_id = rt.id
        ORDER BY CASE
          WHEN b.status = 'checked_in' THEN 1
          WHEN b.status = 'confirmed' THEN 2
          WHEN b.status = 'pending' THEN 3
          ELSE 4
        END, b.check_in_date ASC
      `),
      db.query(`
        SELECT r.*, rt.name AS room_type_name
        FROM rooms r
        JOIN room_types rt ON r.room_type_id = rt.id
        ORDER BY r.floor ASC, r.room_number ASC
      `),
      db.query('SELECT * FROM services WHERE is_available = true ORDER BY name ASC'),
      db.query("SELECT id, username, full_name, phone FROM users WHERE role = 'customer' AND is_active = true ORDER BY full_name ASC"),
      db.query('SELECT * FROM room_types WHERE is_active = true ORDER BY base_price ASC')
    ]);

    res.render('reception', {
      title: 'Bàn lễ tân - Quản lý phòng & đặt phòng',
      bookings: bookingsRes.rows,
      rooms: roomsRes.rows,
      services: servicesRes.rows,
      customers: usersRes.rows,
      roomTypes: typesRes.rows,
      error: req.query.error || null,
      success: req.query.success || null
    });
  } catch (err) {
    console.error('Reception error:', err);
    res.status(500).render('error', { title: 'Lỗi', message: 'Lỗi tải trang lễ tân.' });
  }
});

// Tạo đặt phòng trực tiếp (Walk-in)
router.post('/walk-in', async (req, res) => {
  const { customer_mode, existing_user_id, new_username, new_fullname, new_phone, room_type_id, check_in_date, check_out_date, guests, note } = req.body;
  const staffId = req.session.user.id;

  const client = await db.getClient();
  try {
    await client.query('BEGIN');
    let customerId = existing_user_id;

    if (customer_mode === 'new') {
      const uRes = await client.query('SELECT id FROM users WHERE username = $1', [new_username.trim()]);
      if (uRes.rows.length > 0) {
        await client.query('ROLLBACK');
        return res.redirect('/reception?error=' + encodeURIComponent('Tên người dùng khách hàng đã tồn tại.'));
      }
      const pHash = await bcrypt.hash('Khach123@', 10);
      const email = `${new_username.trim()}@guest.hotel.local`;
      const insU = await client.query(`
        INSERT INTO users (username, email, password_hash, full_name, phone, role)
        VALUES ($1, $2, $3, $4, $5, 'customer') RETURNING id
      `, [new_username.trim(), email, pHash, new_fullname.trim(), new_phone?.trim() || null]);
      customerId = insU.rows[0].id;
    }

    const typeRes = await client.query('SELECT * FROM room_types WHERE id = $1', [room_type_id]);
    const roomType = typeRes.rows[0];

    // Tìm phòng trống
    const rRes = await client.query(`
      SELECT r.id, r.room_number FROM rooms r
      WHERE r.room_type_id = $1 AND r.is_active = true AND r.status != 'maintenance'
        AND r.id NOT IN (
          SELECT b.room_id FROM bookings b
          WHERE b.status IN ('pending', 'confirmed', 'checked_in')
            AND (b.check_in_date < $3 AND b.check_out_date > $2)
        )
      ORDER BY r.room_number ASC LIMIT 1 FOR UPDATE OF r
    `, [room_type_id, check_in_date, check_out_date]);

    if (rRes.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.redirect('/reception?error=' + encodeURIComponent('Không còn phòng trống trong thời gian này.'));
    }

    const assignedRoom = rRes.rows[0];
    const nights = Math.max(1, Math.round((new Date(check_out_date) - new Date(check_in_date)) / (1000 * 3600 * 24)));
    const pricePerNight = parseFloat(roomType.base_price);
    const totalAmount = nights * pricePerNight;
    const bCode = 'WI-' + crypto.randomBytes(4).toString('hex').toUpperCase();

    await client.query(`
      INSERT INTO bookings (
        booking_code, user_id, room_id, check_in_date, check_out_date,
        guests, note, status, price_per_night, total_amount, created_by
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'confirmed', $8, $9, $10)
    `, [bCode, customerId, assignedRoom.id, check_in_date, check_out_date, parseInt(guests, 10), note || null, pricePerNight, totalAmount, staffId]);

    await client.query('COMMIT');
    res.redirect('/reception?success=' + encodeURIComponent(`Tạo đặt phòng walk-in ${bCode} thành công cho phòng ${assignedRoom.room_number}.`));
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Walk-in error:', err);
    res.redirect('/reception?error=' + encodeURIComponent('Lỗi khi tạo đặt phòng trực tiếp.'));
  } finally {
    client.release();
  }
});

// Xác nhận đơn
router.post('/bookings/:id/confirm', async (req, res) => {
  try {
    await db.query("UPDATE bookings SET status = 'confirmed' WHERE id = $1 AND status = 'pending'", [req.params.id]);
    res.redirect('/reception?success=' + encodeURIComponent('Đã xác nhận đơn đặt phòng.'));
  } catch (err) {
    res.redirect('/reception?error=' + encodeURIComponent('Lỗi xác nhận đặt phòng.'));
  }
});

// Hủy đơn (khi chưa check-in)
router.post('/bookings/:id/cancel', async (req, res) => {
  try {
    await db.query("UPDATE bookings SET status = 'cancelled' WHERE id = $1 AND status IN ('pending', 'confirmed')", [req.params.id]);
    res.redirect('/reception?success=' + encodeURIComponent('Đã hủy đơn đặt phòng.'));
  } catch (err) {
    res.redirect('/reception?error=' + encodeURIComponent('Lỗi khi hủy đặt phòng.'));
  }
});

// Check-in
router.post('/bookings/:id/check-in', async (req, res) => {
  const client = await db.getClient();
  try {
    await client.query('BEGIN');
    const bRes = await client.query('SELECT * FROM bookings WHERE id = $1 FOR UPDATE', [req.params.id]);
    if (bRes.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.redirect('/reception?error=' + encodeURIComponent('Không tìm thấy đơn đặt phòng.'));
    }
    const booking = bRes.rows[0];

    const todayStr = new Date().toISOString().split('T')[0];
    const checkInStr = new Date(booking.check_in_date).toISOString().split('T')[0];
    if (todayStr < checkInStr) {
      await client.query('ROLLBACK');
      return res.redirect('/reception?error=' + encodeURIComponent(`Chưa tới ngày nhận phòng (${checkInStr}). Không thể check-in sớm.`));
    }

    const rRes = await client.query('SELECT status FROM rooms WHERE id = $1 FOR UPDATE', [booking.room_id]);
    if (rRes.rows[0].status !== 'available') {
      await client.query('ROLLBACK');
      return res.redirect('/reception?error=' + encodeURIComponent(`Phòng đang ở trạng thái '${rRes.rows[0].status}', không thể check-in.`));
    }

    await client.query("UPDATE bookings SET status = 'checked_in', checked_in_at = CURRENT_TIMESTAMP WHERE id = $1", [booking.id]);
    await client.query("UPDATE rooms SET status = 'occupied' WHERE id = $1", [booking.room_id]);

    await client.query('COMMIT');
    res.redirect('/reception?success=' + encodeURIComponent(`Check-in thành công cho đơn ${booking.booking_code}.`));
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Checkin error:', err);
    res.redirect('/reception?error=' + encodeURIComponent('Lỗi trong quá trình check-in.'));
  } finally {
    client.release();
  }
});

// Thêm dịch vụ vào booking checked_in
router.post('/bookings/:id/services', async (req, res) => {
  const { service_id, quantity } = req.body;
  const bookingId = req.params.id;
  try {
    const sRes = await db.query('SELECT price FROM services WHERE id = $1', [service_id]);
    if (sRes.rows.length === 0) return res.redirect('/reception?error=' + encodeURIComponent('Dịch vụ không tồn tại.'));
    const unitPrice = sRes.rows[0].price;

    await db.query(`
      INSERT INTO booking_services (booking_id, service_id, quantity, unit_price)
      VALUES ($1, $2, $3, $4)
    `, [bookingId, service_id, parseInt(quantity, 10) || 1, unitPrice]);

    res.redirect('/reception?success=' + encodeURIComponent('Đã thêm dịch vụ vào đơn đặt phòng.'));
  } catch (err) {
    console.error('Add service error:', err);
    res.redirect('/reception?error=' + encodeURIComponent('Lỗi thêm dịch vụ.'));
  }
});

// Check-out và thanh toán (Trong 1 transaction)
router.post('/bookings/:id/checkout', async (req, res) => {
  const { payment_method, amount_paid } = req.body;
  const bookingId = req.params.id;
  const staffId = req.session.user.id;

  const client = await db.getClient();
  try {
    await client.query('BEGIN');
    const bRes = await client.query('SELECT * FROM bookings WHERE id = $1 FOR UPDATE', [bookingId]);
    const booking = bRes.rows[0];

    if (booking.status !== 'checked_in') {
      await client.query('ROLLBACK');
      return res.redirect('/reception?error=' + encodeURIComponent('Đơn đặt phòng không ở trạng thái đang nhận phòng.'));
    }

    // Tính tổng tiền phòng + dịch vụ
    const sRes = await client.query(`
      SELECT COALESCE(SUM(quantity * unit_price), 0) AS total_services
      FROM booking_services WHERE booking_id = $1
    `, [bookingId]);
    const totalServices = parseFloat(sRes.rows[0].total_services);
    const roomAmount = parseFloat(booking.total_amount);
    const totalDue = roomAmount + totalServices;

    const paid = parseFloat(amount_paid);
    if (paid < totalDue) {
      await client.query('ROLLBACK');
      return res.redirect('/reception?error=' + encodeURIComponent(`Tiền khách đưa (${paid.toLocaleString()}đ) không đủ thanh toán tổng hóa đơn (${totalDue.toLocaleString()}đ).`));
    }
    const change = paid - totalDue;

    // Ghi nhận thanh toán
    await client.query(`
      INSERT INTO payments (booking_id, method, amount_due, amount_paid, change_amount, received_by)
      VALUES ($1, $2, $3, $4, $5, $6)
    `, [bookingId, payment_method, totalDue, paid, change, staffId]);

    // Cập nhật trạng thái booking & room
    await client.query("UPDATE bookings SET status = 'checked_out', checked_out_at = CURRENT_TIMESTAMP WHERE id = $1", [bookingId]);
    await client.query("UPDATE rooms SET status = 'cleaning' WHERE id = $1", [booking.room_id]);

    await client.query('COMMIT');
    res.redirect(`/reception/invoice/${bookingId}`);
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Checkout error:', err);
    res.redirect('/reception?error=' + encodeURIComponent('Lỗi khi thanh toán check-out.'));
  } finally {
    client.release();
  }
});

// Đánh dấu dọn phòng xong
router.post('/rooms/:id/cleaned', async (req, res) => {
  try {
    await db.query("UPDATE rooms SET status = 'available' WHERE id = $1 AND status = 'cleaning'", [req.params.id]);
    res.redirect('/reception?success=' + encodeURIComponent('Đã chuyển phòng sang trạng thái Sẵn sàng đón khách.'));
  } catch (err) {
    res.redirect('/reception?error=' + encodeURIComponent('Lỗi cập nhật trạng thái phòng.'));
  }
});

// Hóa đơn thanh toán in được (@media print)
router.get('/invoice/:id', async (req, res) => {
  try {
    const bookingRes = await db.query(`
      SELECT b.*, u.full_name AS customer_name, u.phone AS customer_phone, u.email AS customer_email,
             r.room_number, r.floor, rt.name AS room_type_name,
             p.method AS payment_method, p.amount_due, p.amount_paid, p.change_amount, p.paid_at,
             staff.full_name AS cashier_name
      FROM bookings b
      JOIN users u ON b.user_id = u.id
      JOIN rooms r ON b.room_id = r.id
      JOIN room_types rt ON r.room_type_id = rt.id
      LEFT JOIN payments p ON b.id = p.booking_id
      LEFT JOIN users staff ON p.received_by = staff.id
      WHERE b.id = $1
    `, [req.params.id]);

    if (bookingRes.rows.length === 0) return res.status(404).send('Không tìm thấy hóa đơn.');
    const booking = bookingRes.rows[0];

    const servicesRes = await db.query(`
      SELECT bs.*, s.name AS service_name
      FROM booking_services bs
      JOIN services s ON bs.service_id = s.id
      WHERE bs.booking_id = $1
    `, [req.params.id]);

    res.render('invoice', {
      title: 'Hóa đơn thanh toán #' + booking.booking_code,
      booking,
      services: servicesRes.rows
    });
  } catch (err) {
    console.error('Invoice error:', err);
    res.status(500).send('Lỗi tạo hóa đơn.');
  }
});

module.exports = router;
