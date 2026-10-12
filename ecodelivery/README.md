# EcoDelivery S.A.S. — Sistema de Pedidos y Analítica

Solución compuesta por 4 módulos: **backend (API REST)**, **app móvil (Flutter)**,
**pipeline de datos (Airflow)** y **dashboard (Power BI)**, que centralizan y
automatizan la operación de pedidos de la empresa de domicilios ecológicos EcoDelivery S.A.S.

## Estructura del repositorio

```
ecodelivery/
├── backend/                          # API REST (Node.js + Express + SQLite)
│   ├── src/
│   │   ├── db/                       # Conexión, esquema y script de carga (seed)
│   │   ├── middleware/                # Autenticación por API key (opcional)
│   │   ├── models/                    # Lógica de negocio (transiciones de estado)
│   │   ├── routes/                    # Endpoints REST
│   │   └── server.js
│   ├── .env.example
│   └── package.json
├── app_flutter/                      # App móvil (Flutter)
│   └── lib/
│       ├── models/pedido.dart
│       ├── services/api_service.dart
│       ├── screens/                   # login, lista, detalle, crear pedido
│       └── widgets/estado_chip.dart
├── airflow/
│   └── dags/etl_pedidos_diario.py    # DAG con 3 tareas encadenadas
├── powerbi/
│   ├── reporte_pedidos.csv           # Salida del DAG (fuente del dashboard)
│   ├── GUIA_POWERBI.md               # Paso a paso + fórmulas DAX para construir el .pbix
│   └── dashboard_ecodelivery.pbix    # (a construir siguiendo la guía; ver sección 4)
├── dataset_pedidos_semilla.csv       # Dataset de ejemplo (60 pedidos)
└── README.md
```

---

## Inicio rápido — cómo entrar y arrancar el proyecto

Guía mínima para levantar todo desde cero. Los detalles de cada módulo están
en las secciones 1-4 más abajo; esto es solo el camino directo.

### Requisitos previos

| Herramienta | Versión mínima | Para qué |
|---|---|---|
| Node.js | >= 22.5 (verifica con `node -v`) | Backend |
| Flutter SDK | cualquiera reciente (verifica con `flutter --version`) | App móvil |
| Python + Apache Airflow | opcional | Pipeline de datos |
| Power BI Desktop | opcional (solo Windows) | Dashboard |

### Paso 1 — Entrar al proyecto

```bash
cd ecodelivery
```

Esta es la carpeta raíz; todos los comandos de los siguientes pasos parten desde aquí.

### Paso 2 — Levantar el backend (obligatorio, los otros módulos dependen de él)

```bash
cd backend
npm install
npm run seed     # carga dataset_pedidos_semilla.csv en SQLite
npm start        # queda escuchando en http://localhost:3000
```

Deja esta terminal abierta. Verifica en otra terminal:

```bash
curl http://localhost:3000/pedidosn
```

Si ves un JSON con pedidos, el backend está listo.

### Paso 3 — Correr la app Flutter (en una segunda terminal)

```bash
cd app_flutter
flutter pub get
flutter run
```

Antes de correrla revisa `lib/services/api_service.dart` → constante `baseUrl`,
y ajústala según dónde la ejecutes (emulador Android, iOS, dispositivo físico
o Chrome). Ver detalles en la sección 2.

### Paso 4 — (Opcional) Ejecutar el pipeline de Airflow

Con el backend del paso 2 todavía corriendo:

```bash
pip install apache-airflow
export AIRFLOW_HOME=~/airflow
airflow db init
cp airflow/dags/etl_pedidos_diario.py $AIRFLOW_HOME/dags/
airflow dags test etl_pedidos_diario 2026-08-27
```

Esto regenera `powerbi/reporte_pedidos.csv`.

### Paso 5 — (Opcional) Abrir el dashboard de Power BI

Sigue `powerbi/GUIA_POWERBI.md` para construir el `.pbix` usando
`dataset_pedidos_semilla.csv` y `powerbi/reporte_pedidos.csv` como fuentes.

### Resumen del orden

1. `backend` arriba y con datos cargados (`npm run seed && npm start`).
2. `app_flutter` apuntando a esa API (`flutter run`).
3. (Opcional) DAG de Airflow para regenerar el reporte.
4. (Opcional) Dashboard de Power BI leyendo ese reporte.

---

## 1. Backend / API REST

**Stack:** Node.js + Express + SQLite (persistencia real vía el módulo nativo
`node:sqlite`, incluido en Node desde la versión 22.5 — **no requiere instalar
ningún compilador ni Visual Studio Build Tools**, a diferencia de paquetes como
`better-sqlite3`, que necesitan compilación nativa y suelen fallar en Windows
si no tienes las herramientas de C++ instaladas).

**Requisito:** Node.js >= 22.5 (recomendado 22 LTS o superior; funciona también en 24).
Verifica tu versión con `node -v`.

### Instalar y ejecutar

```bash
cd backend
npm install
npm run seed     # carga dataset_pedidos_semilla.csv en la base SQLite (idempotente)
npm start        # levanta el servidor en http://localhost:3000
```

> Verás un `ExperimentalWarning: SQLite is an experimental feature` en la consola.
> Es solo informativo — `node:sqlite` funciona de forma completamente estable
> para este caso de uso, no afecta el funcionamiento de la API.

Verifica que quedó arriba:

```bash
curl http://localhost:3000/
```

### Endpoints

| Método | Ruta                     | Descripción                                              |
|--------|--------------------------|------------------------------------------------------------|
| POST   | `/pedidos`               | Crea un pedido (estado inicial `pendiente`)                |
| GET    | `/pedidos`                | Lista pedidos. Filtros opcionales: `?estado=` y `?zona=`   |
| GET    | `/pedidos/:id`             | Detalle de un pedido                                       |
| PATCH  | `/pedidos/:id/estado`      | Actualiza el estado, validando transiciones lógicas        |

### Ejemplos rápidos (curl)

```bash
# Crear pedido
curl -X POST http://localhost:3000/pedidos \
  -H "Content-Type: application/json" \
  -d '{"cliente":"Pedro Pérez","zona":"Chapinero","metodo_pago":"tarjeta","monto":25000}'

# Listar con filtros
curl "http://localhost:3000/pedidos?estado=pendiente&zona=Norte"

# Avanzar estado
curl -X PATCH http://localhost:3000/pedidos/1/estado \
  -H "Content-Type: application/json" \
  -d '{"estado":"en_camino"}'
```

### Reglas de negocio implementadas

- **Máquina de estados** (`src/models/pedidoModel.js`):
  `pendiente → en_camino → entregado` (y `pendiente`/`en_camino → cancelado`).
  `entregado` y `cancelado` son estados finales: cualquier intento de moverlos
  responde `400 TRANSICION_INVALIDA`.
- Al marcar `entregado`, `fecha_entrega` se registra automáticamente con la hora del servidor.
- Validación de campos requeridos → `400 VALIDATION_ERROR` con el detalle de qué falló.
- Pedido no encontrado → `404 NOT_FOUND`. Creación exitosa → `201`.
- **Autenticación (extra opcional):** los endpoints de escritura (`POST`, `PATCH`) están
  protegidos por un middleware de API key (`src/middleware/auth.js`). Si no defines
  `API_KEY` en `backend/.env`, el middleware se desactiva automáticamente (modo demo,
  para que puedas probar la app/API sin fricción durante la sustentación). Para activarla:
  copia `.env.example` a `.env`, define `API_KEY=alguna-clave`, y envía el header
  `x-api-key: alguna-clave` en cada `POST`/`PATCH`.

---

## 2. App móvil (Flutter)

**Ubicación:** `app_flutter/`. Consume la API real (no hay datos quemados en el código).

### Instalar y ejecutar

Requiere el SDK de Flutter instalado ([flutter.dev](https://flutter.dev)).

```bash
cd app_flutter
flutter pub get
flutter run
```

### Configurar la URL del backend

En `lib/services/api_service.dart`, la constante `baseUrl` está configurada como
`http://10.0.2.2:3000` (así es como el **emulador de Android** accede a `localhost`
de la máquina anfitriona). Ajusta según dónde ejecutes la app:

- Emulador Android → `http://10.0.2.2:3000` (valor por defecto, ya configurado).
- Simulador iOS → `http://localhost:3000`.
- Dispositivo físico → `http://<IP-de-tu-máquina-en-la-red>:3000`.
- Flutter Web (`flutter run -d chrome`) → `http://localhost:3000` (recuerda que CORS
  ya está habilitado en el backend con el paquete `cors`).

### Pantallas

- **Login** (extra opcional): pantalla de entrada simple, sin backend de auth real.
- **Lista de pedidos**: consume `GET /pedidos`, filtros por estado/zona con dropdowns,
  colores por estado, pull-to-refresh, manejo de loading (spinner) y error (mensaje + botón reintentar).
- **Detalle de pedido**: consume `GET /pedidos/:id`, botón dinámico que llama a
  `PATCH /pedidos/:id/estado` para avanzar al siguiente estado lógico.
- **Crear pedido**: formulario con validación básica (campos requeridos, monto numérico > 0)
  que llama a `POST /pedidos`.

---

## 3. Pipeline de datos (Airflow)

**Ubicación:** `airflow/dags/etl_pedidos_diario.py`.

### DAG: `etl_pedidos_diario`

Tres tareas encadenadas: `extraer_pedidos >> transformar_pedidos >> cargar_reporte`.

- **Extraer:** intenta `GET /pedidos` contra el backend (`http://localhost:3000/pedidos`
  por defecto, configurable con la variable de entorno `ECODELIVERY_API_URL`). Si el
  backend no responde, cae automáticamente a `dataset_pedidos_semilla.csv` como respaldo
  (así el DAG siempre es ejecutable, tenga o no el backend levantado).
- **Transformar:** calcula (1) tiempo promedio de entrega en minutos por zona (solo
  pedidos `entregado`), (2) cantidad de pedidos por estado, y (3) ingresos totales por zona.
- **Cargar:** escribe `powerbi/reporte_pedidos.csv` en formato "largo"/tidy
  (`fecha_reporte, tipo_metrica, dimension, categoria, valor`), ideal para consumir desde Power BI.

### Cómo ejecutarlo

**Opción A — Con Airflow instalado:**

```bash
pip install apache-airflow
export AIRFLOW_HOME=~/airflow
airflow db init
cp airflow/dags/etl_pedidos_diario.py $AIRFLOW_HOME/dags/
# opcional: levanta el backend antes para que el DAG lea de la API real
airflow dags test etl_pedidos_diario 2026-08-27
```

O desde la UI (`airflow standalone`): buscar el DAG `etl_pedidos_diario` y darle **Trigger**.

**Opción B — Sin instalar Airflow (verificación de la lógica):**

Las funciones de las 3 tareas son Python puro (usan solo `urllib`, `csv`, `json` de la
librería estándar), así que se pueden ejecutar directamente sin el scheduler de Airflow
si solo quieres validar la lógica de transformación. El archivo `powerbi/reporte_pedidos.csv`
incluido en este repo ya fue generado así, como evidencia de que el pipeline corre correctamente.

---

## 4. Dashboard (Power BI)

**Fuente de datos:** `dataset_pedidos_semilla.csv` (detalle) + `powerbi/reporte_pedidos.csv`
(salida agregada del DAG de Airflow).

Como este entorno de desarrollo no tiene Power BI Desktop instalado (requiere Windows/licencia),
se dejó **`powerbi/GUIA_POWERBI.md`** con el paso a paso exacto —incluyendo las fórmulas
DAX ya escritas para copiar y pegar— para construir el `.pbix` en menos de 15 minutos:

- Gráfico de barras: ingresos por zona.
- Gráfico de líneas: pedidos por día.
- Tarjeta KPI: ticket promedio.
- Slicer por estado.
- Medida DAX propia: `Ticket Promedio` y `Tiempo Promedio Entrega (min)` (ninguna es un
  conteo automático; ambas tienen lógica de negocio: división segura y diferencia de fechas filtrada).

---

## Cómo probar todo el flujo end-to-end (para la sustentación)

1. `cd backend && npm install && npm run seed && npm start`
2. En otra terminal: `curl http://localhost:3000/pedidos` para confirmar que la API responde.
3. Corre la app Flutter (`flutter run`) apuntando al backend y muestra las 3 pantallas
   creando un pedido y avanzando su estado en vivo.
4. Ejecuta el DAG de Airflow (`airflow dags test etl_pedidos_diario 2026-08-27`) con el
   backend arriba, para que la extracción use la API real en lugar del CSV de respaldo.
5. Abre `powerbi/reporte_pedidos.csv` recién generado y muéstralo como fuente del dashboard.

---

## Supuestos tomados sobre el caso de negocio

- El **id_pedido** es autoincremental generado por SQLite (`INTEGER PRIMARY KEY AUTOINCREMENT`),
  no un UUID, para simplificar la demo y las URLs de la API.
- Las transiciones de estado válidas se definieron como:
  `pendiente → en_camino → entregado`, y tanto `pendiente` como `en_camino` pueden
  cancelarse. `entregado` y `cancelado` son estados finales. Se asumió que un pedido
  cancelado nunca puede "revivir" a otro estado.
- El campo `repartidor` es opcional al crear el pedido (nulo hasta que se asigna); se
  puede fijar manualmente al enviar `PATCH /estado` con el campo `repartidor` en el body,
  o quedar sin asignar y asignarse después en una iteración futura (no se construyó un
  endpoint separado `PATCH /pedidos/:id/repartidor` porque el enunciado no lo exige).
- Los montos se asumieron en pesos colombianos (COP), sin decimales, acorde al contexto
  de la empresa ficticia.
- El pipeline de Airflow se diseñó para ejecutarse **una vez al día** (de ahí "diario"),
  generando una foto (snapshot) de las métricas del día de ejecución (`fecha_reporte`);
  no es un proceso incremental que acumule histórico entre corridas.
- El dashboard usa el **dataset de detalle** (`dataset_pedidos_semilla.csv`) como fuente
  principal para los gráficos que necesitan grano fino (pedidos por día, por ejemplo),
  y el **reporte agregado de Airflow** (`reporte_pedidos.csv`) como evidencia de
  trazabilidad del pipeline, ya que el enunciado permite usar cualquiera de los dos.

## Qué quedó incompleto y por qué

- **`dashboard_ecodelivery.pbix`**: no se generó el binario porque el entorno de
  desarrollo no cuenta con Power BI Desktop instalado (aplicación de escritorio Windows
  con licencia). En su lugar se dejó `powerbi/GUIA_POWERBI.md` con instrucciones exactas
  y las medidas DAX ya redactadas, y `powerbi/reporte_pedidos.csv` ya generado y listo
  para importar. Construirlo toma ~15 minutos siguiendo la guía.
- **La app Flutter no se compiló/ejecutó en un emulador** dentro de este entorno (no hay
  SDK de Flutter ni emulador Android/iOS disponibles aquí). El código sí está completo,
  revisado sintácticamente y sigue las buenas prácticas de Flutter (separación en
  models/services/screens/widgets, `FutureBuilder` para estados de carga/error, etc.).
  Se recomienda correr `flutter pub get && flutter run` en una máquina con el SDK instalado
  antes de la sustentación para confirmar visualmente.
- **Scheduler real de Airflow**: el DAG no se dejó corriendo con un scheduler en segundo
  plano (el enunciado indica explícitamente que no es necesario); se valida con
  `airflow dags test` o disparo manual desde la UI.
- **Autenticación JWT completa**: se implementó la versión más simple (API key por header),
  suficiente para cumplir el requisito "extra opcional" sin añadir complejidad de
  manejo de tokens/expiración que no aportaba valor a esta prueba.
- **Driver de base de datos**: se eligió `node:sqlite` (nativo de Node.js) en lugar de
  `better-sqlite3` a propósito, porque este último requiere compilar código C++ al
  instalarse (via `node-gyp`), lo que falla en Windows si no se tiene Visual Studio
  Build Tools instalado. `node:sqlite` ofrece la misma API síncrona (`prepare`, `run`,
  `get`, `all`) sin ninguna dependencia externa que compilar, garantizando que
  `npm install` funcione en cualquier máquina sin configuración adicional.
