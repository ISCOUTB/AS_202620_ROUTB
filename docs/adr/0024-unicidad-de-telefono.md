# ADR 0024: Unicidad de teléfono en la base de datos

## Estado

Aceptado.

## Contexto

El teléfono es el identificador de acceso y el medio de contacto de
contingencia. `create_user` comprobaba el duplicado con una lectura previa:

```python
existing = db.query(User).filter(User.phone == user_data.phone).first()
```

Entre esa lectura y el `INSERT` no había restricción en PostgreSQL. Dos
registros simultáneos con el mismo número podían pasar ambos el chequeo.
Además, el mismo celular podía existir como `3001234567` y como
`+57 300-123-4567` sin que la aplicación los tratara como iguales.

ROUTB no borra ni fusiona cuentas de forma automática. Un índice único no
puede crearse encima de duplicados, y resolverlos exige una decisión humana.

## Decisión

1. **Un solo índice único.** La migración `011_unique_users_phone` crea
   `uq_users_phone` sobre `users.phone`. El modelo lo declara en
   `__table_args__` con ese mismo nombre. No se combina `unique=True` con
   `index=True` en la columna, porque PostgreSQL crearía índices adicionales
   con otros nombres.

2. **Normalizar antes de indexar, y abortar si no se puede.** La migración
   acepta, tras quitar espacios y guiones, `3XXXXXXXXX`, `+573XXXXXXXXX` y
   `573XXXXXXXXX`, y persiste siempre 10 dígitos. Si un valor no entra en
   esos formatos, o si dos filas colisionan al normalizar, la migración
   aborta con un mensaje que identifica los `id` y los teléfonos. No hay
   escrituras previas a esa comprobación: no se borra ni se fusiona a nadie.

3. **La carrera se traduce al contrato existente.** `create_user` conserva
   la lectura previa como respuesta temprana y captura `IntegrityError`. Si
   la violación es `uq_users_phone`, lanza `UserAlreadyExistsError` (HTTP 409).
   Cualquier otra violación se propaga. El router no cambia.

4. **El downgrade solo retira el índice.** No restaura prefijos ni guiones:
   volver al formato anterior reabriría colisiones ya resueltas.

## Alternativas consideradas

### Dejar la unicidad solo en la aplicación

- **Ventajas:** sin migración.
- **Motivo de descarte:** no cierra la ventana entre la lectura y la
  inserción, ni entre varias instancias del proceso.

### Fusionar o borrar duplicados en la migración

- **Ventajas:** `upgrade head` nunca se detiene por datos viejos.
- **Motivo de descarte:** el teléfono identifica la cuenta. Elegir un
  superviviente de forma automática puede mezclar viajes y credenciales.
  Abortar obliga a resolverlo a mano, en staging y en producción, antes de
  crear el índice.

### `unique=True, index=True` en la columna

- **Ventajas:** declaración más corta.
- **Motivo de descarte:** SQLAlchemy generaría un índice único y otro no
  único, con nombres distintos de `uq_users_phone`.

## Consecuencias

### Positivas

- Un teléfono canónico corresponde a un solo usuario, también bajo registros
  simultáneos.
- El conflicto sigue respondiendo HTTP 409, sin cambiar el contrato.
- La migración es reversible en el esquema y no destruye datos.

### Negativas y mitigaciones

- **Hay que revisar staging y producción antes de aplicarla.** Si ya hay
  duplicados o teléfonos fuera de formato, `alembic upgrade head` falla.
  - *Mitigación:* el mensaje lista los registros; no se aplica en producción
    sin respaldo ni sin haber pasado `upgrade → downgrade → upgrade` en
    staging.
- **El downgrade no revierte la normalización.** Quien necesite el texto
  original debe restaurarlo desde el respaldo, no desde `downgrade`.
- **La validación de entrada del API sigue siendo laxa hasta TASK-03.** El
  índice garantiza unicidad del valor persistido; el normalizador de
  registro y login es una tarea aparte.

## Verificación

- `pytest tests/test_registro.py -q` cubre el 409 secuencial, el registro
  concurrente, la traducción de `IntegrityError` y el ciclo de la migración
  011 (normalización, aborto sin pérdida de datos y downgrade/upgrade).

## Trazabilidad

- Migración: `backend/migrations/versions/011_unique_users_phone.py`
- Modelo: `backend/app/modules/users/infrastructure/models.py`
- Caso de uso: `backend/app/modules/users/application/create_user.py`
- Pruebas: `backend/tests/test_registro.py`
- Relacionado: [ADR 0021](0021-integridad-solicitudes-y-concurrencia.md)
