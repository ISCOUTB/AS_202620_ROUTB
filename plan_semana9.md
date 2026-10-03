# Plan de trabajo — Semana 9

## Objetivo

Construir con apoyo de IA una Porción funcional para **solicitar hasta cuatro cupos en un mismo viaje**. Una solicitud representa al pasajero y a un máximo de tres acompañantes, quienes no necesitan tener cuenta en ROUTB. El conductor acepta o rechaza la solicitud completa. Si el pasajero retira una solicitud aceptada, se liberan todos los cupos de esa solicitud.

La IA se utiliza como herramienta de análisis y desarrollo. **No se integra IA en ROUTB.** No se agrega una dependencia nueva para esta Porción; ese criterio queda fuera de su alcance por acuerdo.

## Reglas funcionales y de consistencia

1. La cantidad solicitada es un entero de **1 a 4**, inclusive; una solicitud antigua o sin cantidad explícita equivale a 1.
2. Crear una solicitud no reserva cupos hasta que el conductor la acepte, de acuerdo con el flujo actual.
3. La aceptación reserva la cantidad completa o no reserva ninguna. Debe respetar los cupos disponibles incluso ante aceptaciones concurrentes.
4. El rechazo de una solicitud pendiente no modifica la disponibilidad.
5. Retirar una solicitud aceptada devuelve exactamente su cantidad de cupos; retirar una pendiente no cambia la disponibilidad. La transición no debe devolver cupos dos veces.
6. Se conserva el escenario existente de 20 intentos concurrentes de un cupo sobre 4 cupos: deben aceptarse exactamente 4.
7. No se crean usuarios, cuentas ni solicitudes separadas para los acompañantes. El pasajero titular responde por el grupo.

### Límites de módulos

`requests` es dueño de la solicitud y su cantidad; `trips` es dueño de la disponibilidad del viaje. La aceptación y liberación deben coordinarse mediante una operación pública de aplicación de `trips`, con actualización atómica y transacción coherente. Evitar que `requests` cambie directamente el modelo ORM de `trips` o que un router de un módulo importe helpers privados del router de otro.

## Rúbrica de 10 criterios y plan de cumplimiento

Los criterios 1–5 se evidencian con la Porción y sus resultados. Los criterios 6–10 son transversales. El criterio 8 se excluye de esta Porción conforme al acuerdo; se deja visible como excluido y no se reporta como cumplido.

| # | Criterio | Trabajo para cumplirlo | Evidencia verificable |
|---|---|---|---|
| 1 | Porción real construida con apoyo de IA | Usar IA durante análisis, diseño e implementación de la reserva grupal; revisar cada propuesta y validar la solución. Registrar los commits reales. La IA no forma parte del runtime de ROUTB. | Código y commits que implementan 1–4 cupos; registro de uso en `docs/ia.md`. |
| 2 | Trazabilidad navegable | Añadir un aspecto para la reserva grupal enlazando necesidad, contexto, ADR, código, pruebas y evidencias. Verificar los enlaces. | Fila nueva en `docs/aspectos.md` con enlaces relativos válidos. |
| 3 | ADR con argumento del equipo | Documentar problema, alternativas, decisión, argumentos del equipo, restricciones, consecuencias y compatibilidad. Distinguir decisión del equipo de sugerencias de IA. | `docs/adr/0007-reserva-grupal-de-cupos.md` (confirmar numeración disponible antes de crear). |
| 4 | Prueba que falla si regresa el defecto | Probar límites 1 y 4, cantidades inválidas, aceptación total, capacidad insuficiente, liberación al retirar y concurrencia. Ejecutar una regresión/mutación que muestre que quitar la protección permite sobreventa o liberación incorrecta y que la prueba falla. | Pruebas automatizadas y procedimiento/resultados rojo y verde en `docs/evidencia/prueba-reserva-grupal-semana9.md`. Registrar resultados reales. |
| 5 | Medición del escenario asociado frente al umbral | Repetir el escenario publicado para `GET /trips/`: servicio caliente, 100 respuestas HTTP 200 y p95 **< 3,99 s**, con medición interna de logs de Render y externa complementaria. Comparar antes/después y reportar si la Porción no afecta ese endpoint; no atribuirle una mejora que no causó. | `docs/evidencia/medicion-reserva-grupal-semana9.md`, con fecha, N, fuente, p95, umbral y conclusión; referencia a `docs/evidencia/metricas-escenario-calidad.md`. |
| 6 | Decisiones reales del uso de IA | Añadir Semana 9 con herramienta efectivamente usada, contexto, propuestas, qué se aceptó/corrigió/rechazó y razones. No inventar decisiones retrospectivas. | Sección nueva en `docs/ia.md`, enlazada a ADR/código. |
| 7 | Auditoría de erosión modular y correcciones | Auditar límites con el código actual, no asumir que hallazgos antiguos siguen vigentes; buscar imports cruzados, acceso a ORM ajeno y saltos de capa. Corregir hallazgos y verificar. | `docs/evidencia/auditoria-erosion-semana9.md`, con hallazgo, ubicación, dueño, corrección y verificación. |
| 8 | Dependencia nueva verificada | **Fuera del alcance de la Porción por decisión del equipo.** No añadir dependencia ni afirmar el criterio como cumplido. Si la rúbrica exige un estado, marcar “excluido/no cubierto por acuerdo”. | Exclusión explícita en este plan y en el cierre. |
| 9 | No exponer credenciales | Revisar cambios, ejemplos y documentación de la semana para detectar secretos; usar configuración existente y redactar evidencia sensible. | Resultado real del barrido, sin copiar valores secretos. |
| 10 | Evaluar componente generativo | Comparar chatbot de soporte, resúmenes de viajes y clasificación de motivos de rechazo en costo, latencia, necesidad y compatibilidad con p95 <3,99 s. Documentar por qué no se incorpora IA generativa a producción. | `docs/adr/0008-no-componente-generativo.md`, con decisión no-gen y razones. |

## Tareas y orden

### 1. Confirmar línea base y contrato

- Revisar creación, aceptación, rechazo y retiro de solicitudes, modelos, migraciones, API, cliente móvil y pruebas existentes.
- Confirmar numeración ADR y estado de OpenAPI antes de editar.
- Capturar la línea base del escenario publicado y del test de consistencia existente, sin confundirla con una mejora atribuible a esta Porción.
- Definir compatibilidad: clientes que omiten cantidad siguen solicitando un cupo.

### 2. Implementar reserva de 1–4 cupos

- Añadir `seat_count` a la solicitud, con valor predeterminado 1 para datos/clientes existentes y validación 1–4.
- Cambiar aceptación para reservar la cantidad completa atómicamente; si no caben todos, no aceptar ni descontar parcialmente.
- Cambiar retiro de solicitud aceptada para liberar una sola vez exactamente `seat_count`.
- Mantener el rechazo de solicitud pendiente sin cambios de disponibilidad.
- Actualizar esquemas, respuestas, OpenAPI y cliente móvil para solicitar/mostrar cantidad. Si el contrato publicado requiere cambio de versión, justificarlo y mantener consistencia con el OpenAPI del proyecto.
- Mantener propiedad de datos: solicitudes en `requests`, disponibilidad en `trips`; coordinar mediante interfaz de aplicación pública y transacción segura.

### 3. Verificar defectos y regresiones

| Caso | Resultado esperado |
|---|---|
| Omitir cantidad | Solicitud de 1 cupo |
| Solicitar 1 o 4 | Aceptación reserva exactamente esa cantidad |
| Solicitar 0, negativo o 5 | Validación rechaza la solicitud |
| Solicitar 4 con solo 3 disponibles al aceptar | No hay aceptación ni descuento parcial |
| Retirar solicitud aceptada de 4 | Se liberan exactamente 4 cupos una vez |
| Rechazar/retirar solicitud pendiente | No se liberan cupos que no se reservaron |
| Dos aceptaciones grupales concurrentes que exceden capacidad | Solo se acepta el grupo que cabe; sin sobreventa |
| Escenario heredado: 20 intentos de 1 cupo, capacidad 4 | Exactamente 4 aceptados |

La evidencia roja/verde debe corresponder a un defecto concreto y a una prueba que realmente lo detecte; no basta mostrar que la suite pasa.

### 4. Documentar arquitectura, auditoría y mediciones

- Completar ADR 0007 y actualizar la fila de trazabilidad en `docs/aspectos.md`.
- Ejecutar y documentar la auditoría modular, con correcciones verificadas.
- Repetir el escenario de rendimiento de `GET /trips/` bajo el procedimiento existente y registrar datos reales antes/después. Si el código de búsqueda no cambia, indicar que es una verificación del umbral del sistema, no una mejora causada por la reserva grupal.
- Completar ADR 0008 sin conectar un modelo generativo al sistema.
- Registrar el uso real de IA en `docs/ia.md` y revisar que no haya credenciales en los cambios/evidencias.

### 5. Cierre

- Revisar contrato OpenAPI, enlaces de `docs/aspectos.md`, migración y compatibilidad con solicitudes existentes.
- Ejecutar las pruebas acordadas y registrar resultados reales; conservar evidencia de fallos inducidos y recuperación.
- Confirmar que no se alteró el test de cupos heredado y que sigue cumpliendo su regla de exactamente 4 reservas exitosas.
- Cerrar cada criterio con estado y enlace. El criterio 8 permanece excluido por acuerdo; los demás solo se marcan cumplidos con evidencia observada.

## Archivos previstos (ajustar al código real al implementar)

| Archivo/ruta | Cambio previsto |
|---|---|
| Módulo `requests` (modelo, esquema, casos de uso, router) | Cantidad solicitada, validación 1–4, contrato y serialización |
| Módulo `trips` (servicio/caso de uso público de aplicación) | Descuento/liberación atómicos sin exponer ORM a `requests` |
| Migraciones del backend | Persistir cantidad con compatibilidad para solicitudes existentes |
| Pruebas de `requests`/`trips` y concurrencia | Límites, aceptación/retiro grupal, no sobreventa y regresión existente |
| Cliente Flutter de solicitudes | Selección/visualización de hasta cuatro cupos y manejo de errores |
| `docs/aspectos.md` | Nueva fila y enlaces de trazabilidad |
| `docs/adr/0007-reserva-grupal-de-cupos.md` | Decisión de la Porción |
| `docs/adr/0008-no-componente-generativo.md` | Evaluación de IA generativa en runtime |
| `docs/ia.md` | Registro veraz de Semana 9 |
| `docs/evidencia/auditoria-erosion-semana9.md` | Hallazgos y correcciones modulares reales |
| `docs/evidencia/prueba-reserva-grupal-semana9.md` | Evidencia roja/verde del defecto |
| `docs/evidencia/medicion-reserva-grupal-semana9.md` | Medición del escenario y comparación |

## Riesgos y límites

- **Concurrencia:** leer y luego actualizar cupos no basta; la condición de disponibilidad debe resolverse atómicamente en base de datos.
- **Cancelación doble:** las transiciones deben impedir devolver dos veces los cupos de una solicitud.
- **Datos existentes:** la migración debe asignar 1 a solicitudes previas.
- **API móvil:** clientes antiguos deben seguir funcionando con valor por defecto; documentar cambios incompatibles.
- **Acompañantes:** no se recopilan datos personales de personas sin cuenta; solo se cuenta el tamaño del grupo.
- **Medición:** `GET /trips/` puede no cambiar con esta función. Se reportarán resultados y límites honestamente, sin fabricar mejora o causalidad.

## Estado de ejecución — 2 de octubre de 2026

- **Porción:** implementada en backend y Flutter; máximo 4 contando al titular, decisión completa del conductor y liberación del grupo al cancelar.
- **Backend/OpenAPI:** versión 0.3.0; contrato regenerado. Suite completa en SQLite temporal aislada: `21 passed, 2 warnings`; la prueba OpenAPI pasó.
- **Migración:** se verificó `002 → 003` sobre SQLite temporal; un registro legacy quedó con `seat_count=1`.
- **Regresión:** al retirar temporalmente la condición atómica, la prueba concurrente falló con dos aceptaciones (`[200, 200]` en vez de `[200, 409]`). Se restauró la condición y la suite final pasó.
- **Medición local:** 100 respuestas 200 calientes a `GET /trips/`, p95 0,0762 s frente a 3,99 s. No equivale a Render; repetir la medición oficial cuando se despliegue esta versión.
- **Frontend:** `flutter analyze --no-pub` sin hallazgos. `flutter test` quedó bloqueado por Windows App Control al iniciar `flutter_tester.exe`.
- **Auditoría modular y credenciales:** hallazgos corregidos; búsqueda sin patrones de credenciales. Ver [auditoría](docs/evidencia/auditoria-erosion-semana9.md) y [barrido](docs/evidencia/barrido-credenciales-semana9.md).
- **Criterio 8:** excluido por acuerdo; no se agrega dependencia.
