-- COMPLEX SOLUTIONS S.L. | PostgreSQL base schema
-- This file intentionally contains structure only: no sample or historical data.

BEGIN;

CREATE TABLE employees (
    employee_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL CHECK (btrim(name) <> ''),
    department TEXT NOT NULL CHECK (department IN ('SALES', 'OPERATIONS', 'PURCHASING', 'WAREHOUSE', 'FINANCE', 'MANAGEMENT')),
    role TEXT NOT NULL CHECK (btrim(role) <> ''),
    hire_date DATE NOT NULL
);

CREATE TABLE suppliers (
    supplier_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    supplier_name TEXT NOT NULL UNIQUE CHECK (btrim(supplier_name) <> '')
);

CREATE TABLE categories (
    category_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_name TEXT NOT NULL UNIQUE CHECK (btrim(category_name) <> '')
);

CREATE TABLE customers (
    customer_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_type TEXT NOT NULL CHECK (customer_type IN ('B2B', 'B2C')),
    company_name TEXT NOT NULL CHECK (btrim(company_name) <> ''),
    customer_segment TEXT NOT NULL CHECK (customer_segment IN ('ENTERPRISE', 'SMB', 'CONSUMER', 'PUBLIC_SECTOR')),
    city TEXT NOT NULL CHECK (btrim(city) <> ''),
    province TEXT NOT NULL CHECK (btrim(province) <> ''),
    signup_date DATE NOT NULL,
    acquisition_channel TEXT NOT NULL CHECK (acquisition_channel IN ('ONLINE', 'PHYSICAL_STORE', 'REFERRAL', 'OUTBOUND_SALES', 'PARTNER', 'EVENT')),
    sales_rep_id BIGINT REFERENCES employees(employee_id) ON DELETE RESTRICT
);

CREATE TABLE products (
    product_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku TEXT NOT NULL UNIQUE CHECK (btrim(sku) <> ''),
    product_name TEXT NOT NULL CHECK (btrim(product_name) <> ''),
    category_id BIGINT NOT NULL REFERENCES categories(category_id) ON DELETE RESTRICT,
    brand TEXT NOT NULL CHECK (btrim(brand) <> ''),
    supplier_id BIGINT NOT NULL REFERENCES suppliers(supplier_id) ON DELETE RESTRICT,
    cost_price NUMERIC(12,2) NOT NULL CHECK (cost_price >= 0),
    list_price NUMERIC(12,2) NOT NULL CHECK (list_price > 0)
);

CREATE TABLE sales (
    sale_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id BIGINT NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    employee_id BIGINT NOT NULL REFERENCES employees(employee_id) ON DELETE RESTRICT,
    sale_date DATE NOT NULL,
    channel TEXT NOT NULL CHECK (channel IN ('PHYSICAL_STORE', 'ONLINE', 'B2B')),
    status TEXT NOT NULL CHECK (status IN ('DRAFT', 'CONFIRMED', 'CANCELLED', 'RETURNED'))
);

CREATE TABLE sale_items (
    sale_item_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sale_id BIGINT NOT NULL REFERENCES sales(sale_id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price > 0),
    discount NUMERIC(5,4) NOT NULL DEFAULT 0 CHECK (discount >= 0 AND discount < 1),
    unit_cost NUMERIC(12,2) NOT NULL CHECK (unit_cost >= 0)
);

CREATE TABLE purchase_orders (
    purchase_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    supplier_id BIGINT NOT NULL REFERENCES suppliers(supplier_id) ON DELETE RESTRICT,
    purchase_date DATE NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('DRAFT', 'ORDERED', 'RECEIVED', 'CANCELLED'))
);

CREATE TABLE purchase_items (
    purchase_item_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    purchase_id BIGINT NOT NULL REFERENCES purchase_orders(purchase_id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_cost NUMERIC(12,2) NOT NULL CHECK (unit_cost >= 0)
);

CREATE TABLE inventory_movements (
    movement_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id BIGINT NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT,
    movement_date DATE NOT NULL,
    movement_type TEXT NOT NULL CHECK (movement_type IN ('PURCHASE', 'SALE', 'RETURN', 'ADJUSTMENT')),
    -- Signed quantity makes current stock the simple sum of movements.
    quantity INTEGER NOT NULL CHECK (
        quantity <> 0
        AND (movement_type = 'PURCHASE' AND quantity > 0
             OR movement_type = 'SALE' AND quantity < 0
             OR movement_type = 'RETURN' AND quantity > 0
             OR movement_type = 'ADJUSTMENT')
    ),
    unit_cost NUMERIC(12,2) NOT NULL CHECK (unit_cost >= 0)
);

CREATE TABLE leads (
    lead_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    company_name TEXT NOT NULL CHECK (btrim(company_name) <> ''),
    created_date DATE NOT NULL,
    source TEXT NOT NULL CHECK (source IN ('WEB', 'REFERRAL', 'EVENT', 'OUTBOUND', 'PARTNER', 'PHONE')),
    industry TEXT NOT NULL CHECK (btrim(industry) <> ''),
    sales_rep_id BIGINT REFERENCES employees(employee_id) ON DELETE RESTRICT,
    status TEXT NOT NULL CHECK (status IN ('NEW', 'CONTACTED', 'QUALIFIED', 'DISQUALIFIED', 'CONVERTED'))
);

CREATE TABLE opportunities (
    opportunity_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lead_id BIGINT REFERENCES leads(lead_id) ON DELETE SET NULL,
    customer_id BIGINT NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    sales_rep_id BIGINT NOT NULL REFERENCES employees(employee_id) ON DELETE RESTRICT,
    created_date DATE NOT NULL,
    expected_close_date DATE NOT NULL CHECK (expected_close_date >= created_date),
    stage TEXT NOT NULL CHECK (stage IN ('PROSPECTING', 'QUALIFICATION', 'PROPOSAL', 'NEGOTIATION', 'CLOSED_WON', 'CLOSED_LOST')),
    estimated_value NUMERIC(14,2) NOT NULL CHECK (estimated_value > 0),
    probability NUMERIC(4,3) NOT NULL CHECK (probability >= 0 AND probability <= 1),
    closed_date DATE,
    result TEXT CHECK (result IN ('WON', 'LOST')),
    CHECK (closed_date IS NULL OR closed_date >= created_date),
    CHECK ((result IS NULL AND closed_date IS NULL) OR (result IS NOT NULL AND closed_date IS NOT NULL)),
    CHECK ((stage IN ('CLOSED_WON', 'CLOSED_LOST')) = (result IS NOT NULL)),
    CHECK ((stage <> 'CLOSED_WON' OR result = 'WON') AND (stage <> 'CLOSED_LOST' OR result = 'LOST'))
);

CREATE TABLE crm_activities (
    activity_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    opportunity_id BIGINT NOT NULL REFERENCES opportunities(opportunity_id) ON DELETE CASCADE,
    employee_id BIGINT NOT NULL REFERENCES employees(employee_id) ON DELETE RESTRICT,
    activity_type TEXT NOT NULL CHECK (activity_type IN ('CALL', 'EMAIL', 'MEETING', 'DEMO', 'PROPOSAL', 'NOTE')),
    activity_date DATE NOT NULL
);

CREATE TABLE invoices (
    invoice_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sale_id BIGINT NOT NULL REFERENCES sales(sale_id) ON DELETE RESTRICT,
    invoice_date DATE NOT NULL,
    due_date DATE NOT NULL CHECK (due_date >= invoice_date),
    status TEXT NOT NULL CHECK (status IN ('DRAFT', 'SENT', 'PAID', 'OVERDUE', 'CANCELLED')),
    total_amount NUMERIC(14,2) NOT NULL CHECK (total_amount >= 0)
);

-- Foreign-key indexes and date indexes for the intended analytical workloads.
CREATE INDEX idx_customers_sales_rep_id ON customers (sales_rep_id);
CREATE INDEX idx_customers_signup_date ON customers (signup_date);
CREATE INDEX idx_products_category_id ON products (category_id);
CREATE INDEX idx_products_supplier_id ON products (supplier_id);
CREATE INDEX idx_sales_customer_id ON sales (customer_id);
CREATE INDEX idx_sales_employee_id ON sales (employee_id);
CREATE INDEX idx_sales_sale_date ON sales (sale_date);
CREATE INDEX idx_sales_channel_date ON sales (channel, sale_date);
CREATE INDEX idx_sale_items_sale_id ON sale_items (sale_id);
CREATE INDEX idx_sale_items_product_id ON sale_items (product_id);
CREATE INDEX idx_purchase_orders_supplier_id ON purchase_orders (supplier_id);
CREATE INDEX idx_purchase_orders_purchase_date ON purchase_orders (purchase_date);
CREATE INDEX idx_purchase_items_purchase_id ON purchase_items (purchase_id);
CREATE INDEX idx_purchase_items_product_id ON purchase_items (product_id);
CREATE INDEX idx_inventory_movements_product_date ON inventory_movements (product_id, movement_date);
CREATE INDEX idx_inventory_movements_movement_date ON inventory_movements (movement_date);
CREATE INDEX idx_leads_sales_rep_id ON leads (sales_rep_id);
CREATE INDEX idx_leads_created_date ON leads (created_date);
CREATE INDEX idx_opportunities_customer_id ON opportunities (customer_id);
CREATE INDEX idx_opportunities_lead_id ON opportunities (lead_id);
CREATE INDEX idx_opportunities_sales_rep_id ON opportunities (sales_rep_id);
CREATE INDEX idx_opportunities_created_date ON opportunities (created_date);
CREATE INDEX idx_opportunities_expected_close_date ON opportunities (expected_close_date);
CREATE INDEX idx_opportunities_stage ON opportunities (stage);
CREATE INDEX idx_crm_activities_opportunity_id ON crm_activities (opportunity_id);
CREATE INDEX idx_crm_activities_employee_id ON crm_activities (employee_id);
CREATE INDEX idx_crm_activities_activity_date ON crm_activities (activity_date);
CREATE INDEX idx_invoices_sale_id ON invoices (sale_id);
CREATE INDEX idx_invoices_invoice_date ON invoices (invoice_date);
CREATE INDEX idx_invoices_due_date ON invoices (due_date);

COMMIT;
