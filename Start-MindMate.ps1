# Get the active IPv4 address automatically
# Priority: Windows 10/11 -> Ethernet -> Any private IP (excluding link-local 169.254.x.x)
$ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "*Wi-Fi*" -ErrorAction SilentlyContinue | 
    Where-Object { $_.IPAddress -notlike "169.254.*" } | 
    Select-Object -First 1).IPAddress

if ([string]::IsNullOrEmpty($ip)) {
    # Fallback to Ethernet
    $ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "*Ethernet*" -ErrorAction SilentlyContinue | 
        Where-Object { $_.IPAddress -notlike "169.254.*" } | 
        Select-Object -First 1).IPAddress
}

if ([string]::IsNullOrEmpty($ip)) {
    # Ultimate fallback: Get any private IP except link-local (169.254.x.x)
    $ip = (Get-NetIPAddress -AddressFamily IPv4 | 
        Where-Object { ($_.IPAddress -like "192.168.*" -or $_.IPAddress -like "10.*" -or $_.IPAddress -like "172.16.*") -and $_.IPAddress -notlike "169.254.*" } | 
        Select-Object -First 1).IPAddress
}

if ([string]::IsNullOrEmpty($ip)) {
    Write-Host "Could not find an active IPv4 address. Make sure you are connected to the network." -ForegroundColor Red
    Exit
}

Write-Host "------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Detected Local Computer IP: $ip" -ForegroundColor Green
Write-Host "Phone and Laptop MUST be on the same Wi-Fi network!" -ForegroundColor Yellow
Write-Host "------------------------------------------------------" -ForegroundColor Cyan

# Update api_config.dart
$apiConfigFile = ".\mindmate_patient\lib\api_config.dart"
if (Test-Path $apiConfigFile) {
    # We replace any existing http://XXX.XXX.XXX.XXX:8000 with the new IP dynamically
    (Get-Content $apiConfigFile) -replace 'http://[0-9\.]+:8000', "http://${ip}:8000" | Set-Content $apiConfigFile
    Write-Host "Successfully updated api_config.dart for automatic connection." -ForegroundColor Green
} else {
    Write-Host "Could not find api_config.dart at $apiConfigFile" -ForegroundColor Red
}

Write-Host "Starting AI Microservice Server..." -ForegroundColor Cyan
cd .\ai_microservice

if (-not (Test-Path "venv")) {
    Write-Host "Virtual environment not found. Setting up Python venv..." -ForegroundColor Yellow
    python -m venv venv
    .\venv\Scripts\activate
    Write-Host "Installing dependencies..." -ForegroundColor Yellow
    pip install -r requirements.txt
} else {
    .\venv\Scripts\activate
}

Write-Host "Your API Server is running on: http://${ip}:8000" -ForegroundColor Green
Write-Host "Keep this window open! Now you can run 'flutter run' in mindmate_patient." -ForegroundColor Yellow
Write-Host "------------------------------------------------------" -ForegroundColor Cyan

Write-Host "Syncing Remote Faces..." -ForegroundColor Yellow
.\venv\Scripts\python.exe manage.py sync_faces

Write-Host "Starting Web Server..." -ForegroundColor Yellow
.\venv\Scripts\python.exe manage.py runserver 0.0.0.0:8000
