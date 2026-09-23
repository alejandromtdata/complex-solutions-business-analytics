# ERP + CRM MVP

Aplicación FastAPI/Jinja conectada exclusivamente a PostgreSQL mediante `psycopg`. No existe almacenamiento local ni segunda base de datos.

## Ejecución

```bash
docker compose up -d
uv run uvicorn src.app.main:app --reload
```

Abrir `http://127.0.0.1:8000`. El puerto de PostgreSQL del proyecto es `5433` por defecto.

## Módulos

Dashboard, clientes, productos, ventas, compras, inventario, facturas, leads, oportunidades y actividades. Las ventas crean `sales`, `sale_items`, `inventory_movements` e `invoices` en una transacción; las compras crean cabecera, líneas y movimiento `PURCHASE` en otra. La conversión de lead crea o reutiliza cliente y enlaza la oportunidad mediante `lead_id`.

La aplicación utiliza las constraints de PostgreSQL como última barrera y añade validación de cantidades, descuento, stock y fechas. No modifica el esquema.
