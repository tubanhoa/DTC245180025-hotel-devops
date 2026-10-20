-- =============================================================================
-- KHỞI TẠO CƠ SỞ DỮ LIỆU HỆ THỐNG ĐẶT PHÒNG KHÁCH SẠN (HOTEL MANAGEMENT)
-- MSSV: DTC245180025 - Sinh viên: Quách Anh Tuấn
-- Đề tài: Khách sạn - Phiên bản: Hardened Least-Privilege
-- =============================================================================

-- Thiết lập múi giờ chuẩn Việt Nam (UTC+7)
SET timezone = 'Asia/Ho_Chi_Minh';

-- 1. BẢNG USERS (Quản lý người dùng: khách hàng, lễ tân, quản lý)
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    role VARCHAR(20) NOT NULL CHECK (role IN ('customer', 'staff', 'manager')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- 2. BẢNG ROOM_TYPES (Loại phòng: Standard, Deluxe, Suite, Family...)
CREATE TABLE IF NOT EXISTS room_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    base_price NUMERIC(12,0) NOT NULL CHECK (base_price >= 0),
    capacity INT NOT NULL CHECK (capacity > 0),
    amenities TEXT,
    image_path VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. BẢNG ROOMS (Danh sách phòng cụ thể theo số phòng)
CREATE TABLE IF NOT EXISTS rooms (
    id SERIAL PRIMARY KEY,
    room_number VARCHAR(10) UNIQUE NOT NULL,
    room_type_id INT NOT NULL REFERENCES room_types(id) ON DELETE RESTRICT,
    floor INT NOT NULL CHECK (floor > 0),
    status VARCHAR(20) NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'occupied', 'cleaning', 'maintenance')),
    is_active BOOLEAN DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_rooms_status ON rooms(status);
CREATE INDEX IF NOT EXISTS idx_rooms_type ON rooms(room_type_id);

-- 4. BẢNG SERVICES (Dịch vụ bổ sung: giặt là, ăn sáng, spa, đưa đón...)
CREATE TABLE IF NOT EXISTS services (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    price NUMERIC(12,0) NOT NULL CHECK (price >= 0),
    is_available BOOLEAN DEFAULT true
);

-- 5. BẢNG BOOKINGS (Đặt phòng)
CREATE TABLE IF NOT EXISTS bookings (
    id SERIAL PRIMARY KEY,
    booking_code VARCHAR(20) UNIQUE NOT NULL,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    room_id INT NOT NULL REFERENCES rooms(id) ON DELETE RESTRICT,
    check_in_date DATE NOT NULL,
    check_out_date DATE NOT NULL,
    guests INT NOT NULL DEFAULT 1 CHECK (guests > 0),
    note TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'checked_in', 'checked_out', 'cancelled')),
    price_per_night NUMERIC(12,0) NOT NULL,
    total_amount NUMERIC(12,0) NOT NULL,
    created_by INT REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    checked_in_at TIMESTAMP WITH TIME ZONE,
    checked_out_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT check_booking_dates CHECK (check_out_date > check_in_date)
);

CREATE INDEX IF NOT EXISTS idx_bookings_code ON bookings(booking_code);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status);
CREATE INDEX IF NOT EXISTS idx_bookings_dates ON bookings(check_in_date, check_out_date);

-- 6. BẢNG BOOKING_SERVICES
CREATE TABLE IF NOT EXISTS booking_services (
    id SERIAL PRIMARY KEY,
    booking_id INT NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    service_id INT NOT NULL REFERENCES services(id) ON DELETE RESTRICT,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12,0) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_booking_services_booking ON booking_services(booking_id);

-- 7. BẢNG PAYMENTS
CREATE TABLE IF NOT EXISTS payments (
    id SERIAL PRIMARY KEY,
    booking_id INT NOT NULL UNIQUE REFERENCES bookings(id) ON DELETE CASCADE,
    method VARCHAR(20) NOT NULL CHECK (method IN ('cash', 'card', 'qr')),
    amount_due NUMERIC(12,0) NOT NULL,
    amount_paid NUMERIC(12,0) NOT NULL,
    change_amount NUMERIC(12,0) NOT NULL DEFAULT 0,
    received_by INT REFERENCES users(id) ON DELETE SET NULL,
    paid_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- DỮ LIỆU SEED MẪU
-- =============================================================================

INSERT INTO users (username, email, password_hash, full_name, phone, role) VALUES
('admin', 'admin@hotel.local', '$2b$10$v7xu2QPA5wcU1DZd7TbsTOAeubNgJQBMwkTU1Ob66hS7ua/vtGrty', 'Quản Lý Khách Sạn', '0901234567', 'manager'),
('letan01', 'letan01@hotel.local', '$2b$10$sLXg2WqejDKwoNvkmYntoOgHmKqTZfKm2QRzVz8/yd0JiVxRRJAVi', 'Lễ Tân Ca Sáng', '0912345678', 'staff'),
('letan02', 'letan02@hotel.local', '$2b$10$sLXg2WqejDKwoNvkmYntoOgHmKqTZfKm2QRzVz8/yd0JiVxRRJAVi', 'Lễ Tân Ca Tối', '0923456789', 'staff'),
('khach01', 'khach01@gmail.com', '$2b$10$wi6SdEHx.SJZBCYZV3anm.yBfWRZZmi96nLsww7zyZcp04ilkdpYy', 'Nguyễn Văn Khách', '0934567890', 'customer'),
('khach02', 'khach02@gmail.com', '$2b$10$wi6SdEHx.SJZBCYZV3anm.yBfWRZZmi96nLsww7zyZcp04ilkdpYy', 'Trần Thị Du Lịch', '0945678901', 'customer'),
('test_khach03', 'test_khach03@test.com', '$2a$10$u7Eqoxu2Q8O8Te3IO/RzKOOuIc/XCrFaNbxbhz0xMeqCsj3u/lyaG', 'Nguyen Test', '0988776655', 'customer')
ON CONFLICT (username) DO NOTHING;

INSERT INTO room_types (name, description, base_price, capacity, amenities, image_path) VALUES
('Standard', 'Phòng tiêu chuẩn ấm cúng, đầy đủ tiện nghi cơ bản cho cặp đôi hoặc khách công tác.', 500000, 2, 'WiFi tốc độ cao, TV LED 43 inch, Điều hòa, Minibar, Bình đun nước', '/images/rooms/standard.svg'),
('Superior', 'Phòng cao cấp với ban công thoáng mát nhìn ra sân vườn, nội thất gỗ sang trọng.', 800000, 2, 'Ban công sân vườn, WiFi, Smart TV 50 inch, Bồn tắm đứng, Két sắt điện tử', '/images/rooms/superior.svg'),
('Deluxe', 'Phòng sang trọng view thành phố tuyệt đẹp, giường King size êm ái phong cách 5 sao.', 1200000, 2, 'View toàn cảnh thành phố, Giường King Size, Bồn tắm nằm Jacuzzi, Máy pha cà phê Espresso', '/images/rooms/deluxe.svg'),
('Family', 'Không gian rộng rãi lý tưởng cho gia đình 4 người với 2 giường lớn và khu sinh hoạt chung.', 1800000, 4, '2 Giường Queen, Bàn ăn gia đình, Sofa phòng khách, Tủ lạnh lớn, Lò vi sóng', '/images/rooms/family.svg'),
('Suite', 'Căn hộ khách sạn thượng hạng đẳng cấp nguyên tầng, dịch vụ quản gia và view panorama.', 2500000, 3, 'Phòng khách riêng biệt, View Panorama 180 độ, Quầy bar mini cao cấp, Bồn sục đôi, Trái cây tươi đón tiếp', '/images/rooms/suite.svg'),
('Royal Penthouse', 'Phòng thượng đỉnh với tầm nhìn đắt giá nhất khách sạn.', 3500000, 4, 'Bể bơi vô cực, Quản gia riêng 24/7, Bếp ăn riêng, Hầm rượu mini', '/uploads/5f025e05ca934c323a2575d0331a05ba.png')
ON CONFLICT (name) DO NOTHING;

INSERT INTO rooms (room_number, room_type_id, floor, status) VALUES
('101', 1, 1, 'available'),
('102', 1, 1, 'available'),
('103', 1, 1, 'available'),
('104', 2, 1, 'available'),
('105', 2, 1, 'available'),
('201', 2, 2, 'cleaning'),
('202', 2, 2, 'available'),
('203', 3, 2, 'available'),
('204', 3, 2, 'available'),
('205', 3, 2, 'cleaning'),
('206', 3, 2, 'available'),
('301', 3, 3, 'available'),
('302', 3, 3, 'available'),
('303', 4, 3, 'available'),
('304', 4, 3, 'available'),
('305', 4, 3, 'available'),
('306', 4, 3, 'available'),
('401', 4, 4, 'available'),
('402', 5, 4, 'available'),
('403', 5, 4, 'available'),
('404', 5, 4, 'available'),
('405', 5, 4, 'maintenance')
ON CONFLICT (room_number) DO NOTHING;

INSERT INTO services (name, price, is_available) VALUES
('Ăn sáng Buffet Á - Âu', 150000, true),
('Giặt ủi cao cấp', 80000, true),
('Đưa đón sân bay 4 chỗ', 350000, true),
('Spa thư giãn toàn thân 60p', 500000, true),
('Nước ngọt minibar giải khát', 30000, true),
('Thuê xe máy tay ga theo ngày', 150000, true),
('Bữa tối lãng mạn kèm rượu vang', 650000, true),
('Trà chiều phong cách hoàng gia', 200000, true),
('Giường phụ (Extra Bed)', 300000, true)
ON CONFLICT (name) DO NOTHING;

INSERT INTO bookings (booking_code, user_id, room_id, check_in_date, check_out_date, guests, note, status, price_per_night, total_amount, created_by, created_at, checked_in_at, checked_out_at)
VALUES 
('BK-202610-001', 4, 1, CURRENT_DATE - INTERVAL '3 days', CURRENT_DATE - INTERVAL '1 day', 2, 'Khách đặt qua mạng', 'checked_out', 500000, 1000000, 4, CURRENT_TIMESTAMP - INTERVAL '4 days', CURRENT_TIMESTAMP - INTERVAL '3 days', CURRENT_TIMESTAMP - INTERVAL '1 day'),
('BK-202610-002', 5, 6, CURRENT_DATE - INTERVAL '1 day', CURRENT_DATE + INTERVAL '1 day', 2, 'Khách quen nghỉ dưỡng cuối tuần', 'checked_out', 800000, 1600000, 2, CURRENT_TIMESTAMP - INTERVAL '2 days', CURRENT_TIMESTAMP - INTERVAL '1 day', CURRENT_TIMESTAMP),
('BK-202610-003', 4, 8, CURRENT_DATE + INTERVAL '3 days', CURRENT_DATE + INTERVAL '5 days', 2, 'Cần chuẩn bị phòng tầng cao view đẹp', 'confirmed', 1200000, 2400000, 4, CURRENT_TIMESTAMP, NULL, NULL),
('BK-F16CBAE1', 6, 1, CURRENT_DATE + INTERVAL '12 days', CURRENT_DATE + INTERVAL '14 days', 2, 'HopLe', 'confirmed', 500000, 1000000, 6, CURRENT_TIMESTAMP, NULL, NULL)
ON CONFLICT (booking_code) DO NOTHING;

INSERT INTO booking_services (booking_id, service_id, quantity, unit_price)
SELECT b.id, s.id, 2, s.price FROM bookings b, services s WHERE b.booking_code = 'BK-202610-001' AND s.name = 'Ăn sáng Buffet Á - Âu'
ON CONFLICT DO NOTHING;

INSERT INTO payments (booking_id, method, amount_due, amount_paid, change_amount, received_by, paid_at)
SELECT b.id, 'card', 1300000, 1300000, 0, 2, CURRENT_TIMESTAMP - INTERVAL '1 day'
FROM bookings b WHERE b.booking_code = 'BK-202610-001'
ON CONFLICT (booking_id) DO NOTHING;

-- Đồng bộ giá trị Sequence tự tăng
SELECT setval('users_id_seq', (SELECT MAX(id) FROM users));
SELECT setval('room_types_id_seq', (SELECT MAX(id) FROM room_types));
SELECT setval('rooms_id_seq', (SELECT MAX(id) FROM rooms));
SELECT setval('services_id_seq', (SELECT MAX(id) FROM services));
SELECT setval('bookings_id_seq', (SELECT MAX(id) FROM bookings));
SELECT setval('booking_services_id_seq', (SELECT MAX(id) FROM booking_services));
SELECT setval('payments_id_seq', (SELECT MAX(id) FROM payments));

-- =============================================================================
-- PHÂN QUYỀN TỐI THIỂU (LEAST PRIVILEGE) CHO HOTEL_APP VÀ EXPORTER
-- =============================================================================

-- 1. Tạo user hotel_app cho ứng dụng web (nếu chưa có)
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'hotel_app') THEN
    CREATE ROLE hotel_app WITH LOGIN;
  END IF;
END
$$;

-- 2. Chuyển toàn bộ quyền sở hữu (owner) sang superuser postgres
ALTER TABLE users OWNER TO postgres;
ALTER TABLE room_types OWNER TO postgres;
ALTER TABLE rooms OWNER TO postgres;
ALTER TABLE services OWNER TO postgres;
ALTER TABLE bookings OWNER TO postgres;
ALTER TABLE booking_services OWNER TO postgres;
ALTER TABLE payments OWNER TO postgres;

ALTER SEQUENCE users_id_seq OWNER TO postgres;
ALTER SEQUENCE room_types_id_seq OWNER TO postgres;
ALTER SEQUENCE rooms_id_seq OWNER TO postgres;
ALTER SEQUENCE services_id_seq OWNER TO postgres;
ALTER SEQUENCE bookings_id_seq OWNER TO postgres;
ALTER SEQUENCE booking_services_id_seq OWNER TO postgres;
ALTER SEQUENCE payments_id_seq OWNER TO postgres;

-- 3. Hạn chế quyền schema public (chỉ cho phép CONNECT và USAGE, cấm CREATE)
REVOKE ALL ON SCHEMA public FROM PUBLIC, hotel_app;
GRANT CONNECT ON DATABASE hotel TO hotel_app;
GRANT USAGE ON SCHEMA public TO hotel_app;

-- 4. Cấp quyền chỉ SELECT, INSERT, UPDATE, DELETE cho hotel_app (cấm DROP, TRUNCATE, ALTER)
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM hotel_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO hotel_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO hotel_app;

-- 5. Thiết lập quyền mặc định cho các bảng trong tương lai
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO hotel_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO hotel_app;

-- 6. Role cho Prometheus postgres_exporter (chỉ quyền giám sát pg_monitor)
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'exporter') THEN
    CREATE ROLE exporter WITH LOGIN PASSWORD 'p0stgr3s_3xp0rt3r_98234';
  END IF;
END
$$;
GRANT pg_monitor TO exporter;
