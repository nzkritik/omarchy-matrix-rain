// Which renderer a background path needs. Shared by Service.qml (to decide
// whether this plugin shows itself at all) and BgSurface.qml (to pick a
// renderer), so the two can never disagree about what "live" means.
.pragma library

// The picker can only list still images, so the matrix rain is represented on
// disk by a preview PNG under this name. bin/omarchy-matrix-preview writes it;
// change it in both places or not at all.
var RAIN_FILE = "zz-matrix-rain.png"

function classify(path) {
  var s = String(path || "").trim()
  if (!s) return "none"

  var slash = s.lastIndexOf("/")
  var name = slash >= 0 ? s.slice(slash + 1) : s
  var dot = name.lastIndexOf(".")
  var ext = dot >= 0 ? name.slice(dot + 1).toLowerCase() : ""

  // Matched by name before extension: the rain's stand-in really is a PNG.
  if (name === RAIN_FILE) return "rain"

  switch (ext) {
  case "gif":
  case "webp":
  case "apng":
    // A still WebP or APNG renders fine through AnimatedImage as one frame,
    // so there is no need to tell the two apart here.
    return "animation"
  case "mp4":
  case "webm":
  case "mkv":
  case "mov":
  case "m4v":
  case "avi":
  case "wmv":
    return "video"
  }
  return "image"
}

// Everything a plain Image cannot draw. When this is false the plugin stays
// unmapped and the stock background plugin is the only thing on screen.
function isLive(kind) {
  return kind === "animation" || kind === "video" || kind === "rain"
}
