import importlib.util
from pathlib import Path

import pytest

SCRIPT_PATH = (
    Path(__file__).resolve().parents[2] / "scripts" / "medir_rendimiento.py"
)


def _script():
    spec = importlib.util.spec_from_file_location(
        "medir_rendimiento_script", SCRIPT_PATH
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_target_acepta_host_de_loopback_autorizado():
    script = _script()
    target = script._validate_target(
        "http://127.0.0.1:8014/trips/", script.DEFAULT_ALLOWED_HOSTS
    )
    assert target.host == "127.0.0.1"


def test_target_requiere_autorizacion_explicita_para_host_externo():
    script = _script()
    url = "https://routb.iscoutb.dev/trips/"

    with pytest.raises(ValueError):
        script._validate_target(url, script.DEFAULT_ALLOWED_HOSTS)

    target = script._validate_target(
        url, script.DEFAULT_ALLOWED_HOSTS | {"routb.iscoutb.dev"}
    )
    assert target.host == "routb.iscoutb.dev"


@pytest.mark.parametrize(
    "url",
    [
        "ftp://127.0.0.1/trips/",
        "file:///etc/passwd",
        "http://user:secret@127.0.0.1/trips/",
        "http://127.0.0.1@evil.example/trips/",
        "https://evil.example/trips/",
        "http://localhost.evil.example/trips/",
    ],
)
def test_target_rechaza_esquemas_credenciales_y_hosts_no_autorizados(url):
    script = _script()
    with pytest.raises(ValueError):
        script._validate_target(url, script.DEFAULT_ALLOWED_HOSTS)


def test_output_acepta_archivo_dentro_de_evidencia():
    script = _script()
    output = script._validate_output_path(
        "docs/evidencia/medicion-semana14-prueba.json"
    )
    assert output == script.EVIDENCE_DIR / "medicion-semana14-prueba.json"


@pytest.mark.parametrize(
    "output",
    [
        "docs/medicion.json",
        "docs/evidencia/../medicion.json",
        "../medicion.json",
    ],
)
def test_output_rechaza_rutas_fuera_de_evidencia(output):
    script = _script()
    with pytest.raises(ValueError):
        script._validate_output_path(output)


def test_output_rechaza_el_directorio_de_evidencia():
    script = _script()
    with pytest.raises(ValueError):
        script._validate_output_path("docs/evidencia")


def test_output_rechaza_ruta_absoluta_externa(tmp_path):
    script = _script()
    with pytest.raises(ValueError):
        script._validate_output_path(str(tmp_path / "medicion.json"))
