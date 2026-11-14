# Índices espaciales GiST para matching (migración 012)

Este documento registra la decisión y la verificación de TASK-11. La
conclusión principal es que el índice que el planificador necesita no es
un GiST sobre la columna `geometry`, sino sobre la expresión
`route_geom::geography` que usa la consulta de sugerencias.

## 1. Revisión de las consultas

La búsqueda de matching (`backend/app/modules/matching/application/suggest_trips.py`)
filtra con:

```sql
ST_DWithin(t.route_geom::geography, punto::geography, :radius_m)
```

El cast `::geography` es obligatorio para medir en metros (ADR 0009). Un
índice GiST sobre `route_geom` (tipo `geometry`) no cubre esa expresión:
PostgreSQL necesita un índice cuya expresión sea exactamente
`((route_geom)::geography)`.

Revisión de las demás columnas espaciales:

| Columna | Uso actual | ¿Predicado espacial? | Índice |
|---|---|---|---|
| `trips.route_geom` | `ST_DWithin(route_geom::geography, ...)` en matching; `ST_LineLocatePoint` en `order_stops` | Sí | GiST sobre `((route_geom::geography))` |
| `trips.origin_geom` | `ST_X` / `ST_Y` | No | No aplica |
| `trips.dest_geom` | `ST_X` / `ST_Y` | No | No aplica |
| `request_stops.stop_geom` | `ST_X` / `ST_Y` y argumento de `ST_LineLocatePoint` | No | No aplica |

`ST_LineLocatePoint` es una función escalar: no usa un índice de la
segunda geometría. Crear GiST sobre `origin_geom`, `dest_geom` o
`stop_geom` solo agregaría costo de escritura. Esa es la razón por la que
la migración 012 no crea los tres índices que enumeraba el borrador de la
tarea.

## 2. Decisión

La migración `006_postgis_y_ubicacion.py` ya había creado el índice
correcto con otro nombre:

```text
idx_trips_route_geog -> CREATE INDEX ... USING gist (((route_geom)::geography))
```

La migración `012_add_spatial_gist_indexes.py`:

1. Renombra `idx_trips_route_geog` a `idx_trips_route_geom_gist` si existe
   y el destino no existe.
2. Crea `idx_trips_route_geom_gist` con `CREATE INDEX IF NOT EXISTS` por si
   el índice anterior fue eliminado.
3. En `downgrade`, restaura el nombre `idx_trips_route_geog` para dejar el
   esquema como lo dejó la migración 006.

No se crean dos índices equivalentes. El modelo
`backend/app/modules/trips/infrastructure/models.py` declara el índice con
el mismo nombre y la misma expresión, manteniendo `spatial_index=False`
como pide el ADR 0009. Así, `alembic revision --autogenerate` no propone
crear ni retirar el índice.

## 3. Verificación

Ciclo ejecutado sobre `DATABASE_URL_TEST` (PostgreSQL con PostGIS):

```powershell
alembic upgrade head
alembic downgrade -1
alembic upgrade head
```

El ciclo pasó sin errores. Definición resultante:

```text
idx_trips_route_geom_gist -> CREATE INDEX idx_trips_route_geom_gist ON public.trips
USING gist (((route_geom)::geography))
```

Plan con `EXPLAIN (ANALYZE)` y `SET LOCAL enable_seqscan = off` (la tabla
está vacía, así que el objetivo es demostrar que el índice es elegible):

```text
Index Scan using idx_trips_route_geom_gist on trips t
  (cost=0.27..27.49 rows=1 width=4) (actual time=... rows=0 loops=1)
  Index Cond: ((route_geom)::geography && _st_expand('...'::geography, '800'::double precision))
  Filter: st_dwithin((route_geom)::geography, '...'::geography, '800'::double precision, true)
Planning Time: 9.355 ms
Execution Time: 1.334 ms
```

Con una tabla pequeña el planificador elige `Index Scan` en lugar de
`Bitmap Index Scan`; en ambos casos el nodo referencia
`idx_trips_route_geom_gist`. El nombre del índice aparece en el plan, que
es la comprobación que importa. `SET enable_seqscan = off` solo se usó para
la demostración, no en código de producción.

Pruebas ejecutadas:

```powershell
pytest tests/test_postgis_radius.py tests/test_matching_suggestions.py -q
```

Resultado: `18 passed`. `test_postgis_radius.py` incluye dos pruebas
nuevas: una verifica el nombre y la expresión del índice (y que no quede
el duplicado), y otra verifica que el planificador usa el índice para la
misma expresión de `suggest_trips`. La corrida se repitió en una base
temporal aislada para descartar el bloqueo de otra sesión sobre
`DATABASE_URL_TEST`: `18 passed`.

## 4. Límites conocidos

- La migración 012 depende de la 011 (`uq_users_phone`). La base de
  desarrollo/Staging debe resolver primero los teléfonos no normalizables
  que la 011 detecta; no se aplicó ninguna de las dos en producción desde
  esta tarea.
- Con pocas filas, PostgreSQL puede seguir eligiendo `Seq Scan` si
  `enable_seqscan` está en su valor normal. El índice se vuelve relevante
  cuando crece el histórico de viajes.
- El índice cubre únicamente `route_geom::geography`. Una consulta futura
  que use `route_geom` como `geometry` no lo aprovechará; en ese caso habrá
  que decidir entre cambiar la consulta o agregar otro índice justificado.
