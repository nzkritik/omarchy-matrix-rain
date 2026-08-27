// Looping video wallpaper.
//
// Kept in its own file so `import QtMultimedia` is only resolved when a video
// background is actually selected — see the note in BgSurface.qml.

import QtQuick
import QtMultimedia
import qs.Commons

Item {
  id: video

  property string path: ""
  property bool playing: true

  // `hasVideo` can go true before the first frame is decoded, so the reveal
  // wipe waits on a loaded/buffered stream as well. InvalidMedia deliberately
  // never satisfies this; the fallback timer in Background.qml uncovers a
  // broken file rather than leaving the desktop stuck on the old wallpaper.
  readonly property bool ready: player.hasVideo
                                && (player.mediaStatus === MediaPlayer.LoadedMedia
                                    || player.mediaStatus === MediaPlayer.BufferingMedia
                                    || player.mediaStatus === MediaPlayer.BufferedMedia)

  MediaPlayer {
    id: player

    source: video.path ? Util.fileUrl(video.path) : ""
    videoOutput: output
    loops: MediaPlayer.Infinite

    // No AudioOutput is attached at all. A wallpaper must never make noise,
    // and leaving the sink unset is a stronger guarantee than muting one.

    onMediaStatusChanged: {
      if (mediaStatus === MediaPlayer.LoadedMedia && video.playing) play()
    }
    onErrorOccurred: function (error, errorString) {
      console.warn("background video failed:", video.path, errorString)
    }
  }

  VideoOutput {
    id: output
    anchors.fill: parent
    fillMode: VideoOutput.PreserveAspectCrop
  }

  onPlayingChanged: playing ? player.play() : player.pause()
  Component.onCompleted: if (playing) player.play()
}
