param(
    [string]$BuildMode = "release",
    [string]$OutputDir = "dist"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$AppName = "XmeChat"
$Version = "2.0.0"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  $AppName Windows Package Script v$Version" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Clean previous build
Write-Host "[1/5] Cleaning previous builds..." -ForegroundColor Yellow
if (Test-Path "$ProjectRoot\build\windows") {
    Remove-Item -Recurse -Force "$ProjectRoot\build\windows"
}
if (Test-Path "$ProjectRoot\$OutputDir") {
    Remove-Item -Recurse -Force "$ProjectRoot\$OutputDir"
}

# Step 2: Flutter pub get
Write-Host "[2/5] Running flutter pub get..." -ForegroundColor Yellow
Set-Location -LiteralPath $ProjectRoot
flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }

# Step 3: Build Windows executable
Write-Host "[3/5] Building Windows executable ($BuildMode)..." -ForegroundColor Yellow
if ($BuildMode -eq "release") {
    flutter build windows --release
} else {
    flutter build windows --debug
}
if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed" }

# Step 4: Collect DLLs and resources
Write-Host "[4/5] Collecting runtime DLLs and resources..." -ForegroundColor Yellow

$BuildDir = "$ProjectRoot\build\windows\$($BuildMode)\runner"
$DistDir = "$ProjectRoot\$OutputDir\$AppName"
New-Item -ItemType Directory -Path $DistDir -Force | Out-Null

# Copy the executable
Copy-Item -Path "$BuildDir\$AppName.exe" -Destination "$DistDir\$AppName.exe" -Force

# Copy Flutter DLLs
$FlutterBinCache = "$env:LOCALAPPDATA\flutter\bin\cache"
$FlutterDllSource = "$BuildDir"

# Copy all DLLs from build directory
Get-ChildItem -Path "$BuildDir" -Filter "*.dll" | ForEach-Item {
    Copy-Item -Path $_.FullName -Destination "$DistDir\" -Force
}

# Copy Visual C++ redistributable DLLs (msvcp*.dll, vcruntime*.dll)
$VCRuntimeDirs = @(
    "$env:SYSTEMROOT\System32",
    "$env:SYSTEMROOT\SysWOW64"
)
$VCDlls = @("msvcp140.dll", "vcruntime140.dll", "vcruntime140_1.dll", "msvcp140_1.dll", "msvcp140_2.dll")
foreach ($dll in $VCDlls) {
    foreach ($dir in $VCRuntimeDirs) {
        $dllPath = Join-Path -Path $dir -ChildPath $dll
        if (Test-Path $dllPath) {
            Copy-Item -Path $dllPath -Destination "$DistDir\" -Force
            break
        }
    }
}

# Copy flutter_windows.dll if not already copied
$flutterDll = "$BuildDir\flutter_windows.dll"
if (Test-Path $flutterDll) {
    Copy-Item -Path $flutterDll -Destination "$DistDir\" -Force
}

# Copy data directory (contains ICU data, fonts, assets)
$DataDir = "$BuildDir\data"
if (Test-Path $DataDir) {
    Copy-Item -Recurse -Path $DataDir -Destination "$DistDir\data" -Force
}

# Copy any platform-specific plugins
$PluginsDir = "$ProjectRoot\build\windows\$($BuildMode)\plugins"
if (Test-Path $PluginsDir) {
    Get-ChildItem -Path $PluginsDir -Recurse -Filter "*.dll" | ForEach-Item {
        Copy-Item -Path $_.FullName -Destination "$DistDir\" -Force
    }
}

# Copy audio DLLs from just_audio_windows
$JustAudioDlls = Get-ChildItem -Path "$ProjectRoot\build\windows\$($BuildMode)" -Recurse -Filter "*.dll" | Where-Object { $_.Name -like "*audio*" -or $_.Name -like "*bass*" -or $_.Name -like "*mpg123*" -or $_.Name -like "*opus*" }
$JustAudioDlls | ForEach-Item {
    Copy-Item -Path $_.FullName -Destination "$DistDir\" -Force
}

# Step 5: Create ZIP archive
Write-Host "[5/5] Creating distribution ZIP..." -ForegroundColor Yellow

$ZipName = "$AppName-v$Version-windows-$BuildMode.zip"
$ZipPath = "$ProjectRoot\$OutputDir\$ZipName"
Compress-Archive -Path "$DistDir\*" -DestinationPath $ZipPath -Force

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Package created successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Location: $ZipPath" -ForegroundColor White
Write-Host "  Size: $([math]::Round((Get-Item $ZipPath).Length / 1MB, 2)) MB" -ForegroundColor White
Write-Host ""

# Clean up temporary directory
Remove-Item -Recurse -Force $DistDir

Set-Location -LiteralPath $ProjectRoot
