# 0003 - Control atómico de cupos en reservas

## Estado

Aceptado

## Contexto

ROUTB debe permitir consultar y reservar cupos de los recorridos. Si varios
pasajeros intentan reservar el último cupo al mismo tiempo, leer primero la
disponibilidad y actualizarla después puede producir sobreventa o una cantidad
negativa de cupos.

La línea base previa al cambio es la ausencia de un endpoint funcional de
recorridos y reservas: una solicitud a `/trips/` no podía crear ni consultar
cupos. La validación posterior usa 20 intentos concurrentes sobre un viaje
con 4 cupos.

## Decisión

Se implementa un módulo `trips` con:

- `POST /trips/` para crear un recorrido;
- `GET /trips/{trip_id}` para consultar la disponibilidad;
- `POST /trips/{trip_id}/reservations` para reservar un cupo.

La reserva se realiza mediante una actualización SQL atómica condicionada a
`available_seats > 0`. Solo la transacción que logra actualizar una fila
consume un cupo; las demás reciben `409 Conflict`.

## Alternativas consideradas

### Leer y actualizar en operaciones separadas

Se descarta porque dos solicitudes pueden leer el mismo valor antes de que
cualquiera lo actualice, generando sobreventa bajo concurrencia.

### Bloqueo explícito de la fila

`SELECT ... FOR UPDATE` también resolvería la condición, pero añade una
operación y un bloqueo explícito que no son necesarios para este contador.

## Consecuencias

### Positivas

- No se aceptan más reservas que cupos disponibles.
- La regla de consistencia queda en la base de datos.
- El flujo es comprobable mediante pruebas de endpoint y concurrencia.

### Negativas

- La reserva no registra todavía qué usuario la realizó.
- El módulo necesitará una entidad de solicitud cuando se implemente el flujo
  completo de pasajeros y conductores.

## Medición

La prueba `backend/tests/test_cupos.py` ejecuta 20 intentos concurrentes con 20 workers sobre un viaje con 4 cupos:

- exactamente 4 reservas exitosas;
- cero cupos restantes;
- ningún valor negativo;
- percentil 95 de cada operación inferior a 2 segundos.
