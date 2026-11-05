$ErrorActionPreference = "Stop"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " Packaging mod for Nexus Mods (Zero .BAT, Standalone EXE)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

$distDir = "F:\projects\cyber\dist"
$packageDir = "$distDir\package"
$zipFile = "$distDir\CyberCompanion_v1.0.0_Nexus.zip"
$modDir = "$packageDir\bin\x64\plugins\cyber_engine_tweaks\mods\CyberCompanion"

if (Test-Path $packageDir) {
    Remove-Item -Recurse -Force $packageDir
}

New-Item -ItemType Directory -Force -Path $modDir | Out-Null

Write-Host "[1/3] Copying CET game mod (init.lua)..." -ForegroundColor Yellow
Copy-Item "F:\projects\cyber\init.lua" -Destination "$modDir\init.lua" -Force

Write-Host "[2/3] Copying Standalone CyberCompanionBridge.exe..." -ForegroundColor Yellow
Copy-Item "F:\projects\cyber\dist\CyberCompanionBridge.exe" -Destination "$modDir\CyberCompanionBridge.exe" -Force
Copy-Item "F:\projects\cyber\config.json" -Destination "$modDir\config.json" -Force
Copy-Item "F:\projects\cyber\.env" -Destination "$modDir\.env" -Force
Copy-Item "F:\projects\cyber\README.md" -Destination "$packageDir\README.txt" -Force

Write-Host "[3/3] Creating Nexus Mods Zip archive..." -ForegroundColor Yellow
if (Test-Path $zipFile) {
    Remove-Item -Force $zipFile
}
Compress-Archive -Path "$packageDir\*" -DestinationPath $zipFile -Force

Write-Host "========================================================" -ForegroundColor Green
Write-Host " SUCCESS! Nexus Mods Release created without any .bat files:" -ForegroundColor Green
Write-Host " $zipFile" -ForegroundColor White
Write-Host "========================================================" -ForegroundColor Green
