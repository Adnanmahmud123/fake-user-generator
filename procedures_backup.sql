
USE fake_user_generator;

DROP PROCEDURE IF EXISTS generate_user_batch;

DELIMITER $$

CREATE PROCEDURE generate_user_batch(
    IN p_locale VARCHAR(10),
    IN p_seed BIGINT,
    IN p_batch_index BIGINT,
    IN p_batch_size INT
)
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE v_first VARCHAR(100);
    DECLARE v_last VARCHAR(100);
    DECLARE v_title VARCHAR(30);
    DECLARE v_street VARCHAR(150);
    DECLARE v_city VARCHAR(100);
    DECLARE v_region VARCHAR(100);
    DECLARE v_prefix VARCHAR(12);
    DECLARE v_eye VARCHAR(30);
    DECLARE v_domain VARCHAR(100);
    DECLARE v_postal VARCHAR(20);
    DECLARE v_email VARCHAR(254);
    DECLARE v_full VARCHAR(250);
    DECLARE v_phone VARCHAR(40);
    DECLARE v_lat DOUBLE;
    DECLARE v_lon DOUBLE;
    DECLARE v_birth DATE;
    DECLARE v_height DECIMAL(5,2);
    DECLARE v_weight DECIMAL(5,2);
    DECLARE v_user_index BIGINT;
    DECLARE v_rng BIGINT UNSIGNED;
    DECLARE v_offset INT;
    DECLARE v_count INT;

    IF p_batch_size < 1 OR p_batch_size > 1000 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Batch size must be between 1 and 1000';
    END IF;

    IF p_batch_index < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Batch index cannot be negative';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM locales WHERE locale_code = p_locale
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Unsupported locale';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM names WHERE locale_code = p_locale;

    IF v_count = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No names found for this locale';
    END IF;

    WHILE i < p_batch_size DO
        SET v_user_index = p_batch_index * p_batch_size + i;
        SET v_rng = CRC32(
            CONCAT(p_locale, ':', p_seed, ':', v_user_index)
        );

        SET v_offset = MOD(v_rng, v_count);
        SELECT first_name, last_name INTO v_first, v_last
        FROM names
        WHERE locale_code = p_locale
        ORDER BY id
        LIMIT v_offset, 1;

        SELECT COUNT(*) INTO v_count
        FROM titles WHERE locale_code = p_locale;
        SET v_offset = MOD(v_rng DIV 7, v_count);
        SELECT title INTO v_title
        FROM titles
        WHERE locale_code = p_locale
        ORDER BY id
        LIMIT v_offset, 1;

        SELECT COUNT(*) INTO v_count
        FROM street_names WHERE locale_code = p_locale;
        SET v_offset = MOD(v_rng DIV 11, v_count);
        SELECT street_name INTO v_street
        FROM street_names
        WHERE locale_code = p_locale
        ORDER BY id
        LIMIT v_offset, 1;

        SELECT COUNT(*) INTO v_count
        FROM cities WHERE locale_code = p_locale;
        SET v_offset = MOD(v_rng DIV 13, v_count);
        SELECT city_name, region_name, postal_prefix
        INTO v_city, v_region, v_prefix
        FROM cities
        WHERE locale_code = p_locale
        ORDER BY id
        LIMIT v_offset, 1;

        SELECT COUNT(*) INTO v_count
        FROM eye_colors WHERE locale_code = p_locale;
        SET v_offset = MOD(v_rng DIV 17, v_count);
        SELECT color_name INTO v_eye
        FROM eye_colors
        WHERE locale_code = p_locale
        ORDER BY id
        LIMIT v_offset, 1;

        SELECT COUNT(*) INTO v_count
        FROM email_domains WHERE locale_code = p_locale;
        SET v_offset = MOD(v_rng DIV 19, v_count);
        SELECT domain_name INTO v_domain
        FROM email_domains
        WHERE locale_code = p_locale
        ORDER BY id
        LIMIT v_offset, 1;

        SET v_full = CONCAT(v_title, ' ', v_first, ' ', v_last);
        SET v_postal = CONCAT(
            v_prefix, LPAD(MOD(v_rng DIV 23, 10000), 4, '0')
        );
        SET v_email = CONCAT(
            LOWER(v_first), '.', LOWER(v_last), '.',
            p_seed, '.', v_user_index, '@', v_domain
        );
        SET v_phone = IF(
            p_locale = 'de_DE',
            CONCAT('+49 30 ', LPAD(MOD(v_rng DIV 29, 10000000), 7, '0')),
            CONCAT('+1 202 ', LPAD(MOD(v_rng DIV 29, 10000000), 7, '0'))
        );

        SET v_lat = DEGREES(ASIN(
            2 * (MOD(v_rng DIV 31, 1000000) / 1000000.0) - 1
        ));
        SET v_lon = MOD(v_rng DIV 37, 3600000) / 10000.0 - 180;

        SET v_birth = DATE_ADD(
            '1970-01-01', INTERVAL MOD(v_rng DIV 41, 15000) DAY
        );
        SET v_height = ROUND(
            150 + (
                MOD(v_rng DIV 43, 1000) +
                MOD(v_rng DIV 47, 1000) +
                MOD(v_rng DIV 53, 1000)
            ) / 100.0, 2
        );
        SET v_weight = ROUND(
            55 + (
                MOD(v_rng DIV 59, 1000) +
                MOD(v_rng DIV 61, 1000) +
                MOD(v_rng DIV 67, 1000)
            ) / 20.0, 2
        );

        INSERT INTO generated_users (
            locale_code, seed_value, batch_index, user_index,
            first_name, last_name, full_name, title,
            street_address, city, region_name, postal_code,
            latitude, longitude, birth_date, height_cm, weight_kg,
            eye_color, phone, email
        ) VALUES (
            p_locale, p_seed, p_batch_index, v_user_index,
            v_first, v_last, v_full, v_title,
            CONCAT(1 + MOD(v_rng DIV 71, 9999), ' ', v_street),
            v_city, v_region, v_postal,
            v_lat, v_lon, v_birth, v_height, v_weight,
            v_eye, v_phone, v_email
        )
        ON DUPLICATE KEY UPDATE
            full_name = VALUES(full_name);

        SET i = i + 1;
    END WHILE;

    SELECT *
    FROM generated_users
    WHERE locale_code = p_locale
      AND seed_value = p_seed
      AND batch_index = p_batch_index
    ORDER BY user_index;
END$$

DELIMITER ;
