@echo off
chcp 65001 > nul
echo ========================================================
echo  Установка мода Cyber Companion в Cyberpunk 2077
echo ========================================================
echo.

set "GAME_DIR="

:: Поиск стандартных путей игры
if exist "C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077\bin\x64\Cyberpunk2077.exe" (
    set "GAME_DIR=C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077"
) else if exist "D:\SteamLibrary\steamapps\common\Cyberpunk 2077\bin\x64\Cyberpunk2077.exe" (
    set "GAME_DIR=D:\SteamLibrary\steamapps\common\Cyberpunk 2077"
) else if exist "D:\Games\Cyberpunk 2077\bin\x64\Cyberpunk2077.exe" (
    set "GAME_DIR=D:\Games\Cyberpunk 2077"
) else if exist "E:\Games\Cyberpunk 2077\bin\x64\Cyberpunk2077.exe" (
    set "GAME_DIR=E:\Games\Cyberpunk 2077"
) else if exist "F:\Games\Cyberpunk 2077\bin\x64\Cyberpunk2077.exe" (
    set "GAME_DIR=F:\Games\Cyberpunk 2077"
)

if "%GAME_DIR%"=="" (
    echo [!] Игра не найдена в стандартных папках.
    set /p "GAME_DIR=Укажи полный путь к папке Cyberpunk 2077: "
)

if not exist "%GAME_DIR%\bin\x64\Cyberpunk2077.exe" (
    echo [ОШИБКА] В указанной папке нет Cyberpunk2077.exe!
    pause
    exit /b
)

echo [OK] Найдена игра: %GAME_DIR%

set "MOD_DIR=%GAME_DIR%\bin\x64\plugins\cyber_engine_tweaks\mods\CyberCompanion"
if not exist "%MOD_DIR%" mkdir "%MOD_DIR%"

echo Копирование init.lua в CET...
copy /y "f:\projects\cyber\init.lua" "%MOD_DIR%\init.lua"

echo.
echo ========================================================
echo  МОД УСПЕШНО УСТАНОВЛЕН В ИГРУ!
echo  Папка: %MOD_DIR%
echo ========================================================
pause
