-- ============================================================
-- PROJECT 03 - COMPLEX SOLUTIONS S.L.
-- DATABASE AUDIT
-- ============================================================


-- ============================================================
-- 1. DATABASE / CONNECTION
-- ============================================================

SELECT
    current_database() AS database_name,
    current_user AS user_name,
    version() AS postgres_version;


-- ============================================================
-- 2. TABLE INVENTORY
-- ============================================================

SELECT
    table_schema,
    table_name
FROM information_schema.tables
WHERE table_schema = 'public'
    AND table_type = 'BASE TABLE'
ORDER BY table_name;


-- ============================================================
-- 3. TABLE STRUCTURE
-- ============================================================

SELECT
    table_name,
    ordinal_position,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
ORDER BY
    table_name,
    ordinal_position; 

-- ============================================================
-- 4. ROW COUNTS
-- ============================================================

SELECT 'categories' AS table_name, COUNT(*) AS row_count FROM categories
UNION ALL
SELECT 'crm_activities', COUNT(*) FROM crm_activities
UNION ALL
SELECT 'customers', COUNT(*) FROM customers
UNION ALL
SELECT 'employees', COUNT(*) FROM employees
UNION ALL
SELECT 'inventory_movements', COUNT(*) FROM inventory_movements
UNION ALL
SELECT 'invoices', COUNT(*) FROM invoices
UNION ALL
SELECT 'leads', COUNT(*) FROM leads
UNION ALL
SELECT 'opportunities', COUNT(*) FROM opportunities
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'purchase_items', COUNT(*) FROM purchase_items
UNION ALL
SELECT 'purchase_orders', COUNT(*) FROM purchase_orders
UNION ALL
SELECT 'sale_items', COUNT(*) FROM sale_items
UNION ALL
SELECT 'sales', COUNT(*) FROM sales
UNION ALL
SELECT 'suppliers', COUNT(*) FROM suppliers
ORDER BY table_name;

-- ============================================================
-- 5. ORPHAN FOREIGN KEY CHECKS
-- ============================================================

-- Sales without an existing customer
SELECT COUNT(*) AS orphan_sales_customers
FROM sales s
LEFT JOIN customers c
    ON s.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


-- Sales without an existing employee
SELECT COUNT(*) AS orphan_sales_employees
FROM sales s
LEFT JOIN employees e
    ON s.employee_id = e.employee_id
WHERE e.employee_id IS NULL;


-- Sale items without an existing sale
SELECT COUNT(*) AS orphan_sale_items_sales
FROM sale_items si
LEFT JOIN sales s
    ON si.sale_id = s.sale_id
WHERE s.sale_id IS NULL;


-- Sale items without an existing product
SELECT COUNT(*) AS orphan_sale_items_products
FROM sale_items si
LEFT JOIN products p
    ON si.product_id = p.product_id
WHERE p.product_id IS NULL;


-- Invoices without an existing sale
SELECT COUNT(*) AS orphan_invoices_sales
FROM invoices i
LEFT JOIN sales s
    ON i.sale_id = s.sale_id
WHERE s.sale_id IS NULL;


-- Purchase orders without an existing supplier
SELECT COUNT(*) AS orphan_purchase_orders_suppliers
FROM purchase_orders po
LEFT JOIN suppliers s
    ON po.supplier_id = s.supplier_id
WHERE s.supplier_id IS NULL;


-- Purchase items without an existing purchase order
SELECT COUNT(*) AS orphan_purchase_items_orders
FROM purchase_items pi
LEFT JOIN purchase_orders po
    ON pi.purchase_id = po.purchase_id
WHERE po.purchase_id IS NULL;


-- Purchase items without an existing product
SELECT COUNT(*) AS orphan_purchase_items_products
FROM purchase_items pi
LEFT JOIN products p
    ON pi.product_id = p.product_id
WHERE p.product_id IS NULL;


-- Inventory movements without an existing product
SELECT COUNT(*) AS orphan_inventory_products
FROM inventory_movements im
LEFT JOIN products p
    ON im.product_id = p.product_id
WHERE p.product_id IS NULL;


-- Opportunities without an existing customer
SELECT COUNT(*) AS orphan_opportunities_customers
FROM opportunities o
LEFT JOIN customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


-- CRM activities without an existing opportunity
SELECT COUNT(*) AS orphan_activities_opportunities
FROM crm_activities ca
LEFT JOIN opportunities o
    ON ca.opportunity_id = o.opportunity_id
WHERE o.opportunity_id IS NULL;


-- CRM activities without an existing employee
SELECT COUNT(*) AS orphan_activities_employees
FROM crm_activities ca
LEFT JOIN employees e
    ON ca.employee_id = e.employee_id
WHERE e.employee_id IS NULL;

-- ============================================================
-- 6. NULL CHECK
-- ============================================================

SELECT
    'customers' AS table_name,
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS customer_id_nulls,
    COUNT(*) FILTER (WHERE company_name IS NULL) AS company_name_nulls,
    COUNT(*) FILTER (WHERE signup_date IS NULL) AS signup_date_nulls,
    COUNT(*) FILTER (WHERE sales_rep_id IS NULL) AS sales_rep_id_nulls
FROM customers;


SELECT
    'products' AS table_name,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS product_id_nulls,
    COUNT(*) FILTER (WHERE sku IS NULL) AS sku_nulls,
    COUNT(*) FILTER (WHERE product_name IS NULL) AS product_name_nulls,
    COUNT(*) FILTER (WHERE category_id IS NULL) AS category_id_nulls,
    COUNT(*) FILTER (WHERE supplier_id IS NULL) AS supplier_id_nulls,
    COUNT(*) FILTER (WHERE cost_price IS NULL) AS cost_price_nulls,
    COUNT(*) FILTER (WHERE list_price IS NULL) AS list_price_nulls
FROM products;


SELECT
    'sales' AS table_name,
    COUNT(*) FILTER (WHERE sale_id IS NULL) AS sale_id_nulls,
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS customer_id_nulls,
    COUNT(*) FILTER (WHERE employee_id IS NULL) AS employee_id_nulls,
    COUNT(*) FILTER (WHERE sale_date IS NULL) AS sale_date_nulls,
    COUNT(*) FILTER (WHERE channel IS NULL) AS channel_nulls,
    COUNT(*) FILTER (WHERE status IS NULL) AS status_nulls
FROM sales;


SELECT
    'sale_items' AS table_name,
    COUNT(*) FILTER (WHERE sale_item_id IS NULL) AS sale_item_id_nulls,
    COUNT(*) FILTER (WHERE sale_id IS NULL) AS sale_id_nulls,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS product_id_nulls,
    COUNT(*) FILTER (WHERE quantity IS NULL) AS quantity_nulls,
    COUNT(*) FILTER (WHERE unit_price IS NULL) AS unit_price_nulls,
    COUNT(*) FILTER (WHERE discount IS NULL) AS discount_nulls,
    COUNT(*) FILTER (WHERE unit_cost IS NULL) AS unit_cost_nulls
FROM sale_items;


SELECT
    'invoices' AS table_name,
    COUNT(*) FILTER (WHERE invoice_id IS NULL) AS invoice_id_nulls,
    COUNT(*) FILTER (WHERE sale_id IS NULL) AS sale_id_nulls,
    COUNT(*) FILTER (WHERE invoice_date IS NULL) AS invoice_date_nulls,
    COUNT(*) FILTER (WHERE due_date IS NULL) AS due_date_nulls,
    COUNT(*) FILTER (WHERE status IS NULL) AS status_nulls,
    COUNT(*) FILTER (WHERE total_amount IS NULL) AS total_amount_nulls
FROM invoices;


SELECT
    'leads' AS table_name,
    COUNT(*) FILTER (WHERE lead_id IS NULL) AS lead_id_nulls,
    COUNT(*) FILTER (WHERE company_name IS NULL) AS company_name_nulls,
    COUNT(*) FILTER (WHERE created_date IS NULL) AS created_date_nulls,
    COUNT(*) FILTER (WHERE source IS NULL) AS source_nulls,
    COUNT(*) FILTER (WHERE status IS NULL) AS status_nulls,
    COUNT(*) FILTER (WHERE sales_rep_id IS NULL) AS sales_rep_id_nulls
FROM leads;


SELECT
    'opportunities' AS table_name,
    COUNT(*) FILTER (WHERE opportunity_id IS NULL) AS opportunity_id_nulls,
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS customer_id_nulls,
    COUNT(*) FILTER (WHERE sales_rep_id IS NULL) AS sales_rep_id_nulls,
    COUNT(*) FILTER (WHERE created_date IS NULL) AS created_date_nulls,
    COUNT(*) FILTER (WHERE expected_close_date IS NULL) AS expected_close_date_nulls,
    COUNT(*) FILTER (WHERE stage IS NULL) AS stage_nulls,
    COUNT(*) FILTER (WHERE estimated_value IS NULL) AS estimated_value_nulls,
    COUNT(*) FILTER (WHERE probability IS NULL) AS probability_nulls,
    COUNT(*) FILTER (WHERE closed_date IS NULL) AS closed_date_nulls,
    COUNT(*) FILTER (WHERE result IS NULL) AS result_nulls
FROM opportunities;


SELECT
    'inventory_movements' AS table_name,
    COUNT(*) FILTER (WHERE movement_id IS NULL) AS movement_id_nulls,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS product_id_nulls,
    COUNT(*) FILTER (WHERE movement_date IS NULL) AS movement_date_nulls,
    COUNT(*) FILTER (WHERE movement_type IS NULL) AS movement_type_nulls,
    COUNT(*) FILTER (WHERE quantity IS NULL) AS quantity_nulls,
    COUNT(*) FILTER (WHERE unit_cost IS NULL) AS unit_cost_nulls
FROM inventory_movements;

-- ============================================================
-- 7. BUSINESS RULES / DATA CONSISTENCY
-- ============================================================


-- 7.1 Duplicate customer names
SELECT
    company_name,
    COUNT(*) AS occurrences
FROM customers
GROUP BY company_name
HAVING COUNT(*) > 1
ORDER BY occurrences DESC, company_name;


-- 7.2 Duplicate product SKUs
SELECT
    sku,
    COUNT(*) AS occurrences
FROM products
GROUP BY sku
HAVING COUNT(*) > 1
ORDER BY occurrences DESC, sku;


-- 7.3 Sales without sale items
SELECT COUNT(*) AS sales_without_items
FROM sales s
LEFT JOIN sale_items si
    ON s.sale_id = si.sale_id
WHERE si.sale_id IS NULL;


-- 7.4 Confirmed sales without invoices
SELECT COUNT(*) AS confirmed_sales_without_invoice
FROM sales s
LEFT JOIN invoices i
    ON s.sale_id = i.sale_id
WHERE s.status = 'CONFIRMED'
    AND i.invoice_id IS NULL;


-- 7.5 Invoices whose total does not match the sale
SELECT COUNT(*) AS invoice_total_mismatches
FROM invoices i
JOIN (
    SELECT
        si.sale_id,
        ROUND(
            SUM(
                si.quantity
                * si.unit_price
                * (1 - si.discount)
            ),
            2
        ) AS calculated_total
    FROM sale_items si
    GROUP BY si.sale_id
) calculated
    ON i.sale_id = calculated.sale_id
WHERE ABS(i.total_amount - calculated.calculated_total) > 0.01;


-- 7.6 Sales before customer signup date
SELECT COUNT(*) AS sales_before_customer_signup
FROM sales s
JOIN customers c
    ON s.customer_id = c.customer_id
WHERE s.sale_date < c.signup_date;


-- 7.7 Sales before employee hire date
SELECT COUNT(*) AS sales_before_employee_hire
FROM sales s
JOIN employees e
    ON s.employee_id = e.employee_id
WHERE s.sale_date < e.hire_date;


-- 7.8 Negative current stock
SELECT COUNT(*) AS products_with_negative_stock
FROM (
    SELECT
        p.product_id,
        COALESCE(SUM(im.quantity), 0) AS current_stock
    FROM products p
    LEFT JOIN inventory_movements im
        ON p.product_id = im.product_id
    GROUP BY p.product_id
) stock
WHERE current_stock < 0;

-- ============================================================
-- 8. BUSINESS HEALTH CHECK
-- 8.1 Revenue and gross margin by year
-- ============================================================

SELECT
    EXTRACT(YEAR FROM s.sale_date)::int AS year,
    ROUND(
        SUM(
            si.quantity
            * si.unit_price
            * (1 - si.discount)
        ),
        2
    ) AS revenue,
    ROUND(
        SUM(
            si.quantity
            * si.unit_price
            * (1 - si.discount)
            - si.quantity * si.unit_cost
        ),
        2
    ) AS gross_profit,
    ROUND(
        100.0 *
        SUM(
            si.quantity
            * si.unit_price
            * (1 - si.discount)
            - si.quantity * si.unit_cost
        )
        /
        NULLIF(
            SUM(
                si.quantity
                * si.unit_price
                * (1 - si.discount)
            ),
            0
        ),
        2
    ) AS gross_margin_pct
FROM sales s
JOIN sale_items si
    ON s.sale_id = si.sale_id
WHERE s.status = 'CONFIRMED'
GROUP BY EXTRACT(YEAR FROM s.sale_date)
ORDER BY year;
