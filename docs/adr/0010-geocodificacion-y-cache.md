# ADR 0010: Geocodificación con Photon, caché en PostgreSQL y respaldo a Nominatim

## Estado

Aceptado.

## Contexto

ROUTB requería pasar de la entrada de ubicaciones por texto libre ("Centro", "Bocagrande") a ubicaciones geográficas exactas (`lat, lng`) para trazar rutas y calcular cercanía respecto a la sede de la UTB (Cartagena).

Requisitos y restricciones:
1. **Costo cero ($0.00 USD) y sin tarjeta de crédito:** Servicios como Google Maps Platform o Mapbox no son viables por exigencia de tarjeta de crédito o límites de facturación.
2. **Respeto a límites de uso aceptable:**
   - La API pública de Nominatim exige no superar 1 petición por segundo y un `User-Agent` descriptivo.
   - Photon (basado en OpenStreetMap y desarrollado por Komoot) permite búsquedas directas con sesgo geográfico, pero requiere protección frente a caídas y límites de uso.
3. **Latencia y experiencia de usuario:** La geocodificación debe responder en menos de 1 segundo para búsquedas frecuentes.

## Decisión

1. **Proveedor principal (Photon):**
   - Se utiliza la API pública de Photon (`PHOTON_BASE_URL`, por defecto `https://photon.komoot.io/api`).
   - Se incluye sesgo por coordenadas dentro del bounding box de Cartagena (`GEOCODE_BBOX`).
   - Se fija un timeout estricto de 3 segundos por petición.

2. **Caché persistente en base de datos (`geocode_cache`):**
   - Las consultas normalizadas (minúsculas, sin espacios superfluos) se almacenan en la tabla `geocode_cache` con un TTL configurable de 7 días (`RETENTION_CACHE_DAYS`).
   - Si la consulta ya fue realizada y la caché sigue vigente, se devuelve inmediatamente sin llamar a proveedores externos.

3. **Proveedor de respaldo (Nominatim):**
   - Si Photon no responde o falla, el sistema conmuta automáticamente a Nominatim (`NOMINATIM_BASE_URL`).
   - Se incluye un limitador de velocidad global (`threading.Lock`) que garantiza al menos 1.05 segundos de separación entre peticiones consecutivas a Nominatim.
   - Se identifica con un `User-Agent` propio institucional.

4. **Rate limiting y control de acceso:**
   - El endpoint `GET /geocode/search` exige autenticación JWT.
   - Se restringe a usuarios que hayan otorgado consentimiento explícito de ubicación (`location_consent_required`).

## Consecuencias

- Las búsquedas repetidas responden en milisegundos gracias a la tabla de caché.
- El sistema es resiliente: una caída de Photon no interrumpe el servicio gracias al fallback hacia Nominatim.
- Cumplimiento de políticas de uso justo de OSM mediante control estricto de frecuencia de peticiones.
