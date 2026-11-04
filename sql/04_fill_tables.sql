
-- 1. Load all 10 CSV files.

DO $$
DECLARE
    file_path TEXT;
    i INTEGER;
BEGIN
    FOR i IN 0..9 LOOP
        IF i = 0 THEN
            file_path := '/data/MOCK_DATA.csv';
        ELSE
            file_path := '/data/MOCK_DATA (' || i || ').csv';
        END IF;

        EXECUTE format(
            $copy$
            COPY public.mock_data (
                id,
                customer_first_name,
                customer_last_name,
                customer_age,
                customer_email,
                customer_country,
                customer_postal_code,
                customer_pet_type,
                customer_pet_name,
                customer_pet_breed,
                seller_first_name,
                seller_last_name,
                seller_email,
                seller_country,
                seller_postal_code,
                product_name,
                product_category,
                product_price,
                product_quantity,
                sale_date,
                sale_customer_id,
                sale_seller_id,
                sale_product_id,
                sale_quantity,
                sale_total_price,
                store_name,
                store_location,
                store_city,
                store_state,
                store_country,
                store_phone,
                store_email,
                pet_category,
                product_weight,
                product_color,
                product_size,
                product_brand,
                product_material,
                product_description,
                product_rating,
                product_reviews,
                product_release_date,
                product_expiry_date,
                supplier_name,
                supplier_contact,
                supplier_email,
                supplier_phone,
                supplier_address,
                supplier_city,
                supplier_country
            )
            FROM %L
            WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"')
            $copy$,
            file_path
        );
    END LOOP;
END $$;

-- 2. Fill customer dimension.

INSERT INTO public.dim_customer (
    source_row_id, source_customer_id,
    first_name, last_name, age, email,
    country, postal_code, pet_type, pet_name, pet_breed
)
SELECT
    source_row_id, sale_customer_id,
    customer_first_name, customer_last_name,
    customer_age, customer_email,
    customer_country, customer_postal_code,
    customer_pet_type, customer_pet_name, customer_pet_breed
FROM public.mock_data;

-- 3. Fill seller dimension.

INSERT INTO public.dim_seller (
    source_row_id, source_seller_id,
    first_name, last_name, email, country, postal_code
)
SELECT
    source_row_id, sale_seller_id,
    seller_first_name, seller_last_name,
    seller_email, seller_country, seller_postal_code
FROM public.mock_data;

-- 4. Fill product dimension.

INSERT INTO public.dim_product (
    source_row_id, source_product_id,
    product_name, product_category,
    product_price, product_quantity,
    pet_category, product_weight,
    product_color, product_size,
    product_brand, product_material,
    product_description, product_rating,
    product_reviews, product_release_date,
    product_expiry_date
)
SELECT
    source_row_id, sale_product_id,
    product_name, product_category,
    product_price, product_quantity,
    pet_category, product_weight,
    product_color, product_size,
    product_brand, product_material,
    product_description, product_rating,
    product_reviews, product_release_date,
    product_expiry_date
FROM public.mock_data;

-- 5. Fill store dimension.

INSERT INTO public.dim_store (
    store_name, store_location, store_city,
    store_state, store_country, store_phone, store_email
)
SELECT DISTINCT
    store_name, store_location, store_city,
    store_state, store_country, store_phone, store_email
FROM public.mock_data;

-- 6. Fill supplier dimension.

INSERT INTO public.dim_supplier (
    supplier_name, supplier_contact, supplier_email,
    supplier_phone, supplier_address,
    supplier_city, supplier_country
)
SELECT DISTINCT
    supplier_name, supplier_contact, supplier_email,
    supplier_phone, supplier_address,
    supplier_city, supplier_country
FROM public.mock_data;

-- 7. Fill date dimension.

INSERT INTO public.dim_date (
    date_key, full_date, year, quarter,
    month, day, day_of_week
)
SELECT DISTINCT
    TO_CHAR(sale_date, 'YYYYMMDD')::INTEGER,
    sale_date,
    EXTRACT(YEAR FROM sale_date)::INTEGER,
    EXTRACT(QUARTER FROM sale_date)::INTEGER,
    EXTRACT(MONTH FROM sale_date)::INTEGER,
    EXTRACT(DAY FROM sale_date)::INTEGER,
    EXTRACT(ISODOW FROM sale_date)::INTEGER
FROM public.mock_data
WHERE sale_date IS NOT NULL;

-- 8. Map source rows to stores.

INSERT INTO public.map_store (source_row_id, store_key)
SELECT
    m.source_row_id,
    s.store_key
FROM public.mock_data m
JOIN public.dim_store s
    ON m.store_name IS NOT DISTINCT FROM s.store_name
    AND m.store_location IS NOT DISTINCT FROM s.store_location
    AND m.store_city IS NOT DISTINCT FROM s.store_city
    AND m.store_state IS NOT DISTINCT FROM s.store_state
    AND m.store_country IS NOT DISTINCT FROM s.store_country
    AND m.store_phone IS NOT DISTINCT FROM s.store_phone
    AND m.store_email IS NOT DISTINCT FROM s.store_email;

-- 9. Map source rows to suppliers.

INSERT INTO public.map_supplier (source_row_id, supplier_key)
SELECT
    m.source_row_id,
    s.supplier_key
FROM public.mock_data m
JOIN public.dim_supplier s
    ON m.supplier_name IS NOT DISTINCT FROM s.supplier_name
    AND m.supplier_contact IS NOT DISTINCT FROM s.supplier_contact
    AND m.supplier_email IS NOT DISTINCT FROM s.supplier_email
    AND m.supplier_phone IS NOT DISTINCT FROM s.supplier_phone
    AND m.supplier_address IS NOT DISTINCT FROM s.supplier_address
    AND m.supplier_city IS NOT DISTINCT FROM s.supplier_city
    AND m.supplier_country IS NOT DISTINCT FROM s.supplier_country;

-- 10. Fill fact table.

INSERT INTO public.fact_sales (
    source_row_id,
    customer_key,
    seller_key,
    product_key,
    store_key,
    supplier_key,
    date_key,
    sale_quantity,
    sale_total_price
)
SELECT
    m.source_row_id,
    c.customer_key,
    s.seller_key,
    p.product_key,
    ms.store_key,
    mp.supplier_key,
    d.date_key,
    m.sale_quantity,
    m.sale_total_price
FROM public.mock_data m
JOIN public.dim_customer c
    ON c.source_row_id = m.source_row_id
JOIN public.dim_seller s
    ON s.source_row_id = m.source_row_id
JOIN public.dim_product p
    ON p.source_row_id = m.source_row_id
JOIN public.map_store ms
    ON ms.source_row_id = m.source_row_id
JOIN public.map_supplier mp
    ON mp.source_row_id = m.source_row_id
JOIN public.dim_date d
    ON d.full_date = m.sale_date;

-- 11. Validate the load.

DO $$
DECLARE
    raw_count BIGINT;
    fact_count BIGINT;
    store_count BIGINT;
    supplier_count BIGINT;
    raw_total NUMERIC;
    fact_total NUMERIC;
BEGIN
    SELECT COUNT(*), SUM(sale_total_price)
    INTO raw_count, raw_total
    FROM public.mock_data;

    SELECT COUNT(*), SUM(sale_total_price)
    INTO fact_count, fact_total
    FROM public.fact_sales;

    SELECT COUNT(*) INTO store_count FROM public.map_store;
    SELECT COUNT(*) INTO supplier_count FROM public.map_supplier;

    IF raw_count <> 10000
       OR fact_count <> raw_count
       OR store_count <> raw_count
       OR supplier_count <> raw_count
       OR raw_total IS DISTINCT FROM fact_total
    THEN
        RAISE EXCEPTION
            'Validation failed: raw=%, fact=%, stores=%, suppliers=%, raw_total=%, fact_total=%',
            raw_count, fact_count, store_count,
            supplier_count, raw_total, fact_total;
    END IF;

    RAISE NOTICE 'SUCCESS: % sales loaded, total = %',
        fact_count, fact_total;
END $$;
