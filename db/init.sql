-- =============================================================================
-- CSDL HỆ THỐNG ĐẶT PHÒNG KHÁCH SẠN (HOTEL BOOKING SYSTEM)
-- Tạo 7 bảng quan hệ chuẩn, ràng buộc toàn vẹn, indexes và dữ liệu mẫu seed
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. BẢNG USERS
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

-- 2. BẢNG ROOM_TYPES
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

-- 3. BẢNG ROOMS
CREATE TABLE IF NOT EXISTS rooms (
    id SERIAL PRIMARY KEY,
    room_number VARCHAR(10) UNIQUE NOT NULL,
    room_type_id INT NOT NULL REFERENCES room_types(id) ON DELETE RESTRICT,
    floor INT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'occupied', 'cleaning', 'maintenance')),
    is_active BOOLEAN DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_rooms_room_type ON rooms(room_type_id);
CREATE INDEX IF NOT EXISTS idx_rooms_status ON rooms(status);

-- 4. BẢNG SERVICES
CREATE TABLE IF NOT EXISTS services (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    price NUMERIC(12,0) NOT NULL CHECK (price >= 0),
    is_available BOOLEAN DEFAULT true
);

-- 5. BẢNG BOOKINGS
CREATE TABLE IF NOT EXISTS bookings (
    id SERIAL PRIMARY KEY,
    booking_code VARCHAR(20) UNIQUE NOT NULL,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    room_id INT NOT NULL REFERENCES rooms(id) ON DELETE RESTRICT,
    check_in_date DATE NOT NULL,
    check_out_date DATE NOT NULL,
    CONSTRAINT chk_booking_dates CHECK (check_out_date > check_in_date),
    guests INT NOT NULL CHECK (guests > 0),
    note TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'checked_in', 'checked_out', 'cancelled')),
    price_per_night NUMERIC(12,0) NOT NULL,
    total_amount NUMERIC(12,0) NOT NULL,
    created_by INT REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    checked_in_at TIMESTAMP WITH TIME ZONE,
    checked_out_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_bookings_dates ON bookings(check_in_date, check_out_date);
CREATE INDEX IF NOT EXISTS idx_bookings_user ON bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_room ON bookings(room_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status);

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
-- DỮ LIỆU SEED (MẬT KHẨU BĂM BẰNG BCRYPT ĐƯỢC SINH SẴN TỪ TRƯỚC)
-- =============================================================================

-- Seed Users: 1 manager (admin), 2 staff (letan01, letan02), 2 customers (khach01, khach02)
-- Password Admin: nd-RG4Y91DUAAcMhE2QMmA -> $2b$10$v7xu2QPA5wcU1DZd7TbsTOAeubNgJQBMwkTU1Ob66hS7ua/vtGrty
-- Password Staff: lMIWqC_Er_8oISuOSRWZqQ -> $2b$10$sLXg2WqejDKwoNvkmYntoOgHmKqTZfKm2QRzVz8/yd0JiVxRRJAVi
-- Password Customer: HP-wmSO6_exkMhUSUgHesQ -> $2b$10$wi6SdEHx.SJZBCYZV3anm.yBfWRZZmi96nLsww7zyZcp04ilkdpYy

INSERT INTO users (username, email, password_hash, full_name, phone, role) VALUES
('admin', 'admin@hotel.local', '$2b$10$v7xu2QPA5wcU1DZd7TbsTOAeubNgJQBMwkTU1Ob66hS7ua/vtGrty', 'Quản Lý Khách Sạn', '0901234567', 'manager'),
('letan01', 'letan01@hotel.local', '$2b$10$sLXg2WqejDKwoNvkmYntoOgHmKqTZfKm2QRzVz8/yd0JiVxRRJAVi', 'Lễ Tân Ca Sáng', '0912345678', 'staff'),
('letan02', 'letan02@hotel.local', '$2b$10$sLXg2WqejDKwoNvkmYntoOgHmKqTZfKm2QRzVz8/yd0JiVxRRJAVi', 'Lễ Tân Ca Tối', '0923456789', 'staff'),
('khach01', 'khach01@gmail.com', '$2b$10$wi6SdEHx.SJZBCYZV3anm.yBfWRZZmi96nLsww7zyZcp04ilkdpYy', 'Nguyễn Văn Khách', '0934567890', 'customer'),
('khach02', 'khach02@gmail.com', '$2b$10$wi6SdEHx.SJZBCYZV3anm.yBfWRZZmi96nLsww7zyZcp04ilkdpYy', 'Trần Thị Du Lịch', '0945678901', 'customer')
ON CONFLICT (username) DO NOTHING;

-- Seed Room Types (5 loại phòng giá VND thực tế)
INSERT INTO room_types (name, description, base_price, capacity, amenities, image_path) VALUES
('Standard', 'Phòng tiêu chuẩn ấm cúng, đầy đủ tiện nghi cơ bản cho cặp đôi hoặc khách công tác.', 500000, 2, 'WiFi tốc độ cao, TV LED 43 inch, Điều hòa, Minibar, Bình đun nước', '/images/rooms/standard.svg'),
('Superior', 'Phòng cao cấp với ban công thoáng mát nhìn ra sân vườn, nội thất gỗ sang trọng.', 800000, 2, 'Ban công sân vườn, WiFi, Smart TV 50 inch, Bồn tắm đứng, Két sắt điện tử', '/images/rooms/superior.svg'),
('Deluxe', 'Phòng sang trọng view thành phố tuyệt đẹp, giường King size êm ái phong cách 5 sao.', 1200000, 2, 'View toàn cảnh thành phố, Giường King Size, Bồn tắm nằm Jacuzzi, Máy pha cà phê Espresso', '/images/rooms/deluxe.svg'),
('Family', 'Không gian rộng rãi lý tưởng cho gia đình 4 người với 2 giường lớn và khu sinh hoạt chung.', 1800000, 4, '2 Giường Queen, Bàn ăn gia đình, Sofa phòng khách, Tủ lạnh lớn, Lò vi sóng', '/images/rooms/family.svg'),
('Suite', 'Căn hộ khách sạn thượng hạng đẳng cấp nguyên tầng, dịch vụ quản gia và view panorama.', 2500000, 3, 'Phòng khách riêng biệt, View Panorama 180 độ, Quầy bar mini cao cấp, Bồn sục đôi, Trái cây tươi đón tiếp', '/images/rooms/suite.svg')
ON CONFLICT (name) DO NOTHING;

-- Seed Rooms (22 phòng trên 4 tầng)
INSERT INTO rooms (room_number, room_type_id, floor, status) VALUES
('101', 1, 1, 'available'),
('102', 1, 1, 'available'),
('103', 1, 1, 'available'),
('104', 2, 1, 'available'),
('105', 2, 1, 'available'),
('201', 2, 2, 'occupied'), -- Phòng đang có khách
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

-- Seed Services (9 dịch vụ phong phú)
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

-- Seed Bookings & Payments mẫu để Dashboard KPI có số liệu sống động
-- 1. Đặt phòng đã hoàn tất thanh toán (checked_out)
INSERT INTO bookings (booking_code, user_id, room_id, check_in_date, check_out_date, guests, note, status, price_per_night, total_amount, created_by, created_at, checked_in_at, checked_out_at)
VALUES ('BK-202610-001', 4, 1, CURRENT_DATE - INTERVAL '3 days', CURRENT_DATE - INTERVAL '1 day', 2, 'Khách đặt qua mạng', 'checked_out', 500000, 1000000, 4, CURRENT_TIMESTAMP - INTERVAL '4 days', CURRENT_TIMESTAMP - INTERVAL '3 days', CURRENT_TIMESTAMP - INTERVAL '1 day')
ON CONFLICT (booking_code) DO NOTHING;

-- Dịch vụ của booking 1
INSERT INTO booking_services (booking_id, service_id, quantity, unit_price)
SELECT b.id, s.id, 2, s.price FROM bookings b, services s WHERE b.booking_code = 'BK-202610-001' AND s.name = 'Ăn sáng Buffet Á - Âu'
ON CONFLICT DO NOTHING;

-- Thanh toán của booking 1: 1,000,000 tiền phòng + 300,000 dịch vụ = 1,300,000
INSERT INTO payments (booking_id, method, amount_due, amount_paid, change_amount, received_by, paid_at)
SELECT b.id, 'card', 1300000, 1300000, 0, 2, CURRENT_TIMESTAMP - INTERVAL '1 day'
FROM bookings b WHERE b.booking_code = 'BK-202610-001'
ON CONFLICT (booking_id) DO NOTHING;

-- 2. Đặt phòng đang ở (checked_in) tại phòng 201
INSERT INTO bookings (booking_code, user_id, room_id, check_in_date, check_out_date, guests, note, status, price_per_night, total_amount, created_by, created_at, checked_in_at)
VALUES ('BK-202610-002', 5, 6, CURRENT_DATE, CURRENT_DATE + INTERVAL '2 days', 2, 'Khách quen nghỉ dưỡng cuối tuần', 'checked_in', 800000, 1600000, 2, CURRENT_TIMESTAMP - INTERVAL '1 day', CURRENT_TIMESTAMP)
ON CONFLICT (booking_code) DO NOTHING;

-- Dịch vụ đang sử dụng của phòng 201
INSERT INTO booking_services (booking_id, service_id, quantity, unit_price)
SELECT b.id, s.id, 1, s.price FROM bookings b, services s WHERE b.booking_code = 'BK-202610-002' AND s.name = 'Đưa đón sân bay 4 chỗ'
ON CONFLICT DO NOTHING;

-- 3. Đặt phòng sắp tới (confirmed)
INSERT INTO bookings (booking_code, user_id, room_id, check_in_date, check_out_date, guests, note, status, price_per_night, total_amount, created_by, created_at)
VALUES ('BK-202610-003', 4, 8, CURRENT_DATE + INTERVAL '3 days', CURRENT_DATE + INTERVAL '5 days', 2, 'Cần chuẩn bị phòng tầng cao view đẹp', 'confirmed', 1200000, 2400000, 4, CURRENT_TIMESTAMP)
ON CONFLICT (booking_code) DO NOTHING;
