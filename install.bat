@echo off
chcp 65001 > nul
echo ========================================================
echo  Установка окружения для AI Companion (Cyberpunk 2077)
echo ========================================================
echo.

cd /d "f:\projects\cyber"

echo [1/3] Проверка Python...
python --version
if errorlevel 1 (
    echo [ОШИБКА] Python не найден! Установи Python с python.org и поставь галочку "Add to PATH"
    pause
    exit /b
)

echo.
echo [2/3] Установка библиотек (Whisper, Torch, SoundDevice, DeepSeek SDK)...
pip install -r requirements.txt

echo.
echo [3/3] Готово! Настройка завершена.
echo.
pause
