param(
    [switch]$Flash
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $projectRoot

function Info([string]$Message) {
    Write-Host "[setup] $Message"
}

function Warn([string]$Message) {
    Write-Warning $Message
}

function Invoke-External {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed ($LASTEXITCODE): $FilePath $($Arguments -join ' ')"
    }
}

function Install-CargoBinIfMissing([string]$BinName) {
    if (Get-Command $BinName -ErrorAction SilentlyContinue) {
        Info "$BinName already installed"
    }
    else {
        Info "installing $BinName"
        Invoke-External cargo install --locked $BinName
    }
}

function Ensure-RustSrcComponent {
    $activeToolchainLine = (& rustup show active-toolchain)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($activeToolchainLine)) {
        Warn "could not determine active toolchain; skipping rust-src install"
        return
    }

    $activeToolchain = ($activeToolchainLine -split '\s+')[0]
    if ($activeToolchain -eq 'esp') {
        Warn "active toolchain is 'esp' (linked/custom); skipping rust-src install"
        return
    }

    Info "ensuring rust-src is installed for toolchain '$activeToolchain'"
    try {
        Invoke-External rustup component add rust-src --toolchain $activeToolchain
    }
    catch {
        Warn "failed to add rust-src for '$activeToolchain'; continuing"
    }
}

Info "project root: $projectRoot"

# 1. Install espup and Xtensa toolchain support.
Install-CargoBinIfMissing "espup"
Info "running espup install"
Invoke-External espup install

# 2. Load esp environment if available.
$exportPs1 = Join-Path $HOME "export-esp.ps1"
if (Test-Path $exportPs1) {
    . $exportPs1
    Info "loaded $exportPs1"
}
else {
    Warn "export-esp.ps1 not found. Open a new shell if rustup override fails."
}

# 3. Install flash tool.
Install-CargoBinIfMissing "espflash"

# 4. Configure project toolchain.
Info "setting rustup override to esp"
Invoke-External rustup override set esp

# 5. Install rust-src for this toolchain.
Ensure-RustSrcComponent

# 6. Build.
Info "updating lockfile"
Invoke-External cargo update
Info "building project"
Invoke-External cargo build

# 7. Optional flash + monitor.
if ($Flash) {
    Info "flashing and opening monitor"
    Invoke-External cargo run
    Invoke-External espflash monitor
}
else {
    Info "setup finished"
    Info "next steps: cargo run --release"
    Info "or run: powershell -ExecutionPolicy Bypass -File scripts/setup.ps1 -Flash"
}
