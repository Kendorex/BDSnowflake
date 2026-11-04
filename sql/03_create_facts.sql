
CREATE TABLE public.map_store (
    source_row_id BIGINT PRIMARY KEY
        REFERENCES public.mock_data(source_row_id),
    store_key BIGINT NOT NULL
        REFERENCES public.dim_store(store_key)
);

CREATE TABLE public.map_supplier (
    source_row_id BIGINT PRIMARY KEY
        REFERENCES public.mock_data(source_row_id),
    supplier_key BIGINT NOT NULL
        REFERENCES public.dim_supplier(supplier_key)
);

CREATE TABLE public.fact_sales (
    sale_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_row_id BIGINT NOT NULL UNIQUE
        REFERENCES public.mock_data(source_row_id),
    customer_key BIGINT NOT NULL
        REFERENCES public.dim_customer(customer_key),
    seller_key BIGINT NOT NULL
        REFERENCES public.dim_seller(seller_key),
    product_key BIGINT NOT NULL
        REFERENCES public.dim_product(product_key),
    store_key BIGINT NOT NULL
        REFERENCES public.dim_store(store_key),
    supplier_key BIGINT NOT NULL
        REFERENCES public.dim_supplier(supplier_key),
    date_key INTEGER NOT NULL
        REFERENCES public.dim_date(date_key),
    sale_quantity INTEGER,
    sale_total_price NUMERIC(12,2)
);
