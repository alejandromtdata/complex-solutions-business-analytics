-- ============================================================
-- 9. PROFITABILITY ANALYSIS
-- 9.1 Revenue and gross margin by category
-- ============================================================

SELECT
    c.category_name,
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
    ) AS gross_margin_pct,
    ROUND(
        100.0 *
        SUM(
            si.quantity
            * si.unit_price
            * (1 - si.discount)
        )
        /
        SUM(
            SUM(
                si.quantity
                * si.unit_price
                * (1 - si.discount)
            )
        ) OVER (),
        2
    ) AS revenue_share_pct
FROM sales s
JOIN sale_items si
    ON s.sale_id = si.sale_id
JOIN products p
    ON si.product_id = p.product_id
JOIN categories c
    ON p.category_id = c.category_id
WHERE s.status = 'CONFIRMED'
GROUP BY c.category_name
ORDER BY revenue DESC;

-- ============================================================
-- 10. PROFITABILITY TREND BY CATEGORY
-- ============================================================

SELECT
    EXTRACT(YEAR FROM s.sale_date) AS year,
    c.category_name,

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

JOIN products p
    ON si.product_id = p.product_id

JOIN categories c
    ON p.category_id = c.category_id

WHERE s.status = 'CONFIRMED'

GROUP BY
    EXTRACT(YEAR FROM s.sale_date),
    c.category_name

ORDER BY
    year,
    gross_margin_pct;


-- ============================================================
-- 11. PRICE, COST AND DISCOUNT EVOLUTION BY CATEGORY
-- ============================================================

SELECT
    EXTRACT(YEAR FROM s.sale_date) AS year,
    c.category_name,

    ROUND(
        AVG(si.unit_cost),
        2
    ) AS avg_unit_cost,

    ROUND(
        AVG(si.unit_price),
        2
    ) AS avg_unit_price,

    ROUND(
        AVG(si.discount) * 100,
        2
    ) AS avg_discount_pct,

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

JOIN products p
    ON si.product_id = p.product_id

JOIN categories c
    ON p.category_id = c.category_id

WHERE s.status = 'CONFIRMED'

GROUP BY
    EXTRACT(YEAR FROM s.sale_date),
    c.category_name

ORDER BY
    year,
    c.category_name;

-- ============================================================
-- 12. DISCOUNT EVOLUTION BY CATEGORY
-- ============================================================

SELECT
    EXTRACT(YEAR FROM s.sale_date) AS year,
    c.category_name,

    ROUND(
        AVG(si.discount) * 100,
        2
    ) AS avg_discount_pct,

    ROUND(
        SUM(
            si.quantity * si.unit_price * si.discount
        ),
        2
    ) AS discount_amount,

    ROUND(
        SUM(
            si.quantity * si.unit_price
        ),
        2
    ) AS gross_sales_before_discount,

    ROUND(
        SUM(
            si.quantity * si.unit_price * (1 - si.discount)
        ),
        2
    ) AS revenue_after_discount

FROM sales s

JOIN sale_items si
    ON s.sale_id = si.sale_id

JOIN products p
    ON si.product_id = p.product_id

JOIN categories c
    ON p.category_id = c.category_id

WHERE s.status = 'CONFIRMED'

GROUP BY
    EXTRACT(YEAR FROM s.sale_date),
    c.category_name

ORDER BY
    year,
    c.category_name;

-- ============================================================
-- 13. CUSTOMER VALUE
-- ============================================================

SELECT
    c.customer_id,
    c.company_name,
    c.customer_type,
    c.customer_segment,
    COUNT(DISTINCT s.sale_id) AS total_orders,
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
    MAX(s.sale_date) AS last_purchase_date
FROM customers c
JOIN sales s
    ON c.customer_id = s.customer_id
JOIN sale_items si
    ON s.sale_id = si.sale_id
WHERE s.status = 'CONFIRMED'
GROUP BY
    c.customer_id,
    c.company_name,
    c.customer_type,
    c.customer_segment
ORDER BY revenue DESC;

-- ============================================================
-- 14. CUSTOMER RECENCY
-- ============================================================

SELECT
    c.customer_id,
    c.company_name,
    c.customer_type,
    c.customer_segment,
    MAX(s.sale_date) AS last_purchase_date,
    CURRENT_DATE - MAX(s.sale_date) AS days_since_last_purchase,
    COUNT(DISTINCT s.sale_id) AS total_orders,
    ROUND(
        SUM(
            si.quantity
            * si.unit_price
            * (1 - si.discount)
        ),
        2
    ) AS revenue
FROM customers c
JOIN sales s
    ON c.customer_id = s.customer_id
JOIN sale_items si
    ON s.sale_id = si.sale_id
WHERE s.status = 'CONFIRMED'
GROUP BY
    c.customer_id,
    c.company_name,
    c.customer_type,
    c.customer_segment
ORDER BY days_since_last_purchase DESC;

-- ============================================================
-- 15. CUSTOMER REVENUE CONCENTRATION
-- ============================================================

WITH customer_revenue AS (
    SELECT
        c.customer_id,
        c.company_name,
        SUM(
            si.quantity
            * si.unit_price
            * (1 - si.discount)
        ) AS revenue
    FROM customers c
    JOIN sales s
        ON c.customer_id = s.customer_id
    JOIN sale_items si
        ON s.sale_id = si.sale_id
    WHERE s.status = 'CONFIRMED'
    GROUP BY
        c.customer_id,
        c.company_name
),
ranked_customers AS (
    SELECT
        customer_id,
        company_name,
        ROUND(revenue, 2) AS revenue,
        RANK() OVER (ORDER BY revenue DESC) AS revenue_rank,
        ROUND(
            100.0 * revenue / SUM(revenue) OVER (),
            2
        ) AS revenue_share_pct
    FROM customer_revenue
)
SELECT
    customer_id,
    company_name,
    revenue,
    revenue_rank,
    revenue_share_pct
FROM ranked_customers
ORDER BY revenue_rank;

-- ============================================================
-- 16. TOP 10 CUSTOMER REVENUE CONCENTRATION
-- ============================================================

WITH customer_revenue AS (
    SELECT
        c.customer_id,
        c.company_name,
        SUM(
            si.quantity
            * si.unit_price
            * (1 - si.discount)
        ) AS revenue
    FROM customers c
    JOIN sales s
        ON c.customer_id = s.customer_id
    JOIN sale_items si
        ON s.sale_id = si.sale_id
    WHERE s.status = 'CONFIRMED'
    GROUP BY
        c.customer_id,
        c.company_name
),
ranked AS (
    SELECT
        *,
        RANK() OVER (ORDER BY revenue DESC) AS revenue_rank
    FROM customer_revenue
)
SELECT
    COUNT(*) AS top_10_customers,
    ROUND(SUM(revenue), 2) AS top_10_revenue,
    ROUND(
        100.0 * SUM(revenue)
        / (SELECT SUM(revenue) FROM customer_revenue),
        2
    ) AS top_10_revenue_share_pct
FROM ranked
WHERE revenue_rank <= 10;

-- ============================================================
-- 17. CURRENT STOCK BY PRODUCT
-- ============================================================

SELECT
    p.product_id,
    p.sku,
    p.product_name,
    c.category_name,
    p.cost_price,
    p.list_price,
    COALESCE(SUM(im.quantity), 0) AS current_stock
FROM products p
JOIN categories c
    ON p.category_id = c.category_id
LEFT JOIN inventory_movements im
    ON p.product_id = im.product_id
GROUP BY
    p.product_id,
    p.sku,
    p.product_name,
    c.category_name,
    p.cost_price,
    p.list_price
ORDER BY current_stock DESC;

-- ============================================================
-- 18. CURRENT INVENTORY VALUE
-- ============================================================

WITH stock AS (
    SELECT
        p.product_id,
        p.product_name,
        c.category_name,
        p.cost_price,
        COALESCE(SUM(im.quantity), 0) AS current_stock
    FROM products p
    JOIN categories c
        ON p.category_id = c.category_id
    LEFT JOIN inventory_movements im
        ON p.product_id = im.product_id
    GROUP BY
        p.product_id,
        p.product_name,
        c.category_name,
        p.cost_price
)
SELECT
    product_id,
    product_name,
    category_name,
    current_stock,
    cost_price,
    ROUND(current_stock * cost_price, 2) AS inventory_value
FROM stock
ORDER BY inventory_value DESC;

-- ============================================================
-- 19. LOW ROTATION PRODUCTS
-- ============================================================

WITH stock AS (
    SELECT
        p.product_id,
        COALESCE(SUM(im.quantity), 0) AS current_stock
    FROM products p
    LEFT JOIN inventory_movements im
        ON p.product_id = im.product_id
    GROUP BY p.product_id
),
sales_last_year AS (
    SELECT
        si.product_id,
        SUM(si.quantity) AS units_sold
    FROM sales s
    JOIN sale_items si
        ON s.sale_id = si.sale_id
    WHERE
        s.status = 'CONFIRMED'
        AND s.sale_date >= CURRENT_DATE - INTERVAL '365 days'
    GROUP BY si.product_id
)
SELECT
    p.product_id,
    p.product_name,
    c.category_name,
    stock.current_stock,
    COALESCE(sales_last_year.units_sold, 0) AS units_sold_last_year,
    ROUND(
        stock.current_stock
        * p.cost_price,
        2
    ) AS inventory_value
FROM products p
JOIN categories c
    ON p.category_id = c.category_id
JOIN stock
    ON p.product_id = stock.product_id
LEFT JOIN sales_last_year
    ON p.product_id = sales_last_year.product_id
WHERE stock.current_stock > 0
ORDER BY
    units_sold_last_year ASC,
    inventory_value DESC;

-- ============================================================
-- 20. STOCK COVERAGE
-- ============================================================

WITH stock AS (
    SELECT
        p.product_id,
        COALESCE(SUM(im.quantity), 0) AS current_stock
    FROM products p
    LEFT JOIN inventory_movements im
        ON p.product_id = im.product_id
    GROUP BY p.product_id
),
sales_last_year AS (
    SELECT
        si.product_id,
        SUM(si.quantity) AS units_sold
    FROM sales s
    JOIN sale_items si
        ON s.sale_id = si.sale_id
    WHERE
        s.status = 'CONFIRMED'
        AND s.sale_date >= CURRENT_DATE - INTERVAL '365 days'
    GROUP BY si.product_id
)
SELECT
    p.product_id,
    p.product_name,
    c.category_name,
    stock.current_stock,
    COALESCE(sales_last_year.units_sold, 0) AS units_sold_last_year,
    ROUND(
        COALESCE(sales_last_year.units_sold, 0) / 12.0,
        2
    ) AS avg_monthly_units,
    CASE
        WHEN COALESCE(sales_last_year.units_sold, 0) = 0
            THEN NULL
        ELSE ROUND(
            stock.current_stock
            /
            (sales_last_year.units_sold / 12.0),
            2
        )
    END AS months_of_stock
FROM products p
JOIN categories c
    ON p.category_id = c.category_id
JOIN stock
    ON p.product_id = stock.product_id
LEFT JOIN sales_last_year
    ON p.product_id = sales_last_year.product_id
ORDER BY months_of_stock ASC NULLS LAST;