# ADR 0026: Datos del vehículo y visibilidad restringida al pasajero confirmado

## Estado

Aceptado.

## Contexto

El pasajero solo conocía el nombre y el teléfono del conductor. Al abordar en la
salida del campus no tenía forma de identificar el vehículo (modelo, color y
placa), lo que genera desconfianza y demoras, sobre todo de noche. La placa es un
dato de identificación del vehículo y, combinada con el viaje, permite localizar
al conductor; por eso no puede quedar en respuestas públicas.

La ficha se pensó originalmente dentro de `TripResponse`, pero el listado
`GET /trips/` lo consulta cualquier usuario, incluso sin token. Exponer allí la
placa convertiría un dato de seguridad en un dato público.

## Decisión

1. **Columnas opcionales en `users`.** La migración 013 agrega
   `vehicle_model` (`VARCHAR(50)`), `vehicle_plate` (`VARCHAR(10)`) y
   `vehicle_color` (`VARCHAR(30)`), todas nulas. Un conductor sin vehículo
   propio registrado sigue operando con normalidad.

2. **Registro desde el perfil del conductor.** `PATCH /users/me/vehicle`
   acepta los tres campos. Enviarlos nulos los borra. Solo un usuario con rol
   `driver` puede usarlo (`403` para pasajeros). El modelo y la placa son
   obligatorios para registrar; el color es opcional.

3. **Validación de placa colombiana de automóvil.** Se normaliza a `ABC-123`
   después de quitar espacios y guiones y pasar a mayúsculas. ROUTB transporta
   estudiantes en automóviles, así que no se aceptan formatos de motocicleta
   (`ABC-12D`) ni placas fuera del patrón de tres letras y tres dígitos. Un
   formato distinto devuelve `422`. La regla vive en `app/shared/vehicle.py` y
   se replica en el formulario Flutter para dar un mensaje inmediato.

4. **Visibilidad mínima.** `vehicle_info` (texto
   `Modelo · Color (Placa)`) se calcula al serializar y solo se entrega:
   - en `GET /requests/me` para la solicitud propia en estado `accepted`;
   - en `GET /trips/{trip_id}` para el pasajero con solicitud `accepted`.

   Nunca aparece en `GET /trips/` (listado público), ni en
   `GET /matching/suggestions`, ni en solicitudes `pending`, `rejected`,
   `cancelled` o `expired`. El conductor dueño ve sus propios datos en
   `GET /auth/me`. En el listado público el campo viaja como `null` para
   conservar un único schema de respuesta; no se serializa ningún dato del
   vehículo.

5. **Frontend.** El perfil del conductor ofrece el formulario y permite quitar
   el vehículo con confirmación. La ficha se pinta con
   `RoutbVehicleBadge` en `MyTripCard`, en el detalle de «Mi viaje» y en
   `TripCard` cuando la API la entrega.

## Alternativas consideradas

### Incluir `vehicle_info` en `TripResponse` sin condición

Es la lectura literal de la tarea original, pero expone la placa a cualquier
usuario anónimo y en las sugerencias de matching. Se descartó por privacidad:
la utilidad de la placa es identificar el vehículo al abordar, no publicarlo.

### Guardar el vehículo en una tabla aparte

Permitiría historial de vehículos y varios vehículos por conductor. ROUTB no
necesita esa complejidad todavía: un conductor usa su vehículo habitual y los
campos son opcionales. Una tabla nueva agrega joins y migraciones sin beneficio
para el flujo actual.

### Validar solo en el cliente

El formulario puede saltarse con `curl`. La validación y normalización deben
vivir en el backend; el cliente solo evita el viaje de ida y vuelta.

## Consecuencias

- El pasajero con cupo confirmado puede reconocer el vehículo sin que la placa
  quede publicada.
- El conductor controla cuándo registra o retira el dato y puede operar sin él.
- `docs/openapi.json` incorpora el nuevo endpoint y los campos opcionales.
- Las pruebas `backend/tests/test_trips_flow.py` cubren la validación de placa,
  los permisos y la visibilidad exclusiva; `frontend/test/profile_test.dart`,
  `my_trip_test.dart` y `vehicle_validation_test.dart` cubren el formulario y
  la insignia.
