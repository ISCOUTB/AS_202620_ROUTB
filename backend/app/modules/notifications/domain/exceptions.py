"""Excepciones de dominio del módulo de notificaciones."""


class DeviceTokenNotFoundError(Exception):
    message = "Token de dispositivo no encontrado"


class DeviceTokenRegistrationError(Exception):
    """No se pudo persistir el token de dispositivo (fallo de base de datos)."""

    message = "No se pudo registrar el token de dispositivo"


class NotificationSendError(Exception):
    """Se lanza cuando FCM rechaza el envío de una notificación."""

    def __init__(self, detail: str = "Error enviando la notificación"):
        self.message = detail
        super().__init__(detail)
