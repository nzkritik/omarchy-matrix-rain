// One live wallpaper layer: an animated GIF/WebP, a looping video, or the
// matrix rain, behind a single uniform interface.
//
// Video and rain sit behind a Loader `source` (a separate file, not an inline
// component) so their imports are only resolved when something actually asks
// for them: a missing QtMultimedia then breaks video wallpapers instead of
// taking the whole plugin down with it.

import QtQuick
import qs.Commons
import "Classify.js" as Classify

Item {
  id: surface

  // Filesystem path, not a URL. Empty renders nothing.
  property string path: ""

  // Cleared while the overlay is fading out or unmapped, so an idle desktop is
  // not decoding a video or animating rain that nothing can see.
  property bool playing: true

  readonly property string kind: Classify.classify(surface.path)

  AnimatedImage {
    id: animated
    anchors.fill: parent
    visible: surface.kind === "animation"
    source: surface.kind === "animation" ? Util.fileUrl(surface.path) : ""
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    // Never cached: a decoded full-screen animation is far too large to keep
    // in the pixmap cache alongside the stills.
    cache: false
    smooth: true
    mipmap: true
    playing: surface.playing
    paused: !surface.playing
  }

  Loader {
    id: videoLoader
    anchors.fill: parent
    active: surface.kind === "video"
    source: "VideoSurface.qml"
  }

  Binding {
    target: videoLoader.item
    property: "path"
    value: surface.path
    when: videoLoader.item !== null
    restoreMode: Binding.RestoreNone
  }

  Binding {
    target: videoLoader.item
    property: "playing"
    value: surface.playing
    when: videoLoader.item !== null
    restoreMode: Binding.RestoreNone
  }

  Loader {
    id: rainLoader
    anchors.fill: parent
    active: surface.kind === "rain"
    source: "MatrixRain.qml"
  }

  Binding {
    target: rainLoader.item
    property: "playing"
    value: surface.playing
    when: rainLoader.item !== null
    restoreMode: Binding.RestoreNone
  }
}
