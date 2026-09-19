from app.shared.exceptions import (
    ConflictException,
    EntityNotFoundException,
    ForbiddenException,
    ValidationException,
)


class TripRequestNotFoundError(EntityNotFoundException):
    def __init__(self, message: str = "Solicitud no encontrada"):
        super().__init__(message)


class TripNotActiveError(EntityNotFoundException):
    def __init__(self, message: str = "El viaje no existe o no está activo"):
        super().__init__(message)


class DriverCannotRequestError(ValidationException):
    def __init__(self, message: str = "El conductor no puede solicitar cupo en su propio viaje"):
        super().__init__(message)


class ActiveRequestAlreadyExistsError(ValidationException):
    def __init__(self, message: str = "Ya tienes una solicitud activa para este viaje"):
        super().__init__(message)


class UnauthorizedRequestActionError(ForbiddenException):
    def __init__(self, message: str = "No tienes permiso para gestionar esta solicitud"):
        super().__init__(message)


class NoAvailableSeatsError(ConflictException):
    def __init__(self, message: str = "No hay cupos disponibles en este viaje"):
        super().__init__(message)


class NoSeatsToAcceptError(ConflictException):
    def __init__(self, message: str = "No hay cupos disponibles para aceptar más pasajeros"):
        super().__init__(message)
