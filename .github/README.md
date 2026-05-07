# tabby-xterm-fix

A compact Tabby plugin that fixes the terminal black/blank screen bug that can appear after switching back to an inactive terminal tab.

## Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/DarkPhilosophy/tabby-xterm-fix/main/install.sh | sh
```

Then fully restart Tabby.

## What it fixes

Some Tabby versions unload inactive terminal tab canvases after about 30 seconds by setting xterm canvas dimensions to `0x0`. On some systems, switching back to that tab can leave the terminal permanently black or blank until the tab or window is recreated.

`tabby-xterm-fix` prevents that broken unload path for terminal tabs.

## Repository layout

```text
.
├── install.sh              # one-command installer
├── tabby-xterm-fix/        # actual Tabby plugin
│   ├── index.js
│   └── package.json
└── .github/                # documentation and project metadata
    ├── README.md
    ├── LICENSE.md
    └── CHANGELOG.md
```

## How it works

At plugin load time, `tabby-xterm-fix` patches `BaseTabComponent.prototype.emitVisibility` from `tabby-core`.

For terminal tabs only, it blocks `emitVisibility(false)`, which prevents `BaseTerminalTabComponent` from scheduling Tabby's internal delayed xterm canvas unload. Non-terminal tabs and `emitVisibility(true)` continue to behave normally.

Tradeoff: terminal tabs stay logically visible to Tabby, so Tabby may not reclaim as much canvas memory from inactive terminal tabs. In practice this avoids the much worse permanent black-screen state.

## Manual install

```bash
mkdir -p ~/.config/tabby/plugins/node_modules
git clone https://github.com/DarkPhilosophy/tabby-xterm-fix /tmp/tabby-xterm-fix
cp -R /tmp/tabby-xterm-fix/tabby-xterm-fix ~/.config/tabby/plugins/node_modules/tabby-xterm-fix
```

Then fully restart Tabby.

## Verify that it is loaded

Tabby's plugin list should show `tabby-xterm-fix` as loaded.

The plugin also writes diagnostic logs to:

```text
~/.cache/tabby-xterm-fix.log
```

A successful load contains a line like:

```text
prototype patch installed v1.0.0
```

When a terminal tab is hidden, you may see:

```text
blocked terminal emitVisibility(false)
```

## Uninstall

```bash
rm -rf ~/.config/tabby/plugins/node_modules/tabby-xterm-fix
```

Then fully restart Tabby.

## Credits

Created and published by **DarkPhilosophy** so the Tabby community can benefit from the fix.

## License

MIT, see [LICENSE.md](LICENSE.md).
