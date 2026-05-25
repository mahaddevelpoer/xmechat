# XmeChat Windows Build & Distribution Guide

## Prerequisites

1. **Flutter SDK** (v3.27+): https://flutter.dev/docs/get-started/install/windows
2. **Visual Studio 2022** with "Desktop development with C++" workload
3. **Git** for version control
4. **Google Fonts** - loaded dynamically at runtime (no manual download needed)

## Build Steps

### 1. Get Dependencies

```powershell
cd D:\xmechat
flutter pub get
```

### 2. Run the App (Development)

```powershell
flutter run -d windows
```

### 3. Build for Release

```powershell
flutter build windows --release
```

The compiled executable will be at:
```
build\windows\release\runner\XmeChat.exe
```

### 4. Package for Distribution (Automated)

Run the packaging script to collect all required DLLs and create a clean ZIP:

```powershell
.\package_windows.ps1
```

This will:
- Clean previous builds
- Run `flutter build windows --release`
- Collect all required DLLs (Flutter, VC++ redistributable, audio codecs)
- Include the `data/` directory with assets and ICU data
- Create a ZIP archive at `dist\XmeChat-v2.0.0-windows-release.zip`

### 5. Manual Distribution (if script fails)

If the automated script fails, manually copy these files from `build\windows\release\runner\`:

| File | Required | Description |
|------|----------|-------------|
| `XmeChat.exe` | Yes | Main executable |
| `flutter_windows.dll` | Yes | Flutter engine |
| `data/` directory | Yes | Assets, ICU data, fonts |
| `msvcp140.dll` | Yes | VC++ runtime |
| `vcruntime140.dll` | Yes | VC++ runtime |
| `vcruntime140_1.dll` | Yes | VC++ runtime (VS2022) |
| `*.dll` from plugins | Yes | Audio, WebRTC, etc. |

### 6. Install on Target Machine

- **No admin rights required** - extract ZIP to any folder and run `XmeChat.exe`
- **Windows 10/11 64-bit** only
- If missing VC++ DLLs, install:
  https://aka.ms/vs/17/release/vc_redist.x64.exe

## Troubleshooting

### "DLL not found" errors

If the app fails to start with DLL errors:

1. Install Visual C++ Redistributable:
   ```powershell
   # Download and install
   winget install Microsoft.VCRedist.2015+.x64
   ```

2. Or manually copy from `C:\Windows\System32\`:
   - `msvcp140.dll`
   - `vcruntime140.dll`
   - `vcruntime140_1.dll`

### WebRTC / Audio not working

Ensure the following DLLs are present in the app folder:
- `flutter_windows.dll`
- Any plugin DLLs from `build\windows\release\plugins\`
- Audio codec DLLs (bass, opus, mpg123 from `just_audio_windows`)
