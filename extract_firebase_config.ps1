# PowerShell script to extract Firebase configuration from google-services.json
# Usage: .\extract_firebase_config.ps1

$googleServicesPath = "android\app\google-services.json"

if (-not (Test-Path $googleServicesPath)) {
    Write-Host "google-services.json not found at: $googleServicesPath" -ForegroundColor Red
    Write-Host "Please download it from Firebase Console and place it in android/app/" -ForegroundColor Yellow
    exit 1
}

Write-Host "Found google-services.json" -ForegroundColor Green

try {
    $json = Get-Content $googleServicesPath | ConvertFrom-Json
    
    # Extract Android API Key
    $apiKey = $json.client[0].api_key[0].current_key
    $appId = $json.client[0].client_info.mobilesdk_app_id
    $projectId = $json.project_info.project_id
    $storageBucket = $json.project_info.storage_bucket
    $messagingSenderId = $json.project_info.project_number
    
    Write-Host ""
    Write-Host "Extracted Firebase Configuration:" -ForegroundColor Cyan
    Write-Host "API Key: $apiKey" -ForegroundColor White
    Write-Host "App ID: $appId" -ForegroundColor White
    Write-Host "Project ID: $projectId" -ForegroundColor White
    Write-Host "Storage Bucket: $storageBucket" -ForegroundColor White
    Write-Host "Messaging Sender ID: $messagingSenderId" -ForegroundColor White
    
    Write-Host ""
    Write-Host "Values extracted successfully!" -ForegroundColor Green
    Write-Host "These values will be used to update firebase_options.dart" -ForegroundColor Yellow
    
} catch {
    $errorMsg = $_.Exception.Message
    Write-Host "Error parsing google-services.json: $errorMsg" -ForegroundColor Red
    exit 1
}
