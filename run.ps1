# Root convenience script to run ADB reverse and launch Flutter app
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArgs
)

& powershell -ExecutionPolicy Bypass -File ".\scripts\run.ps1" @FlutterArgs
