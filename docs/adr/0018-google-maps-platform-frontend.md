# 0018 - Google Maps Platform en el cliente Flutter

## Estado

Aceptado. Reemplaza a [ADR 0010 - Geocodificación con Photon, caché en PostgreSQL y respaldo a Nominatim](0010-geocodificacion-y-cache.md). Deja sin efecto la parte de geocodificación del [ADR 0014 - Timeout de routing y caché resiliente](0014-fallback-geocode-cache.md); el routing del backend con OSRM se conserva.

## Contexto

ROUTB necesita geocodificación directa, geocodificación inversa, autocompletado y geometrías de calles con buena cobertura de nomenclatura en Cartagena. La arquitectura anterior resolvía esas operaciones en el backend con Photon y Nominatim, con `geocode_cache` en PostgreSQL y el endpoint `GET /geocode/search`.

La implementación real del cliente ya usa Google Maps Platform mediante llamadas REST desde Flutter:

- Geocoding API para dirección a coordenada y coordenada a dirección.
- Places API (New) para autocompletado y detalles de lugar.
- Routes API para la polilínea de la ruta y el cálculo de desvíos.

El ADR 0010 había descartado Google Maps Platform por costo y tarjeta de crédito. El proyecto mantiene la restricción de costo $0: el uso se mantiene dentro de la capa gratuita de Google Cloud, con cuotas y alertas configuradas. La clave es una credencial de cliente restringida por plataforma, no un secreto de servidor.

## Decisión

1. **Geocodificación y routing en el cliente.** Flutter resuelve dirección, autocompletado, geocodificación inversa y rutas contra Google Maps Platform. El backend no geocodifica direcciones ni almacena una caché de geocodificación.

2. **Clave fuera del repositorio.** La clave vive en `frontend/.env`, ignorado por git, y se inyecta al compilar con `--dart-define-from-file=.env`. No hay clave por defecto en el código. El archivo `frontend/.env.example` solo contiene el nombre de la variable.

3. **Restricciones de la credencial.** La clave debe estar restringida a las APIs de Geocoding, Places API (New) y Routes API, y por plataforma: paquete Android y huella SHA-1, bundle iOS y referrers web. Se configuran cuotas y alertas de facturación para mantener el costo en $0.

4. **Retiro del backend de geocodificación.** Se eliminan `GET /geocode/search`, el módulo `geocode`, el servicio compartido `shared/geocode`, las variables `PHOTON_BASE_URL`, `NOMINATIM_BASE_URL`, `NOMINATIM_USER_AGENT` y `GEOCODE_BBOX`, y la tabla `geocode_cache`. La función `purge_location_data()` deja de borrar de esa tabla.

5. **Degradación explícita.** Si Google no responde o no hay clave configurada:
   - La búsqueda usa el catálogo local de barrios (`Zones`) cuando el texto coincide.
   - El mapa dibuja la curva estimada entre los puntos conocidos.
   - No se reintroduce Nominatim ni OSRM en el cliente.

6. **Privacidad.** La geocodificación directa envía el texto o las coordenadas a Google solo cuando la persona usa el buscador o pulsa «Usar mi ubicación». ROUTB no persiste esas consultas. El consentimiento de ubicación del ADR 0011 sigue siendo obligatorio para publicar viajes, reservar y almacenar coordenadas en el backend; esta decisión reemplaza únicamente la cláusula que exigía geocodificar a través del backend.

## Alternativas consideradas

### Mantener Photon y Nominatim en el backend

- **Ventajas:** costo $0, sin clave de Google, una sola caché centralizada.
- **Motivo de descarte:** la nomenclatura de Cartagena y el autocompletado no alcanzaban la precisión requerida; los límites de uso de Nominatim y la latencia del respaldo afectaban la experiencia.

### Proxy de Google en el backend

- **Ventajas:** la clave no viaja al cliente, se centralizan cuotas, consentimiento y caché.
- **Motivo de descarte:** añade latencia y complejidad operativa al backend, y el equipo ya adoptó la integración directa para el alcance actual. Queda como alternativa si la clave o el costo dejan de ser manejables.

### Google Maps SDK nativo para renderizar

- **Ventajas:** integración directa con la plataforma.
- **Motivo de descarte:** agrega dependencias nativas y Play Services; el renderizado se resolvió con `flutter_map` y tiles de OpenStreetMap en el [ADR 0019](0019-renderizado-mapas-flutter-map-osm.md).

## Consecuencias

### Positivas

- Mejor precisión de direcciones y autocompletado en Cartagena.
- Menos carga y menos latencia en el backend: no hay llamadas a Photon/Nominatim ni caché de geocodificación.
- El contrato OpenAPI se reduce; desaparece una dependencia externa del servidor.
- El costo operativo se mantiene en $0 dentro de la capa gratuita, con cuotas y alertas.

### Negativas y mitigaciones

- **Dependencia de una clave de cliente.** Una clave embebida en una app puede extraerse.
  - *Mitigación:* restricciones por plataforma, APIs mínimas, cuotas, alertas y rotación si hay abuso.
- **Sin fallback de direcciones arbitrarias.** Si Google falla o se agota la cuota, solo queda el catálogo de barrios.
  - *Mitigación:* se acepta para el alcance académico; el catálogo cubre los puntos habituales y el mapa conserva la curva estimada.
- **Datos de ubicación enviados a Google.** La geocodificación inversa comparte coordenadas con el proveedor.
  - *Mitigación:* solo se ejecuta tras una acción de la persona; se documenta en la política de privacidad y no se persiste en ROUTB.
- **Costo variable si se supera la cuota.** El $0 depende de mantener el consumo dentro de la capa gratuita.
  - *Mitigación:* cuotas, alertas y revisión del consumo; ver [costo mensual](../evidencia/costo_mensual.md).

## Verificación

- `flutter analyze`, `flutter test` y `flutter build web` sin referencias a Nominatim, Photon u OSRM en el cliente.
- `docs/openapi.json` sin `GET /geocode/search`.
- `pytest -q` sin pruebas de geocodificación del backend.
- Revisión manual de restricciones, cuotas y alertas en Google Cloud antes de un despliegue.
