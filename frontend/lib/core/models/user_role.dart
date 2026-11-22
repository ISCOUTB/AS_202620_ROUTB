/// Modalidad de viaje que muestra la aplicación.
enum UserRole {
  passenger,
  driver;

  /// Valor con el que se serializa hacia la API.
  String get wire => name;

  String get label => this == UserRole.driver ? 'Conductor' : 'Pasajero';

  /// Interpreta el valor de la API; cualquier cosa desconocida cae en
  /// [UserRole.passenger], que es el valor por defecto del backend.
  static UserRole fromWire(String? raw) =>
      raw == UserRole.driver.name ? UserRole.driver : UserRole.passenger;
}
