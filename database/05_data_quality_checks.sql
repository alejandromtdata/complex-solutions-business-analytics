
-- ============================================================
-- 39. OPEN OPPORTUNITIES BY ACTIVITY RECENCY
-- ============================================================

SELECT
    activity_recency,
    COUNT(*) AS opportunities,
    ROUND(SUM(estimated_value), 2) AS nominal_pipeline,
    ROUND(SUM(estimated_value * probability), 2) AS weighted_pipeline
FROM (
    SELECT
        o.opportunity_id,
        o.estimated_value,
        o.probability,
        CASE
            WHEN MAX(a.activity_date) IS NULL THEN 'NO ACTIVITY'
            WHEN CURRENT_DATE - MAX(a.activity_date) <= 30 THEN '0-30 DAYS'
            WHEN CURRENT_DATE - MAX(a.activity_date) <= 60 THEN '31-60 DAYS'
            WHEN CURRENT_DATE - MAX(a.activity_date) <= 90 THEN '61-90 DAYS'
            WHEN CURRENT_DATE - MAX(a.activity_date) <= 180 THEN '91-180 DAYS'
            ELSE '180+ DAYS'
        END AS activity_recency
    FROM opportunities o
    LEFT JOIN crm_activities a
        ON o.opportunity_id = a.opportunity_id
    WHERE o.stage NOT IN ('CLOSED_WON', 'CLOSED_LOST')
    GROUP BY
        o.opportunity_id,
        o.estimated_value,
        o.probability
) AS opportunity_activity
GROUP BY activity_recency
ORDER BY
    CASE activity_recency
        WHEN '0-30 DAYS' THEN 1
        WHEN '31-60 DAYS' THEN 2
        WHEN '61-90 DAYS' THEN 3
        WHEN '91-180 DAYS' THEN 4
        WHEN '180+ DAYS' THEN 5
        WHEN 'NO ACTIVITY' THEN 6
    END;

-- ============================================================
-- 40. FUTURE CRM ACTIVITIES
-- ============================================================

SELECT
    activity_id,
    opportunity_id,
    employee_id,
    activity_type,
    activity_date
FROM crm_activities
WHERE activity_date > CURRENT_DATE
ORDER BY activity_date;

-- ============================================================
-- 41. FUTURE SALES AND PURCHASES
-- ============================================================

SELECT
    'SALE' AS record_type,
    sale_id AS record_id,
    sale_date AS record_date
FROM sales
WHERE sale_date > CURRENT_DATE

UNION ALL

SELECT
    'PURCHASE' AS record_type,
    purchase_id AS record_id,
    purchase_date AS record_date
FROM purchase_orders
WHERE purchase_date > CURRENT_DATE

ORDER BY record_date;

-- ============================================================
-- 42. INVOICE DATE CONSISTENCY
-- ============================================================

SELECT
    i.invoice_id,
    i.sale_id,
    s.sale_date,
    i.invoice_date,
    i.due_date
FROM invoices i
JOIN sales s
    ON i.sale_id = s.sale_id
WHERE i.invoice_date < s.sale_date
    OR i.due_date < i.invoice_date
ORDER BY i.invoice_id;

-- ============================================================
-- 43. SALES AND INVENTORY CONSISTENCY
-- ============================================================

SELECT
    s.sale_id,
    COUNT(DISTINCT si.sale_item_id) AS sale_items,
    COUNT(
        DISTINCT CASE
            WHEN im.movement_type = 'SALE' THEN im.movement_id
        END
    ) AS inventory_sale_movements
FROM sales s
JOIN sale_items si
    ON s.sale_id = si.sale_id
LEFT JOIN inventory_movements im
    ON im.product_id = si.product_id
    AND im.movement_type = 'SALE'
    AND im.movement_date = s.sale_date
WHERE s.status = 'CONFIRMED'
GROUP BY s.sale_id
HAVING COUNT(DISTINCT si.sale_item_id)
    <> COUNT(
        DISTINCT CASE
            WHEN im.movement_type = 'SALE' THEN im.movement_id
        END
    )
ORDER BY s.sale_id;

-- ============================================================
-- 44. PURCHASE AND INVENTORY CONSISTENCY
-- ============================================================

SELECT
    po.purchase_id,
    COUNT(DISTINCT pi.purchase_item_id) AS purchase_items,
    COUNT(
        DISTINCT CASE
            WHEN im.movement_type = 'PURCHASE' THEN im.movement_id
        END
    ) AS inventory_purchase_movements
FROM purchase_orders po
JOIN purchase_items pi
    ON po.purchase_id = pi.purchase_id
LEFT JOIN inventory_movements im
    ON im.product_id = pi.product_id
    AND im.movement_type = 'PURCHASE'
    AND im.movement_date = po.purchase_date
WHERE po.status = 'RECEIVED'
GROUP BY po.purchase_id
HAVING COUNT(DISTINCT pi.purchase_item_id)
    <> COUNT(
        DISTINCT CASE
            WHEN im.movement_type = 'PURCHASE' THEN im.movement_id
        END
    )
ORDER BY po.purchase_id;

-- ============================================================
-- 45. FINAL DATA QUALITY SUMMARY
-- ============================================================

SELECT
    'Negative stock' AS check_name,
    COUNT(*) AS issue_count
FROM (
    SELECT
        product_id
    FROM inventory_movements
    GROUP BY product_id
    HAVING SUM(quantity) < 0
) AS negative_stock

UNION ALL

SELECT
    'Confirmed sales without invoice' AS check_name,
    COUNT(*) AS issue_count
FROM sales s
LEFT JOIN invoices i
    ON s.sale_id = i.sale_id
WHERE s.status = 'CONFIRMED'
    AND i.invoice_id IS NULL

UNION ALL

SELECT
    'Invoice before sale' AS check_name,
    COUNT(*) AS issue_count
FROM invoices i
JOIN sales s
    ON i.sale_id = s.sale_id
WHERE i.invoice_date < s.sale_date

UNION ALL

SELECT
    'Future sales' AS check_name,
    COUNT(*) AS issue_count
FROM sales
WHERE sale_date > CURRENT_DATE

UNION ALL

SELECT
    'Future purchases' AS check_name,
    COUNT(*) AS issue_count
FROM purchase_orders
WHERE purchase_date > CURRENT_DATE

UNION ALL

SELECT
    'Future CRM activities' AS check_name,
    COUNT(*) AS issue_count
FROM crm_activities
WHERE activity_date > CURRENT_DATE

ORDER BY check_name;

