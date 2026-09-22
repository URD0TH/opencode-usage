import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Settings page for the OpenCode Usage widget.
//
// Standalone: it reads `settings` (the widget's saved values, as handed to
// Panel.qml) and reports changes through signals. Wiring it later is three lines:
//
//   Settings {
//     settings: root.settings
//     onApply: function(values) { root.persistSettings(values) }   // same helper herdr uses
//     onMoveRequested: function(section) { Quickshell.execDetached(["omarchy","bar","move",root.moduleName,"--section",section]) }
//   }
//
// Every key below is a plain value in the widget's inline shell.json entry, so
// Panel.qml can read it with setting("key", default). Defaults live in `defaults`.
Item {
  id: page

  property var settings: ({})
  property color foreground: Color.foreground
  property color accent: Color.accent
  property real contentWidth: Style.space(440)
  property real maxHeight: Style.space(680)

  signal apply(var values)              // { key: value, ... } to persist
  signal moveRequested(string section)  // "left" | "center" | "right"
  signal closeRequested()               // back to main card

  readonly property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.58)

  readonly property var defaults: ({
    auto: true,
    // logo / icon
    icon: "mark", iconSide: "left", logoSize: 14, logoColorMode: "theme", logoColor: "#7AA2F7", logoOpacity: 100,
    // text
    showText: true, readout: "tokens", compactNumbers: true, bold: true, fontSize: 12, gap: 6,
    textColorMode: "theme", textColor: "#FFFFFF",
    // extra visual instead of / next to text
    visual: "none",
    // layout
    section: "right", paddingX: 9, nudgeY: 0, widgetOpacity: 100, hideWhenIdle: false,
    // thresholds
    tintOnLimit: true, warnAt: 60, dangerAt: 85, warnColor: "#D6A84B", dangerColor: "#E5484D",
    // behaviour
    leftClick: "popup", middleClick: "refresh", rightClick: "opencode",
    refreshSec: 10, activeRefreshSec: 2,
    // popup
    popupWidth: 350, showSparkline: true, showModels: true, showNotes: true,
    // data
    dbPath: "", configPath: "", countCache: false, openrouterCredits: false
  })

  // Values the user is looking at right now: saved settings over defaults, with
  // sliders staged locally while they are dragged.
  property var draft: ({})
  function v(key) {
    if (draft[key] !== undefined) return draft[key]
    var s = settings ? settings[key] : undefined
    return s === undefined || s === null ? defaults[key] : s
  }
  function stage(key, value) {
    var d = Object.assign({}, draft); d[key] = value; draft = d
  }
  function set(key, value) {
    stage(key, value)
    var patch = {}; patch[key] = value
    apply(patch)
  }
  function resetAll() {
    draft = Object.assign({}, defaults)
    apply(Object.assign({}, defaults))
  }
  onSettingsChanged: draft = ({})

  readonly property bool auto: v("auto") === true
  property string tab: "look"
  property int previewPct: 30

  implicitWidth: contentWidth
  implicitHeight: body.implicitHeight

  // ---------- helpers: things Panel.qml can reuse to render the real widget ----------
  function levelFor(pct) { return pct >= v("dangerAt") ? "danger" : (pct >= v("warnAt") ? "warn" : "ok") }
  function levelColor(l) { return l === "danger" ? v("dangerColor") : (l === "warn" ? v("warnColor") : page.accent) }
  function pickColor(mode, custom, level, base) {
    if (page.auto) return (level !== "ok" ? levelColor(level) : base)
    if (mode === "accent") return page.accent
    if (mode === "status") return level !== "ok" ? levelColor(level) : base
    if (mode === "custom") return custom
    var tint = v("tintOnLimit") && level !== "ok"
    return tint ? levelColor(level) : base
  }
  readonly property string level: levelFor(previewPct)
  readonly property string effReadout: page.auto ? (level === "ok" ? "tokens" : "percent") : v("readout")
  readonly property string effIcon: page.auto ? "mark" : v("icon")
  readonly property bool effShowText: page.auto ? true : v("showText")
  readonly property string effVisual: page.auto ? "none" : v("visual")
  function glyph(name) {
    return ({ terminal: "\uF120", bolt: "\uF0E7", chart: "\uF080", fire: "\uF06D", robot: "\uDB81\uDEA9" })[name] || ""
  }
  function readoutText() {
    var r = effReadout
    if (r === "requests") return "63 req"
    if (r === "percent") return previewPct + "%"
    if (r === "both") return (v("compactNumbers") ? "184k" : "184,320") + " · " + previewPct + "%"
    if (r === "provider") return "OpenRouter"
    return v("compactNumbers") ? "184k" : "184,320"
  }

  // ------------------------------------------------------------------ pieces
  component Field: Item {
    id: f
    property string label: ""
    property string hint: ""
    property bool locked: false
    default property alias control: slot.data
    width: parent ? parent.width : 0
    height: Math.max(Style.space(32), texts.implicitHeight + Style.space(4))
    opacity: locked ? 0.38 : 1
    enabled: !locked

    Column {
      id: texts
      anchors.left: parent.left
      anchors.right: slot.left
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(1)
      Txt { width: parent.width; text: f.label; color: page.foreground; elide: Text.ElideRight }
      Txt { visible: f.hint !== ""; width: parent.width; text: f.hint; color: page.dim
            font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
    }
    Item {
      id: slot
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: childrenRect.width
      height: childrenRect.height
    }
  }

  component SliderField: Field {
    id: sf
    property string key: ""
    property real from: 0
    property real to: 100
    property real step: 1
    property string suffix: ""
    PanelSlider {
      width: Style.space(150)
      height: Style.space(22)
      minimum: sf.from
      maximum: sf.to
      step: sf.step
      integer: true
      value: Number(page.v(sf.key))
      fillColor: page.accent
      knobColor: page.foreground
      trackColor: Qt.rgba(page.foreground.r, page.foreground.g, page.foreground.b, 0.14)
      onMoved: function(x) { page.stage(sf.key, Math.round(x)) }
      onReleased: function(x) { page.set(sf.key, Math.round(x)) }
    }
    hint: Math.round(Number(page.v(sf.key))) + sf.suffix
  }

  component PickField: Field {
    id: pf
    property string key: ""
    property var options: []
    Dropdown {
      width: Style.space(150)
      options: pf.options
      value: String(page.v(pf.key))
      onChanged: function(val) { page.set(pf.key, val) }
    }
  }

  component ToggleField: Item {
    id: tf
    property string key: ""
    property string label: ""
    property string hint: ""
    property bool locked: false
    width: parent ? parent.width : 0
    height: t.implicitHeight
    opacity: locked ? 0.38 : 1
    enabled: !locked
    Toggle {
      id: t
      width: parent.width
      label: tf.label
      description: tf.hint
      checked: page.v(tf.key) === true
      onClicked: page.set(tf.key, !checked)
    }
  }

  component ColorField: Field {
    id: cf
    property string key: ""
    property bool locked2: false
    locked: locked2
    Row {
      spacing: Style.space(5)
      Repeater {
        model: ["#7AA2F7", "#9ECE6A", "#E0AF68", "#F7768E", "#BB9AF7", "#FFFFFF"]
        delegate: Rectangle {
          required property string modelData
          width: Style.space(18); height: width; radius: Style.cornerRadius > 0 ? width / 2 : 0
          color: modelData
          border.width: String(page.v(cf.key)).toUpperCase() === modelData ? 2 : 1
          border.color: String(page.v(cf.key)).toUpperCase() === modelData ? page.foreground : Qt.rgba(1, 1, 1, 0.25)
          anchors.verticalCenter: parent.verticalCenter
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.set(cf.key, modelData) }
        }
      }
      TextField {
        width: Style.space(78)
        text: String(page.v(cf.key))
        placeholderText: "#RRGGBB"
        onEditingFinished: {
          var t = text.trim()
          if (/^#[0-9a-fA-F]{6}$/.test(t)) page.set(cf.key, t.toUpperCase())
          else text = String(page.v(cf.key))
        }
      }
    }
  }

  component Heading: Txt {
    width: parent ? parent.width : 0
    color: page.dim
    font.bold: true
    font.pixelSize: Style.font.caption
    topPadding: Style.space(6)
  }

  // ------------------------------------------------------------------- page
  Column {
    id: body
    width: parent.width
    spacing: Style.space(10)

    // title + live preview
    Item {
      width: parent.width
      height: Style.space(22)
      
      // Back button
      Rectangle {
        id: backBtn
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: backText.implicitWidth + Style.space(16)
        height: Style.space(22)
        radius: Style.cornerRadius
        color: backArea.containsMouse ? Qt.rgba(page.accent.r, page.accent.g, page.accent.b, 0.15) : "transparent"
        border.width: 1
        border.color: backArea.containsMouse ? page.accent : Qt.rgba(page.foreground.r, page.foreground.g, page.foreground.b, 0.2)
        
        Txt {
          id: backText
          anchors.centerIn: parent
          text: "← Back"
          color: backArea.containsMouse ? page.accent : page.foreground
          font.pixelSize: Style.font.caption
          font.bold: true
        }
        
        MouseArea {
          id: backArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: page.closeRequested()
        }
      }
      
      Txt {
        anchors.centerIn: parent
        text: "OpenCode Usage · Settings"
        color: page.foreground
        font.bold: true
        font.pixelSize: Style.font.title
      }
    }

    Rectangle {
      id: previewBox
      width: parent.width
      height: Style.space(64)
      radius: Style.cornerRadius
      color: Color.bar.background
      border.width: 1
      border.color: Qt.rgba(page.foreground.r, page.foreground.g, page.foreground.b, 0.12)

      Txt { anchors.left: parent.left; anchors.top: parent.top; anchors.margins: Style.space(6)
            text: "Preview"; color: page.dim; font.pixelSize: Style.font.caption }

      // The widget as it will look in the bar.
      Item {
        id: widget
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Number(page.v("nudgeY"))
        opacity: Number(page.v("widgetOpacity")) / 100
        readonly property bool stacked: page.v("iconSide") === "top" || page.v("iconSide") === "bottom"
        readonly property bool iconFirst: page.v("iconSide") === "left" || page.v("iconSide") === "top"
        readonly property color logoColor: page.pickColor(page.v("logoColorMode"), page.v("logoColor"), page.level, page.foreground)
        readonly property color textColor: page.pickColor(page.v("textColorMode"), page.v("textColor"), page.level, page.foreground)
        readonly property real size: page.auto ? 14 : Number(page.v("logoSize"))
        width: flow.width + Style.space(Number(page.v("paddingX"))) * 2
        height: flow.height + Style.space(6)

        Grid {
          id: flow
          anchors.centerIn: parent
          columns: widget.stacked ? 1 : 2
          spacing: Style.space(Number(page.v("gap")))
          horizontalItemAlignment: Grid.AlignHCenter
          verticalItemAlignment: Grid.AlignVCenter
          layoutDirection: widget.iconFirst ? Qt.LeftToRight : Qt.RightToLeft

          Item {
            id: iconBox
            visible: page.effIcon !== "none"
            width: widget.size + (page.effVisual === "ring" ? Style.space(6) : 0)
            height: width
            OpenCodeLogo {
              visible: page.effIcon === "mark"
              anchors.centerIn: parent
              size: widget.size
              color: widget.logoColor
            }
            Text {
              visible: page.effIcon !== "mark" && page.effIcon !== "none"
              anchors.centerIn: parent
              text: page.glyph(page.effIcon)
              textFormat: Text.PlainText
              font.family: Style.font.family
              font.pixelSize: widget.size
              color: widget.logoColor
              renderType: Text.NativeRendering
            }
            Canvas {
              id: ring
              anchors.fill: parent
              visible: page.effVisual === "ring"
              property real pct: page.previewPct
              property color c: widget.logoColor
              onPctChanged: requestPaint()
              onCChanged: requestPaint()
              onWidthChanged: requestPaint()
              onPaint: {
                var ctx = getContext("2d"); ctx.reset()
                var r = width / 2 - 1.5
                ctx.lineWidth = 2
                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.15); ctx.beginPath(); ctx.arc(width / 2, height / 2, r, 0, 2 * Math.PI); ctx.stroke()
                ctx.strokeStyle = c; ctx.beginPath()
                ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * Math.min(1, pct / 100)); ctx.stroke()
              }
            }
          }

          Column {
            visible: page.effShowText || page.effVisual === "bar" || page.effVisual === "dot"
            spacing: Style.space(2)
            Row {
              spacing: Style.space(4)
              Rectangle {
                visible: page.effVisual === "dot"
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(7); height: width; radius: width / 2
                color: page.levelColor(page.level)
              }
              Text {
                visible: page.effShowText && page.effReadout !== "none"
                text: page.readoutText()
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: page.auto ? 12 : Number(page.v("fontSize"))
                font.bold: page.auto ? true : page.v("bold") === true
                color: widget.textColor
                renderType: Text.NativeRendering
              }
            }
            Rectangle {
              visible: page.effVisual === "bar"
              width: Math.max(Style.space(28), parent.width)
              height: Style.space(3); radius: height / 2
              color: Qt.rgba(1, 1, 1, 0.15)
              Rectangle { width: parent.width * Math.min(1, page.previewPct / 100); height: parent.height; radius: height / 2
                          color: page.levelColor(page.level) }
            }
          }
        }
      }

      // pretend-usage picker so every colour state can be checked
      Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Style.space(6)
        spacing: Style.space(4)
        Txt { text: "Simulate"; color: page.dim; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
        Repeater {
          model: [30, 70, 95]
          delegate: Rectangle {
            required property int modelData
            width: Style.space(34); height: Style.space(16); radius: height / 2
            color: page.previewPct === modelData ? Qt.rgba(page.foreground.r, page.foreground.g, page.foreground.b, 0.2) : "transparent"
            border.width: 1
            border.color: Qt.rgba(page.foreground.r, page.foreground.g, page.foreground.b, 0.25)
            Txt { anchors.centerIn: parent; text: modelData + "%"; font.pixelSize: Style.font.caption; color: page.foreground }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.previewPct = modelData }
          }
        }
      }
    }

    // Auto
    ToggleField {
      key: "auto"
      label: "Auto"
      hint: "Follows your theme, tints by usage, switches to a % readout near a limit. Turn off to control everything by hand."
    }

    ButtonGroup {
      width: parent.width
      value: page.tab
      options: [
        { value: "look", label: "Look" },
        { value: "layout", label: "Layout" },
        { value: "behave", label: "Behaviour" },
        { value: "popup", label: "Popup & data" }
      ]
      onChanged: function(val) { page.tab = val }
    }

    PanelSeparator { width: parent.width }

    Flickable {
      id: scroller
      width: parent.width
      clip: true
      contentHeight: pages.implicitHeight
      height: Math.min(contentHeight, Math.max(Style.space(160), page.maxHeight - Style.space(200)))
      interactive: contentHeight > height
      boundsBehavior: Flickable.StopAtBounds
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

      Item {
        id: pages
        width: scroller.width - (scroller.interactive ? Style.space(10) : 0)
        implicitHeight: Math.max(lookCol.visible ? lookCol.implicitHeight : 0, layoutCol.visible ? layoutCol.implicitHeight : 0,
                                 behaveCol.visible ? behaveCol.implicitHeight : 0, popupCol.visible ? popupCol.implicitHeight : 0)

        // ------------------------------------------------------------ LOOK
        Column {
          id: lookCol
          width: parent.width
          visible: page.tab === "look"
          spacing: Style.space(4)

          Heading { text: "LOGO / ICON" }
          PickField { key: "icon"; label: "Icon"; locked: page.auto
            options: [ { value: "mark", label: "OpenCode mark" }, { value: "terminal", label: "Terminal" }, { value: "bolt", label: "Bolt" },
                       { value: "chart", label: "Bar chart" }, { value: "fire", label: "Flame" }, { value: "robot", label: "Robot" },
                       { value: "none", label: "None" } ] }
           SliderField { key: "logoSize"; label: "Size"; from: 8; to: 32; suffix: " px"; locked: false }
          PickField { key: "logoColorMode"; label: "Colour"; locked: page.auto
            options: [ { value: "theme", label: "Match bar" }, { value: "accent", label: "Theme accent" },
                       { value: "status", label: "By usage" }, { value: "custom", label: "Custom" } ] }
          ColorField { key: "logoColor"; label: "Custom colour"; locked2: page.auto || page.v("logoColorMode") !== "custom" }
          SliderField { key: "logoOpacity"; label: "Opacity"; from: 20; to: 100; suffix: " %"; locked: page.auto }

          Heading { text: "TEXT" }
          ToggleField { key: "showText"; label: "Show text"; hint: "Off = icon only (or icon + the extra visual below)."; locked: page.auto }
          PickField { key: "readout"; label: "Show"; locked: page.auto || !page.v("showText")
            options: [ { value: "tokens", label: "Tokens today" }, { value: "requests", label: "Requests today" },
                       { value: "percent", label: "Worst limit %" }, { value: "both", label: "Tokens + %" },
                       { value: "provider", label: "Busiest provider" } ] }
          ToggleField { key: "compactNumbers"; label: "Compact numbers"; hint: "184k instead of 184,320"; locked: page.auto || !page.v("showText") }
          SliderField { key: "fontSize"; label: "Font size"; from: 8; to: 20; suffix: " px"; locked: page.auto || !page.v("showText") }
          ToggleField { key: "bold"; label: "Bold"; locked: page.auto || !page.v("showText") }
          PickField { key: "textColorMode"; label: "Colour"; locked: page.auto || !page.v("showText")
            options: [ { value: "theme", label: "Match bar" }, { value: "accent", label: "Theme accent" },
                       { value: "status", label: "By usage" }, { value: "custom", label: "Custom" } ] }
          ColorField { key: "textColor"; label: "Custom colour"; locked2: page.auto || !page.v("showText") || page.v("textColorMode") !== "custom" }

          Heading { text: "SHOW INSTEAD OF (OR WITH) TEXT" }
          PickField { key: "visual"; label: "Extra visual"; locked: page.auto
            hint: "Progress ring around the icon, a thin bar under the text, or just a status dot."
            options: [ { value: "none", label: "None" }, { value: "ring", label: "Ring around icon" },
                       { value: "bar", label: "Mini bar" }, { value: "dot", label: "Status dot" } ] }

          Heading { text: "LIMIT COLOURS" }
          ToggleField { key: "tintOnLimit"; label: "Tint when close to a limit"; locked: page.auto }
          SliderField { key: "warnAt"; label: "Warn at"; from: 10; to: 95; suffix: " %" }
          ColorField { key: "warnColor"; label: "Warn colour" }
          SliderField { key: "dangerAt"; label: "Danger at"; from: 20; to: 100; suffix: " %" }
          ColorField { key: "dangerColor"; label: "Danger colour" }
        }

        // ---------------------------------------------------------- LAYOUT
        Column {
          id: layoutCol
          width: parent.width
          visible: page.tab === "layout"
          spacing: Style.space(4)

          Heading { text: "POSITION" }
          Field { label: "Bar section"; hint: "Moves the widget in the bar."
            ButtonGroup {
              options: [ { value: "left", label: "Left" }, { value: "center", label: "Center" }, { value: "right", label: "Right" } ]
              value: String(page.v("section"))
              onChanged: function(val) { page.set("section", val); page.moveRequested(val) }
            } }
          PickField { key: "iconSide"; label: "Icon position"; locked: page.auto
            options: [ { value: "left", label: "Left of text" }, { value: "right", label: "Right of text" },
                       { value: "top", label: "Above text" }, { value: "bottom", label: "Below text" } ] }

          Heading { text: "SPACING" }
          SliderField { key: "gap"; label: "Icon ↔ text gap"; from: 0; to: 20; suffix: " px"; locked: page.auto }
          SliderField { key: "paddingX"; label: "Side padding"; from: 0; to: 24; suffix: " px" }
          SliderField { key: "nudgeY"; label: "Vertical nudge"; from: -6; to: 6; suffix: " px" }
          SliderField { key: "widgetOpacity"; label: "Widget opacity"; from: 30; to: 100; suffix: " %" }

          Heading { text: "VISIBILITY" }
          ToggleField { key: "hideWhenIdle"; label: "Hide when nothing used today"; hint: "The widget disappears until your first request." }
        }

        // ------------------------------------------------------- BEHAVIOUR
        Column {
          id: behaveCol
          width: parent.width
          visible: page.tab === "behave"
          spacing: Style.space(4)

          Heading { text: "CLICKS" }
          PickField { key: "leftClick"; label: "Left click"
            options: [ { value: "popup", label: "Open popup" }, { value: "opencode", label: "Open OpenCode" },
                       { value: "refresh", label: "Refresh" }, { value: "none", label: "Nothing" } ] }
          PickField { key: "middleClick"; label: "Middle click"
            options: [ { value: "refresh", label: "Refresh" }, { value: "popup", label: "Open popup" },
                       { value: "opencode", label: "Open OpenCode" }, { value: "none", label: "Nothing" } ] }
          PickField { key: "rightClick"; label: "Right click"
            options: [ { value: "opencode", label: "Open OpenCode" }, { value: "popup", label: "Open popup" },
                       { value: "refresh", label: "Refresh" }, { value: "none", label: "Nothing" } ] }

          Heading { text: "REFRESH" }
          SliderField { key: "refreshSec"; label: "Popup closed"; from: 5; to: 120; suffix: " s" }
          SliderField { key: "activeRefreshSec"; label: "Popup open"; from: 2; to: 30; suffix: " s" }
        }

        // ---------------------------------------------------- POPUP & DATA
        Column {
          id: popupCol
          width: parent.width
          visible: page.tab === "popup"
          spacing: Style.space(4)

          Heading { text: "POPUP" }
          SliderField { key: "popupWidth"; label: "Width"; from: 280; to: 520; suffix: " px" }
          ToggleField { key: "showSparkline"; label: "7-day sparkline" }
          ToggleField { key: "showModels"; label: "Per-model rows"; hint: "Turn off for a provider-only summary." }
          ToggleField { key: "showNotes"; label: "Provider notes"; hint: "The small limit explanations under each provider." }

          Heading { text: "DATA" }
          ToggleField { key: "countCache"; label: "Count cache tokens"; hint: "Adds cache reads/writes to the token total." }
          ToggleField { key: "openrouterCredits"; label: "OpenRouter has $10+ credit"; hint: "Raises the free daily limit from 50 to 1000." }
          Field { label: "OpenCode database"; hint: "Blank = ~/.local/share/opencode/opencode.db"
            TextField { width: Style.space(170); text: String(page.v("dbPath")); placeholderText: "auto"
                        onEditingFinished: page.set("dbPath", text.trim()) } }
          Field { label: "Budgets file"; hint: "Blank = ~/.config/opencode-usage/config.json"
            TextField { width: Style.space(170); text: String(page.v("configPath")); placeholderText: "auto"
                        onEditingFinished: page.set("configPath", text.trim()) } }
        }
      }
    }

    PanelSeparator { width: parent.width }

    Item {
      width: parent.width
      height: Style.space(30)
      Button { anchors.left: parent.left; text: "Reset to defaults"; onClicked: page.resetAll() }
      Txt { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            text: "Changes save instantly"; color: page.dim; font.pixelSize: Style.font.caption }
    }
  }
}
