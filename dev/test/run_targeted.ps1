param(
  [ValidateSet('cosmetics','locker','presentation','music','combat','host','smoke','all')]
  [string]$Group = 'smoke',
  [string]$Tests = ''
)

$ErrorActionPreference = 'Stop'
$testDir = $PSScriptRoot
$siteDir = (Resolve-Path -LiteralPath (Join-Path $testDir '..\..')).Path
$outDir = Join-Path $testDir 'out'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$groups = @{
  cosmetics = 'locker_fit cosmetics wardrobe3d cosmetic_network tracer_cycle tracer_network ultimate_cloud cosmetics_expansion cosmetics_migration'
  locker = 'locker_collections locker_fit milestones flagcase accounts taborder csp'
  presentation = 'presentation presentation_posefit flagcase wardrobe3d locker_fit muzzle presentation_network cosmetic_network csp'
  music = 'music_routing'
  combat = 'solo bosses multiplayer muzzle rewards_lobby_shotgun'
  host = 'hostcheck room_controls multiplayer'
  smoke = 'solo lobby reel_music csp'
  all = 'solo bosses multiplayer cases accounts rewards_lobby_shotgun reel_music music_routing v086 v087 muzzle cosmetics locker_fit locker_collections cosmetic_network social_lobby lobby v090 v090_net hostcheck room_controls csp wardrobe3d friends rewards_screen modifiers skilltree rejoin controller taborder milestones flagcase presentation presentation_posefit presentation_network tracer_cycle tracer_network ultimate_cloud cosmetics_expansion cosmetics_migration'
}
$selectedTests = $(if ($Tests) { $Tests } else { $groups[$Group] }).Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
foreach ($t in $selectedTests) { if ($t -notmatch '^[a-z0-9_]+$' -or -not (Test-Path -LiteralPath (Join-Path $testDir "$t.js"))) { throw "Unknown test: $t" } }
if (-not $env:CHROMIUM -and (Test-Path -LiteralPath 'C:\Program Files\Google\Chrome\Application\chrome.exe')) {
  $env:CHROMIUM = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
}
$started = @()
function Test-Port([int]$Port) {
  try { $client = [System.Net.Sockets.TcpClient]::new('127.0.0.1', $Port); $client.Dispose(); return $true }
  catch { return $false }
}
try {
  if (-not (Test-Port 8080)) {
    $python = (Get-Command python -ErrorAction Stop).Source
    $started += Start-Process -FilePath $python -ArgumentList @('-m','http.server','8080','--directory',"`"$siteDir`"") -WorkingDirectory $siteDir -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $outDir 'http.log') -RedirectStandardError (Join-Path $outDir 'http.err.log')
  }
  if (-not (Test-Port 9000)) {
    $started += Start-Process -FilePath (Get-Command node -ErrorAction Stop).Source -ArgumentList @('peer-server.js') -WorkingDirectory $testDir -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $outDir 'peer.log') -RedirectStandardError (Join-Path $outDir 'peer.err.log')
  }
  Start-Sleep -Seconds 2
  if (-not (Test-Port 8080) -or -not (Test-Port 9000)) { throw 'Local test servers did not start.' }
  $failed = @()
  Push-Location $testDir
  try {
    foreach ($t in $selectedTests) {
      # Windows PowerShell turns native stderr into ErrorRecords. Capture a failed assertion in its log
      # and continue the selected tests instead of terminating the runner before the log is written.
      $previousErrorAction = $ErrorActionPreference
      try { $ErrorActionPreference = 'Continue'; $result = & node "$t.js" 2>&1 | Out-String; $testExitCode = $LASTEXITCODE }
      finally { $ErrorActionPreference = $previousErrorAction }
      $result | Set-Content -LiteralPath (Join-Path $outDir "$t.log")
      if ($testExitCode -eq 0 -and $result -match '(?i)errors?:?\s*(none|\[\])|ERRS \[\]' -and $result -notmatch '(?i)Error:|TypeError|timed out') {
        Write-Output "PASS  $t"
      } else {
        Write-Output "FAIL  $t  (see out/$t.log)"
        $failed += $t
      }
    }
  } finally { Pop-Location }
  if ($failed.Count) { exit 1 }
} finally {
  foreach ($process in $started) { Stop-Process -Id $process.Id -ErrorAction SilentlyContinue }
}
