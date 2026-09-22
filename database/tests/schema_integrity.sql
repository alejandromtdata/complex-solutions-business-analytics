\set ON_ERROR_STOP on

BEGIN;

-- The schema must expose exactly the 14 requested business tables.
DO $$
DECLARE
    expected_tables TEXT[] := ARRAY[
        'categories', 'crm_activities', 'customers', 'employees', 'inventory_movements',
        'invoices', 'leads', 'opportunities', 'products', 'purchase_items',
        'purchase_orders', 'sale_items', 'sales', 'suppliers'
    ];
    actual_tables TEXT[];
BEGIN
    SELECT array_agg(tablename ORDER BY tablename) INTO actual_tables
    FROM pg_tables
    WHERE schemaname = 'public';
    IF actual_tables IS DISTINCT FROM expected_tables THEN
        RAISE EXCEPTION 'Unexpected business tables: %', actual_tables;
    END IF;
END $$;

-- A small valid relationship chain proves the main foreign keys are usable.
INSERT INTO employees (name, department, role, hire_date)
VALUES ('Test Sales Rep', 'SALES', 'Sales Representative', DATE '2020-01-01')
RETURNING employee_id AS test_employee_id \gset
INSERT INTO suppliers (supplier_name) VALUES ('Test Supplier')
RETURNING supplier_id AS test_supplier_id \gset
INSERT INTO categories (category_name) VALUES ('Test Category')
RETURNING category_id AS test_category_id \gset
INSERT INTO customers (customer_type, company_name, customer_segment, city, province, signup_date, acquisition_channel, sales_rep_id)
VALUES ('B2B', 'Test Customer', 'SMB', 'Madrid', 'Madrid', DATE '2020-01-01', 'OUTBOUND_SALES', :test_employee_id)
RETURNING customer_id AS test_customer_id \gset
INSERT INTO products (sku, product_name, category_id, brand, supplier_id, cost_price, list_price)
VALUES ('TEST-SKU-001', 'Test Product', :test_category_id, 'Test Brand', :test_supplier_id, 10.00, 20.00)
RETURNING product_id AS test_product_id \gset
INSERT INTO sales (customer_id, employee_id, sale_date, channel, status)
VALUES (:test_customer_id, :test_employee_id, DATE '2020-01-02', 'B2B', 'CONFIRMED')
RETURNING sale_id AS test_sale_id \gset
INSERT INTO sale_items (sale_id, product_id, quantity, unit_price, discount, unit_cost)
VALUES (:test_sale_id, :test_product_id, 2, 20.00, 0.1000, 10.00);
INSERT INTO invoices (sale_id, invoice_date, due_date, status, total_amount)
VALUES (:test_sale_id, DATE '2020-01-02', DATE '2020-02-01', 'SENT', 36.00);
INSERT INTO purchase_orders (supplier_id, purchase_date, status)
VALUES (:test_supplier_id, DATE '2020-01-01', 'RECEIVED')
RETURNING purchase_id AS test_purchase_id \gset
INSERT INTO purchase_items (purchase_id, product_id, quantity, unit_cost)
VALUES (:test_purchase_id, :test_product_id, 10, 10.00);
INSERT INTO inventory_movements (product_id, movement_date, movement_type, quantity, unit_cost)
VALUES (:test_product_id, DATE '2020-01-01', 'PURCHASE', 10, 10.00);
INSERT INTO leads (company_name, created_date, source, industry, sales_rep_id, status)
VALUES ('Test Lead', DATE '2020-01-01', 'WEB', 'Technology', :test_employee_id, 'QUALIFIED')
RETURNING lead_id AS test_lead_id \gset
-- This opportunity validates the optional lead-to-opportunity relationship.
INSERT INTO opportunities (lead_id, customer_id, sales_rep_id, created_date, expected_close_date, stage, estimated_value, probability)
VALUES (:test_lead_id, :test_customer_id, :test_employee_id, DATE '2020-01-01', DATE '2020-02-01', 'PROPOSAL', 100.00, 0.500)
RETURNING opportunity_id AS test_opportunity_id \gset
INSERT INTO crm_activities (opportunity_id, employee_id, activity_type, activity_date)
VALUES (:test_opportunity_id, :test_employee_id, 'CALL', DATE '2020-01-02');

-- Constraints must reject invalid commercial values.
DO $$
DECLARE
    test_sale_id BIGINT := (SELECT sale_id FROM sales WHERE sale_date = DATE '2020-01-02' AND channel = 'B2B' ORDER BY sale_id DESC LIMIT 1);
    test_product_id BIGINT := (SELECT product_id FROM products WHERE sku = 'TEST-SKU-001' ORDER BY product_id DESC LIMIT 1);
    test_customer_id BIGINT := (SELECT customer_id FROM customers WHERE company_name = 'Test Customer' ORDER BY customer_id DESC LIMIT 1);
    test_employee_id BIGINT := (SELECT employee_id FROM employees WHERE name = 'Test Sales Rep' ORDER BY employee_id DESC LIMIT 1);
BEGIN
    BEGIN
        INSERT INTO sale_items (sale_id, product_id, quantity, unit_price, discount, unit_cost)
        VALUES (test_sale_id, test_product_id, 0, 20.00, 0, 10.00);
        RAISE EXCEPTION 'Zero quantity was accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    BEGIN
        INSERT INTO opportunities (customer_id, sales_rep_id, created_date, expected_close_date, stage, estimated_value, probability)
        VALUES (test_customer_id, test_employee_id, DATE '2020-01-01', DATE '2020-01-02', 'PROSPECTING', 100, 1.001);
        RAISE EXCEPTION 'Invalid probability was accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    BEGIN
        INSERT INTO invoices (sale_id, invoice_date, due_date, status, total_amount)
        VALUES (999999, DATE '2020-01-01', DATE '2020-01-02', 'SENT', 1.00);
        RAISE EXCEPTION 'Invalid invoice-to-sale reference was accepted';
    EXCEPTION WHEN foreign_key_violation THEN NULL;
    END;
    BEGIN
        INSERT INTO opportunities (lead_id, customer_id, sales_rep_id, created_date, expected_close_date, stage, estimated_value, probability)
        VALUES (999999, test_customer_id, test_employee_id, DATE '2020-01-01', DATE '2020-01-02', 'PROSPECTING', 100, 0.500);
        RAISE EXCEPTION 'Invalid opportunity-to-lead reference was accepted';
    EXCEPTION WHEN foreign_key_violation THEN NULL;
    END;
END $$;

ROLLBACK;
