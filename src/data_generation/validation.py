from __future__ import annotations

from typing import Any
import psycopg


def scalar(cur: psycopg.Cursor, query: str) -> Any:
    cur.execute(query)
    return cur.fetchone()[0]


def validate(conn: psycopg.Connection) -> dict[str, Any]:
    with conn.cursor() as cur:
        checks = {
            "sales_without_items": scalar(cur, "SELECT count(*) FROM sales s WHERE NOT EXISTS (SELECT 1 FROM sale_items i WHERE i.sale_id=s.sale_id)"),
            "confirmed_without_invoice": scalar(cur, "SELECT count(*) FROM sales s WHERE s.status='CONFIRMED' AND NOT EXISTS (SELECT 1 FROM invoices i WHERE i.sale_id=s.sale_id)"),
            "temporal_violations": scalar(cur, "SELECT count(*) FROM sales s JOIN customers c USING(customer_id) JOIN employees e ON e.employee_id=s.employee_id WHERE s.sale_date<c.signup_date OR s.sale_date<e.hire_date") + scalar(cur, "SELECT count(*) FROM crm_activities a JOIN opportunities o USING(opportunity_id) JOIN employees e ON e.employee_id=a.employee_id WHERE a.activity_date<o.created_date OR a.activity_date<e.hire_date") + scalar(cur, "SELECT count(*) FROM invoices i JOIN sales s USING(sale_id) WHERE i.invoice_date<s.sale_date") + scalar(cur, "SELECT count(*) FROM opportunities o JOIN leads l USING(lead_id) WHERE o.created_date<l.created_date"),
            "negative_stock_products": scalar(cur, "WITH running AS (SELECT product_id, sum(quantity) OVER (PARTITION BY product_id ORDER BY movement_date, movement_id) stock FROM inventory_movements) SELECT count(DISTINCT product_id) FROM running WHERE stock<0"),
            "invoice_total_mismatches": scalar(cur, "SELECT count(*) FROM invoices i JOIN (SELECT sale_id, round(sum(quantity*unit_price*(1-discount)),2) total FROM sale_items GROUP BY sale_id) x USING(sale_id) WHERE i.total_amount<>x.total"),
            "invalid_crm_activity_links": scalar(cur, "SELECT count(*) FROM crm_activities a LEFT JOIN opportunities o USING(opportunity_id) WHERE o.opportunity_id IS NULL"),
        }
        annual = []
        cur.execute("SELECT extract(year FROM s.sale_date)::int, round(sum(i.quantity*i.unit_price*(1-i.discount)),2), round(sum(i.quantity*i.unit_cost),2) FROM sales s JOIN sale_items i USING(sale_id) WHERE s.status='CONFIRMED' GROUP BY 1 ORDER BY 1")
        for year, revenue, cost in cur.fetchall():
            annual.append({"year": year, "revenue": float(revenue), "gross_margin_pct": round(float((revenue-cost)/revenue*100), 2)})
        checks["annual_metrics"] = annual
        checks["trend_revenue_growth"] = annual[-1]["revenue"] > annual[0]["revenue"] if len(annual) > 1 else False
        checks["trend_margin_deterioration"] = annual[-1]["gross_margin_pct"] < annual[0]["gross_margin_pct"] if len(annual) > 1 else False
        checks["table_counts"] = {t: scalar(cur, f"SELECT count(*) FROM {t}") for t in (
            "employees", "suppliers", "categories", "products", "customers", "leads", "opportunities", "purchase_orders", "purchase_items", "sales", "sale_items", "inventory_movements", "crm_activities", "invoices")}
    failures = [name for name, value in checks.items() if name not in {"annual_metrics", "table_counts", "trend_revenue_growth", "trend_margin_deterioration"} and value != 0]
    if failures or not checks["trend_revenue_growth"] or not checks["trend_margin_deterioration"]:
        detail = ""
        if checks["invoice_total_mismatches"]:
            with conn.cursor() as cur:
                cur.execute("SELECT i.sale_id, i.total_amount, round(sum(x.quantity*x.unit_price*(1-x.discount)),2) FROM invoices i JOIN sale_items x USING(sale_id) GROUP BY i.sale_id, i.total_amount HAVING i.total_amount<>round(sum(x.quantity*x.unit_price*(1-x.discount)),2) LIMIT 3")
                detail = f" samples={cur.fetchall()}"
        raise RuntimeError(f"Validation failed: {failures or 'business trend'}{detail}")
    return checks
