class AppException(Exception):
    """Excepción base para errores de aplicación o dominio."""

    def __init__(self, message: str = "Ha ocurrido un error en la aplicación"):
        self.message = message
        super().__init__(self.message)


class EntityNotFoundException(AppException):
    """Excepción cuando un recurso no es encontrado."""
    pass


class ConflictException(AppException):
    """Excepción cuando una operación genera conflicto de estado o duplicidad."""
    pass


class UnauthorizedException(AppException):
    """Excepción cuando las credenciales son inválidas o no autenticadas."""
    pass


class ForbiddenException(AppException):
    """Excepción cuando el usuario autenticado no tiene permisos para la acción."""
    pass


class ValidationException(AppException):
    """Excepción para validaciones de reglas de negocio insatisfechas."""
    pass
