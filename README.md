# Plantilla Python Analytics

Plantilla base para proyectos de **análisis de datos con Python**, diseñada para trabajar con un entorno reproducible utilizando **uv**, **Jupyter Notebooks** y **VS Code**.

---

## Tecnologías

- Python
- uv
- Pandas
- NumPy
- Matplotlib
- Jupyter / ipykernel
- Git
- GitHub
- VS Code

---

## Estructura del proyecto

```text
plantilla_python_analytics/
│
├── assets/
│   ├── images/
│   └── screenshots/
│
├── data/
│   ├── raw/
│   └── processed/
│
├── docs/
├── notebooks/
├── reports/
│
├── src/
│   └── __init__.py
│
├── tests/
│
├── .gitignore
├── .python-version
├── README.md
├── pyproject.toml
└── uv.lock
```

### `assets/`

Recursos visuales del proyecto.

```text
assets/
├── images/       
└── screenshots/  
```

### `data/`

Datos utilizados durante el proyecto.

```text
data/
├── raw/        
└── processed/  
```

### `docs/`

Documentación adicional del proyecto.

### `notebooks/`

Jupyter Notebooks utilizados durante el análisis.

### `reports/`

Resultados generados durante el proyecto.

### `src/`

Código Python reutilizable.

### `tests/`

Pruebas para funciones o módulos desarrollados en `src/`.

---

# Entorno de Python

El proyecto utiliza **uv** para gestionar dependencias y entorno virtual.

La versión de Python utilizada está definida en:

```text
.python-version
```

Las dependencias del proyecto están definidas en:

```text
pyproject.toml
```

Y las versiones exactas instaladas quedan registradas en:

```text
uv.lock
```

El entorno virtual se crea localmente en:

```text
.venv/
```

Este directorio está incluido en `.gitignore` y no se sube a GitHub.

---

# Instalación

## 1. Clonar el repositorio

```bash
git clone <URL_DEL_REPOSITORIO>
```

Entrar en la carpeta:

```bash
cd plantilla_python_analytics
```

## 2. Sincronizar el entorno

```bash
uv sync
```

Este comando instalará las dependencias definidas en el proyecto y creará el entorno virtual si es necesario.

---

# Ejecutar Python

Para ejecutar Python utilizando el entorno del proyecto:

```bash
uv run python
```

Para comprobar la versión:

```bash
uv run python --version
```

---

# Jupyter Notebooks y VS Code

Abrir el proyecto en VS Code.

Al crear o abrir un notebook, seleccionar como intérprete/kernel el entorno virtual del proyecto:

```text
plantilla-python-analytics
.venv/bin/python
```

De esta forma, el notebook utilizará las mismas dependencias definidas en el proyecto.

---

# Dependencias

Las dependencias principales actuales son:

- Pandas
- NumPy
- Matplotlib

Para trabajar con Jupyter se utiliza:

- ipykernel

Las dependencias se gestionan desde `pyproject.toml`.

Para añadir una nueva dependencia al proyecto:

```bash
uv add nombre_paquete
```

Ejemplo:

```bash
uv add seaborn
```

Para añadir una dependencia únicamente para desarrollo:

```bash
uv add --dev nombre_paquete
```

---

## Objetivo de la plantilla

Esta plantilla está diseñada para proyectos de **Data Analytics con Python** .