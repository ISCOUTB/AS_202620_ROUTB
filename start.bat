@echo off
echo === Iniciando ROUTB ===
echo App:      ROUTB
echo Backend:  https://routb.iscoutb.dev

cd frontend
call flutter pub get
if exist .env (
  flutter run --dart-define-from-file=.env
) else (
  echo Aviso: no existe frontend\.env; la app arrancara sin clave de Google Maps.
  flutter run
)
