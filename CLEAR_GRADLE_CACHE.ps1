# PowerShell script to clear Gradle cache and rebuild
# Run this script from the orthoq_app directory

Write-Host "Clearing Gradle cache..." -ForegroundColor Yellow

# Navigate to android directory
Set-Location android

# Clear Gradle cache
Write-Host "Clearing .gradle directory..." -ForegroundColor Cyan
if (Test-Path .gradle) {
    Remove-Item -Recurse -Force .gradle
    Write-Host ".gradle directory cleared" -ForegroundColor Green
}

# Clear build directories
Write-Host "Clearing build directories..." -ForegroundColor Cyan
if (Test-Path app\build) {
    Remove-Item -Recurse -Force app\build
    Write-Host "app\build cleared" -ForegroundColor Green
}

# Clear Flutter build cache
Set-Location ..
Write-Host "Clearing Flutter build cache..." -ForegroundColor Cyan
flutter clean

# Clear global Gradle cache (optional - uncomment if needed)
# Write-Host "Clearing global Gradle cache..." -ForegroundColor Cyan
# $gradleHome = "$env:USERPROFILE\.gradle\caches"
# if (Test-Path $gradleHome) {
#     Remove-Item -Recurse -Force $gradleHome
#     Write-Host "Global Gradle cache cleared" -ForegroundColor Green
# }

Write-Host "`nCache clearing complete!" -ForegroundColor Green
Write-Host "Now run: flutter pub get" -ForegroundColor Yellow
Write-Host "Then: flutter run" -ForegroundColor Yellow
















