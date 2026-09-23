# Motor de generación de datos

## Propósito y límites de esta fase

Este documento especifica el motor reproducible que poblará PostgreSQL para COMPLEX SOLUTIONS S.L. entre `2020-01-01` y `2026-12-31`. El generador será la única fuente de datos de negocio sintéticos y PostgreSQL será la fuente de verdad resultante.

Esta fase no modifica el esquema y no implementa ERP, CRM, API, interfaz ni Power BI. Las señales analíticas se producirán mediante combinaciones de hechos observables, nunca mediante flags como `at_risk`, `low_margin` o `stalled_opportunity`.

## Configuración reproducible

Una configuración inmutable, cargada desde variables de entorno y sobreescribible por CLI, controlará cada ejecución:

```text
SEED=42
START_DATE=2020-01-01
END_DATE=2026-12-31
SCALE=small                # small | full
DATABASE_URL=postgresql://...
INSERT_BATCH_SIZE=5000
```

La misma combinación de configuración, versión de código y catálogo de referencia producirá los mismos registros en el mismo orden. Se creará un generador raíz de NumPy (`numpy.random.Generator(PCG64(seed))`) y subgeneradores deterministas por dominio/año derivados de una semilla estable, por ejemplo `seed + hash_estable("sales:2024")`. Así, cambiar el volumen de CRM no alterará aleatoriamente productos o ventas ya definidos.

`END_DATE` permite cerrar 2026 completo o parcial. Todos los generadores calcularán el último ejercicio desde esta fecha, sin asumir que exista el 31 de diciembre.

| Perfil | Uso | Volumen orientativo |
|---|---|---|
| `small` | Desarrollo, pruebas de integridad y validación rápida | 7 años, ~100 productos, ~300 clientes, ~2.000 ventas |
| `full` | Dataset de portfolio | 30–40 empleados, 3.000–5.000 productos, 10.000–20.000 clientes, 200.000–300.000 ventas y proporciones CRM/compras solicitadas |

Los perfiles son multiplicadores y topes de volumen; no cambian las reglas comerciales ni los sesgos analíticos.

## Arquitectura propuesta

```text
src/data_generation/
├── __init__.py
├── config.py                 # Config, perfiles, objetivos por año y seed
├── models.py                 # Dataclasses/tablas intermedias tipadas
├── catalog.py                # Catálogos españoles y reglas de productos
├── database.py               # Conexión psycopg, COPY y transacciones
├── pipeline.py               # Orquestación, CLI y manifiesto de ejecución
├── generators/
│   ├── employees.py
│   ├── suppliers.py
│   ├── categories.py
│   ├── products.py
│   ├── customers.py
│   ├── leads.py
│   ├── opportunities.py
│   ├── sales.py              # sales + sale_items como una unidad lógica
│   ├── purchases.py          # purchase_orders + purchase_items
│   ├── inventory.py
│   ├── crm_activities.py
│   └── invoices.py
├── rules/
│   ├── growth.py             # curvas anuales, estacionalidad y canal
│   ├── pricing.py            # costes, precios y descuentos
│   └── behavior.py           # perfiles latentes, Pareto y ciclos de cliente
├── utils/
│   ├── dates.py
│   ├── distributions.py
│   ├── random_utils.py
│   └── validation_queries.py
└── validation/
    ├── structural.py
    ├── temporal.py
    ├── business_rules.py
    └── analytical_signals.py

tests/
├── data_generation/
│   ├── test_reproducibility.py
│   ├── test_temporal_integrity.py
│   └── test_small_pipeline.py
└── sql/
    └── validate_generated_data.sql
```

Los generadores devolverán filas tipadas o `DataFrame` pequeños por lote, no CSV como medio principal. La separación entre `rules` y `generators` hace que la lógica comercial sea auditable y que los perfiles `small` y `full` compartan comportamiento.

## Orden y dependencias

```text
categories ─┐
suppliers ──┼─> products ──┬─> purchase_orders -> purchase_items
employees ──┼─> customers ─┼─> sales -> sale_items -> invoices
            │       │      ├─> opportunities -> crm_activities
            └─> leads ────┘
products + compras + ventas -> inventory_movements
```

Orden de ejecución propuesto:

1. Catálogos fijos: categorías, provincias/ciudades y reglas de marcas.
2. Proveedores y empleados disponibles en la fecha de inicio.
3. Altas progresivas de productos, empleados y clientes por año.
4. Leads y oportunidades, respetando empleados y clientes existentes.
5. Compras y ventas en orden cronológico de cada periodo.
6. Movimientos de inventario derivados de compras, ventas, devoluciones y ajustes.
7. Actividades CRM e invoices, una vez existen sus entidades padre.
8. Validación dentro de una transacción de carga; confirmación solo si se cumplen los umbrales.

## Reglas de generación por entidad

### Categorías, proveedores y productos

- Las diez categorías son: `Computers`, `Components`, `Monitors`, `Peripherals`, `Storage`, `Networking`, `Accessories`, `Printing`, `Servers` y `Security`.
- Se usará un catálogo mantenido en código con familias, marcas plausibles, rangos de precio, multiplicadores de margen y ciclos de vida. No se generarán nombres a partir de palabras aleatorias.
- Se crearán 50–100 proveedores con pesos de suministro desiguales: estratégicos, relevantes y de cola larga. Un proveedor tendrá especialización de categorías, no un reparto uniforme.
- Los SKU serán deterministas y únicos, por ejemplo `CS-{CATEGORIA}-{secuencia}`. Coste y precio de lista usarán `NUMERIC`, con el precio siempre superior al coste en catálogo.
- El catálogo crecerá por cohortes anuales, con alta inicial pequeña en 2020, extensiones anuales y una fracción de referencias cuya demanda disminuye tras su ciclo de vida. La disponibilidad temporal se mantendrá en el estado del generador.
- El coste unitario de compra y de venta se calculará desde un coste base por producto, efectos de proveedor/categoría, inflación irregular por año y ruido limitado. La variación no será común a todos los productos.

### Empleados

- Las altas progresan desde una plantilla reducida en 2020 hasta 30–40 personas en `full`.
- Se distribuyen entre los seis departamentos permitidos por el esquema. Los perfiles comerciales se identifican por `department = SALES` y su `role`, no por una nueva columna.
- Cada comercial recibe parámetros internos no persistidos: capacidad, propensión de descuento, conversión y cartera. Estos parámetros introducen heterogeneidad pero no se insertan como etiquetas de rendimiento.
- Ninguna relación se asignará a un empleado antes de su `hire_date`.

### Clientes

- Se darán de alta por cohortes anuales, con crecimiento irregular y predominio B2C inicial; B2B, SMB, Enterprise y Public Sector ganan peso con el tiempo.
- Ciudad/provincia se tomarán de un catálogo español coherente. El canal de adquisición se pondera por año: tienda física más relevante al inicio; online, outbound, partner y referral ganan peso más adelante.
- Cada cliente tendrá un perfil interno de comportamiento —ocasional, recurrente, alto valor, creciente o declinante— usado únicamente para elegir frecuencia, cesta, canal y recencia. No se almacena dicho perfil.
- Las cuentas B2B se asignan a comerciales contratados; B2C puede no tener `sales_rep_id`.

### Leads, oportunidades y actividades CRM

- Los leads crecen especialmente desde 2022–2023. Se asignan a comerciales existentes y recorren estados compatibles: `NEW`, `CONTACTED`, `QUALIFIED`, `DISQUALIFIED` o `CONVERTED`.
- Parte de los leads cualificados/convertidos origina una oportunidad y se enlaza mediante `opportunities.lead_id`; otras oportunidades se originan directamente desde clientes y tendrán `lead_id = NULL`.
- Las oportunidades se crean para clientes existentes, con valores sesgados a la derecha y probabilidades/etapas coherentes. Las cerradas usan `CLOSED_WON`/`WON` o `CLOSED_LOST`/`LOST`; las abiertas no tienen resultado ni fecha de cierre.
- Las fechas esperadas se derivan de la creada con ciclos por segmento. Algunas abiertas conservarán fecha esperada vencida y baja actividad reciente por su comportamiento generado, no por una etiqueta explícita.
- Las actividades se generan entre creación y cierre/fecha de corte, con cadencia distinta por oportunidad y actividad. Nunca preceden a la oportunidad ni al `hire_date` del empleado.

### Ventas y líneas

- El volumen anual combina curva de crecimiento no lineal, estacionalidad moderada (vuelta al cole, Black Friday/Navidad y ciclos B2B), peso de canal y comportamiento del cliente.
- La selección de clientes y productos empleará distribuciones ponderadas y Zipf/Pareto suavizadas: unos pocos clientes y referencias concentran volumen sin imponer una regla exacta 80/20.
- B2C se concentra en tienda/online; B2B en canal B2B y comerciales, con mayor ticket, más líneas y descuentos más altos.
- Una venta confirmada tendrá una o más líneas. `unit_price`, `discount` y `unit_cost` quedan congelados en `sale_items` para preservar el contexto histórico; no se recalculan al cambiar catálogo o costes posteriores.
- Solo las ventas confirmadas contribuirán a movimientos `SALE` e invoices. Canceladas no afectarán inventario ni facturación. Las devoluciones se modelarán como movimientos `RETURN`, sin añadir campos ni tablas.

### Descuentos, precios y margen

- Descuentos: distribución truncada con base por canal y segmento, ajuste por volumen/cesta, antigüedad, importancia de cuenta, producto y propensión del comercial. Nunca alcanzarán el 100 %.
- B2B y grandes cuentas tenderán a descuentos mayores, con dispersión suficiente para evitar valores constantes por segmento.
- La proporción de categorías de bajo margen, ventas B2B/e-commerce y clientes concentrados aumenta gradualmente. Al mismo tiempo, costes de determinadas familias y proveedores evolucionan al alza de forma desigual.
- El resultado objetivo es ingresos y beneficio bruto crecientes en valor, pero margen porcentual decreciente de forma no perfectamente lineal en los últimos ejercicios. El margen se deriva exclusivamente de las líneas de venta.

### Compras e inventario

- Las compras se calculan a partir de demanda esperada, stock reconstruido, lead time de proveedor, estacionalidad y política de cobertura por familia. Un pedido puede contener varias líneas del mismo proveedor.
- `PURCHASE` se deriva de las líneas recibidas con cantidad positiva; `SALE` de las líneas confirmadas con cantidad negativa; `RETURN` es positiva; `ADJUSTMENT` es excepcional y puede tener ambos signos.
- El planificador interno mantendrá stock diario/lote para impedir ventas que lleven el stock por debajo de cero por errores de generación. Las reposiciones se fechán antes de las ventas que abastecen.
- Una pequeña cohorte de referencias tendrá previsión alta y demanda decreciente, produciendo compras excesivas y stock acumulado. Otra tendrá demanda alta y cobertura baja. Son consecuencias de parámetros de demanda y aprovisionamiento, no campos de riesgo.

### Facturas

- Cada venta `CONFIRMED` generará una factura con `total_amount` igual a la suma de sus líneas netas. Las fechas de factura nunca serán anteriores a la venta.
- El vencimiento se calcula desde la factura con condiciones más cortas para B2C y más largas para B2B. El estado se deriva de fechas y de una distribución de pago: `PAID`, `SENT`, `OVERDUE` o `CANCELLED` cuando aplique.

## Cómo emergen los cuatro comportamientos analíticos

| Área | Mecanismos generadores observables | Comprobación posterior |
|---|---|---|
| Rentabilidad | Mix creciente de bajo margen, presión de costes selectiva, descuentos B2B/grandes cuentas y crecimiento por canal | Revenue anual aumenta; margen % baja en los últimos años, con variación por categoría/canal/comercial. |
| Clientes | Cohortes, frecuencia heterogénea, perfiles internos de declive y concentración B2B | RFM, ingresos por cliente/año, caída de clientes antes valiosos y concentración de facturación. |
| Inventario | Reposición basada en previsión, demanda concentrada, exceso selectivo y ciclos de vida | Stock mediante suma de movimientos, rotación/cobertura, sobrantes y referencias de baja cobertura. |
| CRM | Conversión desigual, valores sesgados, cadencia de actividades variable y fechas esperadas vencidas | Edad, días sin actividad, pipeline ponderado, conversión, win rate y oportunidades abiertas envejecidas. |

## Integridad temporal, referencial y comercial

Antes de insertar, los generadores validarán las referencias contra los IDs creados y las fechas contra el estado temporal. Después de insertar, consultas SQL comprobarán:

- Todas las claves foráneas son válidas (además de la protección nativa de PostgreSQL).
- Cada venta tiene al menos una línea; cada compra tiene al menos una línea; cada factura refiere una venta confirmada.
- Fecha de venta posterior o igual al alta de cliente y contratación de empleado; fecha de actividad posterior o igual a oportunidad y contratación; fecha de factura posterior o igual a venta.
- Si `lead_id` no es nulo, el lead precede o coincide con la oportunidad.
- Las reglas de etapa, resultado, probabilidad, descuento y estados cumplen los `CHECK` del esquema.
- Todos los movimientos cumplen su signo por tipo, se corresponden con hechos generados y el stock acumulado por producto no es negativo.
- Los totales de factura coinciden con las líneas de venta netas dentro de una tolerancia decimal de cero.

## Inserción eficiente en PostgreSQL

Se usará `psycopg` con transacciones explícitas y `COPY FROM STDIN` binario o por filas para lotes grandes. Cada tabla se cargará en lotes configurables, respetando el orden de dependencias. Para `small`, `executemany` por lote es suficiente; para `full`, `COPY` será el camino predeterminado.

La ejecución seguirá este patrón:

1. Validar configuración y abrir una conexión.
2. Verificar que la base destino está vacía. La ejecución normal nunca borra ni añade datos. Solo `--reset` solicita un `TRUNCATE ... RESTART IDENTITY CASCADE` transaccional limitado a las 14 tablas del proyecto antes de regenerar.
3. Generar y cargar cada dominio por orden; mantener IDs devueltos y estado de inventario en memoria/lotes.
4. Ejecutar validaciones SQL y de métricas globales dentro de la misma transacción o antes del marcador final de ejecución.
5. Confirmar únicamente si todas pasan; en caso contrario hacer `ROLLBACK` y emitir un informe.

No se usarán millones de `INSERT` individuales ni CSV gigantes como arquitectura primaria. Un manifiesto de ejecución almacenará configuración, semilla, recuentos y versión del generador para auditoría.

## Plan de validación

### Estructural y temporal

- Recuentos esperados por tabla y año frente al perfil configurado.
- FK sin huérfanos, tablas de líneas no vacías para cabeceras aplicables y productos/proveedores válidos.
- Integridad temporal y stock no negativo conforme a las reglas anteriores.
- Repetir `small` dos veces contra bases vacías y comparar huellas deterministas de filas ordenadas para verificar reproducibilidad.

### Métricas globales y señales analíticas

- Revenue anual, número de ventas/clientes y ticket medio con crecimiento razonable, no necesariamente monótono año a año.
- Margen bruto e índice de margen porcentual por año; el periodo tardío debe ser menor que la referencia inicial dentro de una banda configurable.
- Participación de ingresos de los principales clientes y detección de clientes con ingresos históricos altos y recencia/tendencia descendentes.
- Productos con rotación baja y stock positivo, y productos de demanda elevada con cobertura baja; se calculan a partir de movimientos.
- Pipeline por etapa, oportunidades con `expected_close_date` vencida, días desde última actividad y distribución de conversión por comercial.

Estas son pruebas de rangos/tendencias, no reglas que inserten conclusiones en el dataset. Los umbrales serán configurables por perfil y se documentarán con los resultados de la primera generación pequeña aprobada.

## Decisiones pendientes antes de implementar

1. **Lanzamiento y retirada de productos:** `products` no contiene fecha de alta/baja. El motor puede respetarlo internamente, pero no será auditable mediante SQL una vez cargados los datos. Si se quiere analizar ciclo de vida o demostrar que una venta no precede al lanzamiento, se necesitaría añadir un campo de fecha al esquema. No se propone modificarlo en esta fase.
2. **Trazabilidad de inventario:** `inventory_movements` no referencia `purchase_items` ni `sale_items`. Es suficiente para reconstruir stock, pero no permite exigir relacionalmente que cada movimiento tenga su documento origen. El motor mantendrá esa trazabilidad en ejecución y la validará por importes/fechas agregadas.
3. **Devoluciones comerciales:** el esquema permite movimientos `RETURN`, pero no una línea de devolución vinculada a una venta original. Se modelarán como movimientos de inventario independientes hasta que se necesite análisis detallado de devoluciones.
4. **Facturas por venta:** el esquema admite varias facturas para una venta. El generador crea una factura por venta confirmada; la facturación parcial queda fuera de alcance.
5. **Fiscalidad:** `invoices.total_amount` es importe neto de IVA. Los impuestos no se modelan en esta fase.
6. **Recarga de datos:** la ejecución normal rechaza una base no vacía. `--reset` es la única vía explícita y su alcance se limita a las tablas del proyecto dentro de una transacción.
