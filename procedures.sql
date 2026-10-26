
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
    DECLARE j INT DEFAULT 0;

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
    DECLARE v_rng BIGINT UNSIGNED;
    DECLARE v_offset INT;
    DECLARE v_count INT;
    DECLARE v_height_sum DOUBLE;
    DECLARE v_weight_sum DOUBLE;

    -- Validate inputs.
    IF p_batch_size IS NULL
       OR p_batch_size < 1
       OR p_batch_size > 1000 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Batch size must be between 1 and 1000';
    END IF;

    IF p_batch_index IS NULL OR p_batch_index < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Batch index cannot be negative';
    END IF;

    IF p_seed IS NULL OR p_locale IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Seed and locale are required';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM locales
        WHERE locale_code = p_locale
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Unsupported locale';
    END IF;

    SELECT COUNT(*)
    INTO v_count
    FROM names
    WHERE locale_code = p_locale;

    IF v_count = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No names found for this locale';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM titles
        WHERE locale_code = p_locale
    ) OR NOT EXISTS (
        SELECT 1 FROM street_names
        WHERE locale_code = p_locale
    ) OR NOT EXISTS (
        SELECT 1 FROM cities
        WHERE locale_code = p_locale
    ) OR NOT EXISTS (
        SELECT 1 FROM eye_colors
        WHERE locale_code = p_locale
    ) OR NOT EXISTS (
        SELECT 1 FROM email_domains
        WHERE locale_code = p_locale
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'One or more locale lookup tables are empty';
    END IF;

    WHILE i < p_batch_size DO

        SET v_user_index =
            p_batch_index * p_batch_size + i;

        SET v_rng = CRC32(
            CONCAT(p_locale, ':', p_seed, ':', v_user_index)
        );

        -- Select a name and its gender.
        SET v_offset = MOD(
            CRC32(CONCAT(
                p_locale, ':', p_seed, ':',
                v_user_index, ':name'
            )),
            v_count
        );

        SELECT first_name, last_name, gender
        INTO v_first, v_last, v_gender
        FROM names
        WHERE locale_code = p_locale
        ORDER BY id
        LIMIT v_offset, 1;

        -- Count compatible titles.
        SELECT COUNT(*)
        INTO v_count
        FROM titles
        WHERE locale_code = p_locale
          AND (
              title = 'Dr.'
              OR (
                  v_gender = 'male'
                  AND title IN ('Mr.', 'Herr')
              )
              OR (
                  v_gender = 'female'
                  AND title IN ('Ms.', 'Frau')
              )
              OR v_gender = 'neutral'
          );

        IF v_count = 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No suitable title found for name gender';
        END IF;

        -- Select a compatible title.
        SET v_offset = MOD(
            CRC32(CONCAT(
                p_locale, ':', p_seed, ':',
                v_user_index, ':title'
            )),
            v_count
        );

        SELECT title
        INTO v_title
        FROM titles
        WHERE locale_code = p_locale
          AND (
              title = 'Dr.'
              OR (
                  v_gender = 'male'
                  AND title IN ('Mr.', 'Herr')
              )
              OR (
                  v_gender = 'female'
                  AND title IN ('Ms.', 'Frau')
              )
              OR v_gender = 'neutral'
          )
        ORDER BY id
        LIMIT v_offset, 1;

        -- Select street.
        SELECT COUNT(*)
        INTO v_count
        FROM street_names
        WHERE locale_code = p_locale;

        SET v_offset = MOD(
            CRC32(CONCAT(
                p_locale, ':', p_seed, ':',
                v_user_index, ':street'
            )),
            v_count
        );

        SELECT street_name
        INTO v_street
        FROM street_names
        WHERE locale_code = p_locale
        ORDER BY id
        LIMIT v_offset, 1;

        -- Select city, region and postal prefix.
        SELECT COUNT(*)
        INTO v_count
        FROM cities
        WHERE locale_code = p_locale;

        SET v_offset = MOD(
            CRC32(CONCAT(
                p_locale, ':', p_seed, ':',
                v_user_index, ':city'
            )),
            v_count
        );

        SELECT city_name, region_name, postal_prefix
        INTO v_city, v_region, v_prefix
        FROM cities
        WHERE locale_code = p_locale
        ORDER BY id
        LIMIT v_offset, 1;

        -- Select eye color.
        SELECT COUNT(*)
        INTO v_count
        FROM eye_colors
        WHERE locale_code = p_locale;

        SET v_offset = MOD(
            CRC32(CONCAT(
                p_locale, ':', p_seed, ':',
                v_user_index, ':eye'
            )),
            v_count
        );

        SELECT color_name
        INTO v_eye
        FROM eye_colors
        WHERE locale_code = p_locale
        ORDER BY id
        LIMIT v_offset, 1;

        -- Select email domain.
        SELECT COUNT(*)
        INTO v_count
        FROM email_domains
        WHERE locale_code = p_locale;

        SET v_offset = MOD(
            CRC32(CONCAT(
                p_locale, ':', p_seed, ':',
                v_user_index, ':domain'
            )),
            v_count
        );

        SELECT domain_name
        INTO v_domain
        FROM email_domains
        WHERE locale_code = p_locale
        ORDER BY id
        LIMIT v_offset, 1;

        -- Construct full name.
        SET v_full = CONCAT(
            v_title, ' ', v_first, ' ', v_last
        );

        -- Construct a five-digit postal code.
        SET v_postal = CONCAT(
            v_prefix,
            LPAD(
                MOD(
                    CRC32(CONCAT(
                        p_locale, ':', p_seed, ':',
                        v_user_index, ':postal'
                    )),
                    IF(p_locale = 'en_US', 100, 1000)
                ),
                IF(p_locale = 'en_US', 2, 3),
                '0'
            )
        );

        -- Construct email.
        SET v_email = CONCAT(
            LOWER(v_first), '.',
            LOWER(v_last), '.',
            p_seed, '.',
            v_user_index, '@',
            v_domain
        );

        -- Construct synthetic phone number.
        SET v_phone = IF(
            p_locale = 'de_DE',
            CONCAT(
                '+49 30 ',
                LPAD(
                    MOD(
                        CRC32(CONCAT(
                            p_locale, ':', p_seed, ':',
                            v_user_index, ':phone'
                        )),
                        10000000
                    ),
                    7,
                    '0'
                )
            ),
            CONCAT(
                '+1 202 ',
                LPAD(
                    MOD(
                        CRC32(CONCAT(
                            p_locale, ':', p_seed, ':',
                            v_user_index, ':phone'
                        )),
                        10000000
                    ),
                    7,
                    '0'
                )
            )
        );

        -- Uniform-sphere latitude and longitude.
        SET v_lat = DEGREES(
            ASIN(
                2 * (
                    CRC32(CONCAT(
                        p_locale, ':', p_seed, ':',
                        v_user_index, ':latitude'
                    )) / 4294967296.0
                ) - 1
            )
        );

        SET v_lon = (
            CRC32(CONCAT(
                p_locale, ':', p_seed, ':',
                v_user_index, ':longitude'
            )) / 4294967296.0
        ) * 360 - 180;

        -- Deterministic birth date.
        SET v_birth = DATE_ADD(
            '1970-01-01',
            INTERVAL MOD(
                CRC32(CONCAT(
                    p_locale, ':', p_seed, ':',
                    v_user_index, ':birth'
                )),
                15000
            ) DAY
        );

        -- Generate 12 deterministic pseudo-random samples.
        -- SHA-256 helps reduce correlations between nearby CRC32 inputs.
        SET j = 0;
        SET v_height_sum = 0;
        SET v_weight_sum = 0;

        WHILE j < 12 DO

            SET v_height_sum = v_height_sum +
                CAST(
                    CONV(
                        SUBSTRING(
                            SHA2(CONCAT(
                                p_locale, ':', p_seed, ':',
                                v_user_index, ':height:', j
                            ), 256),
                            1, 8
                        ),
                        16,
                        10
                    ) AS DECIMAL(20,0)
                ) / 4294967295.0;

            SET v_weight_sum = v_weight_sum +
                CAST(
                    CONV(
                        SUBSTRING(
                            SHA2(CONCAT(
                                p_locale, ':', p_seed, ':',
                                v_user_index, ':weight:', j
                            ), 256),
                            1, 8
                        ),
                        16,
                        10
                    ) AS DECIMAL(20,0)
                ) / 4294967295.0;

            SET j = j + 1;
        END WHILE;

        -- Approximate normal distributions.
        -- Target mean height: 170 cm; approximate SD: 4.5 cm.
        SET v_height = ROUND(
            LEAST(
                205,
                GREATEST(
                    140,
                    170 + (v_height_sum - 6) * 4.5
                )
            ),
            2
        );

        -- Target mean weight: 75 kg; approximate SD: 13 kg.
        SET v_weight = ROUND(
            LEAST(
                160,
                GREATEST(
                    40,
                    75 + (v_weight_sum - 6) * 13
                )
            ),
            2
        );

        -- Insert generated user or update the existing record.
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
            CONCAT(
                1 + MOD(
                    CRC32(CONCAT(
                        p_locale, ':', p_seed, ':',
                        v_user_index, ':house'
                    )),
                    9999
                ),
                ' ',
                v_street
            ),
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

    -- Return this batch.
    SELECT *
    FROM generated_users
    WHERE locale_code = p_locale
      AND seed_value = p_seed
      AND batch_index = p_batch_index
    ORDER BY user_index;

END$$

DELIMITER ;
