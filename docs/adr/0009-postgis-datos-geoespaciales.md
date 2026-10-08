# ADR 0009: Habilitación de PostGIS y modelo de datos geoespaciales

## Estado

Aceptado.

## Contexto

ROUTB evoluciona desde un modelo de coincidencia por texto libre ("origen", "destino", "punto de encuentro") hacia un sistema de sugerencias y matching basado en proximidad geográfica real, cálculo de desvíos y paradas intermedias a lo largo de la ruta del conductor.

Para realizar consultas de proximidad eficientes (cálculo de radio en metros sin distorsión por latitud) e indexación espacial indexada sobre geometrías (puntos de parada y rutas trazadas como LineString), se requiere soporte geoespacial nativo en la base de datos relacional.

## Decisión

1. **Habilitar PostGIS:** Se adopta la extensión PostGIS sobre PostgreSQL 16.
2. **Imágenes Docker y CI:**
   - En desarrollo local (`docker-compose.yml`), se adopta la imagen oficial `postgis/postgis:16-alpine`.
   - En integración continua (`.github/workflows/ci.yml`), se adopta `postgis/postgis:16` como service container.
3. **ORM y Migraciones:**
   - Se incorpora `geoalchemy2` fijado con hashes en `requirements.txt`.
   - Los índices espaciales se gestionan directamente a nivel de migraciones Alembic (`GIST ((route_geom::geography))`), manteniendo `spatial_index=False` en los modelos para evitar discrepancias de autogeneración.
   - En `migrations/env.py` se filtran las tablas internas de PostGIS (`spatial_ref_sys`, `geometry_columns`, `geography_columns`).
4. **Cálculos en metros (`geography`):**
   - Todas las consultas por radio se realizan proyectando a `geography` (`ST_DWithin(geom::geography, ...)`), garantizando mediciones reales en metros y no en grados planos.
5. **Procedimiento en Supabase (Staging / Producción):**
   - PostGIS se activa en Supabase mediante el dashboard (*Database → Extensions → postgis*) o ejecutando `CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA extensions;`.
   - Se ejecuta `alembic upgrade head` validando con `SELECT PostGIS_Version();`.

## Consecuencias

- Soporte nativo para tipos `Geometry(Point, 4326)` y `Geometry(LineString, 4326)`.
- Consultas de radio rápidas mediante índices espaciales GiST.
- Compatibilidad retroactiva garantizada: todas las columnas espaciales son `NULL`-ables para no invalidar viajes legados.
- Se incorpora la función idempotente `purge_location_data()` para cumplir con la retención y privacidad de datos de ubicación.
