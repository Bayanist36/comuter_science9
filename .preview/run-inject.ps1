param(
  [Parameter(Mandatory=$true)][string]$Inject,   # путь к файлу с HTML/JS-вставкой перед </body>
  [Parameter(Mandatory=$true)][string]$Marker,   # префикс данных, например PROBE: или AUDIT:
  [string]$DeckPath = 'C:\Users\Владимир\Documents\Gramax\default\comuter_science9\Presentation\Презентация 2.html',
  [string]$WorkDir  = 'C:\Users\Владимир\Documents\Gramax\default\comuter_science9\.preview',
  [string]$Tag      = 'run'
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
$h = Get-Content -Raw -Encoding UTF8 -Path $DeckPath
$ins = Get-Content -Raw -Encoding UTF8 -Path $Inject
$inv = $h -replace '(?s)(</body>)', ($ins + "`n" + '$1')
$auditFile = Join-Path $WorkDir ("inv-" + $Tag + ".html")
Set-Content -Path $auditFile -Value $inv -Encoding UTF8

$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$udd = Join-Path $env:TEMP ('dsh-' + $Tag + '-' + [guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Force -Path $udd | Out-Null
$out = Join-Path $WorkDir ("out-" + $Tag + ".txt")
if (Test-Path $out) { Remove-Item $out -Force }

$p = Start-Process -FilePath $chrome -ArgumentList @(
  '--headless=new', "--user-data-dir=$udd", '--no-first-run', '--disable-gpu',
  '--window-size=1280,720', '--virtual-time-budget=120000', '--dump-dom',
  ('file:///' + ($auditFile -replace '\\','/'))
) -RedirectStandardOutput $out -RedirectStandardError ($out + '.err') -PassThru -Wait

Start-Sleep -Milliseconds 500
if (-not (Test-Path $out)) { Write-Output "NO OUTPUT FILE (exit=$($p.ExitCode))"; exit 2 }
$txt = Get-Content -Raw -Encoding UTF8 -Path $out
if (-not $txt) { Write-Output "EMPTY OUTPUT (exit=$($p.ExitCode))"; Get-Content ($out + '.err') -Tail 6; exit 2 }
$m = [regex]::Match($txt, [regex]::Escape($Marker) + '(\[[\s\S]*?\])</div>')
if (-not $m.Success) { Write-Output "NO MARKER '$Marker' (size=$($txt.Length))"; exit 2 }
$m.Groups[1].Value | ConvertFrom-Json
