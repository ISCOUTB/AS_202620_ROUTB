from app.shared.exceptions import EntityNotFoundException, UnauthorizedException


class InvalidCredentialsError(UnauthorizedException):
    def __init__(self, message: str = "Teléfono o contraseña incorrectos"):
        super().__init__(message)


class UserNotFoundError(EntityNotFoundException):
    def __init__(self, message: str = "Usuario no encontrado"):
        super().__init__(message)
