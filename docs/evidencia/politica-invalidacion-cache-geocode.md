# Evidencia: Política de invalidación de la caché de geocodificación

Este documento complementa el [ADR 0010](../adr/0010-geocodificacion-y-cache.md),
que tomó la decisión de usar `geocode_cache` con TTL en PostgreSQL. Aquí se
formaliza la política de invalidación que rige esa caché, derivada de la
implementación real y del comportamiento del sistema ante fallos de proveedores
externos (ADR 0014).

> **Referencia de código:** `backend/app/modules/geocode/`
> **ADR base:** [ADR 0010](../adr/0010-geocodificacion-y-cache.md)
> **ADR de respaldo/degradado:** [ADR 0014](../adr/0014-fallback-geocode-cache.md)
> **Contexto integrado:** `docs/arc42/08_conceptos_transversales.md` §8.7

---

## Política de invalidación de `geocode_cache`

La caché `geocode_cache` sigue cuatro reglas de invalidación. El objetivo es
que nunca se sirva una coordenada inválida ni una de respaldo como si fuera
definitiva.

| Regla | Trigger | Comportamiento |
|---|---|---|
| **Por expiración (TTL)** | Transcurridos `RETENTION_CACHE_DAYS` días (por defecto 7) desde la escritura de la entrada | La consulta de lectura comprueba `cached_at + RETENTION_CACHE_DAYS > now()`; una entrada expirada se trata como ausente y dispara una nueva geocodificación al proveedor |
| **Por escritura/upsert** | Nueva geocodificación exitosa de la misma consulta normalizada | Se ejecuta un `INSERT ... ON CONFLICT (query_normalized) DO UPDATE SET lat=..., lng=..., cached_at=now()`, reemplazando la entrada anterior; nunca se acumulan versiones antiguas de la misma clave |
| **Por resultado degradado** | El proveedor responde con resultado marcado `degraded=true` (Photon o Nominatim en modo de respaldo limitado) | El resultado **no se persiste** en `geocode_cache`; la entrada anterior, si existe, se conserva intacta hasta su expiración por TTL; así la caché no sirve coordenadas de respaldo como si fueran válidas (ADR 0014; §8.5 en `docs/arc42/08_conceptos_transversales.md`) |
| **Sin sincronización activa con OSM/Photon** | Actualización del mapa base en OpenStreetMap o cambio de la geometría de una zona | ROUTB no suscribe a eventos de actualización geográfica; la coherencia eventual con la fuente se cubre por expiración de TTL; este diseño es aceptable dado que los barrios de Cartagena no cambian con frecuencia |

---

## Garantías derivadas de la política

- Una geocodificación **exitosa y no degradada** siempre actualizará (o creará)
  la entrada de caché; no hay coordenadas obsoletas más allá del TTL.
- Una geocodificación **degradada** nunca contamina la caché; el próximo HIT de
  la misma consulta seguirá devolviendo la última coordenada válida persistida.
- La política no afecta a los cupos ni a ninguna operación de solicitud: los
  cupos se leen siempre en tiempo real desde la tabla `trips` y **nunca pasan
  por esta caché** (ver §8.7 en `docs/arc42/08_conceptos_transversales.md`).

---

## Relación con el criterio 4 de evaluación S12

El criterio 4 exige una política de invalidación explícita. Los puntos de
evidencia son:

1. **Regla de expiración (TTL):** configurable vía `RETENTION_CACHE_DAYS`; la
   lectura filtra entradas expiradas antes de devolverlas.
2. **Regla de upsert:** `ON CONFLICT DO UPDATE` garantiza que una nueva
   geocodificación exitosa siempre reemplaza la entrada anterior de la misma
   clave normalizada.
3. **Regla de degradado:** los resultados marcados `degraded=true` no se
   persisten, evitando que la caché sirva coordenadas de respaldo como válidas
   (documentado en ADR 0014 y §8.5 de arc42).
4. **Ausencia de caché de cupos:** se aclara explícitamente que esta caché solo
   cubre geocodificación; la disponibilidad de cupos se lee siempre en tiempo
   real, sin riesgo de reservas incorrectas por caché desactualizada.