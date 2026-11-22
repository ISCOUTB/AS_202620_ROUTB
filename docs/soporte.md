# Soporte de ROUTB

Desde Seguridad puedes consultar preguntas frecuentes o registrar un problema
en la aplicación. Cuando el servidor confirma el registro, la pantalla muestra
el folio y permite copiarlo para una consulta posterior.

`POST /support/reports` requiere el JWT de la sesión. Acepta un
`submission_id` UUID, una categoría (`trip`, `reservation`, `driver` o
`app`) y una descripción de 10 a 2000 caracteres después de quitar los
espacios exteriores. Devuelve `201` con `{"id": 42}` una vez guardado el
reporte. Reenviar el mismo contenido con el mismo UUID y la misma cuenta
devuelve el mismo folio. Si cambia el contenido, responde `409`.

Aplica la migración `015_support_reports` con `alembic upgrade head` antes
de habilitar el formulario en una instalación existente. El equipo con acceso
autorizado a PostgreSQL puede consultar los reportes en `support_reports`,
identificarlos por folio (`id`) y revisar su fecha, categoría y descripción.
La aplicación confirma el registro. La revisión es manual y no genera
notificaciones. Los reportes se eliminan junto con la cuenta que los creó.

## Contactos de emergencia

Cada cuenta puede guardar hasta tres contactos en el dispositivo. La lista
se conserva al volver a iniciar sesión con la misma cuenta. Si el dispositivo
guardaba contactos antes de que se separaran por cuenta, cada persona debe
volver a agregar los suyos. La lista anterior carece de un identificador de
propietario.
