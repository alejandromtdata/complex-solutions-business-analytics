from __future__ import annotations
import json
import logging
from datetime import date
from decimal import Decimal
from pathlib import Path
from fastapi import FastAPI, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from .db import db
from . import services

logging.basicConfig(level=logging.INFO)
BASE = Path(__file__).parent
app = FastAPI(title="Complex Solutions ERP + CRM")
app.mount("/static", StaticFiles(directory=BASE / "static"), name="static")
templates = Jinja2Templates(directory=BASE / "templates")

def render(request: Request, page: str, **context: object) -> HTMLResponse:
    with db() as conn:
        context.setdefault("employees", services.rows(conn,"SELECT employee_id,name FROM employees ORDER BY name"))
        context.setdefault("categories", services.rows(conn,"SELECT category_id,category_name FROM categories ORDER BY category_name"))
        context.setdefault("suppliers", services.rows(conn,"SELECT supplier_id,supplier_name FROM suppliers ORDER BY supplier_name"))
        context.setdefault("products", services.rows(conn,"SELECT product_id,sku,product_name,list_price FROM products ORDER BY product_name LIMIT 300"))
        context.setdefault("customers", services.rows(conn,"SELECT customer_id,company_name FROM customers ORDER BY company_name LIMIT 300"))
    return templates.TemplateResponse(request, page, context)

@app.get("/health")
def health() -> dict[str,str]:
    with db() as conn: conn.execute("SELECT 1")
    return {"status":"ok"}

@app.get("/", response_class=HTMLResponse)
def home(request: Request):
    with db() as conn: metrics=services.dashboard(conn)
    return render(request,"dashboard.html",metrics=metrics)

@app.get("/customers", response_class=HTMLResponse)
def customers(request: Request, q: str = ""):
    with db() as conn: records=services.rows(conn,"SELECT c.*,e.name sales_rep FROM customers c LEFT JOIN employees e ON e.employee_id=c.sales_rep_id WHERE c.company_name ILIKE %s ORDER BY c.customer_id DESC LIMIT 200",(f"%{q}%",))
    return render(request,"customers.html",records=records,q=q)

@app.post("/customers")
def customer_create(customer_type:str=Form(...),company_name:str=Form(...),customer_segment:str=Form(...),city:str=Form(...),province:str=Form(...),signup_date:date=Form(...),acquisition_channel:str=Form(...),sales_rep_id:int|None=Form(None)):
    with db() as conn: services.create_customer(conn,locals())
    return RedirectResponse("/customers?ok=Cliente creado",303)

@app.get("/products",response_class=HTMLResponse)
def products(request:Request,q:str=""):
    with db() as conn: records=services.rows(conn,"SELECT p.*,c.category_name,s.supplier_name,coalesce(sum(m.quantity),0) stock FROM products p JOIN categories c USING(category_id) JOIN suppliers s USING(supplier_id) LEFT JOIN inventory_movements m USING(product_id) WHERE p.product_name ILIKE %s OR p.sku ILIKE %s GROUP BY p.product_id,c.category_name,s.supplier_name ORDER BY p.product_id DESC LIMIT 200",(f"%{q}%",f"%{q}%"))
    return render(request,"products.html",records=records,q=q)

@app.post("/products")
def product_create(sku:str=Form(...),product_name:str=Form(...),category_id:int=Form(...),brand:str=Form(...),supplier_id:int=Form(...),cost_price:Decimal=Form(...),list_price:Decimal=Form(...)):
    with db() as conn: services.create_product(conn,locals())
    return RedirectResponse("/products?ok=Producto creado",303)

@app.get("/inventory",response_class=HTMLResponse)
def inventory(request:Request):
    with db() as conn: records=services.stock(conn); movements=services.rows(conn,"SELECT m.*,p.sku FROM inventory_movements m JOIN products p USING(product_id) ORDER BY movement_date DESC,movement_id DESC LIMIT 100")
    return render(request,"inventory.html",records=records,movements=movements)

@app.post("/inventory/adjust")
def adjust(product_id:int=Form(...),movement_date:date=Form(...),quantity:int=Form(...),unit_cost:Decimal=Form(...)):
    if not quantity: return RedirectResponse("/inventory?error=Cantidad inválida",303)
    with db() as conn: conn.execute("INSERT INTO inventory_movements(product_id,movement_date,movement_type,quantity,unit_cost) VALUES(%s,%s,'ADJUSTMENT',%s,%s)",(product_id,movement_date,quantity,unit_cost))
    return RedirectResponse("/inventory?ok=Ajuste registrado",303)

@app.get("/sales",response_class=HTMLResponse)
def sales(request:Request):
    with db() as conn: records=services.rows(conn,"SELECT s.*,c.company_name,e.name FROM sales s JOIN customers c USING(customer_id) JOIN employees e USING(employee_id) ORDER BY sale_id DESC LIMIT 100")
    return render(request,"sales.html",records=records)

@app.post("/sales")
def sale(customer_id:int=Form(...),employee_id:int=Form(...),sale_date:date=Form(...),channel:str=Form(...),lines_json:str=Form(...)):
    try:
        with db() as conn: services.create_sale(conn,customer_id,employee_id,sale_date,channel,json.loads(lines_json))
        return RedirectResponse("/sales?ok=Venta y factura creadas",303)
    except Exception as exc:
        logging.exception("Sale failed"); return RedirectResponse(f"/sales?error={str(exc)}",303)

@app.get("/purchases",response_class=HTMLResponse)
def purchases(request:Request):
    with db() as conn: records=services.rows(conn,"SELECT po.*,s.supplier_name FROM purchase_orders po JOIN suppliers s USING(supplier_id) ORDER BY purchase_id DESC LIMIT 100")
    return render(request,"purchases.html",records=records)

@app.post("/purchases")
def purchase(supplier_id:int=Form(...),purchase_date:date=Form(...),lines_json:str=Form(...)):
    try:
        with db() as conn: services.create_purchase(conn,supplier_id,purchase_date,json.loads(lines_json))
        return RedirectResponse("/purchases?ok=Compra registrada",303)
    except Exception as exc: logging.exception("Purchase failed"); return RedirectResponse(f"/purchases?error={str(exc)}",303)

@app.get("/invoices",response_class=HTMLResponse)
def invoices(request:Request,q:str=""):
    with db() as conn: records=services.rows(conn,"SELECT i.*,c.company_name FROM invoices i JOIN sales s USING(sale_id) JOIN customers c USING(customer_id) WHERE c.company_name ILIKE %s ORDER BY invoice_id DESC LIMIT 200",(f"%{q}%",))
    return render(request,"invoices.html",records=records,q=q)

@app.get("/leads",response_class=HTMLResponse)
def leads(request:Request,q:str=""):
    with db() as conn: records=services.rows(conn,"SELECT l.*,e.name FROM leads l LEFT JOIN employees e ON e.employee_id=l.sales_rep_id WHERE l.company_name ILIKE %s ORDER BY lead_id DESC LIMIT 200",(f"%{q}%",))
    return render(request,"leads.html",records=records,q=q)

@app.post("/leads")
def lead(company_name:str=Form(...),created_date:date=Form(...),source:str=Form(...),industry:str=Form(...),sales_rep_id:int|None=Form(None),status:str=Form("NEW")):
    with db() as conn: services.create_lead(conn,locals())
    return RedirectResponse("/leads?ok=Lead creado",303)

@app.post("/leads/{lead_id}/convert")
def lead_convert(lead_id:int,sales_rep_id:int=Form(...)):
    with db() as conn: services.convert_lead(conn,lead_id,sales_rep_id)
    return RedirectResponse("/opportunities?ok=Lead convertido",303)

@app.get("/opportunities",response_class=HTMLResponse)
def opportunities(request:Request):
    with db() as conn: records=services.rows(conn,"SELECT o.*,c.company_name,e.name FROM opportunities o JOIN customers c USING(customer_id) JOIN employees e ON e.employee_id=o.sales_rep_id ORDER BY opportunity_id DESC LIMIT 200")
    return render(request,"opportunities.html",records=records)

@app.post("/opportunities/{opportunity_id}/stage")
def opportunity_stage(opportunity_id:int,stage:str=Form(...),probability:Decimal=Form(...)):
    result = "WON" if stage=="CLOSED_WON" else "LOST" if stage=="CLOSED_LOST" else None
    with db() as conn: conn.execute("UPDATE opportunities SET stage=%s,probability=%s,result=%s,closed_date=CASE WHEN %s IS NULL THEN NULL ELSE current_date END WHERE opportunity_id=%s",(stage,probability,result,result,opportunity_id))
    return RedirectResponse("/opportunities?ok=Oportunidad actualizada",303)

@app.get("/activities",response_class=HTMLResponse)
def activities(request:Request):
    with db() as conn: records=services.rows(conn,"SELECT a.*,o.opportunity_id,e.name FROM crm_activities a JOIN opportunities o USING(opportunity_id) JOIN employees e USING(employee_id) ORDER BY activity_id DESC LIMIT 200")
    return render(request,"activities.html",records=records)

@app.post("/activities")
def activity(opportunity_id:int=Form(...),employee_id:int=Form(...),activity_type:str=Form(...),activity_date:date=Form(...)):
    with db() as conn: conn.execute("INSERT INTO crm_activities(opportunity_id,employee_id,activity_type,activity_date) VALUES(%s,%s,%s,%s)",(opportunity_id,employee_id,activity_type,activity_date))
    return RedirectResponse("/activities?ok=Actividad registrada",303)
