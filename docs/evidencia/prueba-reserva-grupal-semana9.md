# Evidencia de regresión — Solicitudes grupales (Semana 9)

## Defecto que se busca detectar

Si la aceptación descuenta cupos sin condicionar la actualización a que la disponibilidad alcance para todo el grupo, dos solicitudes simultáneas pueden ser aceptadas aunque juntas superen la capacidad. También se verifica que una cancelación no libere dos veces el mismo grupo.

## Casos automatizados

- Solicitud omitida equivale a 1; cantidades 0 y 5 se validan como error.
- Solicitar 4, aceptar y cancelar devuelve disponibilidad de 4 a 0 y de 0 a 4.
- Repetir una aceptación ya confirmada no descuenta el grupo dos veces; repetir la cancelación no libera cupos otra vez.
- Una solicitud de 4 permanece pendiente y sin descuento parcial si solo quedan 3 cupos cuando el conductor intenta aceptarla.
- Dos grupos de 3 compiten por un viaje de 4: solo una aceptación puede tener éxito y queda 1 cupo.
- Se conserva `test_reservas_concurrentes_no_sobrevenden_cupos`: 20 intentos concurrentes sobre 4 cupos producen exactamente 4 reservas exitosas.
- Al aceptar o rechazar desde la app del conductor, la disponibilidad se actualiza por la cantidad de cupos de la solicitud, no por una unidad fija.

## Comprobación de regresión (mutación)

Para verificar que la prueba detecta el defecto, se retiró temporalmente la condición `Trip.available_seats >= seat_count` de la actualización atómica en `backend/app/modules/trips/application/request_seats.py`. Con ese defecto, la prueba `test_aceptaciones_grupales_concurrentes_no_sobrevenden` debe quedar roja porque se aceptan ambos grupos o la disponibilidad se hace negativa. Después se restauró la condición y se repitió el caso y la suite.

### Resultado real

En una base SQLite temporal e independiente de Supabase se ejecutó:

```text
pytest tests/test_requests_flow.py::test_aceptaciones_grupales_concurrentes_no_sobrevenden -q
```

- **Mutante defectuoso:** se retiró la condición `available_seats >= seat_count`. Resultado: `1 failed`; la aserción recibió `[200, 200]` en vez de `[200, 409]`. Código de salida 1. El test detecta la sobreventa.
- **Código restaurado:** la corrida final de `pytest tests -q` dio `21 passed, 2 warnings` en 12,83 s; código de salida 0. Incluye la prueba de concurrencia y el contrato OpenAPI.
- Las advertencias son deprecaciones existentes de `httpx`/Starlette TestClient.

## Verificación del despliegue reportado (2 de octubre de 2026)

Al reproducir el reporte de una solicitud de 4 cupos que aparece como 1, se consultó en modo lectura el OpenAPI de producción (`https://as-202620-routb.onrender.com/openapi.json`). La API pública responde `version: 0.2.0`; `TripRequestResponse` no declara `seat_count` y no existe el esquema de entrada para la solicitud grupal. El código de este repositorio ya corresponde al contrato 0.3.0, que recibe y devuelve ese campo, y la migración `003_group_trip_request_seats.py` agrega el dato persistido.

Esto explica el síntoma: producción descarta la cantidad enviada y aplica el valor histórico de 1; luego la app tampoco puede reconstruir el valor elegido porque la respuesta del servidor no lo incluye. Para que la prueba real funcione es necesario publicar esta versión del backend y aplicar su migración. La corrección cliente hace que el contador visual reste o reponga la cantidad devuelta por el servidor; por sí sola no puede recuperar datos que el backend 0.2.0 no guarda ni devuelve.
