# Revisión de credenciales — Semana 9

Se revisan los archivos agregados o modificados esta semana para detectar
claves privadas, tokens de acceso, secretos de API y credenciales copiadas en
ejemplos o evidencia. Las credenciales de entornos locales no se incorporan a
la documentación.

**Método:** búsqueda de claves privadas PEM, prefijos de tokens comunes de
proveedores y tokens JWT con `rg` sobre los archivos del repositorio, excluyendo
`.env`, entornos virtuales, `.git` y artefactos de build. La búsqueda reporta
solo rutas, nunca el valor coincidente.

**Resultado del 2026-10-02:** no se encontraron patrones de credenciales en los
archivos escaneados. La revisión no sustituye el manejo seguro de secretos en
los despliegues; no se copiaron valores de configuración al repositorio.
