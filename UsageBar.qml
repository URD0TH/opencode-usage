import QtQuick
import qs.Commons

// One limit, minimal: label, used/limit and caption stacked on the left,
// percentage plus a thin progress ring on the right. No bars.
Item {
  id: row

  property string label: ""
  property string rText: ""
  property string caption: ""
  property real ratio: 0
  property string pctText: ""
  property color tone: Color.accent
  property color fg: Color.foreground
  property real ringSize: Style.space(22)

  readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.58)
  readonly property real pct: Math.min(1, Math.max(0, ratio))

  implicitHeight: Math.max(leftCol.implicitHeight, ringSize)

  Column {
    id: leftCol
    anchors.left: parent.left
    anchors.right: rightRow.left
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(2)

    Row {
      width: parent.width
      spacing: Style.space(6)
      Txt {
        text: row.label
        color: row.fg
        elide: Text.ElideRight
        width: Math.min(implicitWidth, Math.max(0, parent.width - rValue.implicitWidth - parent.spacing))
        anchors.verticalCenter: parent.verticalCenter
      }
      Txt {
        id: rValue
        text: row.rText
        color: row.dim
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Txt {
      visible: text !== ""
      width: parent.width
      text: row.caption
      color: row.dim
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }
  }

  Row {
    id: rightRow
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(7)
    Txt {
      text: row.pctText
      color: row.tone
      font.pixelSize: Style.font.caption
      font.bold: true
      anchors.verticalCenter: parent.verticalCenter
    }
    Item {
      width: row.ringSize
      height: width
      anchors.verticalCenter: parent.verticalCenter
      Canvas {
        id: ring
        anchors.fill: parent
        onPaint: {
          var ctx = getContext("2d")
          ctx.reset()
          var r = Math.min(width, height) / 2 - 2
          ctx.lineWidth = 2
          ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.15)
          ctx.beginPath()
          ctx.arc(width / 2, height / 2, r, 0, 2 * Math.PI)
          ctx.stroke()
          if (row.pct > 0) {
            ctx.strokeStyle = row.tone
            ctx.beginPath()
            ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * row.pct)
            ctx.stroke()
          }
        }
        onVisibleChanged: requestPaint()
      }
    }
  }

  // Canvas does not track the bindings read in onPaint; repaint on change.
  onPctChanged: ring.requestPaint()
  onToneChanged: ring.requestPaint()
}
