-- ============================================================
-- 21. INVENTORY MOVEMENTS BY MONTH
-- ============================================================

SELECT
    DATE_TRUNC('month', movement_date)::date AS month,
    movement_type,
    SUM(quantity) AS quantity
FROM inventory_movements
GROUP BY
    DATE_TRUNC('month', movement_date),
    movement_type
ORDER BY
    month,
    movement_type;

-- ============================================================
-- 22. PIPELINE BY STAGE
-- ============================================================

SELECT
    stage,
    COUNT(*) AS opportunities,
    ROUND(SUM(estimated_value), 2) AS pipeline_value,
    ROUND(
        SUM(estimated_value * probability),
        2
    ) AS weighted_pipeline
FROM opportunities
WHERE stage NOT IN ('CLOSED_WON', 'CLOSED_LOST')
GROUP BY stage
ORDER BY
    CASE stage
        WHEN 'PROSPECTING' THEN 1
        WHEN 'QUALIFICATION' THEN 2
        WHEN 'PROPOSAL' THEN 3
        WHEN 'NEGOTIATION' THEN 4
    END;

-- ============================================================
-- 23. PIPELINE BY SALES REP
-- ============================================================

SELECT
    e.employee_id,
    e.name AS sales_rep,
    COUNT(o.opportunity_id) AS open_opportunities,
    ROUND(
        SUM(o.estimated_value),
        2
    ) AS pipeline_value,
    ROUND(
        SUM(
            o.estimated_value * o.probability
        ),
        2
    ) AS weighted_pipeline
FROM opportunities o
JOIN employees e
    ON o.sales_rep_id = e.employee_id
WHERE o.stage NOT IN ('CLOSED_WON', 'CLOSED_LOST')
GROUP BY
    e.employee_id,
    e.name
ORDER BY pipeline_value DESC;

-- ============================================================
-- 24. AGING OPEN OPPORTUNITIES
-- ============================================================

SELECT
    o.opportunity_id,
    c.company_name,
    e.name AS sales_rep,
    o.stage,
    o.created_date,
    CURRENT_DATE - o.created_date AS days_open,
    ROUND(o.estimated_value, 2) AS estimated_value,
    ROUND(
        100.0 * o.probability,
        1
    ) AS probability_pct,
    ROUND(
        o.estimated_value * o.probability,
        2
    ) AS weighted_value
FROM opportunities o
JOIN customers c
    ON o.customer_id = c.customer_id
JOIN employees e
    ON o.sales_rep_id = e.employee_id
WHERE o.stage NOT IN ('CLOSED_WON', 'CLOSED_LOST')
ORDER BY days_open DESC;

-- ============================================================
-- 25. OPPORTUNITIES WITHOUT RECENT ACTIVITY
-- ============================================================

SELECT
    o.opportunity_id,
    c.company_name,
    e.name AS sales_rep,
    o.stage,
    o.created_date,
    CURRENT_DATE - o.created_date AS days_open,
    MAX(a.activity_date) AS last_activity_date,
    CURRENT_DATE - MAX(a.activity_date) AS days_since_activity,
    ROUND(o.estimated_value, 2) AS estimated_value,
    ROUND(
        100.0 * o.probability,
        1
    ) AS probability_pct
FROM opportunities o
JOIN customers c
    ON o.customer_id = c.customer_id
JOIN employees e
    ON o.sales_rep_id = e.employee_id
LEFT JOIN crm_activities a
    ON o.opportunity_id = a.opportunity_id
WHERE o.stage NOT IN ('CLOSED_WON', 'CLOSED_LOST')
GROUP BY
    o.opportunity_id,
    c.company_name,
    e.name,
    o.stage,
    o.created_date,
    o.estimated_value,
    o.probability
ORDER BY
    days_since_activity DESC NULLS FIRST;
