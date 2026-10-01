@echo off
echo === Iniciando ROUTB ===
echo App:      ROUTB
echo Backend:  https://as-202620-routb.onrender.com

cd frontend
call flutter pub get
flutter run