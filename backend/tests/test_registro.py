from fastapi.testclient import TestClient
from app.main import app

# Inicializamos el cliente para simular peticiones web
client = TestClient(app)

def test_registro_usuario_exitoso():
    # PARTE 1: Preparación del payload según Swagger
    payload = {
        "name": "Juan",
        "last_name": "Pérez",
        "phone": "3001234567",
        "password": "PasswordSegura123!"
    }

    # PARTE 2: Ejecución de la petición a la ruta exacta
    response = client.post("/users/", json=payload)

    # PARTE 3: Validación de la respuesta (código 200 y validación de datos)
    assert response.status_code == 200
    
    # Validamos que la base de datos devuelva la confirmación estructurada
    data = response.json()
    assert data["name"] == "Juan"
    assert data["last_name"] == "Pérez"
    assert data["phone"] == "3001234567"
    assert "id" in data # Confirma que se le asignó un ID en la base de datos