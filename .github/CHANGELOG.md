# Changelog

## 1.0.0

- First public release.
- Fixes Tabby's inactive terminal tab black/blank screen bug.
- Prevents Tabby's delayed xterm canvas unload for terminal tabs by blocking `emitVisibility(false)` on terminal tab instances.
- Adds file logging at `~/.cache/tabby-xterm-fix.log`.
