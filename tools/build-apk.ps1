# HINOPT Display Player - APK Build Automation Script
$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   COMPILING HINOPT DISPLAY PLAYER ANDROID APK BINARY     " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$GRADLE_BAT = "C:\Users\abhin\.gradle\wrapper\dists\gradle-8.9-bin\90cnw93cvbtalezasaz0blq0a\gradle-8.9\bin\gradle.bat"
$PLAYER_DIR = Join-Path $PSScriptRoot "..\apps\android-player"
$OUTPUT_DIR = Join-Path $PSScriptRoot "..\bin"

if (-not (Test-Path $OUTPUT_DIR)) {
    New-Item -ItemType Directory -Path $OUTPUT_DIR | Out-Null
}

Push-Location $PLAYER_DIR
try {
    Write-Host "Running Gradle assembleDebug..." -ForegroundColor Yellow
    & $GRADLE_BAT assembleDebug
    
    $BUILT_APK = Join-Path $PLAYER_DIR "app\build\outputs\apk\debug\app-debug.apk"
    $DEST_APK = Join-Path $OUTPUT_DIR "hinopt-player-v1.0.0.apk"
    
    if (Test-Path $BUILT_APK) {
        Copy-Item -Path $BUILT_APK -Destination $DEST_APK -Force
        Write-Host "`nSUCCESS: APK compiled and copied to:" -ForegroundColor Green
        Write-Host "  $DEST_APK" -ForegroundColor White
        Write-Host "Size: $((Get-Item $DEST_APK).Length / 1MB) MB" -ForegroundColor Green
    } else {
        Write-Error "Build finished but APK not found at expected path: $BUILT_APK"
    }
} finally {
    Pop-Location
}
