# ADR 0012: Sugerencias de matching, scoring, enrutamiento y orden de paradas

## Estado

Aceptado.

## Contexto

El modelo inicial de ROUTB requería que el pasajero explorara manualmente una lista de viajes publicados para encontrar uno que coincidiese aproximadamente con su horario y trayecto. Para ofrecer una experiencia puerta a puerta centrada en el pasajero, el sistema requiere sugerir automáticamente viajes compatibles minimizando el desvío para el conductor y calculando tiempos estimados de recogida (ETA).

Restricciones y principios de diseño:
1. **Aprobación humana:** El conductor mantiene el control final; el motor de matching solo *sugiere*, nunca asigna ni escribe en base de datos.
2. **Uso eficiente de servicios externos:** El servidor público de OSRM impone un límite de uso de 1 req/s. No es viable consultar OSRM para decenas de viajes arbitrarios.
3. **Sentidos de viaje:** Dos sentidos de viaje desde el inicio: `to_campus` (origen a UTB) y `from_campus` (UTB a destino).
4. **Ordenación de paradas determinista:** En viajes compartidos con múltiples pasajeros/paradas, el orden de recogida o entrega debe optimizarse a lo largo de la ruta sin incurrir en complejidad combinatoria NP-dura.

## Decisión

1. **Pipeline de matching en tres etapas (`GET /matching/suggestions`):**
   - **Paso 1 (Filtrado geoespacial en PostGIS):** Consulta SQL de solo lectura que filtra viajes `active` con fecha coincidente, mismo sentido (`direction`), cupos disponibles $\ge \text{seat\_count}$, hora de salida dentro de la ventana (`MATCHING_TIME_WINDOW_MIN`), y donde todos los puntos de parada del pasajero se ubiquen a una distancia $\le \text{MATCHING\_RADIUS\_M}$ (por defecto 800 m, ampliable a 1500 m en modo relajado) de la geometría de la ruta del conductor (`ST_DWithin(route_geom::geography, stop_point::geography, radius)`). Se seleccionan como máximo 10 candidatos ordenados por proximidad media.
   - **Paso 2 (Cálculo de desvío y ETA con OSRM):** Solo los 3 mejores candidatos espaciales se consultan contra `RoutingService` insertando las paradas en su posición secuencial a lo largo de la ruta para calcular el desvío en minutos y el ETA de recogida. Se utiliza caché de rutas (`route_cache`) y respaldo geodésico si OSRM no responde.
   - **Paso 3 (Scoring normalizado y descarte):** Se descartan viajes que superen el tope de desvío (`MATCHING_MAX_DETOUR_MIN`, por defecto 10 min, relajado 15 min). Se calcula un score ponderado normalizado (menor es mejor):
     $$\text{score} = 0.5 \cdot \text{desvío\_norm} + 0.3 \cdot \text{espera\_norm} + 0.2 \cdot \text{acercamiento}$$
     Se retornan hasta 5 sugerencias ordenadas por score. Si no hay candidatos, se responde `200 []`.

2. **Ordenación de paradas a lo largo de la ruta:**
   - No se utiliza cálculo de permutaciones (TSP). El orden de las paradas (`stop_seq`) se calcula de forma unívoca y continua proyectando cada parada sobre la geometría de la ruta del viaje con la función espacial `ST_LineLocatePoint(route_geom, stop_geom)`.
   - En sentido `to_campus`, el orden es ascendente hacia el campus.
   - En sentido `from_campus`, el orden es ascendente alejándose del campus.
   - Las paradas de distintas solicitudes aceptadas pueden intercalarse naturalmente según su posición geográfica en el trayecto.
   - Al confirmar una solicitud, fuera de la transacción de cupos, se recalcula la geometría del viaje con todas las paradas aceptadas y se guarda una ETA estimada por posición a lo largo de la ruta. Si OSRM falla se conserva el respaldo geodésico de `RoutingService`.

3. **Solo lectura:**
   - La consulta de sugerencias es estrictamente de solo lectura y no genera reservas, solicitudes ni bloqueos en la base de datos.

## Consecuencias

- Respuestas rápidas de búsqueda al limitar el cómputo pesado de OSRM a un máximo de 3 candidatos previamente filtrados en base de datos.
- Resiliencia garantizada: si OSRM se degrada o no está disponible, el fallback geodésico calcula distancias y tiempos estimados marcando la respuesta como `degraded = true`.
- Secuencia de paradas consistente y predecible para el conductor en ruta.
