const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const db = require('../db');
const { requireAuth } = require('../middleware/auth');

router.use(requireAuth);

router.get('/my-bookings', async (req, res) => {
  try {
    const result = await db.query(`
      SELECT b.*, r.room_number, r.floor, rt.name AS room_type_name,
             p.amount_paid, p.method AS payment_method, p.paid_at
      FROM bookings b
      JOIN rooms r ON b.room_id = r.id
      JOIN room_types rt ON r.room_type_id = rt.id
      LEFT JOIN payments p ON b.id = p.booking_id
      WHERE b.user_id = $1
      ORDER BY b.created_at DESC
    `, [req.session.user.id]);

    res.render('my_bookings', {
      title: 'Đơn đặt phòng của tôi',
      bookings: result.rows,
      error: req.query.error || null,
      success: req.query.success || null
    });
  } catch (err) {
    console.error('Error fetching my bookings:', err);
    res.status(500).render('error', { title: 'Lỗi', message: 'Lỗi khi tải danh sách đặt phòng.' });
  }
});

router.post('/book', async (req, res) => {
  const { room_type_id, check_in_date, check_out_date, guests, note } = req.body;
  const userId = req.session.user.id;

  if (!room_type_id || !check_in_date || !check_out_date || !guests) {
    return res.status(400).render('error', { title: 'Lỗi đặt phòng', message: 'Vui lòng điền đầy đủ các thông tin ngày nhận, ngày trả và số lượng khách.' });
  }

  // 1. Kiểm tra ngày nhận không được trong quá khứ
  const todayStr = new Date().toISOString().split('T')[0];
  if (check_in_date < todayStr) {
    return res.status(400).render('error', { title: 'Lỗi ngày nhận phòng', message: 'Ngày nhận phòng không được ở trong quá khứ.' });
  }

  // 2. Kiểm tra ngày trả phải lớn hơn ngày nhận
  if (check_out_date <= check_in_date) {
    return res.status(400).render('error', { title: 'Lỗi ngày trả phòng', message: 'Ngày trả phòng phải sau ngày nhận phòng ít nhất 1 đêm.' });
  }

  const client = await db.getClient();
  try {
    await client.query('BEGIN');

    // 3. Kiểm tra loại phòng và sức chứa
    const typeRes = await client.query('SELECT * FROM room_types WHERE id = $1 AND is_active = true', [room_type_id]);
    if (typeRes.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).render('error', { title: 'Lỗi', message: 'Loại phòng không tồn tại hoặc đã ngừng kinh doanh.' });
    }
    const roomType = typeRes.rows[0];
    const guestCount = parseInt(guests, 10);
    if (guestCount > roomType.capacity) {
      await client.query('ROLLBACK');
      return res.status(400).render('error', {
        title: 'Vượt quá sức chứa',
        message: `Số khách (${guestCount} người) vượt quá sức chứa tối đa của loại phòng ${roomType.name} (${roomType.capacity} người).`
      });
    }

    // 4. Tìm và khóa 1 phòng trống trong khoảng ngày (SELECT ... FOR UPDATE)
    const availableRoomRes = await client.query(`
      SELECT r.id, r.room_number
      FROM rooms r
      WHERE r.room_type_id = $1
        AND r.is_active = true
        AND r.status != 'maintenance'
        AND r.id NOT IN (
          SELECT b.room_id FROM bookings b
          WHERE b.status IN ('pending', 'confirmed', 'checked_in')
            AND (b.check_in_date < $3 AND b.check_out_date > $2)
        )
      ORDER BY r.room_number ASC
      LIMIT 1
      FOR UPDATE OF r
    `, [room_type_id, check_in_date, check_out_date]);

    if (availableRoomRes.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(409).render('error', {
        title: 'Hết phòng trống',
        message: `Rất tiếc! Hiện tại không còn phòng ${roomType.name} nào trống trong khoảng thời gian từ ${check_in_date} đến ${check_out_date}.`
      });
    }

    const assignedRoom = availableRoomRes.rows[0];

    // 5. Tính số đêm và tổng tiền
    const d1 = new Date(check_in_date);
    const d2 = new Date(check_out_date);
    const nights = Math.max(1, Math.round((d2 - d1) / (1000 * 60 * 60 * 24)));
    const pricePerNight = parseFloat(roomType.base_price);
    const totalAmount = nights * pricePerNight;

    const bookingCode = 'BK-' + crypto.randomBytes(4).toString('hex').toUpperCase();

    await client.query(`
      INSERT INTO bookings (
        booking_code, user_id, room_id, check_in_date, check_out_date,
        guests, note, status, price_per_night, total_amount, created_by
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'confirmed', $8, $9, $10)
    `, [
      bookingCode, userId, assignedRoom.id, check_in_date, check_out_date,
      guestCount, note?.trim() || null, pricePerNight, totalAmount, userId
    ]);

    await client.query('COMMIT');
    res.redirect('/my-bookings?success=' + encodeURIComponent(`Đặt phòng thành công! Mã đặt phòng của bạn là ${bookingCode}. Phòng: ${assignedRoom.room_number}`));
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Booking error:', err);
    res.status(500).render('error', { title: 'Lỗi', message: 'Lỗi xử lý đặt phòng trong CSDL.' });
  } finally {
    client.release();
  }
});

router.post('/my-bookings/:id/cancel', async (req, res) => {
  const bookingId = req.params.id;
  const userId = req.session.user.id;
  try {
    const result = await db.query(
      "SELECT * FROM bookings WHERE id = $1 AND user_id = $2",
      [bookingId, userId]
    );
    if (result.rows.length === 0) {
      return res.redirect('/my-bookings?error=' + encodeURIComponent('Không tìm thấy đơn đặt phòng.'));
    }

    const booking = result.rows[0];
    if (booking.status === 'checked_in' || booking.status === 'checked_out') {
      return res.redirect('/my-bookings?error=' + encodeURIComponent('Đơn đặt phòng đang nhận hoặc đã trả phòng không thể hủy.'));
    }

    await db.query("UPDATE bookings SET status = 'cancelled' WHERE id = $1", [bookingId]);
    res.redirect('/my-bookings?success=' + encodeURIComponent('Đã hủy đặt phòng thành công.'));
  } catch (err) {
    console.error('Cancel booking error:', err);
    res.redirect('/my-bookings?error=' + encodeURIComponent('Lỗi khi hủy đặt phòng.'));
  }
});

module.exports = router;
