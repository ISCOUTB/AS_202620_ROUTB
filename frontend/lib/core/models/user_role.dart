/// Perfil con el que entra una persona a ROUTB.
///
/// El valor de [wire] es el que viaja al backend en `POST /users/`.
enum UserRole {
  passenger,
  driver;

  /// Valor con el que se serializa hacia la API.
  String get wire => name;

  /// Nombre que ve la persona: «Soy pasajero».
  String get title => switch (this) {
        UserRole.passenger => 'Soy pasajero',
        UserRole.driver => 'Soy conductor',
      };

  /// Texto bajo el nombre en las tarjetas de rol.
  String get tagline => switch (this) {
        UserRole.passenger => 'Encuentra un viaje seguro hasta la UTB.',
        UserRole.driver => 'Comparte tu ruta y ayuda a otros estudiantes.',
      };

  /// Encabezado del hero de cada modo.
  String get modeLabel => switch (this) {
        UserRole.passenger => 'Modo pasajero',
        UserRole.driver => 'Modo conductor',
      };

  /// Insignia que confirma el registro.
  String get registrationLabel => switch (this) {
        UserRole.passenger => 'Registro como pasajero',
        UserRole.driver => 'Registro como conductor',
      };

  /// Interpreta el valor de la API; cualquier cosa desconocida cae en
  /// [UserRole.passenger], que es el valor por defecto del backend.
  static UserRole fromWire(String? raw) =>
      raw == UserRole.driver.name ? UserRole.driver : UserRole.passenger;
}