# Windows: run one area's tests (the groups are tags in suite.txt), or everything.
#   powershell -File .\run_targeted.ps1 -Group hud        powershell -File .\run_targeted.ps1 -Group all
#   powershell -File .\run_targeted.ps1 -Tests "solo lobby"
# Same runner as Linux (run_suite.js): parallel, starts and stops its own servers, writes out\<test>.log.
param([string]$Group = 'smoke', [string]$Tests = '', [switch]$Build)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$runArgs = @()
if ($Build) { $runArgs += '--build' }
if ($Tests) { $runArgs += $Tests.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries) }
elseif ($Group -ne 'all') { $runArgs += $Group.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { "@$_" } }
node run_suite.js @runArgs
exit $LASTEXITCODE
