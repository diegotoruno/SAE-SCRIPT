param(
    [Parameter(Mandatory = $true)][string]$CookieFile,
    [string]$Workspace = (Join-Path $env:LOCALAPPDATA 'Potassium\workspace'),
    [string]$Python = 'pythonw.exe'
)
$ErrorActionPreference = 'Stop'
$bridgeCookie = (Resolve-Path -LiteralPath $CookieFile).Path
$bridgeWorkspace = (Resolve-Path -LiteralPath $Workspace).Path
$bridgeScript = Join-Path $PSScriptRoot 'best_ping_bridge.py'
$bridgePidFile = Join-Path $bridgeWorkspace 'sae_best_ping_bridge.pid'
if (Test-Path -LiteralPath $bridgePidFile) {
    $bridgeExistingId = [int](Get-Content -LiteralPath $bridgePidFile)
    $bridgeExisting = Get-CimInstance Win32_Process -Filter "ProcessId = $bridgeExistingId"
    if ($bridgeExisting -and $bridgeExisting.CommandLine.Contains($bridgeScript)) {
        Write-Output "Best Ping ya esta activo (PID $bridgeExistingId)."
        return
    }
}
foreach ($bridgePath in @($bridgeCookie, $bridgeWorkspace, $bridgeScript, $bridgePidFile)) {
    if ($bridgePath.Contains('"')) { throw 'Ruta invalida' }
}
$bridgeArgs = '"' + $bridgeScript + '" --cookie-file "' + $bridgeCookie + '" --workspace "' + $bridgeWorkspace + '" --pid-file "' + $bridgePidFile + '"'
Start-Process -FilePath $Python -ArgumentList $bridgeArgs -WindowStyle Hidden
Write-Output 'Proceso local Best Ping iniciado.'
