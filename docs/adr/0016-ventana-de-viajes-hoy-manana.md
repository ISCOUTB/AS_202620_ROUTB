# 0016 - Ventana de viajes limitada a hoy y mañana

## Estado

Aceptado.

## Contexto

ROUTB es una plataforma de transporte compartido para una comunidad
universitaria pequeña. La interfaz permitía elegir fechas hasta 30 días en el
futuro con un calendario (`showDatePicker`), pero el backend aceptaba
cualquier `departure_date` sin validación: el límite solo existía en la app.

Con una base de usuarios reducida, la oferta se dispersa cuando los viajes se
publican con semanas de anticipación: cada día queda con pocos viajes
publicados y el matching pierde efectividad. Un pasajero que busca para hoy no
encuentra viajes publicados para otras fechas, y un conductor puede dejar
"preparados" viajes lejanos que después no se concretan.

## Decisión

La publicación y la búsqueda de viajes quedan limitadas a **hoy y mañana**
(hora de Colombia):

1. `POST /trips/` responde `422` si `departure_date` no es hoy ni mañana.
2. `GET /matching/suggestions` responde `422` si `date` no es hoy ni mañana.
3. La app reemplaza el calendario por un selector de dos opciones
   (`Hoy` / `Mañana`) en el filtro del pasajero, la publicación del conductor
   y la pantalla de sugerencias (`DateQuickPicker`).
4. Los viajes publicados antes de esta decisión no se modifican: no hay
   migración de datos ni cancelación masiva. Siguen existiendo y son
   consultables por su id o por listado con `departure_date` explícita, pero
   dejan de aparecer en los flujos de búsqueda y publicación de la app.

## Alternativas consideradas

### Mantener el calendario de 30 días

- **Ventajas:** permite planear con anticipación.
- **Motivo de descarte:** fragmenta la oferta en una comunidad pequeña;
  reduce la densidad de viajes por día y con ello la probabilidad de
  encontrar cupo.

### Ventana intermedia (7 días)

- **Ventajas:** equilibrio entre planeación y concentración.
- **Motivo de descarte:** con el tamaño actual de la base, 7 días siguen
  dispersando más de lo que aportan. Reevaluable cuando crezca la comunidad.

### Restringir solo en la interfaz

- **Ventajas:** cambio mínimo, sin tocar la API.
- **Motivo de descarte:** un cliente viejo o cualquier consumidor de la API
  puede saltarse la regla; la app y el servidor quedarían inconsistentes.

### Cancelar o borrar los viajes existentes fuera de la ventana

- **Ventajas:** deja la base alineada con la regla.
- **Motivo de descarte:** implica escribir datos en producción sin necesidad;
  el ciclo de vida de los viajes ya los depura.

## Consecuencias

### Positivas

- La oferta se concentra en las 48 horas siguientes: más probabilidad de que
  un pasajero encuentre un viaje compatible.
- Las publicaciones ocurren cuando el conductor ya sabe que viaja, lo que
  reduce planes a semanas vista que después no se cumplen.
- La regla queda aplicada de extremo a extremo (app y API) y cubierta por
  pruebas.

### Negativas y mitigaciones

- **No se puede planear con más de 48 horas.** Para el patrón de uso
  (desplazamiento casa-universidad) es el comportamiento esperado; si la
  comunidad crece, la ventana se puede ampliar con un ADR nuevo que reemplace
  a este.
- **La ventana es una regla compartida.** El backend la calcula con
  `colombia_today()` y la app la refleja con
  `TripSchedule.clampToTripWindow`; una fecha heredada fuera de la ventana se
  ajusta a hoy o mañana en lugar de romper el formulario.

## Trazabilidad

| Aspecto | Artefactos | Pruebas |
|---|---|---|
| Publicación solo hoy/mañana | `backend/app/modules/trips/application/create_trip.py`, `docs/evidencia/CHANGELOG-api.md` | `backend/tests/test_trips_flow.py` |
| Búsqueda solo hoy/mañana | `backend/app/modules/matching/infrastructure/router.py` | `backend/tests/test_matching_suggestions.py` |
| Selector Hoy/Mañana en la app | `frontend/lib/core/widgets/date_quick_picker.dart`, `frontend/lib/core/models/trip_schedule.dart` | `frontend/test/date_quick_picker_test.dart` |
