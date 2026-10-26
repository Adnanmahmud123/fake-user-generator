
CREATE DATABASE IF NOT EXISTS fake_user_generator
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE fake_user_generator;

-- Supported locales
CREATE TABLE IF NOT EXISTS locales (
    locale_code VARCHAR(10) PRIMARY KEY,
    language_name VARCHAR(50) NOT NULL,
    country_name VARCHAR(50) NOT NULL,
    country_code CHAR(2) NOT NULL
);

-- First and last names
CREATE TABLE IF NOT EXISTS names (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    locale_code VARCHAR(10) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    gender ENUM('male', 'female', 'neutral') NOT NULL DEFAULT 'neutral',
    INDEX idx_names_locale (locale_code),
    FOREIGN KEY (locale_code) REFERENCES locales(locale_code)
);

-- Name titles
CREATE TABLE IF NOT EXISTS titles (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    locale_code VARCHAR(10) NOT NULL,
    title VARCHAR(30) NOT NULL,
    INDEX idx_titles_locale (locale_code),
    FOREIGN KEY (locale_code) REFERENCES locales(locale_code)
);

-- Street names and cities
CREATE TABLE IF NOT EXISTS street_names (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    locale_code VARCHAR(10) NOT NULL,
    street_name VARCHAR(150) NOT NULL,
    INDEX idx_street_locale (locale_code),
    FOREIGN KEY (locale_code) REFERENCES locales(locale_code)
);

CREATE TABLE IF NOT EXISTS cities (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    locale_code VARCHAR(10) NOT NULL,
    city_name VARCHAR(100) NOT NULL,
    region_name VARCHAR(100) NOT NULL,
    postal_prefix VARCHAR(12) NOT NULL DEFAULT '',
    INDEX idx_cities_locale (locale_code),
    FOREIGN KEY (locale_code) REFERENCES locales(locale_code)
);

-- Discrete attributes and email domains
CREATE TABLE IF NOT EXISTS eye_colors (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    locale_code VARCHAR(10) NOT NULL,
    color_name VARCHAR(30) NOT NULL,
    FOREIGN KEY (locale_code) REFERENCES locales(locale_code)
);

CREATE TABLE IF NOT EXISTS email_domains (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    locale_code VARCHAR(10) NOT NULL,
    domain_name VARCHAR(100) NOT NULL,
    FOREIGN KEY (locale_code) REFERENCES locales(locale_code)
);

-- Generated users are reproducible by seed and index
CREATE TABLE IF NOT EXISTS generated_users (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    locale_code VARCHAR(10) NOT NULL,
    seed_value BIGINT NOT NULL,
    batch_index BIGINT NOT NULL,
    user_index BIGINT NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    full_name VARCHAR(250) NOT NULL,
    title VARCHAR(30),
    street_address VARCHAR(250) NOT NULL,
    city VARCHAR(100) NOT NULL,
    region_name VARCHAR(100) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    latitude DECIMAL(10,7) NOT NULL,
    longitude DECIMAL(10,7) NOT NULL,
    birth_date DATE NOT NULL,
    height_cm DECIMAL(5,2) NOT NULL,
    weight_kg DECIMAL(5,2) NOT NULL,
    eye_color VARCHAR(30) NOT NULL,
    phone VARCHAR(40) NOT NULL,
    email VARCHAR(254) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_user_run (
        locale_code, seed_value, batch_index, user_index
    ),
    FOREIGN KEY (locale_code) REFERENCES locales(locale_code)
);

-- Initial supported locales
INSERT IGNORE INTO locales
    (locale_code, language_name, country_name, country_code)
VALUES
    ('en_US', 'English', 'United States', 'US'),
    ('de_DE', 'German', 'Germany', 'DE');

-- Initial lookup data for USA
INSERT INTO names (locale_code, first_name, last_name, gender) VALUES
('en_US', 'James', 'Smith', 'male'),
('en_US', 'Olivia', 'Johnson', 'female'),
('en_US', 'William', 'Brown', 'male'),
('en_US', 'Emma', 'Davis', 'female'),
('en_US', 'Noah', 'Wilson', 'male'),
('en_US', 'Sophia', 'Miller', 'female');

INSERT INTO titles (locale_code, title) VALUES
('en_US', 'Mr.'), ('en_US', 'Ms.'), ('en_US', 'Dr.');

INSERT INTO street_names (locale_code, street_name) VALUES
('en_US', 'Oak Street'),
('en_US', 'Maple Avenue'),
('en_US', 'Washington Street'),
('en_US', 'Lake Drive'),
('en_US', 'Park Boulevard');

INSERT INTO cities (locale_code, city_name, region_name, postal_prefix) VALUES
('en_US', 'New York', 'New York', '100'),
('en_US', 'Los Angeles', 'California', '900'),
('en_US', 'Chicago', 'Illinois', '606'),
('en_US', 'Houston', 'Texas', '770'),
('en_US', 'Phoenix', 'Arizona', '850');

INSERT INTO eye_colors (locale_code, color_name) VALUES
('en_US', 'Blue'), ('en_US', 'Brown'),
('en_US', 'Green'), ('en_US', 'Hazel');

INSERT INTO email_domains (locale_code, domain_name) VALUES
('en_US', 'example.com'),
('en_US', 'example.net'),
('en_US', 'example.org');

-- Initial lookup data for Germany
INSERT INTO names (locale_code, first_name, last_name, gender) VALUES
('de_DE', 'Hans', 'Müller', 'male'),
('de_DE', 'Anna', 'Schmidt', 'female'),
('de_DE', 'Paul', 'Schneider', 'male'),
('de_DE', 'Marie', 'Fischer', 'female'),
('de_DE', 'Leon', 'Weber', 'male'),
('de_DE', 'Sophie', 'Meyer', 'female');

INSERT INTO titles (locale_code, title) VALUES
('de_DE', 'Herr'), ('de_DE', 'Frau'), ('de_DE', 'Dr.');

INSERT INTO street_names (locale_code, street_name) VALUES
('de_DE', 'Hauptstraße'),
('de_DE', 'Bahnhofstraße'),
('de_DE', 'Gartenstraße'),
('de_DE', 'Schulstraße'),
('de_DE', 'Berliner Straße');

INSERT INTO cities (locale_code, city_name, region_name, postal_prefix) VALUES
('de_DE', 'Berlin', 'Berlin', '10'),
('de_DE', 'Hamburg', 'Hamburg', '20'),
('de_DE', 'München', 'Bayern', '80'),
('de_DE', 'Köln', 'Nordrhein-Westfalen', '50'),
('de_DE', 'Frankfurt', 'Hessen', '60');

INSERT INTO eye_colors (locale_code, color_name) VALUES
('de_DE', 'Blau'), ('de_DE', 'Braun'),
('de_DE', 'Grün'), ('de_DE', 'Grau');

INSERT INTO email_domains (locale_code, domain_name) VALUES
('de_DE', 'example.com'),
('de_DE', 'example.net'),
('de_DE', 'example.org');
