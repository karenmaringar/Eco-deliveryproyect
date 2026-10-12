"""
DAG: etl_pedidos_diario
------------------------
Pipeline ETL para EcoDelivery S.A.S.

Extrae los pedidos (desde la API del backend, con fallback al CSV semilla
si la API no está disponible), calcula métricas de negocio y genera
reporte_pedidos.csv, que es la fuente de datos del dashboard de Power BI.

Tareas encadenadas:
    extraer_pedidos >> transformar_pedidos >> cargar_reporte

Cómo ejecutarlo:
    - Vía UI de Airflow (trigger manual del DAG "etl_pedidos_diario")
    - Vía CLI:  airflow dags test etl_pedidos_diario 2026-08-27
"""

from datetime import datetime, timedelta
import csv
import json
import os
import urllib.request
import urllib.error

from airflow import DAG
from airflow.operators.python import PythonOperator

# ---------------------------------------------------------------------------
# Configuración
# ---------------------------------------------------------------------------

# URL del backend. Se puede sobreescribir con la variable de entorno API_URL
# (útil si el backend corre en otro host/puerto, p.ej. Docker: host.docker.internal)
API_URL = os.environ.get("ECODELIVERY_API_URL", "http://localhost:3000/pedidos")

# Ruta al CSV semilla, usado como fuente de respaldo si la API no responde
CSV_SEMILLA_PATH = os.environ.get(
    "ECODELIVERY_CSV_SEMILLA",
    "/opt/ecodelivery/dataset_pedidos_semilla.csv",
)

# Carpeta y archivo de salida del reporte (fuente del dashboard de Power BI)
OUTPUT_DIR = os.environ.get(
    "ECODELIVERY_OUTPUT_DIR",
    "/opt/ecodelivery/powerbi",
)
OUTPUT_PATH = os.path.join(OUTPUT_DIR, "reporte_pedidos.csv")

XCOM_KEY_RAW = "pedidos_crudos"
XCOM_KEY_METRICAS = "metricas_calculadas"

default_args = {
    "owner": "ecodelivery-data-team",
    "retries": 1,
    "retry_delay": timedelta(minutes=2),
}


# ---------------------------------------------------------------------------
# Tarea 1: EXTRACCIÓN
# ---------------------------------------------------------------------------
def extraer_pedidos(**context):
    """
    Intenta traer los pedidos desde GET /pedidos del backend.
    Si el backend no responde (p.ej. no está corriendo), cae al CSV semilla.
    """
    pedidos = []

    try:
        with urllib.request.urlopen(API_URL, timeout=5) as response:
            data = json.loads(response.read().decode("utf-8"))
            pedidos = data
            print(f"[extraer_pedidos] {len(pedidos)} pedidos obtenidos desde la API: {API_URL}")
    except (urllib.error.URLError, urllib.error.HTTPError, ConnectionError, TimeoutError) as e:
        print(f"[extraer_pedidos] API no disponible ({e}). Usando CSV semilla como respaldo.")
        with open(CSV_SEMILLA_PATH, newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            pedidos = list(reader)
        print(f"[extraer_pedidos] {len(pedidos)} pedidos leídos desde {CSV_SEMILLA_PATH}")

    if not pedidos:
        raise ValueError("No se pudo extraer ningún pedido (ni de la API ni del CSV semilla).")

    context["ti"].xcom_push(key=XCOM_KEY_RAW, value=pedidos)


# ---------------------------------------------------------------------------
# Tarea 2: TRANSFORMACIÓN
# ---------------------------------------------------------------------------
def transformar_pedidos(**context):
    """
    Calcula, a partir de los pedidos crudos:
      1. Tiempo promedio de entrega (minutos) por zona, solo estado='entregado'
      2. Cantidad de pedidos por estado
      3. Ingresos totales (monto) por zona
    """
    ti = context["ti"]
    pedidos = ti.xcom_pull(key=XCOM_KEY_RAW, task_ids="extraer_pedidos")

    zonas = ["Norte", "Sur", "Centro", "Occidente", "Chapinero"]
    estados = ["pendiente", "en_camino", "entregado", "cancelado"]

    # --- 1. Tiempo promedio de entrega por zona (solo entregados) ---
    tiempos_por_zona = {z: [] for z in zonas}
    for p in pedidos:
        if p.get("estado") == "entregado" and p.get("fecha_entrega") and p.get("fecha_creacion"):
            try:
                f_creacion = _parse_fecha(p["fecha_creacion"])
                f_entrega = _parse_fecha(p["fecha_entrega"])
                minutos = (f_entrega - f_creacion).total_seconds() / 60.0
                if minutos >= 0 and p.get("zona") in tiempos_por_zona:
                    tiempos_por_zona[p["zona"]].append(minutos)
            except Exception as e:
                print(f"[transformar_pedidos] No se pudo calcular tiempo de entrega para pedido {p.get('id_pedido')}: {e}")

    tiempo_promedio_por_zona = {
        z: (round(sum(t) / len(t), 2) if t else None) for z, t in tiempos_por_zona.items()
    }

    # --- 2. Cantidad de pedidos por estado ---
    conteo_por_estado = {e: 0 for e in estados}
    for p in pedidos:
        estado = p.get("estado")
        if estado in conteo_por_estado:
            conteo_por_estado[estado] += 1

    # --- 3. Ingresos totales (monto) por zona ---
    ingresos_por_zona = {z: 0.0 for z in zonas}
    for p in pedidos:
        zona = p.get("zona")
        try:
            monto = float(p.get("monto") or 0)
        except (TypeError, ValueError):
            monto = 0.0
        if zona in ingresos_por_zona:
            ingresos_por_zona[zona] += monto

    ingresos_por_zona = {z: round(v, 2) for z, v in ingresos_por_zona.items()}

    resultado = {
        "tiempo_promedio_entrega_por_zona": tiempo_promedio_por_zona,
        "conteo_pedidos_por_estado": conteo_por_estado,
        "ingresos_totales_por_zona": ingresos_por_zona,
        "total_pedidos": len(pedidos),
    }

    print("[transformar_pedidos] Métricas calculadas:")
    print(json.dumps(resultado, indent=2, ensure_ascii=False))

    ti.xcom_push(key=XCOM_KEY_METRICAS, value=resultado)


def _parse_fecha(valor):
    """Parsea fechas ISO 8601 con o sin sufijo 'Z' / milisegundos."""
    valor = valor.replace("Z", "+00:00")
    return datetime.fromisoformat(valor)


# ---------------------------------------------------------------------------
# Tarea 3: CARGA
# ---------------------------------------------------------------------------
def cargar_reporte(**context):
    """
    Escribe reporte_pedidos.csv con una fila por combinación zona/métrica,
    en formato "largo" (tidy), fácil de consumir desde Power BI.
    """
    ti = context["ti"]
    metricas = ti.xcom_pull(key=XCOM_KEY_METRICAS, task_ids="transformar_pedidos")

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    zonas = ["Norte", "Sur", "Centro", "Occidente", "Chapinero"]
    estados = ["pendiente", "en_camino", "entregado", "cancelado"]

    filas = []
    fecha_reporte = context["ds"]  # fecha lógica de ejecución del DAG (YYYY-MM-DD)

    for z in zonas:
        filas.append({
            "fecha_reporte": fecha_reporte,
            "tipo_metrica": "tiempo_promedio_entrega_min",
            "dimension": "zona",
            "categoria": z,
            "valor": metricas["tiempo_promedio_entrega_por_zona"].get(z),
        })
        filas.append({
            "fecha_reporte": fecha_reporte,
            "tipo_metrica": "ingresos_totales",
            "dimension": "zona",
            "categoria": z,
            "valor": metricas["ingresos_totales_por_zona"].get(z),
        })

    for e in estados:
        filas.append({
            "fecha_reporte": fecha_reporte,
            "tipo_metrica": "cantidad_pedidos",
            "dimension": "estado",
            "categoria": e,
            "valor": metricas["conteo_pedidos_por_estado"].get(e),
        })

    filas.append({
        "fecha_reporte": fecha_reporte,
        "tipo_metrica": "total_pedidos",
        "dimension": "general",
        "categoria": "total",
        "valor": metricas["total_pedidos"],
    })

    with open(OUTPUT_PATH, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["fecha_reporte", "tipo_metrica", "dimension", "categoria", "valor"])
        writer.writeheader()
        writer.writerows(filas)

    print(f"[cargar_reporte] Reporte generado en: {OUTPUT_PATH} ({len(filas)} filas)")


# ---------------------------------------------------------------------------
# Definición del DAG
# ---------------------------------------------------------------------------
with DAG(
    dag_id="etl_pedidos_diario",
    description="ETL diario de pedidos EcoDelivery: extrae, calcula métricas y genera reporte_pedidos.csv",
    default_args=default_args,
    schedule=None,  # ejecución manual (no se requiere scheduler real, según enunciado)
    start_date=datetime(2026, 1, 1),
    catchup=False,
    tags=["ecodelivery", "etl", "pedidos"],
) as dag:

    t1_extraer = PythonOperator(
        task_id="extraer_pedidos",
        python_callable=extraer_pedidos,
    )

    t2_transformar = PythonOperator(
        task_id="transformar_pedidos",
        python_callable=transformar_pedidos,
    )

    t3_cargar = PythonOperator(
        task_id="cargar_reporte",
        python_callable=cargar_reporte,
    )

    t1_extraer >> t2_transformar >> t3_cargar
