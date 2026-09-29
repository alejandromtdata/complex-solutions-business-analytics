-- ============================================================
-- 26. NOMINAL VS WEIGHTED PIPELINE
-- ============================================================

SELECT
    COUNT(*) AS open_opportunities,
    ROUND(
        SUM(estimated_value),
        2
    ) AS nominal_pipeline,
    ROUND(
        SUM(
            estimated_value * probability
        ),
        2
    ) AS weighted_pipeline,
    ROUND(
        SUM(estimated_value)
        -
        SUM(estimated_value * probability),
        2
    ) AS probability_discount
FROM opportunities
WHERE stage NOT IN ('CLOSED_WON', 'CLOSED_LOST');

-- ============================================================
-- 27. PIPELINE BY STAGE
-- ============================================================

SELECT
    stage,
    COUNT(*) AS opportunities,
    ROUND(SUM(estimated_value), 2) AS nominal_pipeline,
    ROUND(
        SUM(estimated_value * probability),
        2
    ) AS weighted_pipeline,
    ROUND(AVG(probability) * 100, 2) AS avg_probability_pct
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
-- 28. PIPELINE AGE
-- ============================================================

SELECT
    CASE
        WHEN CURRENT_DATE - created_date < 30 THEN '<30 days'
        WHEN CURRENT_DATE - created_date < 60 THEN '30-59 days'
        WHEN CURRENT_DATE - created_date < 90 THEN '60-89 days'
        WHEN CURRENT_DATE - created_date < 180 THEN '90-179 days'
        ELSE '180+ days'
    END AS age_bucket,
    COUNT(*) AS opportunities,
    ROUND(SUM(estimated_value), 2) AS nominal_pipeline,
    ROUND(
        SUM(estimated_value * probability),
        2
    ) AS weighted_pipeline
FROM opportunities
WHERE stage NOT IN ('CLOSED_WON', 'CLOSED_LOST')
GROUP BY
    CASE
        WHEN CURRENT_DATE - created_date < 30 THEN '<30 days'
        WHEN CURRENT_DATE - created_date < 60 THEN '30-59 days'
        WHEN CURRENT_DATE - created_date < 90 THEN '60-89 days'
        WHEN CURRENT_DATE - created_date < 180 THEN '90-179 days'
        ELSE '180+ days'
    END
ORDER BY
    MIN(CURRENT_DATE - created_date);

-- ============================================================
-- 29. STALE OPPORTUNITIES
-- ============================================================

SELECT
    o.opportunity_id,
    o.stage,
    o.created_date,
    o.estimated_value,
    o.probability,
    MAX(a.activity_date) AS last_activity_date,
    CURRENT_DATE - MAX(a.activity_date) AS days_since_activity
FROM opportunities o
LEFT JOIN crm_activities a
    ON o.opportunity_id = a.opportunity_id
WHERE o.stage NOT IN ('CLOSED_WON', 'CLOSED_LOST')
GROUP BY
    o.opportunity_id,
    o.stage,
    o.created_date,
    o.estimated_value,
    o.probability
HAVING
    MAX(a.activity_date) IS NULL
    OR CURRENT_DATE - MAX(a.activity_date) > 60
ORDER BY
    days_since_activity DESC NULLS FIRST;

-- ============================================================
-- 30. STALE PIPELINE VALUE
-- ============================================================

SELECT
    COUNT(*) AS stale_opportunities,
    ROUND(SUM(estimated_value), 2) AS stale_nominal_pipeline,
    ROUND(
        SUM(estimated_value * probability),
        2
    ) AS stale_weighted_pipeline
FROM (
    SELECT
        o.opportunity_id,
        o.estimated_value,
        o.probability,
        MAX(a.activity_date) AS last_activity_date
    FROM opportunities o
    LEFT JOIN crm_activities a
        ON o.opportunity_id = a.opportunity_id
    WHERE o.stage NOT IN ('CLOSED_WON', 'CLOSED_LOST')
    GROUP BY
        o.opportunity_id,
        o.estimated_value,
        o.probability
) AS opportunity_activity
WHERE
    last_activity_date IS NULL
    OR CURRENT_DATE - last_activity_date > 60;

-- ============================================================
-- 31. PIPELINE BY SALES REP
-- ============================================================

SELECT
    e.name AS sales_rep,
    COUNT(o.opportunity_id) AS open_opportunities,
    ROUND(
        SUM(o.estimated_value),
        2
    ) AS nominal_pipeline,
    ROUND(
        SUM(o.estimated_value * o.probability),
        2
    ) AS weighted_pipeline,
    ROUND(
        AVG(o.probability) * 100,
        2
    ) AS avg_probability_pct
FROM opportunities o
JOIN employees e
    ON o.sales_rep_id = e.employee_id
WHERE o.stage NOT IN ('CLOSED_WON', 'CLOSED_LOST')
GROUP BY e.employee_id, e.name
ORDER BY nominal_pipeline DESC;

-- ============================================================
-- 32. OPPORTUNITY CONVERSION
-- ============================================================

SELECT
    result,
    COUNT(*) AS opportunities,
    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (),
        2
    ) AS pct_of_closed_opportunities,
    ROUND(
        SUM(estimated_value),
        2
    ) AS total_estimated_value
FROM opportunities
WHERE stage IN ('CLOSED_WON', 'CLOSED_LOST')
GROUP BY result
ORDER BY opportunities DESC;

-- ============================================================
-- 33. CONVERSION BY SALES REP
-- ============================================================

SELECT
    e.name AS sales_rep,
    COUNT(*) AS closed_opportunities,
    SUM(
        CASE
            WHEN o.result = 'WON' THEN 1
            ELSE 0
        END
    ) AS won_opportunities,
    SUM(
        CASE
            WHEN o.result = 'LOST' THEN 1
            ELSE 0
        END
    ) AS lost_opportunities,
    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN o.result = 'WON' THEN 1
                ELSE 0
            END
        )
        / NULLIF(COUNT(*), 0),
        2
    ) AS conversion_rate_pct
FROM opportunities o
JOIN employees e
    ON o.sales_rep_id = e.employee_id
WHERE o.stage IN ('CLOSED_WON', 'CLOSED_LOST')
GROUP BY e.employee_id, e.name
ORDER BY closed_opportunities DESC;

-- ============================================================
-- 34. LEADS BY STATUS
-- ============================================================

SELECT
    status,
    COUNT(*) AS leads,
    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (),
        2
    ) AS pct_of_leads
FROM leads
GROUP BY status
ORDER BY leads DESC;

-- ============================================================
-- 35. LEAD CONVERSION
-- ============================================================

SELECT
    COUNT(*) AS total_leads,
    SUM(
        CASE
            WHEN status = 'CONVERTED' THEN 1
            ELSE 0
        END
    ) AS converted_leads,
    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN status = 'CONVERTED' THEN 1
                ELSE 0
            END
        )
        / NULLIF(COUNT(*), 0),
        2
    ) AS lead_conversion_rate_pct
FROM leads;

-- ============================================================
-- 36. LEADS BY SOURCE
-- ============================================================

SELECT
    source,
    COUNT(*) AS leads,
    SUM(
        CASE
            WHEN status = 'CONVERTED' THEN 1
            ELSE 0
        END
    ) AS converted_leads,
    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN status = 'CONVERTED' THEN 1
                ELSE 0
            END
        )
        / NULLIF(COUNT(*), 0),
        2
    ) AS conversion_rate_pct
FROM leads
GROUP BY source
ORDER BY leads DESC;

-- ============================================================
-- 37. LEADS BY SALES REP
-- ============================================================

SELECT
    e.name AS sales_rep,
    COUNT(l.lead_id) AS leads,
    SUM(
        CASE
            WHEN l.status = 'CONVERTED' THEN 1
            ELSE 0
        END
    ) AS converted_leads,
    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN l.status = 'CONVERTED' THEN 1
                ELSE 0
            END
        )
        / NULLIF(COUNT(l.lead_id), 0),
        2
    ) AS conversion_rate_pct
FROM leads l
JOIN employees e
    ON l.sales_rep_id = e.employee_id
GROUP BY e.employee_id, e.name
ORDER BY leads DESC;

-- ============================================================
-- 38. CRM ACTIVITY COVERAGE BY OPPORTUNITY
-- ============================================================

SELECT
    o.opportunity_id,
    o.stage,
    o.created_date,
    MAX(a.activity_date) AS last_activity_date,
    COUNT(a.activity_id) AS activity_count,
    CURRENT_DATE - MAX(a.activity_date) AS days_since_last_activity
FROM opportunities o
LEFT JOIN crm_activities a
    ON o.opportunity_id = a.opportunity_id
WHERE o.stage NOT IN ('CLOSED_WON', 'CLOSED_LOST')
GROUP BY
    o.opportunity_id,
    o.stage,
    o.created_date
ORDER BY
    days_since_last_activity DESC NULLS FIRST;

