import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// The popup: today's total, a 7-day sparkline, then one block per provider with
// its free-tier limit bars and a share-of-limit bar for every model.
PanelKeyCatcher {
  id: card

  property var panel: null
  property real maxHeight: Style.space(600)

  readonly property var view: panel ? panel.view : ({ ok: false })
  readonly property color fg: panel ? panel.foreground : Color.foreground
  readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.58)
  readonly property real bodyHeight: content.implicitHeight
  readonly property real chrome: head.height + spark.height + rule.height + foot.height + content.spacing * 4
  readonly property real listCap: Math.max(Style.space(80), maxHeight - chrome)

  anchors.fill: parent
  onCloseRequested: { if (panel.settingsOpen) panel.closeSettings(); else panel.close() }
  onTextKey: function(t) { if (t === "r") panel.refresh(); else if (t === "o") panel.launch(); else if (t === "s") panel.openSettings() }

  Column {
    id: content
    anchors.fill: parent
    spacing: Style.space(10)

    // ---------------------------------------------------------- header
    Item {
      id: head
      width: parent.width
      height: Style.space(40)

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: panel.openSettings()
      }

      OpenCodeLogo {
        id: logo
        size: Style.space(26)
        color: panel.accent
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
      }
      Column {
        anchors.left: logo.right
        anchors.leftMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(1)
        Txt { text: "OpenCode usage"; color: card.fg; font.bold: true; font.pixelSize: Style.font.title }
        Txt { text: card.view.ok ? card.view.today.requests + " requests today" : "Free-model tracker"
              color: card.dim; font.pixelSize: Style.font.caption }
      }
      Column {
        id: headRight
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(1)
        Txt { anchors.right: parent.right; text: card.view.ok ? card.view.today.label : "–"
              color: card.fg; font.bold: true; font.pixelSize: Style.font.heading }
        Txt { anchors.right: parent.right; text: "tokens today"; color: card.dim; font.pixelSize: Style.font.caption }
        Txt { anchors.right: parent.right
              visible: card.view.ok && card.view.savings && card.view.savings.today > 0
              text: "saved " + ((card.view.savings || {}).todayLabel || "") + " today"
              color: panel.accent; font.pixelSize: Style.font.caption; font.bold: true }
      }
    }

    // ------------------------------------------------------- sparkline
    Item {
      id: spark
      width: parent.width
      visible: card.view.ok
      height: visible ? Style.space(62) : 0

      Row {
        anchors.fill: parent
        spacing: Style.space(6)
        Repeater {
          model: card.view.ok ? card.view.week : []
          delegate: Item {
            id: barDelegate
            required property var modelData
            required property int index
            width: (spark.width - Style.space(6) * 6) / 7
            height: spark.height

            MouseArea {
              id: barArea
              anchors.fill: parent
              hoverEnabled: true
            }

            // Native hover popup: day usage right at the hovered bar.
            PanelToolTip {
              visible: barArea.containsMouse
              text: {
                var d = barDelegate.modelData
                var s = d.day + " · " + (d.requests || 0) + " req · " + d.label
                if (d.cached > 0 && d.cachedLabel) s += " + " + d.cachedLabel + " cached"
                if (d.saved > 0 && d.savedLabel) s += "\nSaved " + d.savedLabel
                return s
              }
            }

            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: dayLabel.top
              anchors.bottomMargin: Style.space(3)
              width: parent.width * 0.62
              radius: Math.min(width / 2, Style.space(3))
              height: barDelegate.modelData.tokens > 0
                ? Math.max(Style.space(3), (parent.height - dayLabel.height - Style.space(8)) * barDelegate.modelData.tokens / card.view.weekMax)
                : Style.space(2)
              color: barDelegate.modelData.today ? panel.accent : Qt.rgba(card.fg.r, card.fg.g, card.fg.b, 0.22)
              Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            }
            Txt {
              id: dayLabel
              anchors.bottom: parent.bottom
              anchors.horizontalCenter: parent.horizontalCenter
              text: barDelegate.modelData.day
              color: barDelegate.modelData.today ? card.fg : card.dim
              font.pixelSize: Style.font.caption
              font.bold: barDelegate.modelData.today
            }
          }
        }
      }
    }

    PanelSeparator { id: rule; width: parent.width }

    // Savings vs baseline: one line showing week total.
    Txt {
      width: parent.width
      visible: card.view.ok && card.view.savings && card.view.savings.week > 0
      text: {
        var s = card.view.savings || {}
        return "Saved " + (s.weekLabel || "") + " this week"
          + (s.baseline ? " vs " + s.baseline : "")
          + " · " + (s.todayLabel || "") + " today"
      }
      color: card.dim
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignHCenter
    }

    // -------------------------------------------------------- problems
    Txt {
      visible: !card.view.ok
      width: parent.width
      text: (card.view.error || "Loading…") + (card.view.hint ? "\n" + card.view.hint : "")
      color: card.view.error ? panel.urgent : card.dim
      wrapMode: Text.WordWrap
    }

    // ------------------------------------------------------- providers
    Flickable {
      id: list
      width: parent.width
      visible: card.view.ok
      clip: true
      contentHeight: providers.implicitHeight
      height: visible ? Math.min(contentHeight, card.listCap) : 0
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

      Column {
        id: providers
        width: list.width - (list.interactive ? Style.space(10) : 0)
        spacing: Style.space(8)

        Txt {
          visible: card.view.ok && card.view.providers.length === 0
          width: parent.width
          text: "No OpenCode requests in the last 7 days."
          color: card.dim
        }

        Repeater {
          model: card.view.ok ? card.view.providers : []

          delegate: Rectangle {
            id: block
            required property var modelData
            readonly property var p: modelData
            width: providers.width
            height: inner.implicitHeight + Style.space(20)
            radius: Style.cornerRadius
            color: Qt.rgba(card.fg.r, card.fg.g, card.fg.b, 0.06)
            border.width: 1
            border.color: Qt.rgba(card.fg.r, card.fg.g, card.fg.b, 0.12)

            Column {
              id: inner
              anchors.fill: parent
              anchors.margins: Style.space(12)
              spacing: Style.space(10)

              // provider header
              Item {
                width: parent.width
                height: Math.max(pname.implicitHeight, psum.implicitHeight) + Style.space(4)
                // provider logo — nerd-font glyph per provider, robot for new ones
                Text {
                  id: provGlyph
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: block.p.icon || ""
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  color: panel.levelColor(block.p.level)
                  renderType: Text.NativeRendering
                }
                Txt { id: pname; anchors.left: provGlyph.right; anchors.leftMargin: Style.space(10)
                      anchors.right: psum.left; anchors.rightMargin: Style.space(10)
                      text: block.p.name; color: card.fg; font.bold: true; font.pixelSize: Style.font.body; elide: Text.ElideRight }
                Txt { id: psum; anchors.right: parent.right; text: block.p.summary
                      color: card.dim; font.pixelSize: Style.font.caption }
              }

              PanelSeparator { width: parent.width; opacity: 0.5 }

              // limits
              Repeater {
                model: block.p.limits
                delegate: UsageBar {
                  required property var modelData
                  width: inner.width
                  fg: card.fg
                  label: modelData.label
                  rText: modelData.right
                  caption: modelData.caption
                  ratio: modelData.limit > 0 ? modelData.used / modelData.limit : 0
                  pctText: modelData.pct + "%"
                  tone: panel.levelColor(modelData.level)
                }
              }

              Txt {
                visible: !block.p.hasLimit
                width: parent.width
                text: "No published free limit. Counts only; add a budget in config.json for a bar."
                color: card.dim
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }

              PanelSeparator { width: parent.width; opacity: 0.3; visible: block.p.models.length > 0 }

              // models — bounded in one bordered box; rows unchanged
              Rectangle {
                visible: block.p.models.length > 0
                width: parent.width
                height: modelsCol.implicitHeight + Style.space(20)
                radius: Math.max(0, Style.cornerRadius - Style.space(2))
                color: Qt.rgba(card.fg.r, card.fg.g, card.fg.b, 0.04)
                border.width: 1
                border.color: Qt.rgba(card.fg.r, card.fg.g, card.fg.b, 0.10)

              Column {
                id: modelsCol
                anchors.fill: parent
                anchors.margins: Style.space(10)
                spacing: Style.space(8)

              Repeater {
                model: block.p.models
                delegate: Column {
                  id: mrow
                  required property var modelData
                  readonly property var m: modelData
                  width: modelsCol.width
                  spacing: Style.space(3)

                  Item {
                    width: parent.width
                    height: Math.max(mname.implicitHeight, mstats.implicitHeight)
                    Row {
                      anchors.left: parent.left
                      anchors.right: mstats.left
                      anchors.rightMargin: Style.space(8)
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(6)
                      Txt { id: mname; text: mrow.m.name; color: card.fg; font.pixelSize: Style.font.bodySmall
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, parent.width - chip.width - tokenChip.width - parent.spacing * 2) }
                      Rectangle {
                        id: tokenChip
                        anchors.verticalCenter: parent.verticalCenter
                        width: tokenText.implicitWidth + Style.space(10)
                        height: tokenText.implicitHeight + Style.space(3)
                        radius: height / 2
                        color: Qt.rgba(panel.accent.r, panel.accent.g, panel.accent.b, 0.08)
                        border.width: 1
                        border.color: Qt.rgba(panel.accent.r, panel.accent.g, panel.accent.b, 0.25)
                        Txt { 
                          id: tokenText
                          anchors.centerIn: parent
                          text: (mrow.m.tokens >= 1000000 ? (mrow.m.tokens / 1000000).toFixed(1) + "M" :
                                 mrow.m.tokens >= 1000 ? (mrow.m.tokens / 1000).toFixed(1) + "k" :
                                 mrow.m.tokens) + " tok"
                          color: panel.accent
                          font.pixelSize: Style.font.caption
                          font.bold: true
      }
    }
                      Rectangle {
                        id: chip
                        anchors.verticalCenter: parent.verticalCenter
                        width: chipText.implicitWidth + Style.space(10)
                        height: chipText.implicitHeight + Style.space(2)
                        radius: height / 2
                        color: mrow.m.paid ? Qt.rgba(panel.urgent.r, panel.urgent.g, panel.urgent.b, 0.18) : "transparent"
                        border.width: 1
                        border.color: mrow.m.paid ? panel.urgent : Qt.rgba(card.fg.r, card.fg.g, card.fg.b, 0.3)
                        Txt { id: chipText; anchors.centerIn: parent; text: mrow.m.tag
                              color: mrow.m.paid ? panel.urgent : card.dim; font.pixelSize: Style.font.caption }
                      }
                    }
                    Txt { id: mstats; anchors.right: parent.right; text: mrow.m.requests + " req"
                          color: card.dim; font.pixelSize: Style.font.caption }
                  }

                  Item {
                    visible: mrow.m.barKind !== "none"
                    width: parent.width
                    height: Style.space(14)
                    Rectangle {
                      anchors.left: parent.left
                      anchors.right: mpct.left
                      anchors.rightMargin: Style.space(8)
                      anchors.verticalCenter: parent.verticalCenter
                      height: Style.space(5); radius: height / 2
                      color: Qt.rgba(card.fg.r, card.fg.g, card.fg.b, 0.15)
                      Rectangle {
                        height: parent.height; radius: height / 2
                        width: mrow.m.ratio > 0 ? Math.max(height, parent.width * Math.min(1, mrow.m.ratio)) : 0
                        color: mrow.m.barKind === "limit" ? panel.levelColor(mrow.m.level) : panel.accent
                        Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                      }
                    }
                    Txt { id: mpct; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                          width: Style.space(38); horizontalAlignment: Text.AlignRight
                          text: mrow.m.pct; color: card.fg; font.pixelSize: Style.font.caption; font.bold: mrow.m.ratio > 0.5 }
                  }

                  Txt {
                    visible: mrow.m.barKind === "none"
                    width: parent.width
                    text: "Not counted toward the free quota."
                    color: card.dim; font.pixelSize: Style.font.caption
                  }
                }
              }
              }
              }
            }
          }
        }
      }
    }

    // ----------------------------------------------------------- footer
    Item {
      id: foot
      width: parent.width
      height: Math.max(keysRow.implicitHeight, gearRow.implicitHeight)
      Row {
        id: keysRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(8)
        Txt { text: "r"; color: card.fg; font.bold: true; font.pixelSize: Style.font.caption }
        Txt { text: "refresh"; color: card.dim; font.pixelSize: Style.font.caption }
        Txt { text: "·"; color: card.dim; font.pixelSize: Style.font.caption }
        Txt { text: "o"; color: card.fg; font.bold: true; font.pixelSize: Style.font.caption }
        Txt { text: "open"; color: card.dim; font.pixelSize: Style.font.caption }
        Txt { text: "·"; color: card.dim; font.pixelSize: Style.font.caption }
        Txt { text: "esc"; color: card.fg; font.bold: true; font.pixelSize: Style.font.caption }
        Txt { text: "close"; color: card.dim; font.pixelSize: Style.font.caption }
      }
      Item {
        id: gearRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: footGear.implicitWidth + footGearLabel.implicitWidth + Style.space(7 + 5 + 8)
        height: Math.max(footGear.implicitHeight, footGearLabel.implicitHeight) + Style.space(10)
        Rectangle {
          anchors.fill: parent; radius: height/2
          color: footArea.containsMouse ? Qt.rgba(panel.accent.r, panel.accent.g, panel.accent.b, 0.14) : Qt.rgba(card.fg.r, card.fg.g, card.fg.b, 0.05)
          border.width: 1
          border.color: footArea.containsMouse ? Qt.rgba(panel.accent.r, panel.accent.g, panel.accent.b, 0.4) : Qt.rgba(card.fg.r, card.fg.g, card.fg.b, 0.12)
          Behavior on color { ColorAnimation { duration: 150 } }
        }
        Text {
          id: footGear
          anchors.left: parent.left; anchors.leftMargin: Style.space(7); anchors.verticalCenter: parent.verticalCenter
          text: "\uF013"; font.family: Style.font.family; font.pixelSize: Style.font.body
          color: footArea.containsMouse ? panel.accent : card.dim
          rotation: footArea.containsMouse ? 28 : 0
          Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
          Behavior on color { ColorAnimation { duration: 150 } }
        }
        Txt { id: footGearLabel; anchors.left: footGear.right; anchors.leftMargin: Style.space(5); anchors.verticalCenter: parent.verticalCenter
              text: "Settings"; color: footArea.containsMouse ? card.fg : card.dim; font.pixelSize: Style.font.caption; font.bold: true }
        MouseArea { id: footArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: panel.openSettings() }
      }
    }
  }
}
