const express = require('express');
const router = express.Router();
const db = require('../db');

router.get('/', (req, res) => {
  res.redirect('/rooms');
});

router.get('/rooms', async (req, res) => {
  try {
    const { room_type_id, min_price, max_price, capacity, check_in, check_out, sort } = req.query;

    let query = `
      SELECT r.id, r.room_number, r.floor, r.status,
             rt.id AS room_type_id, rt.name AS type_name, rt.description, rt.base_price, rt.capacity, rt.amenities, rt.image_path
      FROM rooms r
      JOIN room_types rt ON r.room_type_id = rt.id
      WHERE r.is_active = true AND rt.is_active = true AND r.status != 'maintenance'
    `;
    const params = [];

    if (room_type_id) {
      params.push(room_type_id);
      query += ` AND rt.id = $${params.length}`;
    }

    if (capacity) {
      params.push(parseInt(capacity, 10));
      query += ` AND rt.capacity >= $${params.length}`;
    }

    if (min_price) {
      params.push(parseFloat(min_price));
      query += ` AND rt.base_price >= $${params.length}`;
    }

    if (max_price) {
      params.push(parseFloat(max_price));
      query += ` AND rt.base_price <= $${params.length}`;
    }

    // Lọc theo ngày check_in và check_out: phòng không bị trùng lịch confirmed, checked_in, pending
    if (check_in && check_out && check_out > check_in) {
      params.push(check_in, check_out);
      query += `
        AND r.id NOT IN (
          SELECT b.room_id FROM bookings b
          WHERE b.status IN ('pending', 'confirmed', 'checked_in')
            AND (b.check_in_date < $${params.length} AND b.check_out_date > $${params.length - 1})
        )
      `;
    }

    // Sắp xếp
    if (sort === 'price_asc') {
      query += ` ORDER BY rt.base_price ASC, r.room_number ASC`;
    } else if (sort === 'price_desc') {
      query += ` ORDER BY rt.base_price DESC, r.room_number ASC`;
    } else if (sort === 'name') {
      query += ` ORDER BY rt.name ASC, r.room_number ASC`;
    } else {
      query += ` ORDER BY r.floor ASC, r.room_number ASC`;
    }

    const [roomsRes, typesRes] = await Promise.all([
      db.query(query, params),
      db.query('SELECT * FROM room_types WHERE is_active = true ORDER BY base_price ASC')
    ]);

    res.render('rooms', {
      title: 'Khám phá phòng khách sạn',
      rooms: roomsRes.rows,
      roomTypes: typesRes.rows,
      filters: req.query
    });
  } catch (err) {
    console.error('Error fetching rooms:', err);
    res.status(500).render('error', { title: 'Lỗi', message: 'Lỗi khi tải danh sách phòng.' });
  }
});

module.exports = router;
