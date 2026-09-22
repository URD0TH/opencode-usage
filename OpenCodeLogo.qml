import QtQuick

// A simplified OpenCode-style mark drawn from rectangles so it takes any colour
// (an outlined square with a filled block inside). Not the official artwork.
Item {
  id: logo
  property color color: "white"
  property real size: 16
  width: size
  height: size

  Rectangle {
    anchors.fill: parent
    color: "transparent"
    border.width: Math.max(1.5, logo.size * 0.16)
    border.color: logo.color
  }
  Rectangle {
    width: logo.size * 0.36
    height: logo.size * 0.36
    x: logo.size * 0.32
    y: logo.size * 0.32
    color: logo.color
    opacity: 0.55
  }
}
