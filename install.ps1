$ErrorActionPreference = 'Stop'

$PluginName = 'tabby-xterm-fix'
$RepoUrl = if ($env:TABBY_XTERM_FIX_REPO_URL) { $env:TABBY_XTERM_FIX_REPO_URL } else { 'https://github.com/DarkPhilosophy/tabby-xterm-fix.git' }
$Branch = if ($env:TABBY_XTERM_FIX_BRANCH) { $env:TABBY_XTERM_FIX_BRANCH } else { 'main' }
$ArchiveUrl = if ($env:TABBY_XTERM_FIX_ARCHIVE_URL) { $env:TABBY_XTERM_FIX_ARCHIVE_URL } else { "https://github.com/DarkPhilosophy/tabby-xterm-fix/archive/refs/heads/$Branch.zip" }

function Info([string] $Message) {
    Write-Host "[tabby-xterm-fix] $Message"
}

function Fail([string] $Message) {
    Write-Error "[tabby-xterm-fix] ERROR: $Message"
    exit 1
}

if (-not $env:APPDATA -and -not $env:TABBY_PLUGINS_ROOT -and -not $env:TABBY_XTERM_FIX_INSTALL_DIR) {
    Fail 'APPDATA is not set. Set TABBY_PLUGINS_ROOT or TABBY_XTERM_FIX_INSTALL_DIR manually.'
}

$DefaultPluginsRoot = Join-Path $env:APPDATA 'tabby\plugins\node_modules'
$PluginsRoot = if ($env:TABBY_PLUGINS_ROOT) { $env:TABBY_PLUGINS_ROOT } else { $DefaultPluginsRoot }
$InstallDir = if ($env:TABBY_XTERM_FIX_INSTALL_DIR) { $env:TABBY_XTERM_FIX_INSTALL_DIR } else { Join-Path $PluginsRoot $PluginName }
$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("tabby-xterm-fix-" + [System.Guid]::NewGuid().ToString('N'))
$RepoDir = Join-Path $TempDir 'repo'
$BackupDir = $null

try {
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

    Info "Install target: $InstallDir"
    Info 'Downloading plugin...'

    $cloned = $false
    if (Get-Command git -ErrorAction SilentlyContinue) {
        & git clone --depth 1 --branch $Branch $RepoUrl $RepoDir *> $null
        if ($LASTEXITCODE -eq 0) {
            $cloned = $true
        }
    }

    if (-not $cloned) {
        Info 'git clone unavailable or failed, trying archive download...'
        $ZipPath = Join-Path $TempDir 'repo.zip'
        Invoke-WebRequest -Uri $ArchiveUrl -OutFile $ZipPath -UseBasicParsing
        Expand-Archive -Path $ZipPath -DestinationPath $TempDir -Force
        $Expanded = Get-ChildItem -Path $TempDir -Directory | Where-Object { $_.Name -like 'tabby-xterm-fix-*' } | Select-Object -First 1
        if (-not $Expanded) {
            Fail 'Could not extract plugin archive.'
        }
        Move-Item -Path $Expanded.FullName -Destination $RepoDir
    }

    $SourceDir = Join-Path $RepoDir $PluginName
    if (-not (Test-Path (Join-Path $SourceDir 'package.json'))) { Fail "Plugin package not found at $SourceDir" }
    if (-not (Test-Path (Join-Path $SourceDir 'index.js'))) { Fail "Plugin entrypoint not found at $SourceDir\index.js" }

    New-Item -ItemType Directory -Path (Split-Path -Parent $InstallDir) -Force | Out-Null

    if (Test-Path $InstallDir) {
        $BackupDir = "$InstallDir.backup.$(Get-Date -Format yyyyMMddHHmmss)"
        Info "Existing install found, backing it up to $BackupDir"
        Move-Item -Path $InstallDir -Destination $BackupDir
    }

    Copy-Item -Path $SourceDir -Destination $InstallDir -Recurse -Force
    Info "Installed to $InstallDir"

    $Package = Get-Content -Path (Join-Path $InstallDir 'package.json') -Raw | ConvertFrom-Json
    Info "tabby-xterm-fix v$($Package.version) installed successfully."
    Info 'Fully restart Tabby, then check the plugin log if needed.'
}
catch {
    if ($BackupDir -and (Test-Path $BackupDir)) {
        Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
        Move-Item -Path $BackupDir -Destination $InstallDir
    }
    Fail $_.Exception.Message
}
finally {
    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}
