CREATE TYPE establishment_type AS ENUM ('restaurant', 'cafe', 'fast_food', 'pub', 'deli');
CREATE TYPE establishment_status AS ENUM ('active', 'inactive', 'closed', 'suspended');
CREATE TYPE vehicle_type AS ENUM ('bicycle', 'motorcycle', 'car', 'on_foot');
CREATE TYPE courier_status AS ENUM ('available', 'busy', 'offline');
CREATE TYPE order_status AS ENUM ('AWAITING_PAYMENT', 'CANCELLED', 'PROCESSING', 'PREPARING', 'IN_DELIVERY', 'DELIVERED', 'COMPLETED');
CREATE TYPE payment_status AS ENUM ('PENDING', 'SUCCESS', 'FAILED');

-- 1. Модуль "Пользователи"
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100),
    bonus_points_balance INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE user_addresses (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    address_line VARCHAR(255) NOT NULL,
    latitude DECIMAL(9, 6) NOT NULL,
    longitude DECIMAL(9, 6) NOT NULL
);

CREATE TABLE bonus_point_transactions (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    order_id BIGINT,
    amount INT NOT NULL,
    type VARCHAR(50) NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Модуль "Заведения и Меню"
CREATE TABLE establishments (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    establishment_type establishment_type NOT NULL,
    address VARCHAR(255) NOT NULL,
    logo_url VARCHAR(255),
    status establishment_status NOT NULL DEFAULT 'inactive',
    average_rating DECIMAL(2, 1) DEFAULT 0.0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE item_categories (
    id BIGSERIAL PRIMARY KEY,
    establishment_id BIGINT NOT NULL REFERENCES establishments(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    sort_order INT DEFAULT 0
);

CREATE TABLE items (
    id BIGSERIAL PRIMARY KEY,
    establishment_id BIGINT NOT NULL REFERENCES establishments(id) ON DELETE CASCADE,
    category_id BIGINT REFERENCES item_categories(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price INT NOT NULL,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    average_rating DECIMAL(2, 1) DEFAULT 0.0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE item_images (
    id BIGSERIAL PRIMARY KEY,
    item_id BIGINT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    image_url VARCHAR(255) NOT NULL,
    is_main BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE item_modifier_groups (
    id BIGSERIAL PRIMARY KEY,
    item_id BIGINT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    selection_type VARCHAR(20) NOT NULL DEFAULT 'MULTIPLE' 
);

CREATE TABLE item_modifiers (
    id BIGSERIAL PRIMARY KEY,
    group_id BIGINT NOT NULL REFERENCES item_modifier_groups(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    price_delta INT NOT NULL
);

-- 3. Модуль "Курьеры"
CREATE TABLE couriers (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    telegram_user_id BIGINT UNIQUE,
    telegram_chat_id BIGINT UNIQUE,
    vehicle_type vehicle_type NOT NULL,
    status courier_status NOT NULL DEFAULT 'offline',
    has_thermal_bag BOOLEAN NOT NULL DEFAULT FALSE,
    average_rating DECIMAL(2, 1) DEFAULT 0.0
);

-- 4. Модуль "Заказы и Платежи"
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    total_amount INT NOT NULL,
    status payment_status NOT NULL DEFAULT 'PENDING',
    payment_system_transaction_id VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE orders (
    id BIGSERIAL PRIMARY KEY,
    public_id VARCHAR(20) UNIQUE NOT NULL,
    user_id BIGINT NOT NULL REFERENCES users(id),
    establishment_id BIGINT NOT NULL REFERENCES establishments(id),
    payment_id UUID REFERENCES payments(id),
    courier_id BIGINT REFERENCES couriers(id),
    status order_status NOT NULL DEFAULT 'AWAITING_PAYMENT',
    total_price INT NOT NULL,
    delivery_fee INT NOT NULL,
    service_fee INT NOT NULL,
    bonus_points_spent INT DEFAULT 0,
    delivery_address VARCHAR(255) NOT NULL,
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    delivered_at TIMESTAMPTZ
);
ALTER TABLE bonus_point_transactions ADD CONSTRAINT fk_bpt_order FOREIGN KEY (order_id) REFERENCES orders(id);

CREATE TABLE order_items (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    item_id BIGINT NOT NULL REFERENCES items(id),
    quantity INT NOT NULL CHECK (quantity > 0),
    price_at_purchase INT NOT NULL
);

CREATE TABLE selected_order_item_modifiers (
    order_item_id BIGINT NOT NULL REFERENCES order_items(id) ON DELETE CASCADE,
    modifier_id BIGINT NOT NULL REFERENCES item_modifiers(id),
    PRIMARY KEY (order_item_id, modifier_id)
);

-- 5. Модуль "Отзывы"
CREATE TABLE order_reviews (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT UNIQUE NOT NULL REFERENCES orders(id),
    user_id BIGINT NOT NULL REFERENCES users(id),
    establishment_rating INT CHECK (establishment_rating BETWEEN 1 AND 5),
    courier_rating INT CHECK (courier_rating BETWEEN 1 AND 5),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE order_item_reviews (
    id BIGSERIAL PRIMARY KEY,
    order_review_id BIGINT NOT NULL REFERENCES order_reviews(id) ON DELETE CASCADE,
    order_item_id BIGINT UNIQUE NOT NULL REFERENCES order_items(id),
    rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5)
);

-- Индексы
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_items_establishment_id ON items(establishment_id);