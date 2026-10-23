# Historial de versiones — Contrato de API ROUTB

## Descripción

Este documento registra la evolución del contrato ejecutable de la API de
ROUTB (`docs/openapi.json`), correlacionando cada versión declarada  del contrato con el commit del repositorio en el que se
introdujo o modificó.

## Historial

| Versión | Commit    | Rama      | Cambio principal |
|---------|-----------|-----------|-------------------|
| 0.1.0   | [`4334c50`](https://github.com/ISCOUTB/AS_202620_ROUTB/tree/4334c506731ed54be9b6af5bf3160d23c7d46087) | `Changes` | Versión inicial del contrato de la API. |
| 0.2.0   | [`53ed7c3`](https://github.com/ISCOUTB/AS_202620_ROUTB/tree/53ed7c3be807068d9dfc74cc7a58caed2c191009) | `master`  | Versión consolidada y completa del contrato, cubriendo los cuatro dominios funcionales del backend: `users`, `auth`, `trips` y `requests`, con 16 operaciones y 9 esquemas de datos declarados. |
| 0.3.0   | [`2da6f31`](https://github.com/ISCOUTB/AS_202620_ROUTB/tree/2da6f31b6189f62ca9712253472e1e640e7952df) | `Changes` | Agrega `seat_count` opcional a la creación de solicitudes (1–4, por defecto 1), lo devuelve en las respuestas, y documenta la reserva grupal con aceptación/rechazo completo y contrato OpenAPI regenerado. |
| 0.4.0   | Cambios locales sin commit | `Changes` | Añade fecha de salida y punto de encuentro a los viajes; permite filtrar por día y devuelve esos datos en las solicitudes del pasajero. |
| 0.5.0   | Cambios locales sin commit | `Changes` | Añade endpoint de matching (`GET /matching/suggestions`) con sugerencias ordenadas por score de compatibilidad (Fase 2). |
| 0.6.0   | Cambios locales sin commit | `Changes` | Amplía solicitudes con fecha y paradas; agrega estados `cancelled`/`expired`, vencimiento, exclusividad por día y sentido, y registro de tokens y push FCM. |
| 0.7.0   | Cambios locales sin commit | `Changes` | Endurece la identidad de endpoints del Aspecto 3: retira `GET /users/` y `POST /trips/{trip_id}/reservations`, y exige token y propiedad en `POST /trips/` y `PATCH /trips/{trip_id}/cancel`. |
| 0.8.0   | Cambios locales sin commit | `Changes` | Añade el historial del conductor (parámetro `scope` en `GET /trips/my-trips`) y expone `location_consent_at` en `GET /auth/me` para el perfil de solo lectura. Cambios aditivos. |
| 0.9.0   | Cambios locales sin commit | `Changes` | Retira `GET /geocode/search` y la geocodificación del backend; la resolución de direcciones y rutas pasa al cliente Flutter con Google Maps Platform (ADR 0018). |

## Endurecimiento de endpoints (Aspecto 3)

- Se retira `GET /users/`, que respondía sin autenticación y sin `response_model`
  devolviendo la tabla de usuarios (incluido `hashed_password`). El registro sigue
  en `POST /users/`.
- Se retira `POST /trips/{trip_id}/reservations`, reserva anónima legada
  sustituida por `POST /requests/trips/{trip_id}` con aceptación del conductor.
  La primitiva atómica `reserve_seat` se conserva para la prueba de concurrencia.
- `POST /trips/` exige token; ya no se crean viajes sin dueño (`driver_id` nulo).
- `PATCH /trips/{trip_id}/cancel` exige token y propiedad; se elimina el caso en
  que un llamador anónimo cancelaba cualquier viaje.
- CORS pasa a `allow_credentials=False` (la autenticación es Bearer, no cookies).

## Ajustes de matching y sugerencias (Fase 2)

- `GET /matching/suggestions` sugiere viajes compatibles a partir de sentido, puntos de parada, fecha, hora y cupos solicitados; la fecha debe ser hoy o mañana (`422` fuera de la ventana, ADR 0016).
- Exige autenticación y consentimiento previo de ubicación (`403 location_consent_required`).
- Filtra por cercanía de ruta en PostGIS (`ST_DWithin` geográfico), calcula desvío y ETA con OSRM (con caché y respaldo), y ordena por score ponderado normalizado.
- `POST /requests/trips/{trip_id}` acepta `requested_at` y hasta cuatro `stops`, con coordenadas, dirección, tipo de lugar y cantidad de personas; valida consentimiento, rangos geográficos de coordenadas (`-90..90`, `-180..180`), cupos y reglas del sentido.
- `GET /requests/trips/{trip_id}` queda restringido al conductor y devuelve direcciones de paradas sin coordenadas; `GET /requests/me` aplica vencimiento y devuelve los estados de cada solicitud.
- `PATCH /requests/{id}/accept` serializa aceptaciones del pasajero, reserva cupos atómicamente, cancela sus alternativas del mismo día y sentido y ordena las paradas aceptadas en la ruta.
- `PUT` y `DELETE /notifications/device-token` gestionan tokens Android. Las pushes informan al conductor de nuevas solicitudes y al pasajero de aceptación/rechazo; la API REST conserva la verdad del estado.

## Ajustes de geocodificación y privacidad (Fase 1)

- `POST /trips/` acepta `direction` (`to_campus` | `from_campus`) y `driver_point` opcionales; con coordenadas exige consentimiento (`403 location_consent_required`) y valida rangos de lat/lng (`422`); solo admite fechas de hoy o mañana (`422` fuera de la ventana, ADR 0016); al publicar calcula y guarda la ruta (`route_geom`, `route_distance_m`, `route_duration_s`, `route_source`, con respaldo `fallback`).
- `GET /geocode/search` exige consentimiento (`403 location_consent_required`);
- Si Photon y Nominatim están indisponibles responde `503 geocode_unavailable`; una búsqueda válida sin coincidencias conserva `200 []`.
- `DELETE /users/me/location-consent` cancela solicitudes pendientes y elimina sus paradas geográficas.

## Resiliencia de routing (Semana 10)

- Se parametriza el timeout de OSRM con `ROUTING_TIMEOUT_SECONDS` (valor por
  defecto `1.4` s tras la medición del corte 2; antes `3.0` s) y se aplica el
  mismo timeout a Photon y Nominatim; se corrige la expresión PostgreSQL del
  TTL de `route_cache` y se evita guardar rutas `degraded`. No cambia el
  contrato HTTP/OpenAPI; decisión en [ADR 0014](../adr/0014-fallback-geocode-cache.md).

## Retiro de geocodificación del backend (cambio actual)

- Se retira `GET /geocode/search`, el módulo `geocode`, el servicio
  `shared/geocode` y la tabla `geocode_cache`.
- La geocodificación directa, inversa, el autocompletado y las rutas se
  resuelven en el cliente Flutter con Google Maps Platform
  ([ADR 0018](../adr/0018-google-maps-platform-frontend.md)).
- `docs/openapi.json` se regenera sin esa ruta. Los demás endpoints y sus
  códigos HTTP no cambian.
- La función `purge_location_data()` deja de borrar de `geocode_cache` porque
  la tabla ya no existe; conserva la purga de viajes, paradas y `route_cache`.

## Historial del conductor y perfil (cambio actual)

- `GET /trips/my-trips` acepta el parámetro de consulta `scope` con tres
  valores: `active` (por defecto, mismo comportamiento de antes: solo rutas
  activas), `history` (canceladas o con fecha pasada) y `all` (todas). Un
  valor fuera del conjunto responde `422`. El cambio es aditivo y no altera
  las respuestas existentes.
- `GET /auth/me` incorpora `location_consent_at` (o `null`) a su respuesta
  para el perfil de solo lectura. Esta operación no declara esquema de
  respuesta en el contrato OpenAPI, así que el campo no aparece en
  `docs/openapi.json`.

## Salida de `git log`

La siguiente salida se obtuvo con:

```text
git log --format="%h %H %ad %s" --date=iso --follow -- docs/openapi.json
```

```text
53ed7c3 53ed7c3be807068d9dfc74cc7a58caed2c191009 2026-09-19 17:43:00 -0500 Semana 7 - ROUTB
```

Antes de integrarse en `master`, el contrato tuvo dos cambios relevantes en la
rama `Changes`. Primero se creó el contrato versionado en el commit
`4334c50`:

```text
4334c50 4334c506731ed54be9b6af5bf3160d23c7d46087 2026-09-19 15:50:31 -0500 feat(api): agregar contrato OpenAPI versionado, script de exportación y pruebas de contrato (S7)
```

Después, en la misma rama, se obtuvo el commit `3a15c29`, que incrementó la
versión del contrato a `0.2.0`:

```text
3a15c29 3a15c298fa9341816f2f6a43efd880c2186ffbc5 2026-09-19 16:47:05 -0500 chore(api): bump versión del contrato a 0.2.0 (ADR 0004, escenario 6.3)
```

Posteriormente, ese cambio quedó integrado en `master` dentro del commit
`53ed7c3`, que es el commit que actualmente contiene el contrato versionado
entregado en la rama principal.
