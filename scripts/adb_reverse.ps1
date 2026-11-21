# PowerShell script to reverse forward backend ports to all connected ADB devices (USB & Wireless)
$ports = @(8085, 8000)

$rawDevices = adb devices
$deviceList = @()

foreach ($line in ($rawDevices -split "`r?`n")) {
    if ($line -match '^([^\s]+)\s+device$') {
        $deviceList += $matches[1]
    }
}

if ($deviceList.Count -eq 0) {
    Write-Host "[ADB Reverse] No active ADB devices found." -ForegroundColor Yellow
    exit 0
}

Write-Host "[ADB Reverse] Found $($deviceList.Count) device(s): $($deviceList -join ', ')" -ForegroundColor Cyan

foreach ($device in $deviceList) {
    Write-Host "`n--> Configuring device: $device" -ForegroundColor Green
    foreach ($port in $ports) {
        $result = adb -s $device reverse tcp:$port tcp:$port 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    [OK] tcp:$port -> tcp:$port" -ForegroundColor Gray
        } else {
            Write-Host "    [ERR] tcp:$port -> tcp:$port : $result" -ForegroundColor Red
        }
    }
}

Write-Host "`n[ADB Reverse] Successfully configured all devices.`n" -ForegroundColor Cyan
