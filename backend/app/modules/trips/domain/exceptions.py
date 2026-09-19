from app.shared.exceptions import ConflictException, EntityNotFoundException, ForbiddenException


class TripNotFoundError(EntityNotFoundException):
    def __init__(self, message: str = "Viaje no encontrado"):
        super().__init__(message)


class TripNotAuthorizedError(ForbiddenException):
    def __init__(self, message: str = "No autorizado para operar sobre este viaje"):
        super().__init__(message)


class NoSeatsAvailableError(ConflictException):
    def __init__(self, message: str = "No hay cupos disponibles"):
        super().__init__(message)
