# ADR 0011: Consentimiento de ubicación, retención y purga de datos

## Estado

Aceptado.

## Contexto

El tratamiento de datos de ubicación geográfica (puntos exactos de partida, llegada y paradas intermedias) involucra información sensible y privada de los estudiantes y conductores de la UTB, regida bajo los principios de la Ley 1581 de 2012 (Protección de Datos Personales en Colombia).

Se requiere:
- Autorización previa y revocable para recolectar y almacenar coordenadas exactas.
- Acceso restringido (principio de necesidad y mínimo privilegio).
- Política de retención definida y purga automatizada periódica.

## Decisión

1. **Consentimiento previo explícito:**
   - Se añade la columna `location_consent_at TIMESTAMPTZ` en la tabla `users`.
   - Si el valor es `NULL`, la API rechaza cualquier operación que intente almacenar coordenadas exactas, realizar búsquedas de geocodificación o publicar rutas con `403 Forbidden` (`location_consent_required`).
   - Se proporcionan endpoints específicos:
     - `POST /users/me/location-consent`: registra la aceptación con marca temporal.
     - `DELETE /users/me/location-consent`: revoca el consentimiento de forma inmediata, cancela solicitudes de viaje pendientes y elimina las geometrías de paradas asociadas en `request_stops`.

2. **Acceso mínimo y ofuscación temporal:**
   - Antes de que el conductor acepte una solicitud, solo puede visualizar la dirección en texto descriptivo (`address_text`) o barrio, nunca las coordenadas precisas (`stop_geom`).
   - La API administrativa (`/admin`) no expone ni serializa geometrías exactas.

3. **Política de retención y purga periódica:**
   - Coordenadas de viajes y paradas: se conservan durante un máximo de 30 días (`RETENTION_TRIP_DAYS`) posteriores a la salida del viaje.
   - Entradas de caché espacial (`geocode_cache` y `route_cache`): se conservan durante un máximo de 7 días (`RETENTION_CACHE_DAYS`).
   - Función SQL idempotente `purge_location_data()`: anula `origin_geom`, `dest_geom` y `route_geom` de viajes vencidos, y elimina paradas y entradas de caché caducadas.
   - Se habilita ejecución automática programada vía GitHub Actions (`.github/workflows/purge-location-data.yml`) o extensión `pg_cron` en la base de datos de producción.

## Consecuencias

- Los usuarios mantienen control y facultad de revocación sobre sus datos de ubicación.
- Reducción sustancial del riesgo de exposición de patrones de desplazamiento habituales tras completarse los viajes.
