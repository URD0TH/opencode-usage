import QtQuick
import qs.Commons

// Plain text in the theme's font. Plain on purpose: model names come from disk.
Text {
  textFormat: Text.PlainText
  font.family: Style.font.family
  font.pixelSize: Style.font.body
  color: Color.foreground
  renderType: Text.NativeRendering
}
