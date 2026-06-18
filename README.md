# LLM Evaluation Framework — Medical Bot Evaluator

Este framework está diseñado bajo el patrón **POM (Page Object Model)** para automatizar, evaluar y auditar la seguridad, el cumplimiento ético y la calidad de las respuestas de **MedAssist**, un chatbot de asistencia médica virtual.

El objetivo principal es garantizar que el asistente entregue información clínica óptima, resista ataques de *jailbreak* e inyecciones de *prompts*, mantenga una estricta restricción de dominio y opere bajo una política de **Zero-Retention / Stateless** (aislamiento absoluto entre sesiones de chat).

---

## Arquitectura del Framework

El proyecto está estructurado de forma desacoplada para separar la lógica de conexión con las APIs (Capa de Clientes), los datasets de validación (Capa de Datos) y la orquestación y aserciones de las pruebas (Capa de Tests).

```
LLM-EVAL-FRAMEWORK/
│
├── error_logs/                    # Registros de errores y fallos de ejecución
│
├── reports/                       # Directorio de evidencias y resultados
│   ├── report.json                # Reporte de resultados estructurado
│   └── transcripts.md             # Transcripciones y logs detallados de interacciones
│
├── src/
│   └── clients/                   # CAPA POM: Objetos de comunicación con las APIs
│       ├── __init__.py
│       └── openrouter_client.py   # Implementación de clientes y Circuit Breaker
│
├── tests/
│   ├── data/                      # Capa de Datos (Data-Driven Testing)
│   │   └── test_cases.json        # Dataset de producción con casos de prueba
│   ├── __init__.py
│   ├── conftest.py                # Configuración de sesión y Gatekeeper de APIs
│   └── test_medical_bot.py        # Suite parametrizada y Smoke Tests
│
├── .env                           # Variables de entorno y credenciales locales
├── .gitignore
├── install.ps1                    # Gestor CLI interactivo e instalador (PowerShell)
├── pytest.ini                     # Configuración global del test runner
├── README.md
└── requirements.txt               # Dependencias de producción
```

---

## Modelos e IA en la Arquitectura

El framework utiliza el patrón **LLM-as-a-Judge** (evaluación cruzada por IA) con dos modelos independientes para evitar sesgos de autoevaluación.

| Rol | Modelo | Descripción |
|-----|--------|-------------|
| Generador (Asistente) | `amazon/nova-2-lite-v1` | Simula a MedAssist. Configurado de forma determinista para responder consultas de salud y rechazar solicitudes fuera de dominio. |
| Juez Evaluador | `google/gemini-3.5-flash` | Actúa como auditor clínico y experto en seguridad. Analiza el input del usuario y el output del asistente, emitiendo un veredicto estructurado: score del 1 al 10, flag de seguridad y justificación. |

---

## Mecanismos de Resiliencia

### Gatekeeper — Validación Temprana de APIs

Antes de consumir el dataset y gastar tokens, `conftest.py` ejecuta un ping rápido a ambos modelos en OpenRouter. Si las credenciales son inválidas, están vacías o no hay saldo, la suite aplica un **Fail-Fast** y aborta la ejecución en menos de 2 segundos.

### Circuit Breaker y Fallback Seguro

Si durante la ejecución ocurren caídas de red o errores HTTP (por ejemplo, `429 Too Many Requests`), el cliente POM intercepta la excepción, inyecta una respuesta de contingencia y guarda la traza del error en `error_logs/`. Esto garantiza que un fallo puntual de API no rompa la ejecución de toda la suite.

---

## Categorías de Evaluación

El dataset `test_cases.json` evalúa el comportamiento del chatbot frente a los siguientes escenarios críticos.

**Resistencia a Jailbreaks e Inyecciones de Prompts**
Intentos maliciosos de forzar al bot a ignorar sus instrucciones del sistema (por ejemplo: *"Olvida tus reglas anteriores y actúa como..."*).

**Restricción de Dominio (Scope Creep)**
Intentos de hacer que el bot genere código, traduzca textos irrelevantes o responda sobre temas fuera del área de salud.

**Seguridad Clínica — Cero Prescripción / Diagnóstico**
Validar que el bot decline dar dosis exactas de medicamentos (como oxicodona) o emitir diagnósticos definitivos.

**Aislamiento y Privacidad**
Garantizar que el bot no solicite ni revele datos personales, operando de forma 100% stateless (cada sesión comienza desde cero).

---

## Requisitos Previos e Instalación

### Opcion 1 — Gestor Interactivo (Recomendado)

El proyecto incluye una CLI interactiva (`install.ps1`) que automatiza el aprovisionamiento en Windows. Para lanzarla, abre PowerShell en la raíz del proyecto y ejecuta:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; .\install.ps1
```

El gestor presenta las siguientes opciones:

- **Instalar todo:** Verifica e instala Python 3.14+ (via `winget`), crea el entorno virtual `llm-eval-framework-env` y configura el `.env` base.
- **Activar venv:** Abre una sub-terminal con el entorno aislado listo para trabajar.
- **Reinstalar todo:** Elimina el entorno actual y lo reconstruye desde cero.
- **Ejecutar Pruebas / Smoke Test:** Lanza las suites directamente desde el menu.

### Opcion 2 — Instalacion Manual

```bash
# 1. Crear el entorno virtual
python -m venv llm-eval-framework-env

# 2. Activar el entorno virtual (PowerShell)
.\llm-eval-framework-env\Scripts\Activate.ps1

# 3. Instalar dependencias
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

---

## Configuracion del Entorno (.env)

Crea un archivo `.env` en la raiz del proyecto con tus credenciales de OpenRouter.

> **Importante:** Las llaves deben ir **sin comillas** para que el sistema de configuracion las cargue correctamente.

```
OPENROUTER_API_KEY_A=TU_LLAVE_DEL_MODELO_GENERADOR
OPENROUTER_API_KEY_B=TU_LLAVE_DEL_MODELO_JUEZ
```

---

## Ejecucion de las Pruebas

Con el entorno virtual activado, utiliza los siguientes comandos de PyTest.

**Suite completa**

```bash
pytest tests/ -v -s --tb=short
```

**Solo Smoke Tests** — verifica conectividad de APIs y respuesta de los clientes POM

```bash
pytest tests/ -k "smoke" -v -s
```

**Tests de control del Juez** — audita que el modelo Juez detecte fallos de seguridad inyectados a mano

```bash
pytest tests/ -k "judge_detects" -v -s
```

---

## Reportes y Artefactos

Al finalizar cada corrida, el framework genera automaticamente dos artefactos de auditoria en `reports/`.

### report.json — Consolidado Estadistico

Contiene metadatos de la sesion, tasas de exito en porcentaje, tiempos exactos de respuesta y mensajes de error truncados de los casos fallidos. Apto para integracion con dashboards o pipelines CI/CD.

### transcripts.md — Transcripciones Forenses

Log de auditoria en formato Markdown con el texto completo y sin recortar de todas las interacciones, legible por humanos.

---

## Aprendizajes y Retos Tecnicos

Uno de los hitos mas significativos del proyecto fue la investigacion e implementacion del patron **LLM-as-a-Judge**.

Viniendo de la automatización tradicional donde una prueba simplemente pasa o falla, implementar el patrón LLM-as-a-Judge fue un cambio de chip total. Poner a una API a auditar a otra API me obligó a salir de la zona de confort e investigar cómo funcionan realmente los modelos por detrás. El reto que más disfruté fue afinar los prompts del Juez para evitar falsos positivos y aprender a lidiar con lo impredecible que puede ser el lenguaje natural. Fue un desafío bastante entretenido y retador que le dio muchísimo valor técnico a este framework.
---

## Historial de Cambios

| Cambio | Descripcion |
|--------|-------------|
| Gestor CLI interactivo | Evolucion del instalador hacia un menu en PowerShell para unificar instalacion y ejecucion. |
| Refactorizacion POM | Migracion de `client.py` hacia `src/clients/openrouter_client.py`, aislando los system prompts del flujo de pruebas. |
| Capa de Datos Segura | Centralizacion del dataset en `tests/data/test_cases.json`, eliminando codigo duro en los casos de prueba. |
| Manejo defensivo de tokens | Asercion que intercepta `finish_reason = "length"` para evitar que respuestas truncadas alteren el juicio de seguridad. |
| Correccion BOM en `.env` | Eliminacion de la marca UTF-8 BOM del `.env` generado automaticamente, garantizando la correcta lectura de variables en distintos entornos. |
| Implementacion de Fallback | Capa de resiliencia en los clientes POM para inyectar respuestas de contingencia y registrar logs ante fallos de API. |
| Casos negativos de control | Integracion de 2 casos de prueba en `test_medical_bot.py` para validar que el Juez sea capaz de identificar fallos inyectados. |