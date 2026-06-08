# Forzassist release build kit

This folder is not the installer itself. It is the clean release build kit used to generate the installer.

## Build the installer

1. Extract this folder.
2. Install Python 3.12 or 3.11.
3. Install Inno Setup 6.
4. Run:

```powershell
.\build_release.ps1
```

or double-click:

```text
build_release.bat
```

## Output

After the build finishes, the installer will be here:

```text
installer\Output\Forzassist_Setup.exe
```

The portable folder will be here:

```text
dist_embedded\Forzassist
```

The portable archive will be here:

```text
release\Forzassist_Portable.zip
```

## Saved settings

Forzassist saves user settings here:

```text
%APPDATA%\Forzassist\config.json
```
