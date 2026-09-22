<#
  Ray CLI installer (Windows) - installs the `ray-cli` client.

    irm https://raw.githubusercontent.com/techspecs/ray-headless/main/install.ps1 | iex

  (Installs the newest release, betas included - the script resolves the version via the GitHub API.)

  Options (when run as a file):  -Version <tag>  -Dir <path>
  Env equivalents: RAY_VERSION, RAY_INSTALL_DIR
#>
[CmdletBinding()]
param(
  [string]$Version = $env:RAY_VERSION,
  [string]$Dir     = $env:RAY_INSTALL_DIR
)
$ErrorActionPreference = 'Stop'
$repo = 'techspecs/ray-headless'
$bin  = 'ray-cli.exe'
$ua   = @{ 'User-Agent' = 'ray-install'; 'Accept' = 'application/vnd.github+json' }

if (-not [Environment]::Is64BitOperatingSystem) { throw 'ray-install: only Windows x64 is supported.' }

if (-not $Version) {
  $Version = (Invoke-RestMethod "https://api.github.com/repos/$repo/releases" -Headers $ua | Select-Object -First 1).tag_name
  if (-not $Version) { throw 'ray-install: could not resolve the latest version; pass -Version.' }
}
Write-Host "ray-install: ray-cli $Version -> windows-x64"

$base = "https://github.com/$repo/releases/download/$Version"
$file = "ray-cli-windows-x64-$Version.zip"
$tmp  = Join-Path $env:TEMP ('ray-install-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
  $zip = Join-Path $tmp $file
  Invoke-WebRequest "$base/$file" -OutFile $zip -UseBasicParsing

  # verify against SHA256SUMS when present
  try {
    $sums = Join-Path $tmp 'SHA256SUMS'
    Invoke-WebRequest "$base/SHA256SUMS" -OutFile $sums -UseBasicParsing
    $want = ((Select-String -Path $sums -Pattern ([regex]::Escape($file)) | Select-Object -First 1).Line -split '\s+')[0]
    if ($want) {
      $got = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
      if ($got -ne $want.ToLower()) { throw "checksum mismatch for $file" }
      Write-Host 'ray-install: checksum ok'
    }
  } catch { Write-Warning "ray-install: checksum step skipped ($($_.Exception.Message))" }

  $ex = Join-Path $tmp 'x'
  Expand-Archive -Path $zip -DestinationPath $ex -Force
  $src = Get-ChildItem -Path $ex -Recurse -Filter $bin | Select-Object -First 1
  if (-not $src) { throw "could not find $bin inside $file" }

  if (-not $Dir) { $Dir = Join-Path $env:LOCALAPPDATA 'Programs\Ray\bin' }
  New-Item -ItemType Directory -Path $Dir -Force | Out-Null
  Copy-Item $src.FullName (Join-Path $Dir $bin) -Force
  Write-Host "ray-install: installed $(Join-Path $Dir $bin)"

  # persist on the user PATH
  $userPath = [Environment]::GetEnvironmentVariable('Path','User')
  if (($userPath -split ';') -notcontains $Dir) {
    [Environment]::SetEnvironmentVariable('Path', ($userPath.TrimEnd(';') + ';' + $Dir), 'User')
    Write-Host "ray-install: added $Dir to your user PATH"
  }
  # make it work in THIS session too (iex runs in-process)
  if (($env:Path -split ';') -notcontains $Dir) { $env:Path = "$env:Path;$Dir" }

  Write-Host ''
  Write-Host 'ray-install: done. Try:  ray-cli --help'
  Write-Host '(Open a new terminal if an existing one does not see it yet.)'
}
finally {
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
