# ADR 0029. Modalidades de viaje de una misma cuenta

## Contexto

El teléfono identifica una cuenta y el JWT contiene su identificador en el
campo sub. Las rutas, las solicitudes y el vehículo ya pertenecen a esa misma
identidad. El registro anterior elegía una sola experiencia de navegación.

## Decisión

Toda cuenta nueva comienza como pasajero. El servidor reconoce como conductor
a quien ya tenía el rol histórico driver o activó esta modalidad registrando
modelo, color y placa con las validaciones existentes. La activación registra
la fecha y el vehículo en la misma transacción. La preferencia de navegación
se guarda por usuario en PostgreSQL. Flutter conserva el último estado
confirmado para restaurar la interfaz sin conexión.

Los controladores obtienen la identidad de la sesión autenticada. El modo
activo no concede permisos. Las operaciones sobre una ruta siguen comprobando
su propietario y la reserva rechaza al conductor de la propia ruta. El cambio
de modo no modifica el JWT, el rol histórico ni los compromisos existentes.

## Contrato y despliegue

- Aplicar la migración 016_user_travel_modes antes de actualizar la API y
  distribuir el frontend. Los dos campos nuevos son opcionales. Una preferencia
  nula conserva la experiencia original de cada cuenta.
- POST /users/ acepta el campo anterior role por compatibilidad. El servidor
  registra la cuenta como pasajero incluso si un cliente anterior envía driver.
- PUT /users/me/driver recibe vehicle_model, vehicle_plate y vehicle_color.
  Un vehículo incompleto o inválido devuelve 422. La respuesta confirma la
  habilitación y selecciona conductor.
- PATCH /users/me/mode recibe mode con passenger o driver. Requiere sesión y
  devuelve 403 si se solicita conductor sin habilitación. Se pueden conservar
  viajes y reservas activos en ambos modos.
- El perfil y el ingreso incluyen driver_enabled y active_mode. El campo role
  sigue orientando a los clientes anteriores. Ningún endpoint público modifica
  privilegios administrativos.
- Quitar el vehículo impide publicar hasta volver a completarlo. La cuenta
  conserva el acceso a su historial de conductor.

El repositorio no incluye un proceso de aprobación documental ni un panel
administrativo ejecutable. La validación del vehículo comprueba su formato.
