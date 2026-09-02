// Live matrix rain wallpaper for the Omarchy shell.
//
// Omarchy's own omarchy.background draws stills on the wlr *background* layer,
// and this plugin never touches it, so it keeps every upstream fix. This one
// claims the *bottom* layer instead -- above the wallpaper, below every window
// and the bar -- and maps itself only while the rain is the selected
// background.
//
// With any other wallpaper selected the PanelWindow is not mapped at all, so
// the desktop is bit-for-bit stock and this plugin costs nothing.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  // The picker can only list still images, so the rain is represented on disk
  // by a preview PNG under this name. bin/omarchy-matrix-preview writes it;
  // change it in both places or not at all.
  readonly property string rainFile: "zz-matrix-rain.png"

  readonly property string home: Quickshell.env("HOME")
  readonly property string backgroundLink: home + "/.local/state/omarchy/current/background"
  readonly property string themeNamePath: home + "/.local/state/omarchy/current/theme.name"

  // Qt hands out a file:// URL; Process needs a plain path.
  readonly property string pluginDir: {
    var u = String(Qt.resolvedUrl("."))
    return u.indexOf("file://") === 0 ? u.substring(7) : u
  }

  property string currentPath: ""
  readonly property bool rainSelected: String(currentPath).split("/").pop() === rainFile

  // Cross-fades against whatever the stock plugin is showing underneath.
  // Driving visibility off this (rather than off `rainSelected`) keeps the
  // surface mapped until the fade-out has actually finished.
  property real fade: rainSelected ? 1 : 0

  Behavior on fade {
    NumberAnimation {
      duration: 420
      easing.type: Easing.InOutCubic
    }
  }

  // Prefer the copy shipped in this plugin, fall back to one on PATH, so a
  // fresh `omarchy plugin add` works with nothing else installed while anyone
  // who already has the script keeps a single install.
  readonly property string bundledPreview: pluginDir + "bin/omarchy-matrix-preview"
  readonly property string pickBin: 'if [ -x "$0" ]; then bin="$0"; else bin=omarchy-matrix-preview; fi; '

  function setPath(line) {
    var p = String(line || "").trim()
    if (!p || p === currentPath) return
    currentPath = p
  }

  function useMatrixRain() {
    if (!matrixProc.running) matrixProc.running = true
  }

  function refreshPreview() {
    if (!previewProc.running) previewProc.running = true
  }

  // omarchy-theme-bg-set only writes a symlink and pushes to the stock
  // plugin's IPC, so there is no event to subscribe to. Watch the directory
  // the link lives in and re-resolve on any change; fall back to a slow poll
  // where inotifywait is missing. One long-lived process either way, emitting
  // the resolved path a line at a time.
  Process {
    id: watcher
    running: true
    command: ["bash", "-c", "link=\"$1\"; dir=\"${link%/*}\"; readlink -f \"$link\" || true; if command -v inotifywait >/dev/null 2>&1; then inotifywait -q -m -e create,moved_to,delete,attrib --format '' \"$dir\" 2>/dev/null | while read -r _; do readlink -f \"$link\" || true; done; else while sleep 1; do readlink -f \"$link\" || true; done; fi", "omarchy-matrix-rain-watch", root.backgroundLink]
    stdout: SplitParser {
      onRead: function (line) {
        root.setPath(line)
      }
    }
  }

  // Regenerates the rain's stand-in preview into the current theme's user
  // background folder, which is a directory the stock picker already scans.
  // That is the whole reason this needs no override of any packaged command.
  Process {
    id: previewProc
    command: ["bash", "-c", root.pickBin + 'exec "$bin"', root.bundledPreview]
  }

  Process {
    id: matrixProc
    command: ["bash", "-c", root.pickBin + 'p=$("$bin" --print-path) && exec omarchy-theme-bg-set "$p"', root.bundledPreview]
  }

  // A theme switch rewrites theme.name, which is the cue to re-tint the preview
  // and drop a copy into the new theme's folder. No theme-set hook needed.
  //
  // The file is watched but never opened. Only the fact that it changed is
  // needed here, and opening a predictable path under ~/.local/state from a
  // long-lived shell process is a liability: a FIFO left in its place would
  // block the shell on read, and an oversized or redirected file would be
  // pulled into it whole. inotifywait reports directory events by name and the
  // fallback compares mtime, so neither path opens the file, follows a link
  // into one, or reads a byte of it.
  Process {
    id: themeWatcher
    running: true
    command: ["bash", "-c", "p=\"$1\"; dir=\"${p%/*}\"; base=\"${p##*/}\"; if command -v inotifywait >/dev/null 2>&1; then inotifywait -q -m -e create,moved_to,close_write,attrib --format '%f' \"$dir\" 2>/dev/null | while IFS= read -r f; do [ \"$f\" = \"$base\" ] && echo changed; done; else last=\"\"; while :; do cur=$(stat -c %Y \"$p\" 2>/dev/null || true); if [ \"$cur\" != \"$last\" ]; then last=\"$cur\"; echo changed; fi; sleep 2; done; fi", "omarchy-matrix-rain-theme-watch", root.themeNamePath]
    stdout: SplitParser {
      onRead: previewDebounce.restart()
    }
  }

  Timer {
    id: previewDebounce
    // A theme switch rewrites several files at once; coalesce into one run.
    interval: 400
    repeat: false
    onTriggered: root.refreshPreview()
  }

  IpcHandler {
    target: "matrix-rain"

    // Selects the rain the same way the picker does -- by pointing the normal
    // background symlink at the preview file -- so it survives a restart and
    // shows as the selected entry in the switcher.
    function select(): void {
      root.useMatrixRain()
    }

    function refresh(): void {
      root.refreshPreview()
    }

    function status(): string {
      return (root.rainSelected ? "rain" : "still") + "\t" + root.currentPath
    }
  }

  Component.onCompleted: refreshPreview()

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      visible: root.fade > 0 && !remapGuard.remapping
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore

      ScreenMoveRemap {
        id: remapGuard
        window: panel
      }

      WlrLayershell.namespace: "omarchy-matrix-rain"
      // Above omarchy-background, below every window and the bar. Nothing else
      // on an Omarchy desktop uses this layer.
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      // Empty input region: clicks fall straight through to the stock
      // background layer underneath, so double-click-to-open-the-picker and
      // right-double-click-for-themes keep working untouched.
      mask: Region {}

      // Behind a Loader source rather than inline, so nothing is instantiated
      // while another wallpaper is selected, and the renderer is torn down
      // again once the fade-out finishes.
      Loader {
        id: rainLoader
        anchors.fill: parent
        opacity: root.fade
        active: root.fade > 0
        source: "MatrixRain.qml"
      }

      Binding {
        target: rainLoader.item
        property: "playing"
        value: root.fade > 0
        when: rainLoader.item !== null
        restoreMode: Binding.RestoreNone
      }
    }
  }
}
