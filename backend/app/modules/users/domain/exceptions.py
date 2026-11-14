from app.shared.exceptions import ConflictException, ValidationException


class UserAlreadyExistsError(ConflictException):
    def __init__(self, message: str = "El teléfono ya está registrado"):
        super().__init__(message)


class ActiveCommitmentsError(ConflictException):
    """La cuenta no se puede eliminar mientras tenga compromisos activos."""

    def __init__(
        self,
        message: str = (
            "Cancela tus rutas activas y solicitudes pendientes antes de "
            "eliminar tu cuenta."
        ),
    ):
        super().__init__(message)


class InvalidCurrentPasswordError(ValidationException):
    """La contraseña actual no coincide con la guardada."""

    def __init__(self, message: str = "La contraseña actual no es correcta"):
        super().__init__(message)
