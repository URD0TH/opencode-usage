import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// OpenCode Usage: logo + today's tokens in the bar; a click opens the card with
// free-tier limits and per-model bars. Data comes from bin/opencode-usage, which
// reads OpenCode's local database read-only.
Panel {
  id: root

  moduleName: "URD0TH.opencode-usage"
  ipcTarget: "URD0TH.opencode-usage"

  readonly property string script:
    Qt.resolvedUrl("bin/opencode-usage").toString().replace(/^file:\/\//, "")

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accent: Color.accent
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color warning: "#D6A84B"
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property var view: ({ ok: false, error: "", hint: "" })
  property bool settingsOpen: false
  function openSettings() { settingsOpen = true; open() }
  function closeSettings() { settingsOpen = false }
  function persistSettings(values) {
    var cur = {}
    if (settings) for (var k in settings) cur[k] = settings[k]
    for (var k in values) cur[k] = values[k]
    cur.id = moduleName
    if (bar && bar.shell && bar.shell.updateEntryInline) bar.shell.updateEntryInline(moduleName, cur)
    else settings = cur
  }

  // Settings wiring — every key is a plain value in shell.json via setting(key, default)
  readonly property var defaults: ({ auto: true, icon: "mark", iconSide: "left", logoSize: 14, logoColorMode: "theme", logoColor: "#7AA2F7", logoOpacity: 100, showText: true, readout: "tokens", compactNumbers: true, bold: true, fontSize: 12, gap: 6, textColorMode: "theme", textColor: "#FFFFFF", visual: "none", section: "right", paddingX: 9, nudgeY: 0, widgetOpacity: 100, hideWhenIdle: false, tintOnLimit: true, warnAt: 60, dangerAt: 85, warnColor: "#D6A84B", dangerColor: "#E5484D", leftClick: "popup", middleClick: "refresh", rightClick: "opencode",     refreshSec: 10, activeRefreshSec: 2, popupWidth: 350, showSparkline: true, showModels: true, showNotes: true, dbPath: "", configPath: "", countCache: false, openrouterCredits: false })
  function v(key) { return root.setting(key, defaults[key]) }
  function levelFor(pct) { return pct >= v("dangerAt") ? "danger" : (pct >= v("warnAt") ? "warn" : "ok") }
  function pickColor(mode, custom, lvl, base) {
    if (v("auto")) return (lvl !== "ok" ? levelColor(lvl) : base)
    if (mode === "accent") return accent
    if (mode === "status") return lvl !== "ok" ? levelColor(lvl) : base
    if (mode === "custom") return custom
    return (v("tintOnLimit") && lvl !== "ok") ? levelColor(lvl) : base
  }
  readonly property string effIcon: v("auto") ? "mark" : v("icon")
  readonly property bool effShowText: v("auto") ? true : v("showText")
  readonly property string effReadout: v("auto") ? (worst === "ok" ? "tokens" : "percent") : v("readout")
  readonly property string effVisual: v("auto") ? "none" : v("visual")
  function glyph(name) { return ({ terminal: "\uF120", bolt: "\uF0E7", chart: "\uF080", fire: "\uF06D", robot: "\uDB81\uDEA9" })[name] || "" }
  function readoutText() {
    if (!view.ok) return "–"
    var r = effReadout
    if (r === "requests") return view.today.requests + " req"
    if (r === "percent") { var p = 0; for (var i=0;i<view.providers.length;i++) for (var j=0;j<view.providers[i].limits.length;j++) p = Math.max(p, view.providers[i].limits[j].pct); return p + "%" }
    if (r === "both") { var q = 0; for (var i=0;i<view.providers.length;i++) for (var j=0;j<view.providers[i].limits.length;j++) q = Math.max(q, view.providers[i].limits[j].pct); return view.today.label + " · " + q + "%" }
    if (r === "provider") { var best=""; var max=-1; for (var i=0;i<view.providers.length;i++) if (view.providers[i].requests>max){max=view.providers[i].requests; best=view.providers[i].name;} return best||view.today.label }
    return view.today.label
  }

  readonly property string worst: {
    if (!view.ok) return "ok"
    var w = "ok"
    for (var i = 0; i < view.providers.length; i++) {
      var lims = view.providers[i].limits
      if (lims) for (var j=0;j<lims.length;j++) {
        var lvl = levelFor(lims[j].pct)
        if (lvl === "danger") return "danger"
        if (lvl === "warn") w = "warn"
      }
      var l = view.providers[i].level
      if (l === "danger") return "danger"
      if (l === "warn" && w !== "danger") w = "warn"
    }
    return w
  }

  function levelColor(level) {
    var dc = v("dangerColor"), wc = v("warnColor")
    // allow custom colors, fallback to defaults if invalid
    try { if (dc && String(dc).charAt(0)==="#") { /* valid */ } else dc = urgent } catch(e){ dc = urgent }
    try { if (wc && String(wc).charAt(0)==="#") { /* valid */ } else wc = warning } catch(e){ wc = warning }
    return level === "danger" ? dc : (level === "warn" ? wc : accent)
  }

  function refresh() {
    if (collector.running) return
    collector.running = true
  }

  function launch() {
    Quickshell.execDetached(["omarchy-launch-tui", "opencode"])
    close()
  }

  function apply(text) {
    var doc = null
    try { doc = JSON.parse(text) } catch (e) { doc = null }
    view = doc && typeof doc === "object"
      ? doc
      : { ok: false, error: "The usage collector returned unreadable output.", hint: "Run bin/opencode-usage in a terminal." }
  }

  // Minimal two-line tooltip: total + busiest provider
  function worstTip() {
    var p=0
    if (view.ok) for (var i=0;i<view.providers.length;i++) for (var j=0;j<view.providers[i].limits.length;j++) p=Math.max(p, view.providers[i].limits[j].pct)
    return p
  }
  function tooltip() {
    if (!view.ok) return view.error || "OpenCode usage"
    var busy = "", max = -1
    for (var i=0;i<view.providers.length;i++) if (view.providers[i].requests>max) { max=view.providers[i].requests; busy=view.providers[i].name }
    var w = worstTip()
    var tip = view.today.label + " · " + view.today.requests + " req today"
    if (busy) tip += "\n" + busy + (w>0 ? " · " + w + "% of limit" : "")
    return tip
  }



  readonly property bool hidden: v("hideWhenIdle") && view.ok && view.today.tokens===0
  implicitWidth: hidden ? 0 : (bar && bar.vertical ? bar.barSize : (button.contentWidth + Style.space(Number(v("paddingX"))*2)))
  implicitHeight: hidden ? 0 : (bar && bar.vertical ? button.contentWidth + Style.space(18) : (bar ? bar.barSize : Style.bar.sizeHorizontal))
  opacity: Number(v("widgetOpacity"))/100
  y: Number(v("nudgeY"))

  Process {
    id: collector
    command: ["python3", root.script, root.setting("configPath", ""), root.setting("dbPath", "")]
    stdout: StdioCollector {
      onStreamFinished: root.apply(text)
    }
  }

  // Polled: respects settings (active vs idle) + file watcher for near-realtime
  Timer {
    id: pollTimer
    interval: root.opened ? Math.max(2000, Number(v("activeRefreshSec"))*1000) : Math.max(5000, Number(v("refreshSec"))*1000)
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
  Timer { id: refreshDebounce; interval: 700; repeat: false; onTriggered: root.refresh() }
  FileView {
    id: dbWatcher
    // Watch only: the OpenCode database is multi-GB, and a normal FileView
    // reads the whole file into memory. blockLoading keeps it at mtime-only.
    blockLoading: true
    watchChanges: true
    // watch the DB file; if custom dbPath is set use it, else default
    path: {
      var p = root.setting("dbPath", "")
      if (p && String(p).trim() !== "") {
        var s = String(p)
        if (s.startsWith("~")) return (Quickshell.env("HOME")||"/home/sam") + s.slice(1)
        return s
      }
      var base = Quickshell.env("XDG_DATA_HOME")
      if (!base || String(base).trim()==="") base = (Quickshell.env("HOME")||"/home/sam") + "/.local/share"
      return base + "/opencode/opencode.db"
    }
    onFileChanged: refreshDebounce.restart()
    onLoadFailed: {}
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    fixedWidth: -1
    tooltipText: root.tooltip()

    readonly property real contentWidth: rowWrapper.width

    // Bar chip — logo and text same line, perfectly centered (up-down centre of bar)
    Item {
      id: rowWrapper
      anchors.centerIn: parent
      anchors.verticalCenterOffset: Number(v("nudgeY"))
      opacity: Number(v("widgetOpacity"))/100
      width: row.width
      height: row.height + (barVisual.visible ? barVisual.height + Style.space(1) : 0)
      Grid {
        id: row
        x: (parent.width - width)/2
        y: 0
        columns: (v("iconSide")==="top" || v("iconSide")==="bottom") ? 1 : 2
        spacing: Style.space(Number(v("gap")))
        layoutDirection: (v("iconSide")==="right" || v("iconSide")==="bottom") ? Qt.RightToLeft : Qt.LeftToRight
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        // icon / logo — fixed size, centered with text row
        Item {
          id: iconBox
          visible: root.effIcon !== "none"
          width: iconSize
          height: iconSize
          readonly property real iconSize: Number(v("logoSize"))
          readonly property color iconColor: root.pickColor(v("logoColorMode"), v("logoColor"), root.worst, button.foreground)
          opacity: Number(v("logoOpacity"))/100
          // Meet the text's painted centre (see readout): the Grid centres
          // boxes, but the text's ink rides high in its line box, so a
          // centred 12px logo lands ~1px low next to it (measured). Live,
          // so any font/size/content stays aligned; off when stacked or
          // icon-only, where there is nothing to meet.
          transform: Translate { y: rowWrapper.iconOpticalShift }
          OpenCodeLogo {
            visible: root.effIcon === "mark"
            anchors.centerIn: parent
            size: iconBox.iconSize
            color: iconBox.iconColor
          }
          Text {
            visible: root.effIcon !== "mark" && root.effIcon !== "none"
            anchors.centerIn: parent
            text: root.glyph(root.effIcon)
            font.family: Style.font.family
            font.pixelSize: iconBox.iconSize
            color: iconBox.iconColor
            renderType: Text.NativeRendering
          }
          Canvas {
            id: ring
            anchors.fill: parent
            visible: root.effVisual === "ring"
            property real pct: {
              var p=0; if (root.view.ok) for (var i=0;i<root.view.providers.length;i++) for (var j=0;j<root.view.providers[i].limits.length;j++) p=Math.max(p, root.view.providers[i].limits[j].pct); return p;
            }
            property color c: iconBox.iconColor
            onPctChanged: requestPaint(); onCChanged: requestPaint(); onWidthChanged: requestPaint()
            onPaint: {
              var ctx=getContext("2d"); ctx.reset(); var r=width/2-1.5; ctx.lineWidth=2;
              ctx.strokeStyle=Qt.rgba(1,1,1,0.15); ctx.beginPath(); ctx.arc(width/2,height/2,r,0,2*Math.PI); ctx.stroke();
              ctx.strokeStyle=c; ctx.beginPath(); ctx.arc(width/2,height/2,r,-Math.PI/2,-Math.PI/2+2*Math.PI*Math.min(1,pct/100)); ctx.stroke();
            }
          }
        }

        // dot when icon-only
        Rectangle {
          visible: root.effVisual === "dot" && !root.effShowText
          width: Style.space(7); height: width; radius: width/2
          color: root.levelColor(root.worst)
        }

        // text row — same line as icon, vertically centred
        Row {
          id: labelRow
          visible: root.effShowText
          spacing: Style.space(4)
          Rectangle {
            visible: root.effVisual === "dot"
            width: Style.space(7); height: width; radius: width/2
            color: root.levelColor(root.worst)
          }
          Text {
            id: readout
            visible: !(root.bar && root.bar.vertical)
            text: root.readoutText()
            font.family: Style.font.family
            font.pixelSize: v("auto") ? button.fontSize : Number(v("fontSize"))
            font.bold: v("auto") ? true : v("bold")===true
            color: root.pickColor(v("textColorMode"), v("textColor"), root.worst, button.foreground)
            renderType: Text.NativeRendering
            // Optical alignment: the Grid centres this line box against the
            // logo box, but the line box carries empty descender space, so
            // digit-only readouts ("89.9k") float above centre while strings
            // with descenders ("48 req") sink below it. Measure the painted
            // glyphs live and meet the two centres exactly — right for any
            // content, font or size, with no hand-tuned offset to drift.
            transform: Translate { y: rowWrapper.readoutOpticalShift }
          }
        }
      }
      // Painted-glyph metrics for the readout; zero-size, lays out nothing.
      TextMetrics {
        id: readoutMetrics
        font.family: Style.font.family
        font.pixelSize: v("auto") ? button.fontSize : Number(v("fontSize"))
        text: root.readoutText()
      }
      readonly property real readoutOpticalShift: {
        var box = readoutMetrics.tightBoundingRect
        if (!box || !(box.height > 0) || !(readout.height > 0)) return 0
        return readout.height / 2 - (readout.baselineOffset + box.y + box.height / 2)
      }
      readonly property real iconOpticalShift: {
        if (!root.effShowText) return 0
        var side = v("iconSide")
        if (side === "top" || side === "bottom") return 0
        if (!(row.height > 0) || !(iconBox.height > 0)) return 0
        var textCenter = labelRow.y + readout.y + readout.height / 2 + readoutOpticalShift
        return textCenter - (iconBox.y + iconBox.height / 2)
      }
      Rectangle {
        id: barVisual
        visible: root.effVisual === "bar"
        x: (parent.width - width)/2
        y: row.height + Style.space(1)
        width: row.width
        height: Style.space(3); radius: height/2
        color: Qt.rgba(1,1,1,0.15)
        Rectangle { width: parent.width * Math.min(1, (function(){ var p=0; if(root.view.ok) for(var i=0;i<root.view.providers.length;i++) for(var j=0;j<root.view.providers[i].limits.length;j++) p=Math.max(p, root.view.providers[i].limits[j].pct); return p; })()/100); height: parent.height; radius: height/2; color: root.levelColor(root.worst) }
      }
    }

    onPressed: function(b) {
      if (root.settingsOpen) { root.closeSettings(); return }
      var act = b===Qt.LeftButton ? v("leftClick") : b===Qt.MiddleButton ? v("middleClick") : v("rightClick")
      if (act === "popup") root.toggle()
      else if (act === "opencode") root.launch()
      else if (act === "refresh") root.refresh()
      else if (act === "none") {}
      // also allow Shift+Right to open settings quickly
      if (b === Qt.RightButton && act !== "popup" && !root.settingsOpen) {
        // if rightClick is not popup, still allow opening settings via Shift? keep as is
      }
    }
  }

  // Close settings when panel closes
  onOpenedChanged: if (!opened) settingsOpen = false

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: settingsOpen ? settingsPage : card
    contentWidth: panel.fittedContentWidth(Style.space(settingsOpen ? settingsPage.contentWidth : 350))
    contentHeight: panel.fittedContentHeight(settingsOpen ? settingsPage.implicitHeight : card.bodyHeight)

    Card {
      id: card
      anchors.fill: parent
      visible: !root.settingsOpen
      panel: root
      maxHeight: panel.availableCardHeight - panel.verticalContentInset
    }
    Settings {
      id: settingsPage
      visible: root.settingsOpen
      anchors.fill: parent
      settings: root.settings
      onApply: function(values) { root.persistSettings(values) }
      onMoveRequested: function(section) { Quickshell.execDetached(["omarchy","bar","move",root.moduleName,"--section",section]) }
      onCloseRequested: root.closeSettings()
    }
  }
}
