from __future__ import annotations
from datetime import date
from decimal import Decimal, ROUND_HALF_UP
from typing import Any
from psycopg import Connection

def rows(conn: Connection, query: str, params: tuple = ()) -> list[dict[str, Any]]:
    with conn.cursor() as cur:
        cur.execute(query, params)
        names = [c.name for c in cur.description]
        return [dict(zip(names, r)) for r in cur.fetchall()]

def dashboard(conn: Connection) -> dict[str, Any]:
    q = """SELECT (SELECT coalesce(sum(quantity*unit_price*(1-discount)),0) FROM sale_items) revenue,
      (SELECT count(*) FROM sales) sales, (SELECT count(*) FROM customers) customers,
      (SELECT count(*) FROM products) products, (SELECT coalesce(sum(quantity),0) FROM inventory_movements) stock,
      (SELECT count(*) FROM opportunities WHERE result IS NULL) opportunities"""
    return rows(conn, q)[0]

def stock(conn: Connection, product_id: int | None = None) -> list[dict[str, Any]]:
    where, params = ("WHERE p.product_id=%s", (product_id,)) if product_id else ("", ())
    return rows(conn, f"""SELECT p.product_id,p.sku,p.product_name,coalesce(sum(m.quantity),0) stock
      FROM products p LEFT JOIN inventory_movements m USING(product_id) {where}
      GROUP BY p.product_id,p.sku,p.product_name ORDER BY p.product_name""", params)

def create_customer(conn: Connection, data: dict[str, Any]) -> int:
    with conn.cursor() as cur:
        cur.execute("""INSERT INTO customers(customer_type,company_name,customer_segment,city,province,signup_date,acquisition_channel,sales_rep_id)
          VALUES(%(customer_type)s,%(company_name)s,%(customer_segment)s,%(city)s,%(province)s,%(signup_date)s,%(acquisition_channel)s,%(sales_rep_id)s) RETURNING customer_id""", data)
        return cur.fetchone()[0]

def create_product(conn: Connection, data: dict[str, Any]) -> int:
    with conn.cursor() as cur:
        cur.execute("""INSERT INTO products(sku,product_name,category_id,brand,supplier_id,cost_price,list_price)
          VALUES(%(sku)s,%(product_name)s,%(category_id)s,%(brand)s,%(supplier_id)s,%(cost_price)s,%(list_price)s) RETURNING product_id""", data)
        return cur.fetchone()[0]

def create_purchase(conn: Connection, supplier_id: int, purchase_date: date, lines: list[dict[str, Any]]) -> int:
    if not lines: raise ValueError("Añade al menos una línea de compra.")
    with conn.transaction(), conn.cursor() as cur:
        cur.execute("INSERT INTO purchase_orders(supplier_id,purchase_date,status) VALUES(%s,%s,'RECEIVED') RETURNING purchase_id", (supplier_id,purchase_date))
        purchase_id = cur.fetchone()[0]
        for line in lines:
            if int(line["quantity"]) <= 0 or Decimal(str(line["unit_cost"])) < 0: raise ValueError("Cantidad o coste inválido.")
            cur.execute("INSERT INTO purchase_items(purchase_id,product_id,quantity,unit_cost) VALUES(%s,%s,%s,%s)", (purchase_id,line["product_id"],line["quantity"],line["unit_cost"]))
            cur.execute("INSERT INTO inventory_movements(product_id,movement_date,movement_type,quantity,unit_cost) VALUES(%s,%s,'PURCHASE',%s,%s)", (line["product_id"],purchase_date,line["quantity"],line["unit_cost"]))
    return purchase_id

def create_sale(conn: Connection, customer_id: int, employee_id: int, sale_date: date, channel: str, lines: list[dict[str, Any]]) -> int:
    if not lines: raise ValueError("Añade al menos una línea de venta.")
    with conn.transaction(), conn.cursor() as cur:
        cur.execute("SELECT signup_date FROM customers WHERE customer_id=%s", (customer_id,)); customer = cur.fetchone()
        if not customer or customer[0] > sale_date: raise ValueError("Cliente inexistente o fecha anterior a su alta.")
        cur.execute("SELECT hire_date FROM employees WHERE employee_id=%s", (employee_id,)); employee = cur.fetchone()
        if not employee or employee[0] > sale_date: raise ValueError("Empleado inexistente o no contratado aún.")
        cur.execute("INSERT INTO sales(customer_id,employee_id,sale_date,channel,status) VALUES(%s,%s,%s,%s,'CONFIRMED') RETURNING sale_id", (customer_id,employee_id,sale_date,channel)); sale_id=cur.fetchone()[0]
        total=Decimal("0")
        for line in lines:
            product_id, qty = int(line["product_id"]), int(line["quantity"])
            price, discount = Decimal(str(line["unit_price"])), Decimal(str(line.get("discount",0)))
            if qty<=0 or price<=0 or not Decimal("0")<=discount<Decimal("1"): raise ValueError("Línea de venta inválida.")
            cur.execute("SELECT coalesce(sum(quantity),0), cost_price FROM products p LEFT JOIN inventory_movements m USING(product_id) WHERE p.product_id=%s GROUP BY p.cost_price", (product_id,)); product=cur.fetchone()
            if not product: raise ValueError("Producto inexistente.")
            if product[0] < qty: raise ValueError("No hay stock suficiente.")
            cur.execute("INSERT INTO sale_items(sale_id,product_id,quantity,unit_price,discount,unit_cost) VALUES(%s,%s,%s,%s,%s,%s)", (sale_id,product_id,qty,price,discount,product[1]))
            cur.execute("INSERT INTO inventory_movements(product_id,movement_date,movement_type,quantity,unit_cost) VALUES(%s,%s,'SALE',%s,%s)", (product_id,sale_date,-qty,product[1]))
            total += Decimal(qty)*price*(Decimal("1")-discount)
        total=total.quantize(Decimal(".01"),rounding=ROUND_HALF_UP)
        cur.execute("INSERT INTO invoices(sale_id,invoice_date,due_date,status,total_amount) VALUES(%s,%s,%s,'SENT',%s)", (sale_id,sale_date,sale_date.replace(day=min(28,sale_date.day)),total))
    return sale_id

def create_lead(conn: Connection, data: dict[str, Any]) -> int:
    with conn.cursor() as cur:
        cur.execute("INSERT INTO leads(company_name,created_date,source,industry,sales_rep_id,status) VALUES(%(company_name)s,%(created_date)s,%(source)s,%(industry)s,%(sales_rep_id)s,%(status)s) RETURNING lead_id",data); return cur.fetchone()[0]

def convert_lead(conn: Connection, lead_id: int, rep_id: int) -> int:
    with conn.transaction(), conn.cursor() as cur:
        cur.execute("SELECT company_name,created_date FROM leads WHERE lead_id=%s FOR UPDATE",(lead_id,)); lead=cur.fetchone()
        if not lead: raise ValueError("Lead inexistente.")
        cur.execute("SELECT customer_id FROM customers WHERE company_name=%s ORDER BY customer_id LIMIT 1",(lead[0],)); found=cur.fetchone()
        if found: customer_id=found[0]
        else:
            cur.execute("INSERT INTO customers(customer_type,company_name,customer_segment,city,province,signup_date,acquisition_channel,sales_rep_id) VALUES('B2B',%s,'SMB','Madrid','Madrid',%s,'OUTBOUND_SALES',%s) RETURNING customer_id",(lead[0],lead[1],rep_id)); customer_id=cur.fetchone()[0]
        cur.execute("UPDATE leads SET status='CONVERTED',sales_rep_id=%s WHERE lead_id=%s",(rep_id,lead_id))
        cur.execute("INSERT INTO opportunities(lead_id,customer_id,sales_rep_id,created_date,expected_close_date,stage,estimated_value,probability) VALUES(%s,%s,%s,%s,%s,'QUALIFICATION',1000,0.3) RETURNING opportunity_id",(lead_id,customer_id,rep_id,lead[1],lead[1].replace(day=min(28,lead[1].day))))
        return cur.fetchone()[0]
