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
    DECLARE v_gender VARCHAR(10);
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
    DECLARE v_offset INT;
    DECLARE v_count INT;
    DECLARE v_postal_digits INT;
    DECLARE v_hash BIGINT UNSIGNED;

    /* Validate input parameters */
    IF p_locale IS NULL OR TRIM(p_locale) = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Locale cannot be empty';
    END IF;

    IF p_seed IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Seed cannot be NULL';
    END IF;

    IF p_batch_index IS NULL OR p_batch_index < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Batch index must be non-negative';
    END IF;

    IF p_batch_size IS NULL
       OR p_batch_size < 1
       OR p_batch_size > 1000 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Batch size must be between 1 and 1000';
    END IF;

    IF p_batch_index > 9223372036854775807 / p_batch_size THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Batch index is too large';
    END IF;

    /* Validate locale */
    SELECT COUNT(*)
      INTO v_count
      FROM locales
     WHERE locale_code = p_locale;

    IF v_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Unsupported locale';
    END IF;

    /* Validate required lookup data */
    SELECT COUNT(*) INTO v_count
      FROM names
     WHERE locale_code = p_locale;

    IF v_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No names found for this locale';
    END IF;

    SELECT COUNT(*) INTO v_count
      FROM titles
     WHERE locale_code = p_locale;

    IF v_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No titles found for this locale';
    END IF;

    SELECT COUNT(*) INTO v_count
      FROM street_names
     WHERE locale_code = p_locale;

    IF v_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No street names found for this locale';
    END IF;

    SELECT COUNT(*) INTO v_count
      FROM cities
     WHERE locale_code = p_locale
       AND latitude IS NOT NULL
       AND longitude IS NOT NULL;

    IF v_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No cities with coordinates found for this locale';
    END IF;

    SELECT COUNT(*) INTO v_count
      FROM eye_colors
     WHERE locale_code = p_locale;

    IF v_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No eye colors found for this locale';
    END IF;

    SELECT COUNT(*) INTO v_count
      FROM email_domains
     WHERE locale_code = p_locale;

    IF v_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No email domains found for this locale';
    END IF;

    /* Generate exactly p_batch_size profiles */
    WHILE i < p_batch_size DO

        SET v_user_index = p_batch_index * p_batch_size + i;

        /* Select a deterministic shuffled name */
        SELECT COUNT(*) INTO v_count
          FROM names
         WHERE locale_code = p_locale;

        SET v_offset = MOD(v_user_index, v_count);

        SELECT first_name, last_name, gender
          INTO v_first, v_last, v_gender
          FROM names
         WHERE locale_code = p_locale
         ORDER BY
             CRC32(CONCAT(p_locale, ':', p_seed, ':name_order:', id)),
             id
         LIMIT v_offset, 1;

        /* Select a title compatible with the name's gender */
        SELECT title INTO v_title
          FROM titles
         WHERE locale_code = p_locale
           AND (
                title = 'Dr.'
                OR (
                    LOWER(v_gender) IN ('male', 'm')
                    AND title IN ('Mr.', 'Herr')
                )
                OR (
                    LOWER(v_gender) IN ('female', 'f')
                    AND title IN ('Ms.', 'Frau')
                )
           )
         ORDER BY
             CRC32(CONCAT(p_locale, ':', p_seed, ':title:', v_user_index, ':', title)),
             title
         LIMIT 1;

        /* Fallback if no gender-compatible title is available */
        IF v_title IS NULL THEN
            SELECT title INTO v_title
              FROM titles
             WHERE locale_code = p_locale
             ORDER BY
                 CRC32(CONCAT(p_locale, ':', p_seed, ':title_fallback:', v_user_index, ':', title)),
                 title
             LIMIT 1;
        END IF;

        /* Select a deterministic shuffled street name */
        SELECT COUNT(*) INTO v_count
          FROM street_names
         WHERE locale_code = p_locale;

        SET v_offset = MOD(v_user_index, v_count);

        SELECT street_name INTO v_street
          FROM street_names
         WHERE locale_code = p_locale
         ORDER BY
             CRC32(CONCAT(p_locale, ':', p_seed, ':street_order:', id)),
             id
         LIMIT v_offset, 1;

        /* Select city and matching coordinates */
        SELECT COUNT(*) INTO v_count
          FROM cities
         WHERE locale_code = p_locale
           AND latitude IS NOT NULL
           AND longitude IS NOT NULL;

        SET v_offset = MOD(v_user_index, v_count);

        SELECT
            city_name,
            region_name,
            postal_prefix,
            latitude,
            longitude
          INTO
            v_city,
            v_region,
            v_prefix,
            v_lat,
            v_lon
          FROM cities
         WHERE locale_code = p_locale
           AND latitude IS NOT NULL
           AND longitude IS NOT NULL
         ORDER BY
             CRC32(CONCAT(p_locale, ':', p_seed, ':city_order:', id)),
             id
         LIMIT v_offset, 1;

        /* Select eye color */
        SELECT COUNT(*) INTO v_count
          FROM eye_colors
         WHERE locale_code = p_locale;

        SET v_offset = generator_offset(
            p_locale, p_seed, v_user_index, 'eye', v_count
        );

        SELECT color_name INTO v_eye
          FROM eye_colors
         WHERE locale_code = p_locale
         ORDER BY id
         LIMIT v_offset, 1;

        /* Select email domain */
        SELECT COUNT(*) INTO v_count
          FROM email_domains
         WHERE locale_code = p_locale;

        SET v_offset = generator_offset(
            p_locale, p_seed, v_user_index, 'domain', v_count
        );

        SELECT domain_name INTO v_domain
          FROM email_domains
         WHERE locale_code = p_locale
         ORDER BY id
         LIMIT v_offset, 1;

        /* Build profile fields */
        SET v_full = CONCAT(v_first, ' ', v_last);

        SET v_hash = CRC32(
            CONCAT(p_locale, ':', p_seed, ':postal:', v_user_index)
        );

        SET v_postal_digits = 10000 + MOD(v_hash, 90000);

        SET v_postal = CONCAT(
            COALESCE(v_prefix, ''),
            v_postal_digits
        );

        SET v_email = LOWER(
            CONCAT(
                REPLACE(v_first, ' ', ''),
                '.',
                REPLACE(v_last, ' ', ''),
                '.',
                p_seed,
                '.',
                v_user_index,
                '@',
                v_domain
            )
        );

        SET v_hash = CRC32(
            CONCAT(p_locale, ':', p_seed, ':phone:', v_user_index)
        );

        SET v_phone = CONCAT(
            '+',
            CASE
                WHEN p_locale = 'en_US' THEN '1'
                WHEN p_locale = 'de_DE' THEN '49'
                ELSE '99'
            END,
            LPAD(MOD(v_hash, 10000000000), 10, '0')
        );

        /* Deterministic birth date */
        SET v_hash = CRC32(
            CONCAT(p_locale, ':', p_seed, ':birth:', v_user_index)
        );

        SET v_birth = DATE_ADD(
            '1970-01-01',
            INTERVAL MOD(v_hash, 12000) DAY
        );

        /* Deterministic height: 150.00 to 199.99 cm */
        SET v_hash = CRC32(
            CONCAT(p_locale, ':', p_seed, ':height:', v_user_index)
        );

        SET v_height = 150 + MOD(v_hash, 5000) / 100;

        /* Deterministic weight: 45.00 to 119.99 kg */
        SET v_hash = CRC32(
            CONCAT(p_locale, ':', p_seed, ':weight:', v_user_index)
        );

        SET v_weight = 45 + MOD(v_hash, 7500) / 100;

        /* Insert profile or update an existing profile */
        INSERT INTO generated_users (
            locale_code,
            seed_value,
            batch_index,
            user_index,
            first_name,
            last_name,
            full_name,
            title,
            street_address,
            city,
            region_name,
            postal_code,
            latitude,
            longitude,
            birth_date,
            height_cm,
            weight_kg,
            eye_color,
            phone,
            email
        )
        VALUES (
            p_locale,
            p_seed,
            p_batch_index,
            v_user_index,
            v_first,
            v_last,
            v_full,
            v_title,
            CONCAT(1 + MOD(v_user_index, 9999), ' ', v_street),
            v_city,
            v_region,
            v_postal,
            v_lat,
            v_lon,
            v_birth,
            v_height,
            v_weight,
            v_eye,
            v_phone,
            v_email
        )
        ON DUPLICATE KEY UPDATE
            first_name = VALUES(first_name),
            last_name = VALUES(last_name),
            full_name = VALUES(full_name),
            title = VALUES(title),
            street_address = VALUES(street_address),
            city = VALUES(city),
            region_name = VALUES(region_name),
            postal_code = VALUES(postal_code),
            latitude = VALUES(latitude),
            longitude = VALUES(longitude),
            birth_date = VALUES(birth_date),
            height_cm = VALUES(height_cm),
            weight_kg = VALUES(weight_kg),
            eye_color = VALUES(eye_color),
            phone = VALUES(phone),
            email = VALUES(email);

        SET i = i + 1;

    END WHILE;

    /* Return only the requested batch */
    SELECT *
      FROM generated_users
     WHERE locale_code = p_locale
       AND seed_value = p_seed
       AND batch_index = p_batch_index
       AND user_index >= p_batch_index * p_batch_size
       AND user_index < (p_batch_index + 1) * p_batch_size
     ORDER BY user_index
     LIMIT p_batch_size;

END$$

DELIMITER ;