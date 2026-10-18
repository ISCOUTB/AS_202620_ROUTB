@echo off
echo === Iniciando ROUTB ===
echo App:      ROUTB
echo Backend:  https://routb.iscoutb.dev

cd frontend
call flutter pub get
flutter run