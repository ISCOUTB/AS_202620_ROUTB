FROM python:3.14-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8000

WORKDIR /app

# Crear usuario sin privilegios ANTES de copiar nada con --chown
RUN adduser --disabled-password --gecos "" appuser

# Instalar dependencias con verificación estricta de hashes
COPY requirements.txt .
RUN pip install --no-cache-dir --only-binary :all: --require-hashes -r requirements.txt

# Copiar el código de la aplicación con dueño del usuario no-root
COPY --chown=appuser:appuser app ./app
COPY --chown=appuser:appuser migrations ./migrations
COPY --chown=appuser:appuser alembic.ini .

# Cambiar al usuario sin privilegios antes del CMD
USER appuser

EXPOSE 8000

# Ejecutar Uvicorn usando la variable PORT (compatible con Render y local)
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]