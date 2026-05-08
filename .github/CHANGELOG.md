# Changelog

## 1.1.0

- Adds WSL auto-detection to `install.sh`.
- When run inside WSL, installs into Windows Tabby's `%APPDATA%\tabby\plugins\node_modules` folder.
- Adds native Windows PowerShell installer `install.ps1`.
- Adds Windows-friendly plugin log path support.
- Documents Linux, macOS, WSL, and Windows install paths.

## 1.0.0

- First public release.
- Fixes Tabby's inactive terminal tab black/blank screen bug.
- Prevents Tabby's delayed xterm canvas unload for terminal tabs by blocking `emitVisibility(false)` on terminal tab instances.
- Adds file logging at `~/.cache/tabby-xterm-fix.log`.
