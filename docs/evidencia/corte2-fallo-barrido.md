# Barrido de secretos — Semana 10, corte 2 (fallo de proveedores)

**Fecha:** 2026-10-13. **Alcance:** archivos versionados del repositorio
(`git grep`, excluye `.env` ignorados, `.venv`, `.git` y artefactos).

**Método:** búsqueda de claves privadas PEM, prefijos de tokens comunes
(`AKIA`, `AIza`, `ghp_`/`gho_`, `xox`), `service_role`, valor de
`FCM_SERVICE_ACCOUNT_B64` y tokens JWT (`eyJ.*\..*\..`), sobre el rango del
corte 2 (geocode, routing, matching, contrato OpenAPI, evidencias). La
búsqueda reporta solo rutas, nunca valores.

**Resultado:** sin coincidencias en archivos versionados. Los `.env` están
ignorados y nunca se versionaron; solo aparece el placeholder documentado de
`backend/.env.example` (incluye `ROUTING_TIMEOUT_SECONDS=1.4` sin secretos).
Este barrido no sustituye el manejo seguro de secretos en Render ni el
Quality Gate de SonarCloud.
