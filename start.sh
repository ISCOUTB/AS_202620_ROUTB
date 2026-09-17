#!/bin/bash
echo "=== Iniciando ROUTB ==="

echo "1. Verificando dependencias e iniciando el Backend en segundo plano..."
(cd backend && source .venv/bin/activate && pip install -r requirements.txt && uvicorn app.main:app --reload) &
BACKEND_PID=$!

echo "2. Verificando dependencias e iniciando el Frontend..."
cd frontend && flutter pub get && flutter run

# Al cerrar la app de Flutter, matamos el proceso del backend
kill $BACKEND_PID