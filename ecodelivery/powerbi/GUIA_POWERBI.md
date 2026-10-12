# Guía para construir el dashboard en Power BI Desktop

Este entorno de trabajo no tiene Power BI Desktop instalado (requiere Windows/licencia),
por eso no se generó un `.pbix` directamente. Aquí tienes el paso a paso **exacto**
para construirlo en menos de 15 minutos, con las fórmulas DAX ya escritas para copiar y pegar.

## 1. Fuentes de datos a usar

Carga **ambos** archivos como tablas independientes en Power BI:

1. **`dataset_pedidos_semilla.csv`** (raíz del repo) → grano de detalle (1 fila = 1 pedido).
   Es la fuente principal: de aquí salen el gráfico de líneas por día, el de barras por zona y el slicer.
2. **`powerbi/reporte_pedidos.csv`** (generado por el DAG de Airflow, módulo 3) → tabla resumen
   ya agregada por el pipeline (formato "largo": fecha_reporte, tipo_metrica, dimension, categoria, valor).
   Se usa para **demostrar en la sustentación** que el pipeline de Airflow alimenta el dashboard.

## 2. Pasos en Power BI Desktop

### a) Importar datos
1. `Inicio` → `Obtener datos` → `Texto/CSV`.
2. Selecciona `dataset_pedidos_semilla.csv`. En la vista previa, clic en **Transformar datos** (abre Power Query).
3. En Power Query:
   - Cambia el tipo de columna `fecha_creacion` y `fecha_entrega` a **Fecha/Hora**.
   - Cambia `monto` a **Número decimal**.
   - Cambia `id_pedido` a **Número entero**.
   - Agrega columna `Fecha` (solo día, sin hora) para el eje del gráfico de líneas:
     `Agregar columna` → `Columna de fecha` → `Solo fecha`, aplicada sobre `fecha_creacion`.
4. `Cerrar y aplicar`.
5. Repite `Obtener datos` → `Texto/CSV` para `reporte_pedidos.csv` (opcional, tabla secundaria de respaldo).

### b) Medidas DAX (créalas en la tabla `dataset_pedidos_semilla`)

Clic derecho sobre la tabla → **Nueva medida**, y pega cada una:

```DAX
Cantidad Pedidos = COUNTROWS(dataset_pedidos_semilla)
```

```DAX
Ingreso Total = SUM(dataset_pedidos_semilla[monto])
```

```DAX
Ticket Promedio =
DIVIDE(
    SUM(dataset_pedidos_semilla[monto]),
    COUNTROWS(dataset_pedidos_semilla),
    0
)
```

```DAX
Tiempo Promedio Entrega (min) =
AVERAGEX(
    FILTER(dataset_pedidos_semilla, dataset_pedidos_semilla[estado] = "entregado"),
    DATEDIFF(dataset_pedidos_semilla[fecha_creacion], dataset_pedidos_semilla[fecha_entrega], MINUTE)
)
```

```DAX
Ingresos Pedidos Entregados =
CALCULATE(
    SUM(dataset_pedidos_semilla[monto]),
    dataset_pedidos_semilla[estado] = "entregado"
)
```

> La medida obligatoria pedida en el enunciado ("al menos 1 medida DAX creada por ti") es
> **Ticket Promedio** o **Tiempo Promedio Entrega (min)** — ninguna de las dos es un conteo
> automático, ambas tienen lógica de negocio real (división segura y cálculo de diferencia de fechas filtrado).

### c) Visualizaciones (mínimo 3 + 1 slicer)

1. **Gráfico de barras** — Ingresos por zona:
   - Tipo: `Gráfico de columnas agrupadas`.
   - Eje X: `zona`. Valores: `Ingreso Total`.

2. **Gráfico de líneas** — Pedidos por día:
   - Tipo: `Gráfico de líneas`.
   - Eje X: `Fecha` (la columna solo-fecha creada en Power Query).
   - Valores: `Cantidad Pedidos`.

3. **Tarjeta (KPI)**:
   - Tipo: `Tarjeta`.
   - Campo: `Ticket Promedio` (o `Ingreso Total`, puedes poner ambas en dos tarjetas).

4. **Slicer**:
   - Tipo: `Segmentación de datos`.
   - Campo: `estado` (o `zona`, o ambos en dos slicers separados).

### d) Formato sugerido
- Colores por estado (consistentes con la app Flutter):
  `pendiente` = naranja, `en_camino` = azul, `entregado` = verde, `cancelado` = rojo.
- Título del reporte: "EcoDelivery — Operación diaria".
- Agrega una página con el resumen del DAG (captura de la tabla `reporte_pedidos.csv`) como evidencia de trazabilidad del pipeline.

### e) Guardar
`Archivo` → `Guardar como` → `powerbi/dashboard_ecodelivery.pbix`.

## 3. Si no tienes Power BI instalado para la sustentación

Como alternativa (ya prevista en el enunciado), toma capturas de pantalla de cada
visualización después de construirlas (por ejemplo usando la versión web gratuita
en https://app.powerbi.com, que no requiere licencia de escritorio) y colócalas en
esta misma carpeta `powerbi/capturas/`.
