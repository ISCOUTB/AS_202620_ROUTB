@echo off
echo === Iniciando ROUTB ===

echo 1. Verificando dependencias e iniciando el Backend (FastAPI)...
:: Abre una nueva terminal, activa el entorno, instala requerimientos y ejecuta uvicorn
start cmd /k "cd backend && call .venv\Scripts\activate && pip install -r requirements.txt && uvicorn app.main:app --reload"

echo 2. Verificando dependencias e iniciando el Frontend (Flutter)...
cd frontend
call flutter pub get
flutter run