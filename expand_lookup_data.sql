USE fake_user_generator;

-- Expand locale-aware names, streets, and cities.
-- Safe to rerun: existing values are skipped.

-- =========================================================
-- 1. TEMPORARY FIRST NAMES
-- =========================================================

CREATE TEMPORARY TABLE tmp_first_names (
    locale_code VARCHAR(10) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    gender ENUM('male','female','neutral') NOT NULL,
    PRIMARY KEY (locale_code, first_name, gender)
);

-- =========================================================
-- 2. TEMPORARY LAST NAMES
-- =========================================================

CREATE TEMPORARY TABLE tmp_last_names (
    locale_code VARCHAR(10) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    PRIMARY KEY (locale_code, last_name)
);

-- =========================================================
-- 3. FIRST NAME DATA
-- =========================================================

INSERT INTO tmp_first_names (locale_code, first_name, gender) VALUES
('en_US','James','male'),
('en_US','William','male'),
('en_US','Noah','male'),
('en_US','Liam','male'),
('en_US','Mason','male'),
('en_US','Ethan','male'),
('en_US','Lucas','male'),
('en_US','Logan','male'),
('en_US','Benjamin','male'),
('en_US','Elijah','male'),
('en_US','Alexander','male'),
('en_US','Daniel','male'),
('en_US','Matthew','male'),
('en_US','Henry','male'),
('en_US','Jackson','male'),
('en_US','Olivia','female'),
('en_US','Emma','female'),
('en_US','Sophia','female'),
('en_US','Ava','female'),
('en_US','Isabella','female'),
('en_US','Mia','female'),
('en_US','Amelia','female'),
('en_US','Harper','female'),
('en_US','Evelyn','female'),
('en_US','Abigail','female'),
('en_US','Emily','female'),
('en_US','Elizabeth','female'),
('en_US','Sofia','female'),
('en_US','Ella','female'),
('en_US','Grace','female'),

('de_DE','Hans','male'),
('de_DE','Paul','male'),
('de_DE','Leon','male'),
('de_DE','Lukas','male'),
('de_DE','Felix','male'),
('de_DE','Jonas','male'),
('de_DE','Finn','male'),
('de_DE','Noah','male'),
('de_DE','Elias','male'),
('de_DE','Ben','male'),
('de_DE','Luca','male'),
('de_DE','Maximilian','male'),
('de_DE','Henry','male'),
('de_DE','Emil','male'),
('de_DE','Theo','male'),
('de_DE','Anna','female'),
('de_DE','Marie','female'),
('de_DE','Sophie','female'),
('de_DE','Mia','female'),
('de_DE','Emilia','female'),
('de_DE','Hannah','female'),
('de_DE','Emma','female'),
('de_DE','Lina','female'),
('de_DE','Ella','female'),
('de_DE','Clara','female'),
('de_DE','Lea','female'),
('de_DE','Lena','female'),
('de_DE','Maja','female'),
('de_DE','Johanna','female'),
('de_DE','Laura','female');

-- =========================================================
-- 4. LAST NAME DATA
-- =========================================================

INSERT INTO tmp_last_names (locale_code, last_name) VALUES
('en_US','Smith'),
('en_US','Johnson'),
('en_US','Brown'),
('en_US','Davis'),
('en_US','Wilson'),
('en_US','Miller'),
('en_US','Taylor'),
('en_US','Anderson'),
('en_US','Thomas'),
('en_US','Jackson'),
('en_US','White'),
('en_US','Harris'),
('en_US','Martin'),
('en_US','Thompson'),
('en_US','Garcia'),
('en_US','Martinez'),
('en_US','Robinson'),
('en_US','Clark'),
('en_US','Rodriguez'),
('en_US','Lewis'),
('en_US','Lee'),
('en_US','Walker'),
('en_US','Hall'),
('en_US','Allen'),
('en_US','Young'),
('en_US','King'),
('en_US','Wright'),
('en_US','Scott'),
('en_US','Green'),
('en_US','Baker'),

('de_DE','Müller'),
('de_DE','Schmidt'),
('de_DE','Schneider'),
('de_DE','Fischer'),
('de_DE','Weber'),
('de_DE','Meyer'),
('de_DE','Wagner'),
('de_DE','Becker'),
('de_DE','Schulz'),
('de_DE','Hoffmann'),
('de_DE','Schäfer'),
('de_DE','Koch'),
('de_DE','Bauer'),
('de_DE','Richter'),
('de_DE','Klein'),
('de_DE','Wolf'),
('de_DE','Schröder'),
('de_DE','Neumann'),
('de_DE','Schwarz'),
('de_DE','Zimmermann'),
('de_DE','Braun'),
('de_DE','Krüger'),
('de_DE','Hofmann'),
('de_DE','Hartmann'),
('de_DE','Lange'),
('de_DE','Schmitt'),
('de_DE','Werner'),
('de_DE','Schmitz'),
('de_DE','Krause'),
('de_DE','Meier');

-- =========================================================
-- 5. EXPAND THE MAIN NAMES TABLE
-- =========================================================

INSERT INTO names (locale_code, first_name, last_name, gender)
SELECT
    f.locale_code,
    f.first_name,
    l.last_name,
    f.gender
FROM tmp_first_names AS f
JOIN tmp_last_names AS l
    ON l.locale_code = f.locale_code
WHERE NOT EXISTS (
    SELECT 1
    FROM names AS n
    WHERE n.locale_code = f.locale_code
      AND n.first_name = f.first_name
      AND n.last_name = l.last_name
      AND n.gender = f.gender
);

DROP TEMPORARY TABLE tmp_first_names;
DROP TEMPORARY TABLE tmp_last_names;

-- =========================================================
-- 6. EXPAND STREET NAMES
-- =========================================================

INSERT INTO street_names (locale_code, street_name)
SELECT
    v.locale_code,
    v.street_name
FROM (
    SELECT 'en_US' AS locale_code, 'Cedar Lane' AS street_name
    UNION ALL SELECT 'en_US','River Road'
    UNION ALL SELECT 'en_US','Sunset Drive'
    UNION ALL SELECT 'en_US','Pine Street'
    UNION ALL SELECT 'en_US','Hillcrest Avenue'
    UNION ALL SELECT 'en_US','Meadow Lane'
    UNION ALL SELECT 'en_US','Willow Court'
    UNION ALL SELECT 'en_US','Highland Road'
    UNION ALL SELECT 'en_US','Lakeview Drive'
    UNION ALL SELECT 'en_US','Lincoln Avenue'
    UNION ALL SELECT 'en_US','Jefferson Street'
    UNION ALL SELECT 'en_US','Cherry Blossom Way'
    UNION ALL SELECT 'en_US','Forest Road'
    UNION ALL SELECT 'en_US','Ridge Street'
    UNION ALL SELECT 'en_US','Broadway'

    UNION ALL SELECT 'de_DE','Lindenstraße'
    UNION ALL SELECT 'de_DE','Schillerstraße'
    UNION ALL SELECT 'de_DE','Goethestraße'
    UNION ALL SELECT 'de_DE','Waldweg'
    UNION ALL SELECT 'de_DE','Bergstraße'
    UNION ALL SELECT 'de_DE','Kirchweg'
    UNION ALL SELECT 'de_DE','Rosenstraße'
    UNION ALL SELECT 'de_DE','Mozartstraße'
    UNION ALL SELECT 'de_DE','Friedrichstraße'
    UNION ALL SELECT 'de_DE','Kaiserstraße'
    UNION ALL SELECT 'de_DE','Hafenstraße'
    UNION ALL SELECT 'de_DE','Wiesenweg'
    UNION ALL SELECT 'de_DE','Schlossallee'
    UNION ALL SELECT 'de_DE','Buchenweg'
    UNION ALL SELECT 'de_DE','Am Markt'
) AS v
WHERE NOT EXISTS (
    SELECT 1
    FROM street_names AS s
    WHERE s.locale_code = v.locale_code
      AND s.street_name = v.street_name
);

-- =========================================================
-- 7. TEMPORARY CITIES TABLE
-- =========================================================

CREATE TEMPORARY TABLE tmp_cities (
    locale_code VARCHAR(10) NOT NULL,
    city_name VARCHAR(100) NOT NULL,
    region_name VARCHAR(100) NOT NULL,
    postal_prefix VARCHAR(12) NOT NULL,
    latitude DECIMAL(10,7) NOT NULL,
    longitude DECIMAL(10,7) NOT NULL,
    PRIMARY KEY (locale_code, city_name, region_name)
);

-- =========================================================
-- 8. CITY DATA
-- =========================================================

INSERT INTO tmp_cities (
    locale_code,
    city_name,
    region_name,
    postal_prefix,
    latitude,
    longitude
) VALUES
('en_US','Seattle','Washington','981',47.6062000,-122.3321000),
('en_US','San Diego','California','921',32.7157000,-117.1611000),
('en_US','Dallas','Texas','752',32.7767000,-96.7970000),
('en_US','Austin','Texas','787',30.2672000,-97.7431000),
('en_US','Denver','Colorado','802',39.7392000,-104.9903000),
('en_US','Boston','Massachusetts','021',42.3601000,-71.0589000),
('en_US','Atlanta','Georgia','303',33.7490000,-84.3880000),
('en_US','Portland','Oregon','972',45.5152000,-122.6784000),
('en_US','Miami','Florida','331',25.7617000,-80.1918000),
('en_US','Detroit','Michigan','482',42.3314000,-83.0458000),
('en_US','Nashville','Tennessee','372',36.1627000,-86.7816000),
('en_US','Charlotte','North Carolina','282',35.2271000,-80.8431000),
('en_US','Minneapolis','Minnesota','554',44.9778000,-93.2650000),
('en_US','Baltimore','Maryland','212',39.2904000,-76.6122000),
('en_US','Las Vegas','Nevada','891',36.1699000,-115.1398000),

('de_DE','Stuttgart','Baden-Württemberg','70',48.7758000,9.1829000),
('de_DE','Düsseldorf','Nordrhein-Westfalen','40',51.2277000,6.7735000),
('de_DE','Dortmund','Nordrhein-Westfalen','44',51.5136000,7.4653000),
('de_DE','Essen','Nordrhein-Westfalen','45',51.4556000,7.0116000),
('de_DE','Leipzig','Sachsen','04',51.3397000,12.3731000),
('de_DE','Bremen','Bremen','28',53.0793000,8.8017000),
('de_DE','Dresden','Sachsen','01',51.0504000,13.7373000),
('de_DE','Hannover','Niedersachsen','30',52.3759000,9.7320000),
('de_DE','Nürnberg','Bayern','90',49.4521000,11.0767000),
('de_DE','Duisburg','Nordrhein-Westfalen','47',51.4344000,6.7623000),
('de_DE','Bochum','Nordrhein-Westfalen','44',51.4818000,7.2162000),
('de_DE','Wuppertal','Nordrhein-Westfalen','42',51.2562000,7.1508000),
('de_DE','Bonn','Nordrhein-Westfalen','53',50.7374000,7.0982000),
('de_DE','Mannheim','Baden-Württemberg','68',49.4875000,8.4660000),
('de_DE','Karlsruhe','Baden-Württemberg','76',49.0069000,8.4037000);

-- =========================================================
-- 9. INSERT CITIES COMPATIBLY WITH DIFFERENT SCHEMAS
-- =========================================================

SET @has_city_coordinates = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'cities'
      AND COLUMN_NAME IN ('latitude', 'longitude')
);

SET @city_insert_sql = IF(
    @has_city_coordinates = 2,

    'INSERT INTO cities
       (locale_code, city_name, region_name, postal_prefix, latitude, longitude)
     SELECT t.locale_code, t.city_name, t.region_name, t.postal_prefix,
            t.latitude, t.longitude
     FROM tmp_cities AS t
     WHERE NOT EXISTS (
         SELECT 1 FROM cities AS c
         WHERE c.locale_code = t.locale_code
           AND c.city_name = t.city_name
           AND c.region_name = t.region_name
     )',

    'INSERT INTO cities
       (locale_code, city_name, region_name, postal_prefix)
     SELECT t.locale_code, t.city_name, t.region_name, t.postal_prefix
     FROM tmp_cities AS t
     WHERE NOT EXISTS (
         SELECT 1 FROM cities AS c
         WHERE c.locale_code = t.locale_code
           AND c.city_name = t.city_name
           AND c.region_name = t.region_name
     )'
);

PREPARE city_insert_stmt FROM @city_insert_sql;
EXECUTE city_insert_stmt;
DEALLOCATE PREPARE city_insert_stmt;

DROP TEMPORARY TABLE tmp_cities;

-- =========================================================
-- 10. VERIFY INSERTED DATA
-- =========================================================

SELECT
    locale_code,
    COUNT(*) AS names_count
FROM names
GROUP BY locale_code
ORDER BY locale_code;

SELECT
    locale_code,
    COUNT(*) AS street_names_count
FROM street_names
GROUP BY locale_code
ORDER BY locale_code;

SELECT
    locale_code,
    COUNT(*) AS cities_count
FROM cities
GROUP BY locale_code
ORDER BY locale_code;