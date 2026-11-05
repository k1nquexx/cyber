@echo off
chcp 65001 > nul
cd /d "f:\projects\cyber"
echo ========================================================
echo  Запуск голосового сервера AI Companion (Рэй)
echo ========================================================
echo.
python voice_listener.py
pause
