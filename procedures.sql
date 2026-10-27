USE defaultdb;

DROP PROCEDURE IF EXISTS generate_user_batch;
DROP FUNCTION IF EXISTS generator_offset;
DROP FUNCTION IF EXISTS generator_uniform;

DELIMITER $$

CREATE FUNCTION generator_uniform(
    p_locale VARCHAR(10),
    p_seed BIGINT,
    p_user_index BIGINT,
    p_field VARCHAR(30)
)
RETURNS DOUBLE
DETERMINISTIC
NO SQL
BEGIN
    DECLARE v_bits DECIMAL(20,0);
    SET v_bits = CAST(
        CONV(
            SUBSTRING(
                SHA2(CONCAT(p_locale, ':', p_seed, ':', p_user_index, ':', p_field), 256),
                1,
                8
            ),
            16,
            10
        ) AS DECIMAL(20,0)
    );
    RETURN (v_bits + 0.5) / 4294967296.0;
END$$

CREATE FUNCTION generator_offset(
    p_locale VARCHAR(10),
    p_seed BIGINT,
    p_user_index BIGINT,
    p_field VARCHAR(30),
    p_count INT
)
RETURNS INT
DETERMINISTIC
NO SQL
BEGIN
    IF p_count IS NULL OR p_count < 1 THEN
        RETURN 0;
    END IF;

    RETURN MOD(
        CRC32(CONCAT(
            p_locale, ':', p_seed, ':', p_user_index, ':', p_field
        )),
        p_count
    );
END$$

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
    DECLARE v_phone_digits VARCHAR(7);
    DECLARE v_phone_style INT;

    DECLARE v_lat DOUBLE;
    DECLARE v_lon DOUBLE;
    DECLARE v_u DOUBLE;
    DECLARE v_u1 DOUBLE;
    DECLARE v_u2 DOUBLE;
    DECLARE v_z_height DOUBLE;
    DECLARE v_z_weight DOUBLE;
    DECLARE v_birth DATE;
    DECLARE v_height DECIMAL(5,2);
    DECLARE v_weight DECIMAL(5,2);

    DECLARE v_user_index BIGINT;
    DECLARE v_offset INT;
    DECLARE v_count INT;
    DECLARE v_postal_digits INT;

    -- Validate inputs.
    IF p_batch_size IS NULL
       OR p_batch_size < 1
       OR p_batch_size > 1000 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Batch size must be between 1 and 1000';
    END IF;

    IF p_batch_index IS NULL OR p_batch_index < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Batch index cannot be negative';
    END IF;

    IF p_seed IS NULL OR p_locale IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Seed and locale are required';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM locales
        WHERE locale_code = p_locale
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Unsupported locale';
    END IF;

    -- Validate names.
    SELECT COUNT(*)
    INTO v_count
    FROM names
    WHERE locale_code = p_locale;

    IF v_count = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'No names found for this locale';
    END IF;

    -- Validate required lookup tables.
    IF NOT EXISTS (
        SELECT 1
        FROM titles
        WHERE locale_code = p_locale
    ) OR NOT EXISTS (
        SELECT 1
        FROM street_names
        WHERE locale_code = p_locale
    ) OR NOT EXISTS (
        SELECT 1
        FROM cities
        WHERE locale_code = p_locale
    ) OR NOT EXISTS (
        SELECT 1
        FROM eye_colors
        WHERE locale_code = p_locale
    ) OR NOT EXISTS (
        SELECT 1
        FROM email_domains
        WHERE locale_code = p_locale
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'One or more lookup tables are empty or incomplete';
    END IF;

    WHILE i < p_batch_size DO

        SET v_user_index =
            p_batch_index * p_batch_size + i;

        -- Select names in a deterministic shuffled order.
        -- This avoids repeating a name row across consecutive
        -- user indexes until the available name count is reached.
        SELECT COUNT(*)
        INTO v_count
        FROM names
        WHERE locale_code = p_locale;

        SET v_offset = MOD(v_user_index, v_count);

        SELECT first_name, last_name, gender
        INTO v_first, v_last, v_gender
        FROM names
        WHERE locale_code = p_locale
        ORDER BY
            CRC32(
                CONCAT(
                    p_locale, ':',
                    p_seed, ':name_order:',
                    id
                )
            ),
            id
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
            SET MESSAGE_TEXT =
                'No suitable title found for name gender';
        END IF;

        -- Vary the name format: some profiles have no title.
        IF generator_offset(
            p_locale, p_seed, v_user_index, 'title_presence', 4
        ) = 0 THEN
            SET v_title = NULL;
        ELSE
            -- Select compatible title.
            SET v_offset = generator_offset(
                p_locale, p_seed, v_user_index, 'title', v_count
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
        END IF;

        -- Select street.
        SELECT COUNT(*)
        INTO v_count
        FROM street_names
        WHERE locale_code = p_locale;

        SET v_offset = generator_offset(
            p_locale, p_seed, v_user_index, 'street', v_count
        );

        SELECT street_name
        INTO v_street
        FROM street_names
        WHERE locale_code = p_locale
        ORDER BY id
        LIMIT v_offset, 1;

        -- Select a locale-specific city/address component.
        SELECT COUNT(*)
        INTO v_count
        FROM cities
        WHERE locale_code = p_locale;

        SET v_offset = generator_offset(
            p_locale, p_seed, v_user_index, 'city', v_count
        );

        SELECT city_name, region_name, postal_prefix
        INTO v_city, v_region, v_prefix
        FROM cities
        WHERE locale_code = p_locale
        ORDER BY id
        LIMIT v_offset, 1;

        -- Uniform random point on a sphere.
        -- u is uniform on [0,1); latitude = asin(2u-1),
        -- longitude is uniform on [-180,180).
        SET v_u = generator_uniform(
            p_locale, p_seed, v_user_index, 'geo_lat'
        );

        SET v_lat = DEGREES(ASIN(2 * v_u - 1));

        SET v_u = generator_uniform(
            p_locale, p_seed, v_user_index, 'geo_lon'
        );

        SET v_lon = 360 * v_u - 180;

        -- Select eye color.
        SELECT COUNT(*)
        INTO v_count
        FROM eye_colors
        WHERE locale_code = p_locale;

        SET v_offset = generator_offset(
            p_locale, p_seed, v_user_index, 'eye', v_count
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

        SET v_offset = generator_offset(
            p_locale, p_seed, v_user_index, 'domain', v_count
        );

        SELECT domain_name
        INTO v_domain
        FROM email_domains
        WHERE locale_code = p_locale
        ORDER BY id
        LIMIT v_offset, 1;

        -- Construct full name.
        SET v_full = IF(
            v_title IS NULL,
            CONCAT(v_first, ' ', v_last),
            CONCAT(v_title, ' ', v_first, ' ', v_last)
        );

        -- Generate a five-character synthetic postal code.
        SET v_postal_digits = 5 - CHAR_LENGTH(v_prefix);

        IF v_postal_digits < 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Postal prefix must not exceed five characters';
        END IF;

        SET v_postal = CONCAT(
            v_prefix,
            LPAD(
                MOD(
                    CRC32(
                        CONCAT(
                            p_locale, ':', p_seed, ':',
                            v_user_index, ':postal'
                        )
                    ),
                    POW(10, v_postal_digits)
                ),
                v_postal_digits,
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

        -- Generate a deterministic phone number with format variation.
        SET v_phone_digits = LPAD(
            MOD(
                CRC32(CONCAT(
                    p_locale, ':', p_seed, ':', v_user_index, ':phone'
                )),
                10000000
            ),
            7,
            '0'
        );

        SET v_phone_style = generator_offset(
            p_locale, p_seed, v_user_index, 'phone_style', 3
        );

        IF p_locale = 'de_DE' THEN
            SET v_phone = CASE v_phone_style
                WHEN 0 THEN CONCAT('+49 30 ', LEFT(v_phone_digits, 3), ' ', RIGHT(v_phone_digits, 4))
                WHEN 1 THEN CONCAT('+49 (0)30-', LEFT(v_phone_digits, 3), '-', RIGHT(v_phone_digits, 4))
                ELSE CONCAT('030 ', LEFT(v_phone_digits, 3), ' ', RIGHT(v_phone_digits, 4))
            END;
        ELSE
            SET v_phone = CASE v_phone_style
                WHEN 0 THEN CONCAT('+1 (202) ', LEFT(v_phone_digits, 3), '-', RIGHT(v_phone_digits, 4))
                WHEN 1 THEN CONCAT('202-', LEFT(v_phone_digits, 3), '-', RIGHT(v_phone_digits, 4))
                ELSE CONCAT('+1 202 ', LEFT(v_phone_digits, 3), ' ', RIGHT(v_phone_digits, 4))
            END;
        END IF;

        -- Generate deterministic birth date.
        SET v_birth = DATE_ADD(
            '1970-01-01',
            INTERVAL MOD(
                CRC32(
                    CONCAT(
                        p_locale, ':', p_seed, ':',
                        v_user_index, ':birth'
                    )
                ),
                15000
            ) DAY
        );

        -- Generate approximately normal height and weight values using
        -- deterministic Box-Muller transforms from SHA-256-derived pseudo-uniform inputs.
        SET v_u1 = generator_uniform(
            p_locale, p_seed, v_user_index, 'height_u1'
        );
        SET v_u2 = generator_uniform(
            p_locale, p_seed, v_user_index, 'height_u2'
        );
        SET v_z_height = SQRT(-2 * LN(v_u1)) * COS(2 * PI() * v_u2);

        SET v_u1 = generator_uniform(
            p_locale, p_seed, v_user_index, 'weight_u1'
        );
        SET v_u2 = generator_uniform(
            p_locale, p_seed, v_user_index, 'weight_u2'
        );
        SET v_z_weight = SQRT(-2 * LN(v_u1)) * COS(2 * PI() * v_u2);

        -- Truncated normal-like values avoid extreme synthetic profiles.
        SET v_height = ROUND(
            LEAST(200, GREATEST(145, 170 + 10 * v_z_height)),
            2
        );
        SET v_weight = ROUND(
            LEAST(160, GREATEST(40, 75 + 15 * v_z_weight)),
            2
        );

        -- Insert or update generated profile.
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
            CASE generator_offset(
                p_locale, p_seed, v_user_index, 'address_style', 3
            )
                WHEN 0 THEN CONCAT(
                    1 + MOD(CRC32(CONCAT(p_locale, ':', p_seed, ':', v_user_index, ':house')), 9999),
                    ' ', v_street
                )
                WHEN 1 THEN CONCAT(
                    1 + MOD(CRC32(CONCAT(p_locale, ':', p_seed, ':', v_user_index, ':house')), 9999),
                    ' ', v_street, ', Apt ',
                    1 + MOD(CRC32(CONCAT(p_locale, ':', p_seed, ':', v_user_index, ':apt')), 999)
                )
                ELSE CONCAT(
                    v_street, ' ',
                    1 + MOD(CRC32(CONCAT(p_locale, ':', p_seed, ':', v_user_index, ':house')), 9999)
                )
            END,
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

    -- Remove stale rows from a previous call of this same batch if the
    -- requested batch size changed; preserve all other runs and batches.
    DELETE FROM generated_users
    WHERE locale_code = p_locale
      AND seed_value = p_seed
      AND batch_index = p_batch_index
      AND (
          user_index < p_batch_index * p_batch_size
          OR user_index >= (p_batch_index + 1) * p_batch_size
      );

    -- Return exactly the requested batch.
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
