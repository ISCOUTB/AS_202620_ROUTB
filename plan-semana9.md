# Plan de cumplimiento — Semana 9 (ROUTB)

Actualizado: 3 de octubre de 2026 · Commit base revisado: `7d72888`
Matriz de referencia: `semana 9.md` (10 criterios)

---

## 0. Decisiones y estado de partida

| Tema | Estado |
|---|---|
| Aporte / tarifa por cupo | **Se retira del backend y del frontend.** ROUTB no gestiona pagos ni tarifas (arc42 §2.5). No se justifica con un ADR nuevo: se descarta como alternativa en el ADR 0007. |
| CI de GitHub Actions | 20 passed, **1 failed**: `test_reserva_grupal_de_cuatro_y_cancelacion_libera_todos_los_cupos` (`assert 1 == 4` en `GET /requests/me`). Causa en la Fase 1. |
| Medición externa en Render (3-oct-2026) | 200 en 100/100, **p95 490 ms**, máximo 833 ms. Tabla en la Fase 4. |
| Medición interna (oficial, logs de Render) | Pendiente. |

---

## Fase 1 — Poner el CI en verde (criterios 1 y 4)

**Causa del fallo.** En `backend/app/modules/requests/infrastructure/router.py` la función `_to_my_response` está definida **dos veces**. Python se queda con la última, y esa es la versión vieja: no pasa `seat_count`. El esquema `MyRequestResponse` tiene `seat_count = 1` por defecto, así que `/requests/me` devuelve 1 aunque la solicitud sea de 4. La aceptación y los cupos del viaje sí funcionan (por eso pasan las otras aserciones del test).

**Arreglo.**

- [ ] Borrar la **segunda** `_to_my_response`, la que no tiene `seat_count`, `departure_date`, `meeting_point` ni `fare_per_seat`. Deja la primera.
- [ ] En `requests/application/list_requests.py`, quitar `from app.modules.trips.infrastructure.models import Trip` (no se usa).
- [ ] Confirmar que no quedan referencias al ORM `User` en los routers (ya lo arreglaste, pero comprueba):

```powershell
git grep -n -E "Annotated\[User" -- backend/app
```

Debe salir vacío.

**Verificación.**

```powershell
cd backend
pytest tests -q
```

Debe terminar en `all passed`. Con el duplicado borrado, la suite completa pasó en mi copia de prueba (21 passed antes de añadir las guardas de la Fase 6).

### Evidencia del run en rojo (criterio 4)

El CI detectó la regresión antes de que se corrigiera: eso demuestra que la prueba falla ante el defecto que cubre. Para que cuente, regístralo en `docs/evidencia/prueba-reserva-grupal-semana9.md` como una sección aparte de la mutación:

- [ ] **Run en rojo:** enlace a la ejecución de GitHub Actions y SHA del commit que la disparó.
- [ ] **Prueba que falló:** `test_reserva_grupal_de_cuatro_y_cancelacion_libera_todos_los_cupos`, `assert 1 == 4` en `tests/test_requests_flow.py:321` (resultado: 1 failed, 20 passed).
- [ ] **Defecto:** `_to_my_response` duplicada; la versión que quedaba activa no pasaba `seat_count`, y `GET /requests/me` devolvía 1 en vez de 4 (ADR 0007: la API muestra cuántos cupos tiene cada solicitud).
- [ ] **Corrección:** SHA del commit que borra el duplicado y enlace al run en **verde** de ese commit. El par rojo → verde de la misma prueba es lo que lo hace evidencia.
- [ ] Conservar la mutación de sobreventa ya documentada: cubre otro defecto (aceptar dos grupos que juntos superan la capacidad) y no se debe mezclar con este.

---

## Fase 2 — Retirar el aporte por cupo (criterio 3)

### 2.1 Backend

Quitar `fare_per_seat` en estos puntos (números de línea del commit `7d72888`):

- [ ] `trips/infrastructure/models.py:30` — la columna.
- [ ] `trips/infrastructure/schemas.py:18` (entrada) y `:51` (salida).
- [ ] `trips/application/create_trip.py:16`.
- [ ] `trips/infrastructure/router.py:63`.
- [ ] `requests/infrastructure/router.py:63` (dentro de `_to_my_response`).
- [ ] `requests/infrastructure/schemas.py:56`.

### 2.2 Migración

Antes de tocar nada, mira qué tiene aplicada Supabase:

```powershell
cd backend
alembic current
```

- **Si NO muestra `004_trip_schedule_details`** (lo esperable: producción sigue en 0.2.0): edita la migración 004. Elimina el bloque `op.add_column("trips", sa.Column("fare_per_seat", ...))` de `upgrade()` y la línea `op.drop_column("trips", "fare_per_seat")` de `downgrade()`. Actualiza el docstring a "Add date and meetup point to trips."
- **Si SÍ la muestra**: no edites la 004. Crea `005_drop_fare_per_seat.py`:

```python
"""Retira fare_per_seat: ROUTB no gestiona tarifas."""
from alembic import op
import sqlalchemy as sa

revision = "005_drop_fare_per_seat"
down_revision = "004_trip_schedule_details"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_column("trips", "fare_per_seat")


def downgrade() -> None:
    op.add_column(
        "trips",
        sa.Column("fare_per_seat", sa.Integer(), server_default="0", nullable=False),
    )
```

Después, en una base **vacía** de Postgres: `alembic upgrade head` debe llegar al final sin errores.

### 2.3 Contrato

- [ ] Regenerar el contrato (no lo edites a mano):

```powershell
python scripts/export_openapi.py
```

- [ ] Se queda en versión **0.4.0**: el campo nunca se publicó, así que no hay cambio incompatible que versionar.

### 2.4 Frontend

- [ ] `core/models/trip.dart`: líneas 26, 62–63, 105, 252, 266, 285 y 301.
- [ ] `core/models/my_request.dart`: líneas 27, 67–68, 111 y 208.
- [ ] `features/driver/widgets/publish_route_sheet.dart`: líneas 28 y 55–56.
- [ ] `features/driver/screens/driver_screen.dart:262`.
- [ ] `features/trips/data/trip_repository.dart`: líneas 54, 65 y 150.
- [ ] `core/models/trip_schedule.dart:3`: el comentario pasa a "Formatos compartidos para la fecha de un viaje."

```powershell
cd frontend
flutter analyze --no-pub
```

Debe salir `No issues found`.

### 2.5 Documentos

- [ ] `docs/evidencia/CHANGELOG-api.md`, fila 0.4.0: quitar "y aporte por cupo" y poner el hash real del commit.
- [ ] `docs/adr/0007-reserva-grupal-de-cupos.md`, sección *Alternativas consideradas*, añadir:

```markdown
### Aporte económico por cupo

Se descarta: ROUTB no administra pagos, tarifas ni servicios comerciales de
transporte (arc42, sección 2.5). El acuerdo entre estudiantes ocurre fuera de
la plataforma.
```

- [ ] En el mismo ADR, bajo *Costos y límites*, aclara que la 0.3.0 introduce `seat_count` y que la 0.4.0 añade fecha y punto de encuentro (ver CHANGELOG). El número 0.3.0 del ADR es correcto; solo falta esa aclaración para que no parezca desactualizado.

### 2.6 Verificación

```powershell
git grep -n -i -E "fare|tarifa|aporte" -- backend frontend/lib docs/openapi.json
```

Debe salir vacío. (Las menciones a "tarifas de uso" en `docs/evidencia/taller-despliegue.md` son de Railway y no cuentan.)

La guarda automática está en `backend/tests/test_guardas_semana9.py`: falla si el contrato vuelve a exponer `fare`, `tarifa`, `price`, `payment` o `pago`.

---

## Fase 3 — Commits ordenados (criterio 1)

Nada de "Semana 9 - ROUTB" repetido. Un mensaje por cambio:

1. `fix(api): usar UserIdentity en routers y quitar _to_my_response duplicado`
2. `feat(requests): solicitud grupal de 1 a 4 cupos` (ADR 0007, migración 003, pruebas)
3. `feat(trips): fecha de salida y punto de encuentro` (migración 004, sin tarifa)
4. `refactor(frontend): retirar aporte por cupo`
5. `test: guardas de erosión modular y de no-pagos`
6. `docs(s9): evidencias, auditoría, medición e ia.md`

El CHANGELOG debe apuntar al hash real del commit 3.

---

## Fase 4 — Medición contra el umbral (criterio 5)

### 4.1 Pasos

- [ ] Confirmar qué versión corre en Render **antes** de atribuirle la medición a la porción:

```powershell
(curl.exe -s https://as-202620-routb.onrender.com/openapi.json | ConvertFrom-Json).info.version
```

Si responde `0.2.0`, el despliegue todavía no tiene la reserva grupal y la medición es solo una línea base más. Despliega, aplica `alembic upgrade head` y repite la medición.

- [ ] Hacer la medición **interna** (oficial) siguiendo §3.1 de `metricas-escenario-calidad.md` (fases 1 a 3 con los logs de Render) y añadirla como columna.

### 4.2 Resultado de la medición externa

Escenario: `GET /trips/`, servicio caliente, mínimo 100 respuestas con código 200, **p95 < 3,99 s** (arc42 §10.2). Fuente: script de PowerShell sobre `https://as-202620-routb.onrender.com`. Los valores del 3 de octubre están redondeados al milisegundo.

| Indicador | Línea base (26-sep-2026) | Posterior (3-oct-2026) | Variación | Umbral | Resultado |
|---|---:|---:|---:|---|---|
| Respuestas 200 / enviadas | 100 / 100 | 100 / 100 | — | ≥ 100 con código 200 | Cumple |
| Mínimo | 426,80 ms | no registrado | — | — | — |
| Promedio | 507,70 ms | no registrado | — | — | — |
| **p95** | **585,10 ms** | **490 ms** | **−95,10 ms (−16,3 %)** | **< 3.990 ms** | **CUMPLE** |
| Máximo | 724,40 ms | 833 ms | +108,60 ms (+15,0 %) | — | — |
| p95 como % del umbral | 14,7 % | 12,3 % | — | — | — |

**Cómo leerla.** El p95 queda 3.500 ms por debajo del umbral y usa solo el 12,3 % del margen permitido. La diferencia con la línea base (p95 un poco menor, máximo un poco mayor) está dentro de la variación normal de red entre corridas, así que no se atribuye mejora ni deterioro a la porción. La medición externa es complementaria; la oficial es la interna, con los logs de Render.

### 4.3 Dónde se registra

- [ ] Reemplazar la sección "Medición posterior a la implementación" de `docs/evidencia/medicion-reserva-grupal-semana9.md` por la tabla anterior y su lectura. La medición local con SQLite (p95 0,0762 s) queda como dato secundario y se dice que no es comparable con Render.
- [ ] Añadir la fila del 3-oct a la sección 5 de `metricas-escenario-calidad.md`.

---

## Fase 5 — `docs/ia.md` (criterio 6)

- [ ] Añadir **Codex (OpenAI)** a la tabla de herramientas.
- [ ] Mover la sección **Semana 9** para que quede antes de "Observaciones" (hoy está debajo).
- [ ] Añadir a la sección de la semana 9, adaptando el texto a lo que realmente pasó:

```markdown
- **Qué se corrigió (adicional):** al integrar las ramas, el merge dejó referencias
  residuales al ORM `User` en los routers y una función `_to_my_response` duplicada.
  Las referencias hicieron fallar la colección de pruebas; el duplicado hizo que
  `/requests/me` devolviera `seat_count = 1` y lo detectó el CI
  (`assert 1 == 4`). Se corrigieron y se volvió a ejecutar la suite completa.
- **Qué se rechazó (adicional):** el aporte económico por cupo (`fare_per_seat`).
  Contradice la restricción de que ROUTB no administra pagos ni tarifas
  (arc42 §2.5); se retiró de backend, frontend, migración y contrato.
```

- [ ] Los cambios de fecha de salida y punto de encuentro deben aparecer en el registro con la herramienta que los generó (indica cuál fue).
- [ ] En el documento de entrega, citar un extracto textual de esa sección.

---

## Fase 6 — Auditoría de erosión (criterio 7)

- [ ] Copiar `backend/tests/test_guardas_semana9.py` al repo. Dos pruebas:
  - `test_api_no_expone_tarifas_ni_pagos`
  - `test_capa_de_aplicacion_no_importa_el_orm_de_otro_modulo`

  Comprobé que la segunda falla si se reintroduce el import de `Trip` en `list_requests.py` y pasa sin él. Con esto la erosión se detecta sola en el CI.
- [ ] En `docs/evidencia/auditoria-erosion-semana9.md`:
  - Corregir la frase que dice que no quedan imports de modelos de `trips` en `requests.application`: había uno residual (`list_requests.py:4`) y se retiró.
  - Añadir el hallazgo **E7**: referencias residuales al ORM `User` (`trips/infrastructure/router.py:126`, `requests/infrastructure/router.py:181`) y `_to_my_response` duplicada; corrección y la prueba que lo detecta.
  - Añadir una línea que cite `test_guardas_semana9.py` como verificación automática.
  - Actualizar el conteo de la suite.

---

## Fase 7 — Dependencias (criterio 8)

- [ ] Comprobar que no se añadió ningún paquete:

```powershell
git diff eae667e..HEAD -- backend/requirements.in backend/requirements.txt frontend/pubspec.yaml
```

Resultado esperado: sin paquetes nuevos en el backend; en `pubspec.yaml` solo cambian assets (fuentes) y la descripción.
- [ ] Dejar por escrito: "Dependencias añadidas en esta porción: ninguna (backend ni frontend)".
- [ ] Las fuentes `BricolageGrotesque` y `DMSans` son archivos, no paquetes. Verifica su licencia en el sitio oficial (Google Fonts) y registra el enlace en `ia.md` o en una nota de evidencia. Si no puedes confirmarlas, quita las fuentes.

---

## Fase 8 — Barrido de credenciales (criterio 9)

- [ ] Repetir el barrido **al final**, cuando ya existan todos los archivos nuevos (incluido `docs/` y este plan).
- [ ] Anotar en `barrido-credenciales-semana9.md`: comando exacto, fecha y resultado.
- [ ] Documentar las excepciones esperadas: `postgresql://test:test@localhost` en `.github/workflows/ci.yml` y los valores de `backend/.env.example` son datos de ejemplo, no credenciales reales.
- [ ] Confirmar que `.env` no está versionado (`git ls-files | Select-String "\.env"` solo debe mostrar `.env.example`).

---

## Fase 9 — Trazabilidad y cierre (criterios 2 y 10)

- [ ] `docs/aspectos.md`, fila 6: añadir el commit final, `test_guardas_semana9.py` en la columna de pruebas y la medición en Render en la de evidencia.
- [ ] ADR 0008 (sin componente generativo): no tocar. Ya cumple el criterio 10.

---

## Verificación final (antes de entregar)

1. Clonar el repo en una carpeta limpia, en el commit final.
2. `pytest tests -q` → todo en verde.
3. Mutación: quitar la condición `Trip.available_seats >= seat_count` de `trips/application/request_seats.py` → deben fallar `test_solicitud_grupal_no_se_acepta_parcialmente` y `test_aceptaciones_grupales_concurrentes_no_sobrevenden` (recibe `[200, 200]` en vez de `[200, 409]`). Restaurar la condición.
4. `git grep -n -i -E "fare|tarifa|aporte" -- backend frontend/lib docs/openapi.json` → vacío.
5. `info.version` de `/openapi.json` en producción = versión de `docs/openapi.json`.
6. El CI de GitHub Actions termina en verde en el commit final.

---

## Mapa de criterios

| # | Criterio | Fase |
|---|---|---|
| 1 | Porción real con rutas y commits | 1, 3 |
| 2 | Cadena navegable en `aspectos.md` | 9 |
| 3 | ADR con la decisión argumentada | 2 |
| 4 | Prueba que falla ante el defecto | 1, verificación final |
| 5 | Medición contra el umbral | 4 |
| 6 | `docs/ia.md` | 5 |
| 7 | Auditoría de erosión | 6 |
| 8 | Dependencias verificadas | 7 |
| 9 | Sin credenciales | 8 |
| 10 | Componente generativo o ADR | 9 (ya cumple) |
