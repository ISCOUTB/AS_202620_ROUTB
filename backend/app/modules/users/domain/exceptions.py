from app.shared.exceptions import ConflictException


class UserAlreadyExistsError(ConflictException):
    def __init__(self, message: str = "El teléfono ya está registrado"):
        super().__init__(message)
