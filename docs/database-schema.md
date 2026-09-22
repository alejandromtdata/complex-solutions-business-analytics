# Esquema de base de datos

`database/schema.sql` define el modelo relacional PostgreSQL de COMPLEX SOLUTIONS S.L. No inserta datos ni modela aún la aplicación ERP/CRM.

## Entidades y relaciones

| Área | Tablas | Relación principal |
|---|---|---|
| Maestros | `employees`, `customers`, `suppliers`, `categories`, `products` | Un empleado puede gestionar clientes; cada producto pertenece a una categoría y proveedor. |
| Ventas | `sales`, `sale_items` | Una venta pertenece a un cliente y empleado; sus líneas apuntan a productos. |
| Compras | `purchase_orders`, `purchase_items` | Un pedido pertenece a un proveedor; sus líneas apuntan a productos. |
| Inventario | `inventory_movements` | Cada movimiento pertenece a un producto. |
| CRM | `leads`, `opportunities`, `crm_activities` | Leads y oportunidades se asignan a empleados; una oportunidad puede proceder opcionalmente de un lead, pertenece a un cliente y agrupa actividades. |
| Facturación | `invoices` | Cada factura pertenece a una venta. |

## Decisiones de diseño

- Las claves son `BIGINT GENERATED ALWAYS AS IDENTITY`; los SKU y los nombres de categoría/proveedor son únicos.
- Los importes son `NUMERIC`, nunca `FLOAT`, para mantener precisión monetaria.
- `sale_items` conserva precio, descuento y coste unitarios históricos. No existe un campo de margen: se calcula con `quantity * unit_price * (1 - discount) - quantity * unit_cost`.
- Las cantidades de inventario tienen signo: `PURCHASE` y `RETURN` suman, `SALE` resta y `ADJUSTMENT` puede sumar o restar. Por tanto, el stock a una fecha se obtiene con `SUM(quantity)` filtrando por fecha.
- Se emplean restricciones `CHECK` para dominios de estados, etapas, descuentos, probabilidades, importes y fechas coherentes. Las eliminaciones de cabeceras de venta, compra y oportunidades eliminan sus líneas/actividades; los maestros referenciados se protegen con `RESTRICT`.
- Los índices cubren las claves foráneas y las fechas empleadas en análisis de ventas, compras, inventario, CRM y facturación.
