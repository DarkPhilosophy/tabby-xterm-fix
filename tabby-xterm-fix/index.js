/* eslint-disable @typescript-eslint/no-var-requires */
/**
 * tabby-xterm-fix v1.1.0
 * Prevents Tabby's terminal visibility=false path from reaching the internal
 * delayed xterm canvas unload handler that can cause black/blank terminals.
 */

const { NgModule } = require('@angular/core')
const tabbyCore = require('tabby-core')

let fs = null
let path = null
try { fs = require('fs'); path = require('path') } catch (_) {}

const PLUGIN_ID = 'tabby-xterm-fix'
const VERSION = '1.1.0'
const PATCH_FLAG = '__tabbyXtermFixPatched'
function getLogFile () {
    if (!path) return null
    const cacheDir = process.env.XDG_CACHE_HOME ||
        (process.platform === 'win32'
            ? (process.env.LOCALAPPDATA || process.env.TEMP || process.env.USERPROFILE)
            : (process.env.HOME ? path.join(process.env.HOME, '.cache') : null))
    return cacheDir ? path.join(cacheDir, 'tabby-xterm-fix.log') : null
}
const LOG_FILE = getLogFile()

function writeFileLog (level, args) {
    if (!LOG_FILE || !fs) return
    try {
        fs.mkdirSync(path.dirname(LOG_FILE), { recursive: true })
        fs.appendFileSync(LOG_FILE, `${new Date().toISOString()} ${level} ${args.map(x => {
            if (x instanceof Error) return x.stack || x.message
            if (typeof x === 'object') { try { return JSON.stringify(x) } catch (_) { return String(x) } }
            return String(x)
        }).join(' ')}\n`)
    } catch (_) {}
}

function log (...args) {
    console.log(`[${PLUGIN_ID}]`, ...args)
    writeFileLog('INFO', args)
}

function warn (...args) {
    console.warn(`[${PLUGIN_ID}]`, ...args)
    writeFileLog('WARN', args)
}

function isTerminalTabLike (tab) {
    const frontend = tab && tab.frontend
    return !!(frontend && frontend.xterm && typeof frontend.xterm.refresh === 'function')
}

function patchBaseTabPrototype () {
    const BaseTabComponent = tabbyCore.BaseTabComponent
    if (!BaseTabComponent || !BaseTabComponent.prototype) {
        warn('BaseTabComponent export missing', { keys: Object.keys(tabbyCore || {}) })
        return
    }

    const proto = BaseTabComponent.prototype
    if (proto[PATCH_FLAG]) {
        log('BaseTabComponent.prototype already patched')
        return
    }

    const original = proto.emitVisibility
    if (typeof original !== 'function') {
        warn('emitVisibility missing on BaseTabComponent.prototype')
        return
    }

    proto.emitVisibility = function patchedEmitVisibility (visible) {
        if (visible === false && isTerminalTabLike(this)) {
            log('blocked terminal emitVisibility(false)', {
                tabTitle: this.title || this.customTitle || '',
                frontendName: this.frontend?.constructor?.name || '',
                cols: this.frontend?.xterm?.cols,
                rows: this.frontend?.xterm?.rows,
            })
            // Keep terminal tabs logically visible so BaseTerminalTabComponent's
            // delayed visibility=false subscription never runs the canvas 0x0 unload.
            return
        }
        return original.call(this, visible)
    }

    proto[PATCH_FLAG] = true
    log(`prototype patch installed v${VERSION}`, `log=${LOG_FILE || 'console-only'}`)
}

patchBaseTabPrototype()

class XTermBlackScreenFixModule {}
NgModule({})(XTermBlackScreenFixModule)

exports.default = XTermBlackScreenFixModule
