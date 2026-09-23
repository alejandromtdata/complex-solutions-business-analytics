from __future__ import annotations

import argparse
from datetime import date, timedelta
from decimal import Decimal, ROUND_HALF_UP
import json
import random

from .config import SCALE_TARGETS, Settings
from .database import assert_empty_or_reset, connect, copy_rows, insert_returning
from .validation import validate

CATEGORIES = ["Computers", "Components", "Monitors", "Peripherals", "Storage", "Networking", "Accessories", "Printing", "Servers", "Security"]
BRANDS = ["Acer", "ASUS", "Dell", "HP", "Lenovo", "LG", "Logitech", "Samsung", "TP-Link", "Western Digital"]
CITIES = [("Madrid", "Madrid"), ("Barcelona", "Barcelona"), ("Valencia", "Valencia"), ("Sevilla", "Sevilla"), ("Bilbao", "Bizkaia"), ("Zaragoza", "Zaragoza")]


def day(rng: random.Random, start: date, end: date) -> date:
    return start + timedelta(days=rng.randrange((end - start).days + 1))


def money(value: float) -> Decimal:
    return Decimal(str(round(value, 2)))


def run(settings: Settings, reset: bool) -> dict:
    rng = random.Random(settings.seed)
    target = SCALE_TARGETS[settings.scale]
    conn = connect(settings.database_url)
    try:
        with conn.transaction():
            assert_empty_or_reset(conn, reset)
            copy_rows(conn, "categories", ("category_name",), [(x,) for x in CATEGORIES])
            category_ids = {name: ident for ident, name in conn.execute("SELECT category_id, category_name FROM categories")}

            employees = []
            for i in range(target["employees"]):
                hire = date(2020, 1, 1) if i < 4 else day(rng, date(2020, 1, 1), date(2025, 12, 31))
                department = "SALES" if i < max(4, target["employees"] // 3) else ["OPERATIONS", "PURCHASING", "WAREHOUSE", "FINANCE", "MANAGEMENT"][i % 5]
                employees.append((f"Employee {i+1:02d}", department, "Sales Representative" if department == "SALES" else f"{department.title()} Specialist", hire))
            employee_ids = insert_returning(conn, "employees", ("name", "department", "role", "hire_date"), employees, "employee_id", settings.batch_size)
            reps = [(ident, row[3]) for ident, row in zip(employee_ids, employees) if row[1] == "SALES"]

            suppliers = [(f"Supplier {i+1:03d}",) for i in range(target["suppliers"])]
            supplier_ids = insert_returning(conn, "suppliers", ("supplier_name",), suppliers, "supplier_id", settings.batch_size)
            product_rows, available = [], []
            for i in range(target["products"]):
                available_from = date(2020, 1, 2) if i < 20 else day(rng, date(2020, 1, 10), date(2026, 7, 1))
                category = CATEGORIES[i % len(CATEGORIES)]
                base = 25 + (i % 16) ** 2 * 8
                margin = 1.10 + (i % 7) * .055
                cost, price = money(base), money(base * margin)
                product_rows.append((f"CS-{category[:3].upper()}-{i+1:05d}", f"{BRANDS[i % len(BRANDS)]} {category} Model {i+1}", category_ids[category], BRANDS[i % len(BRANDS)], supplier_ids[i % len(supplier_ids)], cost, price))
                available.append(available_from)
            product_ids = insert_returning(conn, "products", ("sku", "product_name", "category_id", "brand", "supplier_id", "cost_price", "list_price"), product_rows, "product_id", settings.batch_size)

            customers = []
            for i in range(target["customers"]):
                signup = day(rng, settings.start_date, settings.end_date - timedelta(days=30))
                b2b = i % 3 == 0
                city, province = CITIES[i % len(CITIES)]
                rep = next((r for r in reps if r[1] <= signup), None) if b2b else None
                customers.append(("B2B" if b2b else "B2C", f"Customer {i+1:05d}", "SMB" if b2b else "CONSUMER", city, province, signup, "OUTBOUND_SALES" if b2b else "ONLINE", rep[0] if rep else None))
            customer_ids = insert_returning(conn, "customers", ("customer_type", "company_name", "customer_segment", "city", "province", "signup_date", "acquisition_channel", "sales_rep_id"), customers, "customer_id", settings.batch_size)

            leads, lead_dates = [], []
            for i in range(target["leads"]):
                created = day(rng, date(2021, 1, 1), settings.end_date - timedelta(days=30))
                eligible = [r for r in reps if r[1] <= created]
                leads.append((f"Lead {i+1:05d}", created, ["WEB", "REFERRAL", "EVENT", "OUTBOUND"][i % 4], "Technology", eligible[i % len(eligible)][0], "CONVERTED" if i % 3 == 0 else "QUALIFIED"))
                lead_dates.append(created)
            lead_ids = insert_returning(conn, "leads", ("company_name", "created_date", "source", "industry", "sales_rep_id", "status"), leads, "lead_id", settings.batch_size)

            opportunities, opportunity_dates = [], []
            for i, lead_id in enumerate(lead_ids[::3]):
                created = lead_dates[i * 3]
                eligible_customers = [j for j, c in enumerate(customers) if c[5] <= created]
                ci = eligible_customers[i % len(eligible_customers)]
                rep_id = leads[i * 3][4]
                closed = i % 4 == 0
                stage, result, closed_date = ("CLOSED_WON", "WON", created + timedelta(days=30)) if closed else ("PROPOSAL", None, None)
                opportunities.append((lead_id, customer_ids[ci], rep_id, created, created + timedelta(days=45 if not closed else 30), stage, money(500 + (i % 20) * 250), Decimal("0.650") if closed else Decimal("0.450"), closed_date, result))
                opportunity_dates.append(created)
            opportunity_ids = insert_returning(conn, "opportunities", ("lead_id", "customer_id", "sales_rep_id", "created_date", "expected_close_date", "stage", "estimated_value", "probability", "closed_date", "result"), opportunities, "opportunity_id", settings.batch_size)

            # One purchase per product seeds real stock before its first eligible sale.
            po_rows = [(product_rows[i][4], available[i] - timedelta(days=1), "RECEIVED") for i in range(len(product_ids))]
            po_ids = insert_returning(conn, "purchase_orders", ("supplier_id", "purchase_date", "status"), po_rows, "purchase_id", settings.batch_size)
            copy_rows(conn, "purchase_items", ("purchase_id", "product_id", "quantity", "unit_cost"), [(po_ids[i], product_ids[i], 1_000, product_rows[i][5]) for i in range(len(product_ids))])

            sales_rows, sale_product_indexes = [], []
            annual_weights = [110, 180, 260, 335, 405, 470, 570]
            total_weight = sum(annual_weights)
            for i in range(target["sales"]):
                bucket = rng.randrange(total_weight)
                year_idx = next(j for j, cumulative in enumerate(__import__('itertools').accumulate(annual_weights)) if bucket < cumulative)
                year = 2020 + year_idx
                candidates = [j for j, c in enumerate(customers) if c[5] <= date(year, 12, 20)]
                ci = candidates[rng.randrange(len(candidates))]
                sale_date = day(rng, max(customers[ci][5], date(year, 1, 10)), min(settings.end_date, date(year, 12, 20)))
                available_products = [j for j, since in enumerate(available) if since <= sale_date]
                # A Zipf-like weighted choice produces concentrated demand without a single SKU
                # exhausting its seeded stock in the small profile.
                pi = rng.choices(available_products, weights=[1 / (rank + 1) ** 0.7 for rank in range(len(available_products))], k=1)[0]
                channel = "B2B" if customers[ci][0] == "B2B" else ("ONLINE" if rng.random() < .65 else "PHYSICAL_STORE")
                rep = customers[ci][7] or next(r[0] for r in reps if r[1] <= sale_date)
                sales_rows.append((customer_ids[ci], rep, sale_date, channel, "CONFIRMED"))
                sale_product_indexes.append(pi)
            sale_ids = insert_returning(conn, "sales", ("customer_id", "employee_id", "sale_date", "channel", "status"), sales_rows, "sale_id", settings.batch_size)
            item_rows, invoice_rows, movement_rows = [], [], []
            for sid, pi, sale in zip(sale_ids, sale_product_indexes, sales_rows):
                qty = 1 + rng.randrange(3)
                price = product_rows[pi][6]
                cost = money(float(product_rows[pi][5]) * (1 + .018 * (sale[2].year - 2020)))
                discount = Decimal(str(round((.03 + rng.random()*.05) if sale[3] != "B2B" else (.10 + rng.random()*.12), 4)))
                item_rows.append((sid, product_ids[pi], qty, price, discount, cost))
                total = (Decimal(qty) * price * (Decimal("1") - discount)).quantize(Decimal(".01"), rounding=ROUND_HALF_UP)
                invoice_rows.append((sid, sale[2], sale[2] + timedelta(days=30 if sale[3] == "B2B" else 7), "PAID", total))
                movement_rows.append((product_ids[pi], sale[2], "SALE", -qty, cost))
            copy_rows(conn, "sale_items", ("sale_id", "product_id", "quantity", "unit_price", "discount", "unit_cost"), item_rows)
            copy_rows(conn, "invoices", ("sale_id", "invoice_date", "due_date", "status", "total_amount"), invoice_rows)
            purchase_movements = [(product_ids[i], po_rows[i][1], "PURCHASE", 1_000, product_rows[i][5]) for i in range(len(product_ids))]
            copy_rows(conn, "inventory_movements", ("product_id", "movement_date", "movement_type", "quantity", "unit_cost"), purchase_movements + movement_rows)

            activities = []
            for oid, created, opportunity in zip(opportunity_ids, opportunity_dates, opportunities):
                for offset, kind in ((2, "CALL"), (10, "EMAIL"), (20, "PROPOSAL")):
                    activities.append((oid, opportunity[2], kind, created + timedelta(days=offset)))
            copy_rows(conn, "crm_activities", ("opportunity_id", "employee_id", "activity_type", "activity_date"), activities)
            report = validate(conn)
        return report
    finally:
        conn.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate the COMPLEX SOLUTIONS synthetic dataset")
    parser.add_argument("--scale", choices=("small", "full"), default=None)
    parser.add_argument("--reset", action="store_true", help="Explicitly reset only project tables before generation")
    args = parser.parse_args()
    report = run(Settings.from_env(args.scale), args.reset)
    print(json.dumps(report, indent=2, default=str))


if __name__ == "__main__":
    main()
