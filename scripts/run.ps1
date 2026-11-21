# PowerShell script to reverse forward ADB ports and launch the Flutter app
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArgs
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$reverseScript = Join-Path $scriptDir "adb_reverse.ps1"

if (Test-Path $reverseScript) {
    & powershell -ExecutionPolicy Bypass -File $reverseScript
}

Write-Host "`n[Flutter Run] Starting fvm flutter run $FlutterArgs...`n" -ForegroundColor Green
fvm flutter run @FlutterArgs
