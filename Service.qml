// Live wallpaper overlay for the Omarchy shell.
//
// Omarchy's own omarchy.background draws stills on the wlr *background* layer,
// and this plugin never touches it, so it keeps every upstream fix. This one
// claims the *bottom* layer instead — above the wallpaper, below every window
// and the bar — and maps itself only while the selected background is
// something a still Image cannot draw: an animated GIF/WebP, a video, or the
// built-in matrix rain.
//
// With a plain image selected the PanelWindow is not mapped at all, so the
// desktop is bit-for-bit stock and this plugin costs nothing.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "Classify.js" as Classify

Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string backgroundLink: home + "/.local/state/omarchy/current/background"
  readonly property string themeNamePath: home + "/.local/state/omarchy/current/theme.name"

  // Qt hands out a file:// URL; Process needs a plain path.
  readonly property string pluginDir: {
    var u = String(Qt.resolvedUrl("."))
    return u.indexOf("file://") === 0 ? u.substring(7) : u
  }

  property string currentPath: ""
  readonly property string kind: Classify.classify(currentPath)
  readonly property bool live: Classify.isLive(kind)

  // Cross-fades against whatever the stock plugin is showing underneath.
  // Driving visibility off this (rather than off `live`) keeps the surface
  // mapped until the fade-out has actually finished.
  property real fade: live ? 1 : 0

  // Held across the fade-out so the outgoing effect stays on screen while it
  // dissolves, instead of vanishing the instant a still is selected.
  property string livePath: ""

  onCurrentPathChanged: {
    // Classified directly rather than read off `live`, whose binding may not
    // have re-evaluated yet when this handler runs.
    if (Classify.isLive(Classify.classify(currentPath))) livePath = currentPath
  }

  Behavior on fade {
    NumberAnimation {
      duration: 420
      easing.type: Easing.InOutCubic
      onFinished: if (root.fade === 0) root.livePath = ""
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

  // A theme switch rewrites this file, which is the cue to re-tint the preview
  // and drop a copy into the new theme's folder. No theme-set hook needed.
  FileView {
    id: themeName
    path: root.themeNamePath
    watchChanges: true
    printErrors: false
    onLoaded: previewDebounce.restart()
    onFileChanged: reload()
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

    // Selects the rain the same way the picker does — by pointing the normal
    // background symlink at the preview file — so it survives a restart and
    // shows as the selected entry in the switcher.
    function select(): void {
      root.useMatrixRain()
    }

    function refresh(): void {
      root.refreshPreview()
    }

    function status(): string {
      return root.kind + "\t" + root.currentPath
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

      BgSurface {
        anchors.fill: parent
        opacity: root.fade
        path: root.livePath
        playing: root.fade > 0
      }
    }
  }
}
