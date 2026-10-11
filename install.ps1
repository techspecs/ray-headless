<#
  Ray installer (Windows) - installs the `ray-cli` client, or with -Server the whole
  Ray Headless server: the `ray` command (`ray serve` starts it) and `ray-cli`.

    irm https://raw.githubusercontent.com/techspecs/ray-headless/main/install.ps1 | iex

  The server (a download of several hundred MB), either of:

    $env:RAY_INSTALL_SERVER = '1'; irm https://raw.githubusercontent.com/techspecs/ray-headless/main/install.ps1 | iex
    & ([scriptblock]::Create((irm https://raw.githubusercontent.com/techspecs/ray-headless/main/install.ps1))) -Server

  (Installs the newest release, betas included - the script resolves the version via the GitHub API.)

  Options (when run as a file or as the scriptblock above):  -Server  -Version <tag>  -Dir <path>  -NoPath
  Env equivalents: RAY_INSTALL_SERVER=1, RAY_VERSION, RAY_INSTALL_DIR
  Default folder: %LOCALAPPDATA%\Programs\Ray\bin, or %LOCALAPPDATA%\Programs\Ray\headless with -Server.
#>
[CmdletBinding()]
param(
  # Install the server too: ray-server, ray-cli and the `ray` command.
  [switch]$Server,
  [string]$Version = $env:RAY_VERSION,
  [string]$Dir     = $env:RAY_INSTALL_DIR,
  # Leave PATH alone (for scripts that put the folder on PATH themselves).
  [switch]$NoPath
)
# Everything below runs in its own scope: `irm ... | iex` runs a script in the caller's session,
# where this script's settings, variables and functions would otherwise stay behind.
& {
$ErrorActionPreference = 'Stop'
$repo = 'techspecs/ray-headless'
$bin  = 'ray-cli.exe'
$ua   = @{ 'User-Agent' = 'ray-install'; 'Accept' = 'application/vnd.github+json' }
# `irm ... | iex` cannot pass -Server: RAY_INSTALL_SERVER=1 does the same.
$serverMode = $Server.IsPresent -or ($env:RAY_INSTALL_SERVER -match '^(1|true|yes|on)$')

if (-not [Environment]::Is64BitOperatingSystem) { throw 'ray-install: only Windows x64 is supported.' }
# Older Windows 10 builds don't offer TLS 1.2 by default; GitHub needs it.
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

# Download with a progress bar that shows the amount, the speed and the time left.
function Save-RayDownload([string]$url, [string]$out) {
  $request = [Net.HttpWebRequest]::Create($url)
  $request.UserAgent = 'ray-install'
  try { $response = $request.GetResponse() }
  catch {
    $why = $_.Exception; if ($why.InnerException) { $why = $why.InnerException }
    throw "ray-install: download failed: $url ($($why.Message))"
  }
  $activity = 'Downloading ' + (Split-Path -Leaf $out)
  try {
    $total = $response.ContentLength
    $in = $response.GetResponseStream()
    $saved = [IO.File]::Create($out)
    try {
      $buffer = New-Object byte[] (1MB)
      $done = 0L; $clock = [Diagnostics.Stopwatch]::StartNew(); $nextUpdate = 0L
      while (($n = $in.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $saved.Write($buffer, 0, $n); $done += $n
        if ($clock.ElapsedMilliseconds -ge $nextUpdate) {
          $nextUpdate = $clock.ElapsedMilliseconds + 500
          $speed = $done / [Math]::Max($clock.Elapsed.TotalSeconds, 0.001)
          if ($total -gt 0) {
            $status = '{0:N0} of {1:N0} MB, {2:N1} MB/s' -f ($done / 1MB), ($total / 1MB), ($speed / 1MB)
            Write-Progress -Activity $activity -Status $status -PercentComplete ([int](100 * $done / $total)) `
                           -SecondsRemaining ([int](($total - $done) / [Math]::Max($speed, 1)))
          } else {
            Write-Progress -Activity $activity -Status ('{0:N0} MB, {1:N1} MB/s' -f ($done / 1MB), ($speed / 1MB))
          }
        }
      }
      if ($total -gt 0 -and $done -ne $total) { throw "ray-install: download incomplete: $url" }
    } finally { $saved.Dispose(); $in.Dispose() }
  } finally {
    $response.Dispose()
    Write-Progress -Activity $activity -Completed
  }
}

# Programs started from the install folder (an upgrade can't replace files in use).
function Get-RunningFrom([string]$folder) {
  $prefix = ($folder.TrimEnd('\') + '\').ToLowerInvariant()
  # (one system query: asking each process for its path takes many seconds)
  try { $all = Get-CimInstance -ClassName Win32_Process -Property Name, ExecutablePath -ErrorAction Stop }
  catch { $all = Get-Process -Name 'ray-server', 'ray-cli' -ErrorAction SilentlyContinue | Select-Object Name, @{ n = 'ExecutablePath'; e = { $_.Path } } }
  @($all | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.ToLowerInvariant().StartsWith($prefix) })
}

# In PowerShell, `ray` runs ray.ps1 rather than ray.cmd when both are there. Where PowerShell
# scripts are turned off (Windows' own default), ray.ps1 would be refused, so it is left out
# and `ray` runs ray.cmd. (A setting made for this window only does not count.)
function Test-ScriptsAllowed {
  foreach ($scope in 'MachinePolicy', 'UserPolicy', 'CurrentUser', 'LocalMachine') {
    $policy = [string](Get-ExecutionPolicy -Scope $scope)
    if ($policy -ne 'Undefined') { return ($policy -in @('Unrestricted', 'RemoteSigned', 'Bypass')) }
  }
  return $false
}

# The user PATH as it is stored: entries like %USERPROFILE%\bin stay as they are. (Read and
# written through [Environment], they would be saved expanded, as fixed folders.)
function Get-UserPath {
  $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment')
  if (-not $key) { return '' }
  try { return [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) }
  finally { $key.Close() }
}
function Set-UserPath([string]$value) {
  $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment')
  try { $key.SetValue('Path', $value, [Microsoft.Win32.RegistryValueKind]::ExpandString) }
  finally { $key.Close() }
  # Setting a variable through [Environment] tells Windows the environment changed, so new
  # terminals see the new PATH; a helper variable, set and removed, does that here.
  [Environment]::SetEnvironmentVariable('RAY_INSTALL_PATH_CHANGED', '1', 'User')
  [Environment]::SetEnvironmentVariable('RAY_INSTALL_PATH_CHANGED', $null, 'User')
}

# It must start here (its DLLs load), or nothing is said to be installed.
function Assert-Starts([string]$exe, [string]$arg) {
  # (stderr lines from a native program must not stop this script; only its exit code counts)
  $previous = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { $out = & $exe $arg 2>&1 | Out-String } finally { $ErrorActionPreference = $previous }
  $code = $LASTEXITCODE
  if ($code -ne 0) {
    # (the one thing Ray needs that Windows may not have yet; the server brings its installer)
    if ($code -eq -1073741515) {
      $redist = Join-Path (Split-Path -Parent $exe) 'vc_redist.x64.exe'
      if (-not (Test-Path $redist)) { $redist = 'https://aka.ms/vs/17/release/vc_redist.x64.exe' }
      throw "ray-install: $exe was installed but does not start: Windows is missing the Microsoft Visual C++ runtime. Install it ($redist), then run this installer again."
    }
    throw "ray-install: $exe was installed but does not start (exit code $code): $($out.Trim())"
  }
}

if (-not $Version) {
  # (Windows PowerShell passes the whole JSON list on as ONE object: ForEach-Object takes it
  # apart, or .tag_name would be every release's tag at once.)
  $latest = Invoke-RestMethod "https://api.github.com/repos/$repo/releases?per_page=1" -Headers $ua |
    ForEach-Object { $_ } | Select-Object -First 1
  $Version = [string]$latest.tag_name
  if (-not $Version) { throw 'ray-install: could not resolve the latest version; pass -Version.' }
}
if ($serverMode) {
  Write-Host "ray-install: Ray Headless server $Version -> windows-x64 (a download of several hundred MB)"
  $file = "ray-headless-windows-x64-$Version.zip"
  if (-not $Dir) { $Dir = Join-Path $env:LOCALAPPDATA 'Programs\Ray\headless' }
} else {
  Write-Host "ray-install: ray-cli $Version -> windows-x64"
  $file = "ray-cli-windows-x64-$Version.zip"
  if (-not $Dir) { $Dir = Join-Path $env:LOCALAPPDATA 'Programs\Ray\bin' }
}
$Dir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Dir).TrimEnd('\')
$parent = try { Split-Path -Parent $Dir } catch { $null }   # (none for a drive like T:\)
if (-not $parent) { throw "ray-install: choose a folder for Ray with -Dir, not $Dir" }

if ($serverMode -and (Test-Path $Dir)) {
  # The server's folder is replaced as a whole, so it must be new, empty or an earlier install.
  $isEarlier = (Test-Path (Join-Path $Dir 'ray-cli.exe')) -and (Test-Path (Join-Path $Dir 'ray.cmd'))
  if (-not $isEarlier -and (Get-ChildItem -LiteralPath $Dir -Force | Select-Object -First 1)) {
    throw "ray-install: $Dir holds other files; choose a new folder with -Dir."
  }
}
$running = Get-RunningFrom $Dir
if ($running.Count -gt 0) {
  $names = ($running | ForEach-Object { $_.Name } | Select-Object -Unique) -join ', '
  throw "ray-install: Ray is running from $Dir ($names). Stop it, then run this installer again."
}

$base = "https://github.com/$repo/releases/download/$Version"
# The server unpacks to about a GB: it is unpacked next to its folder and moved into place
# without a second copy.
if ($serverMode) {
  New-Item -ItemType Directory -Path $parent -Force | Out-Null
  $tmp = Join-Path $parent ('.ray-install-' + [guid]::NewGuid().ToString('N'))
} else {
  $tmp = Join-Path $env:TEMP ('ray-install-' + [guid]::NewGuid().ToString('N'))
}
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
  $zip = Join-Path $tmp $file
  Save-RayDownload "$base/$file" $zip

  # verify against SHA256SUMS when present (a download that doesn't match is never installed)
  $want = $null
  try {
    $sums = Join-Path $tmp 'SHA256SUMS'
    Invoke-WebRequest "$base/SHA256SUMS" -OutFile $sums -UseBasicParsing
    $want = ((Select-String -Path $sums -Pattern ([regex]::Escape($file) + '$') | Select-Object -First 1).Line -split '\s+')[0]
  } catch { Write-Warning "ray-install: checksum step skipped ($($_.Exception.Message))" }
  if ($want) {
    $got = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
    if ($got -ne $want.ToLower()) { throw "ray-install: checksum mismatch for $file" }
    Write-Host 'ray-install: checksum ok'
  }

  $ex = Join-Path $tmp 'x'
  if ($serverMode) { Write-Host 'ray-install: unpacking' }
  Expand-Archive -Path $zip -DestinationPath $ex -Force
  Remove-Item $zip -Force

  if ($serverMode) {
    # The server bundle: ray-server.exe and ray-cli.exe with their DLLs, qt6\plugins, tools\ and
    # the ray.cmd / ray.ps1 launchers. It is installed as it is, in its own folder.
    $src = Get-ChildItem -Path $ex -Recurse -Filter 'ray-server.exe' | Select-Object -First 1
    if (-not $src) { throw "could not find ray-server.exe inside $file" }
    $bundle = $src.Directory.FullName
    foreach ($need in @($bin, 'ray.cmd')) {
      if (-not (Test-Path (Join-Path $bundle $need))) { throw "could not find $need inside $file" }
    }
    # So ray-cli.exe finds its plugins without the launcher (MCP apps start it directly). Bundles
    # from 4.0.16 on ship their own qt.conf; only an older bundle gets this one, with the same
    # content and LF line endings.
    if (-not (Test-Path (Join-Path $bundle 'qt.conf'))) {
      [IO.File]::WriteAllText((Join-Path $bundle 'qt.conf'), "[Paths]`nPrefix = .`nPlugins = qt6/plugins`n",
                              (New-Object System.Text.ASCIIEncoding))
    }
    $ps1 = Join-Path $bundle 'ray.ps1'
    if ((Test-Path $ps1) -and -not (Test-ScriptsAllowed)) { Remove-Item $ps1 -Force }

    # Replace an earlier copy in one step: the new folder is ready next to it first.
    $old = "$Dir.old"
    if (Test-Path $old) { Remove-Item $old -Recurse -Force }
    if (Test-Path $Dir) {
      try { Move-Item -LiteralPath $Dir -Destination $old }
      catch { throw "ray-install: could not replace $Dir (is Ray running from it?): $($_.Exception.Message)" }
    }
    try { Move-Item -LiteralPath $bundle -Destination $Dir }
    catch {
      if ((Test-Path $old) -and -not (Test-Path $Dir)) { Move-Item -LiteralPath $old -Destination $Dir }
      throw
    }
    Remove-Item $old -Recurse -Force -ErrorAction SilentlyContinue

    Assert-Starts (Join-Path $Dir $bin) '--help'
    Assert-Starts (Join-Path $Dir 'ray-server.exe') '--version'
    Write-Host "ray-install: installed $Dir (ray, ray-cli, ray-server)"
  } else {
    $src = Get-ChildItem -Path $ex -Recurse -Filter $bin | Select-Object -First 1
    if (-not $src) { throw "could not find $bin inside $file" }

    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    # ray-cli.exe needs what comes with it: the Qt DLLs beside it and the qt6\plugins folder (secure
    # connections). Everything in its folder is installed, except the bundle's own launchers. A
    # folder goes into the one an earlier install made (copied whole, it would land inside it).
    $bundle = $src.Directory.FullName
    Get-ChildItem -Path $bundle -Force | Where-Object { $_.Name -notin @('ray.cmd', 'ray.ps1') } |
      ForEach-Object {
        $target = Join-Path $Dir $_.Name
        if ($_.PSIsContainer) {
          New-Item -ItemType Directory -Path $target -Force | Out-Null
          Copy-Item -Path (Join-Path $_.FullName '*') -Destination $target -Recurse -Force
        } else {
          Copy-Item -LiteralPath $_.FullName -Destination $target -Force
        }
      }
    # So it finds its plugins without the launcher (which sets QT_PLUGIN_PATH): MCP apps and scripts
    # start ray-cli.exe directly. Bundles from 4.0.16 on ship their own qt.conf (copied above);
    # only an older bundle gets this one.
    if (-not (Test-Path (Join-Path $bundle 'qt.conf'))) {
      # The same content and LF line endings as the qt.conf the bundles ship.
      [IO.File]::WriteAllText((Join-Path $Dir 'qt.conf'), "[Paths]`nPrefix = .`nPlugins = qt6/plugins`n",
                              (New-Object System.Text.ASCIIEncoding))
    }

    Assert-Starts (Join-Path $Dir $bin) '--help'
    Write-Host "ray-install: installed $(Join-Path $Dir $bin)"
  }

  if (-not $NoPath) {
    # persist on the user PATH. The server's folder goes first: the Ray desktop app puts its own
    # `ray` on the user PATH, and that one can't start a server.
    $userPath = Get-UserPath
    $entries = @($userPath -split ';' | Where-Object { $_ })
    if ($serverMode) {
      if ($entries.Count -eq 0 -or $entries[0] -ne $Dir) {
        $newPath = (@($Dir) + @($entries | Where-Object { $_ -ne $Dir })) -join ';'
        Set-UserPath $newPath
        Write-Host "ray-install: put $Dir first on your user PATH"
      }
    } elseif ($entries -notcontains $Dir) {
      $newPath = if ($userPath) { $userPath.TrimEnd(';') + ';' + $Dir } else { $Dir }
      Set-UserPath $newPath
      Write-Host "ray-install: added $Dir to your user PATH"
    }
    # make it work in THIS session too (iex runs in-process)
    if ($serverMode) { $env:Path = (@($Dir) + @($env:Path -split ';' | Where-Object { $_ -and $_ -ne $Dir })) -join ';' }
    elseif (($env:Path -split ';') -notcontains $Dir) { $env:Path = "$env:Path;$Dir" }
  }

  Write-Host ''
  if ($serverMode) {
    # `ray` when it is this server's, else the full path.
    $found = (Get-Command ray -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    $ours = $found -and $found.ToLowerInvariant().StartsWith(($Dir + '\').ToLowerInvariant())
    if ($ours) { Write-Host 'ray-install: done. Start the server:  ray serve' }
    else { Write-Host "ray-install: done. Start the server:  & `"$(Join-Path $Dir 'ray.cmd')`" serve" }
    Write-Host 'Then open http://127.0.0.1:8787/ on this computer (or the port its "listening on" line shows).'
    if (-not $NoPath -and $found -and -not $ours) {
      Write-Host "Note: ``ray`` here starts $found, which comes first on your PATH."
    }
  } else {
    Write-Host 'ray-install: done. Try:  ray-cli --help'
  }
  if (-not $NoPath) { Write-Host '(Open a new terminal if an existing one does not see it yet.)' }
}
finally {
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
}
