# 0019 - Renderizado de mapas con flutter_map y teselas de OpenStreetMap

## Estado

Aceptado. Complementa al [ADR 0018 - Google Maps Platform en el cliente Flutter](0018-google-maps-platform-frontend.md).

## Contexto

La app necesita mostrar el origen, el destino, las paradas intermedias y la geometría de la ruta. La información de direcciones y rutas proviene de Google Maps Platform, pero el renderizado no requiere el SDK nativo de Google ni Google Play Services.

`flutter_map` ya está integrado en el cliente y usa teselas de OpenStreetMap. Es una dependencia Dart pura que funciona en Android, iOS y web sin agregar SDKs nativos.

## Decisión

1. **Renderizado con `flutter_map`.** El mapa se dibuja con `flutter_map` y `latlong2`; la geometría de la ruta se pinta como una polilínea sobre las teselas.

2. **Teselas de OpenStreetMap.** Se usa `https://tile.openstreetmap.org/{z}/{x}/{y}.png` con atribución visible. El uso se mantiene dentro de la política de uso justo de OpenStreetMap; para un crecimiento que supere el alcance académico se debe evaluar un proveedor de teselas con contrato.

3. **Separación entre datos y renderizado.** Google resuelve direcciones y rutas; `flutter_map` solo las dibuja. Cambiar el proveedor de datos no obliga a cambiar el renderizador, y viceversa.

4. **Fallback visual.** Si no hay geometría de Google, el mapa dibuja una curva estimada entre los puntos conocidos. Si no hay coordenadas ni catálogo, muestra el estado de ubicación desconocida.

5. **Atribución obligatoria.** La atribución a OpenStreetMap se mantiene visible en el mapa, conforme a la licencia de las teselas.

## Alternativas consideradas

### Google Maps SDK para Flutter

- **Ventajas:** integración directa con Google Maps Platform y sus datos.
- **Motivo de descarte:** agrega dependencias nativas, Play Services y configuración por plataforma; el renderizado con `flutter_map` ya funciona y mantiene el costo de teselas en $0.

### Mapbox

- **Ventajas:** mapas vectoriales y buen rendimiento.
- **Motivo de descarte:** requiere cuenta, clave y facturación; no aporta una ventaja suficiente para el alcance actual.

### Mapas estáticos generados por el backend

- **Ventajas:** control centralizado y menos dependencias en el cliente.
- **Motivo de descarte:** pierde interactividad y añade latencia y almacenamiento al backend.

## Consecuencias

### Positivas

- Sin SDK nativo de Google ni Play Services para renderizar.
- Funciona en Android, iOS y web con la misma implementación Dart.
- Costo de renderizado $0 dentro de la política de uso de OpenStreetMap.
- La atribución y el fallback visual están explícitos en el widget.

### Negativas y mitigaciones

- **Dependencia de teselas públicas.** El servidor de OpenStreetMap no es un CDN con SLA para producción.
  - *Mitigación:* se mantiene el uso académico y se documenta la necesidad de un proveedor contratado si el tráfico crece.
- **Sin mapas vectoriales ni temas avanzados.** El renderizado es de teselas raster.
  - *Mitigación:* suficiente para mostrar rutas y paradas; se acepta para el alcance actual.
- **La atribución no es opcional.** Ocultarla incumple la licencia.
  - *Mitigación:* el widget la muestra por defecto.

## Verificación

- `route_map_test.dart` verifica marcadores, paradas y renderizado sin llamadas de red.
- `flutter build web` compila el mapa con `flutter_map`.
- Revisión visual de la atribución de OpenStreetMap en la app.
