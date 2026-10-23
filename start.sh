#!/bin/bash
echo "=== Iniciando ROUTB ==="
echo "App:      ROUTB"
echo "Backend:  https://routb.iscoutb.dev"

cd frontend && flutter pub get
if [ -f .env ]; then
  flutter run --dart-define-from-file=.env
else
  echo "Aviso: no existe frontend/.env; la app arrancará sin clave de Google Maps."
  flutter run
fi
