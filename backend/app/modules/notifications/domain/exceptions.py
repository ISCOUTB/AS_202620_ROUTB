"""Excepciones de dominio del módulo de notificaciones."""


class DeviceTokenNotFoundError(Exception):
    message = "Token de dispositivo no encontrado"


class NotificationSendError(Exception):
    """Se lanza cuando FCM rechaza el envío de una notificación."""

    def __init__(self, detail: str = "Error enviando la notificación"):
        self.message = detail
        super().__init__(detail)
