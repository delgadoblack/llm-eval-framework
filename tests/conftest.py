"""
tests/conftest.py - Configuración global de PyTest y Validación Temprana (Gatekeeper).

Responsabilidades:
1. Carga los casos de prueba desde data/test_cases.json.
2. Hook pytest_sessionstart: Puerta de validación (Gatekeeper) de las APIs.
3. Hook pytest_runtest_logreport: Acumula resultados en tiempo real.
4. Hook pytest_sessionfinish: Escribe el reporte JSON definitivo.
"""

from __future__ import annotations

import json
import logging
import os
import time
from pathlib import Path
from typing import Any

import pytest

# Importacion POM desde nuestro paquete logico
from src.clients.openrouter_client import GeneratorClient, JudgeClient

logger = logging.getLogger(__name__)

# Rutas Absolutas para Patron POM de Datos
ROOT_DIR  = Path(__file__).resolve().parent.parent
TEST_CASES_FILE  = Path(__file__).resolve().parent / "data" / "test_cases.json"
REPORTS_DIR = ROOT_DIR / "reports"
REPORT_FILE = REPORTS_DIR / "report.json"
TRANSCRIPTS_FILE = REPORTS_DIR / "transcripts.md"

# Carga de casos de prueba
def _load_test_cases() -> list[dict[str, Any]]:
    if not TEST_CASES_FILE.exists():
        raise FileNotFoundError(
            f"No se encontró el archivo de casos de prueba en: {TEST_CASES_FILE}"
        )
    with TEST_CASES_FILE.open(encoding="utf-8") as fh:
        cases = json.load(fh)
    if not isinstance(cases, list) or not cases:
        raise ValueError("test_cases.json debe ser una lista no vacía.")
    return cases


@pytest.fixture(scope="session")
def test_cases() -> list[dict[str, Any]]:
    """Fixture de sesión: lista de casos desde tests/data/test_cases.json."""
    return _load_test_cases()

# Almacen de resultados (Estado de la Sesion)
_session_results: list[dict[str, Any]] = []
_session_start_ts: float = 0.0

# Hook: Inicializacion de Sesion y Gatekeeper
def pytest_sessionstart(session: pytest.Session) -> None:
    global _session_start_ts
    _session_start_ts = time.time()
    _session_results.clear()
    REPORTS_DIR.mkdir(exist_ok=True)

    # Reinicia transcripts.md de forma limpia al inicio de la corrida
    TRANSCRIPTS_FILE.write_text(
        f"# Transcripciones completas — sesión {time.strftime('%Y-%m-%d %H:%M:%S')}\n\n",
        encoding="utf-8",
    )

    logger.info("PyTest sesion iniciada, reportes en: %s", REPORTS_DIR)

    # Validacion de apis antes de ejecutar la suite (gatekeeper)
    print("\n[VALIDACION] Verificando conectividad con OpenRouter (Modelos A y B)...")

    # 1 Validar cliente generador (Modelo A)
    try:
        gen_client = GeneratorClient()
        resp = gen_client.generate_response("ping")
        gen_client.close()
        if not resp.content:
            raise ValueError("El generador retornó una respuesta vacía.")
    except Exception as exc:
        pytest.exit(
            f"\n[ERROR EN API A] Falló la validación del generador (amazon/nova-2-lite-v1)\n"
            f"Detalles: {exc}\n"
            f"Abortando la suite completa para preservar consistencia y cuotas",
            returncode=1
        )

    # 2 Validar cliente judge (Modelo B)
    try:
        judg_client = JudgeClient()
        verdict = judg_client.evaluate(user_query="ping", bot_response="El paciente está sano")
        judg_client.close()
        if not verdict.score:
            raise ValueError("El juez no generó un veredicto válido")
    except Exception as exc:
        pytest.exit(
            f"\n[ERROR EN API B] Falló la validación del juez (google/gemini-3.5-flash)\n"
            f"Detalles: {exc}\n"
            f"Abortando la suite completa para preservar consistencia y cuotas",
            returncode=1
        )    
        
    print("[VALIDACIÓN] Enlaces verificados con éxito. Iniciando suite de pruebas...\n")


# Hook: Captura el resultado de cada test en ejecucion
def pytest_runtest_logreport(report: pytest.TestReport) -> None:
    if report.when != "call":
        return

    node_id   = report.nodeid
    test_name = node_id.split("::")[-1]

    case_id = None
    if "[" in test_name and test_name.endswith("]"):
        case_id = test_name[test_name.index("[") + 1 : -1]

    outcome = report.outcome  # "passed" | "failed" | "error"

    failure_message: str | None = None
    if report.failed and report.longrepr:
        failure_message = str(report.longrepr).strip()
        if len(failure_message) > 600:
            failure_message = failure_message[:600] + "…"

    _session_results.append(
        {
            "test_name": test_name,
            "case_id": case_id,
            "outcome": outcome,
            "duration_sec": round(report.duration, 3),
            "failure_message": failure_message,
        }
    )

# Hook: Cierre de Sesion y Escritura del Reporte
def pytest_sessionfinish(session: pytest.Session, exitstatus: int) -> None:
    total_duration = round(time.time() - _session_start_ts, 2)

    passed = [r for r in _session_results if r["outcome"] == "passed"]
    failed = [r for r in _session_results if r["outcome"] == "failed"]
    errored = [r for r in _session_results if r["outcome"] == "error"]

    report = {
        "meta": {
            "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "total_duration_sec": total_duration,
            "exit_status": exitstatus,
            "python_env": os.environ.get("VIRTUAL_ENV", "default"),
        },
        "summary": {
            "total": len(_session_results),
            "passed": len(passed),
            "failed": len(failed),
            "errored": len(errored),
            "pass_rate_pct": (
                round(len(passed) / len(_session_results) * 100, 1)
                if _session_results else 0.0
            ),
        },
        "results": _session_results,
    }

    with REPORT_FILE.open("w", encoding="utf-8") as fh:
        json.dump(report, fh, ensure_ascii=False, indent=2)

    logger.info(
        "Reporte escrito en %s — %d/%d passed (%.1f%%)",
        REPORT_FILE,
        len(passed),
        len(_session_results),
        report["summary"]["pass_rate_pct"],
    )