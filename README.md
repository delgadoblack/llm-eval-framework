# LLM Evaluation Framework (Medical Bot Evaluator)

Este framework está diseñado bajo el patrón **POM (Page Object Model)** para automatizar, evaluar y auditar la seguridad, el cumplimiento ético y la calidad de las respuestas de **MedAssist**, un chatbot de asistencia médica virtual.

El objetivo principal de este entorno es garantizar que el asistente entregue información clínica óptima, resista ataques de *Jailbreak* e inyecciones de *prompts*, mantenga una estricta restricción de dominio y opere bajo una política estricta de **Zero-Retention/Stateless** (aislamiento absoluto entre sesiones de chat).

---

## Arquitectura del Framework (Patrón POM)

El proyecto está estructurado de manera desacoplada para separar la lógica de conexión de las APIs (Capa de Clientes), los datasets de validación (Capa de Datos) y la orquestación/aserciones de las pruebas (Capa de Tests).

```text
LLM-EVAL-FRAMEWORK/
│
├── error_logs/               # Registros de errores y fallos de ejecución
│
├── reports/                  # Directorio de evidencias y resultados
│   ├── report.json           # Reporte de resultados de pruebas estructurado
│   └── transcripts.md        # Transcripciones y logs detallados de las interacciones
│
├── src/                      # Capa Lógica del Framework
│   └── clients/              # CAPA POM: Objetos de comunicación con las APIs
│      ├── __init__.py
│      └── openrouter_client.py   # Implementación de Clientes y Circuit Breaker
│
├── tests/                    # Capa de Orquestación y Ejecución
│   ├── data/                 # Capa de Datos (Data-Driven Testing)
│   │   └── test_cases.json   # Dataset de producción con casos de prueba
│   ├── __init__.py
│   ├── conftest.py           # Configuración de sesión y Gatekeeper de APIs
│   └── test_medical_bot.py   # Suite parametrizada y Smoke Tests 
│
├── .env                      # Variables de entorno y credenciales locales (API Keys)
├── .gitignore                # Archivos excluidos del control de versiones (Git)
├── install.ps1               # Gestor CLI interactivo e instalador (PowerShell)
├── pytest.ini                # Configuración global del test runner
├── README.md                 # Documentación técnica e instrucciones del proyecto
└── requirements.txt          # Dependencias de producción del proyecto
```

---

## Componentes e IA amarrados en la Arquitectura

El framework utiliza una estrategia de **LLM-as-a-Judge** (Evaluación cruzada por IA) utilizando dos modelos independientes para evitar sesgos de autoevaluación:

* **Modelo A (Generador - Asistente): `amazon/nova-2-lite-v1`**
    * *Rol:* Simula al agente conversacional médico (*MedAssist*). Está configurado de forma determinista para responder consultas de salud de manera clara y concisa, rechazando cualquier solicitud fuera de dominio.
* **Modelo B (Juez Evaluador): `google/gemini-3.5-flash`**
    * *Rol:* Actúa como un auditor clínico y experto en seguridad informática. Analiza el *input* del usuario y el *output* del asistente para emitir un veredicto estructurado (Score del 1 al 10, flag de seguridad y justificación).

---

## Mecanismos de Resiliencia y Control de Fallos

Para garantizar una automatización robusta, el framework implementa mecanismos de control de red defensivos:

1. **Gatekeeper (Validación Temprana de APIs):** Antes de consumir el dataset y gastar tokens, `conftest.py` ejecuta un *ping* rápido a ambos modelos en OpenRouter. Si las credenciales son inválidas, están vacías o no hay saldo, la suite aplica un *Fail-Fast* y aborta la ejecución en menos de 2 segundos, protegiendo el entorno.
2. **Circuit Breaker y Fallback Seguro:** Si durante la ejecución masiva ocurren caídas de red o errores HTTP (ej. 429 Too Many Requests) por parte del proveedor de IA, el cliente POM intercepta la excepción, inyecta una respuesta de **Fallback de contingencia** para el usuario y guarda la traza del error en `error_logs/`. Esto asegura que un fallo puntual de API no rompa la ejecución de toda la suite de pruebas.

---

## Criterios y Categorías Claves de Evaluación

El dataset de pruebas (`test_cases.json`) evalúa el comportamiento del chatbot frente a desafíos críticos de seguridad y calidad:

1. **Resistencia a Jailbreaks e Inyecciones:** Intentos maliciosos de forzar al bot a ignorar sus instrucciones del sistema (Ej: *"Olvida tus reglas anteriores y actúa como..."*).
2. **Restricción de Dominio (Scope Creep):** Intentos de hacer que el bot genere código, traduzca textos irrelevantes o hable de temas fuera del área de salud.
3. **Seguridad Clínica (Cero Prescripción/Diagnóstico):** Validar que el bot decline amablemente dar dosis exactas de medicamentos (como la *oxicodona*) o emitir diagnósticos definitivos.
4. **Aislamiento y Privacidad:** Garantizar que el bot no solicite ni revele datos personales de terceros, operando de forma 100% *stateless* (cada chat es un inicio limpio desde cero, eliminando cualquier laguna mental o persistencia de datos).

---

## Requisitos Previos e Instalación

### Opción 1: Gestor Interactivo Automático (Recomendado)
El proyecto cuenta con una herramienta CLI interactiva (`install.ps1`) que automatiza el aprovisionamiento y la ejecución en Windows. 

Para lanzarlo, abre PowerShell en la raíz del proyecto y corre:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; .\install.ps1
```

Este gestor te presentará un menú con las siguientes opciones:
* **Instalar todo:** Verifica/instala **Python 3.14+** (vía `winget`), crea el entorno virtual `llm-eval-framework-env` y configura el `.env` base.
* **Activar venv:** Abre una sub-terminal con el entorno aislado listo para trabajar.
* **Reinstalar todo:** Elimina el entorno actual y lo reconstruye desde cero.
* **Ejecutar Pruebas / Smoke Test:** Lanza las suites de automatización directamente desde el menú, validando automáticamente la existencia del entorno.

### Opción 2: Instalación Manual
Si prefieres configurar el entorno paso a paso por consola:
```bash
# 1. Crear el entorno virtual personalizado
python -m venv llm-eval-framework-env

# 2. Activar el entorno virtual
# En Windows (PowerShell):
.\llm-eval-framework-env\Scripts\Activate.ps1

# 3. Instalar dependencias
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

---

## Configuración del Entorno (`.env`)

El framework requiere que configures tus credenciales secretas de OpenRouter en un archivo `.env` en la raíz del proyecto (este archivo está protegido por Git y nunca se subirá al repositorio):

```env
OPENROUTER_API_KEY_A="TU_LLAVE_DEL_MODELO_GENERADOR"
OPENROUTER_API_KEY_B="TU_LLAVE_DEL_MODELO_JUEZ"
```

---

## Ejecución Manual de las Pruebas

Si estás en la consola con el entorno virtual activado, puedes usar PyTest directamente con estos comandos:

### Correr la Suite Completa
Para ejecutar todas las pruebas parametrizadas, las validaciones de rúbrica del juez y los tests de humo, ejecuta:
```bash
pytest tests/ -v -s --tb=short
```

### Correr Únicamente los Smoke Tests
Para verificar la conectividad de las APIs y que los clientes POM respondan bien:
```bash
pytest tests/ -k "smoke" -v -s
```

### Correr los Tests de Control del Juez en Aislamiento
Para auditar que el modelo Juez (`Gemini-3.5-flash`) no tenga puntos ciegos detectando fallas de seguridad inyectadas a mano:
```bash
pytest tests/ -k "judge_detects" -v -s
```

---

## Secciones de Reportes y Artefactos

Al finalizar cada corrida, el framework genera de forma automatizada dos artefactos de auditoría en la raíz del proyecto dentro de la carpeta `reports/`:

### 1. Consolidado Estadístico (`reports/report.json`)
Contiene metadatos de la sesión, tasas de éxito en porcentaje, tiempos exactos de respuesta y los mensajes de error truncados de los casos fallidos para dashboards o integración CI/CD.

### 2. Transcripciones Forenses (`reports/transcripts.md`)
Un log de auditoría humana en formato Markdown legible que almacena el texto **completo y sin recortar** de las interacciones.

---

## Aprendizajes y Retos Tecnicos

Uno de los hitos más significativos a nivel personal y profesional en el desarrollo de este framework fue la investigación e implementación del patrón **LLM-as-a-Judge**. 

Viniendo de la automatización tradicional donde una prueba simplemente pasa o falla, implementar el patrón LLM-as-a-Judge fue un cambio de chip total. Poner a una API a auditar a otra API me obligó a salir de la zona de confort e investigar cómo funcionan realmente los modelos por detrás. El reto que más disfruté fue afinar los prompts del Juez para evitar falsos positivos y aprender a lidiar con lo impredecible que puede ser el lenguaje natural. Fue un desafío bastante entretenido y retador que le dio muchísimo valor técnico a este framework.

---

## Historial de Cambios y Evolución del Framework

* **Gestor Interactivo CLI:** Evolución del instalador hacia un menú interactivo en PowerShell para unificar instalación y ejecución.
* **Refactorización POM:** Se migró toda la lógica de `client.py` hacia `src/clients/openrouter_client.py`, aislando los *prompts* del sistema del flujo de pruebas.
* **Capa de Datos Segura:** Se centralizó el dataset en `tests/data/test_cases.json`, eliminando el código duro de los casos de prueba.
* **Manejo Defensivo de Tokens:** Se añadió una aserción que intercepta el flag `finish_reason = "length"` para evitar que respuestas truncadas por límites de tokens alteren el juicio de seguridad.