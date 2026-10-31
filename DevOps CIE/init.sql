-- ==============================================================================
-- Database Initialization Script for Food Delivery Platform
-- DevOps CIE: Question 3
-- ==============================================================================

CREATE DATABASE IF NOT EXISTS food_delivery_db;
USE food_delivery_db;

CREATE TABLE IF NOT EXISTS orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    restaurant_name VARCHAR(100) NOT NULL,
    items VARCHAR(255) NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,
    order_status VARCHAR(50) NOT NULL DEFAULT 'Placed',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed initial order records
INSERT INTO orders (customer_name, restaurant_name, items, total_amount, order_status) VALUES
('Siddharth Amdal', 'Pizza Palace', 'Margherita Pizza, Garlic Bread', 450.00, 'Delivered'),
('Aarav Sharma', 'Biryani Blues', 'Hyderabadi Chicken Biryani, Raita', 380.00, 'On The Way'),
('Priya Patel', 'Sushi Express', 'Salmon Roll, Miso Soup', 620.00, 'Preparing'),
('Rahul Verma', 'Burger Hub', 'Double Cheeseburger, Peri-Peri Fries', 310.00, 'Placed'),
('Ananya Sen', 'Chai Point', 'Ginger Chai, Bun Maska', 140.00, 'Delivered');
