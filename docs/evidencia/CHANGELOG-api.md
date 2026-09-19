# Historial de versiones — Contrato de API ROUTB

## Descripción

Este documento registra la evolución del contrato ejecutable de la API de
ROUTB (`docs/openapi.json`), correlacionando cada versión declarada  del contrato con el commit del repositorio en el que se
introdujo o modificó.

## Historial

| Versión | Commit    | Rama      | Cambio principal |
|---------|-----------|-----------|-------------------|
| 0.1.0   | [`4334c50`](https://github.com/ISCOUTB/AS_202620_ROUTB/tree/4334c506731ed54be9b6af5bf3160d23c7d46087) | `Changes` | Versión inicial del contrato de la API. |
| 0.2.0   | [`53ed7c3`](https://github.com/ISCOUTB/AS_202620_ROUTB/tree/53ed7c3be807068d9dfc74cc7a58caed2c191009) | `master`  | Versión consolidada y completa del contrato, cubriendo los cuatro dominios funcionales del backend: `users`, `auth`, `trips` y `requests`, con 16 operaciones y 9 esquemas de datos declarados. |

## Salida de `git log`

La siguiente salida se obtuvo con:

```text
git log --format="%h %H %ad %s" --date=iso --follow -- docs/openapi.json
```

```text
53ed7c3 53ed7c3be807068d9dfc74cc7a58caed2c191009 2026-09-19 17:43:00 -0500 Semana 7 - ROUTB
```

Antes de integrarse en `master`, el contrato tuvo dos cambios relevantes en la
rama `Changes`. Primero se creó el contrato versionado en el commit
`4334c50`:

```text
4334c50 4334c506731ed54be9b6af5bf3160d23c7d46087 2026-09-19 15:50:31 -0500 feat(api): agregar contrato OpenAPI versionado, script de exportación y pruebas de contrato (S7)
```

Después, en la misma rama, se obtuvo el commit `3a15c29`, que incrementó la
versión del contrato a `0.2.0`:

```text
3a15c29 3a15c298fa9341816f2f6a43efd880c2186ffbc5 2026-09-19 16:47:05 -0500 chore(api): bump versión del contrato a 0.2.0 (ADR 0004, escenario 6.3)
```

Posteriormente, ese cambio quedó integrado en `master` dentro del commit
`53ed7c3`, que es el commit que actualmente contiene el contrato versionado
entregado en la rama principal.