import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Date/time label for the bar, and the host for the calendar popup.
//
// Left click reveals the calendar — asking "what is the date?" is what a
// click on a clock means — right click walks the common label formats, and
// middle click opens the timezone picker.
BarWidget {
  id: root
  moduleName: "io.github.hugorolimf.clock"

  property date displayDate: clock.date

  readonly property string configuredFormat: vertical
    ? setting("verticalFormat", "HH\n—\nmm")
    : setting("format", "dddd HH:mm")
  readonly property string configuredAltFormat: vertical
    ? setting("verticalFormatAlt", "dd\nMMM\n'W'ww\n''yy")
    : setting("formatAlt", "d MMMM 'W'ww yyyy")

  readonly property var formatRing: Model.clockFormatRing(configuredFormat, configuredAltFormat, Model.clockFormats(vertical))

  // What the bar shows is what shell.json stores, so a cycled format is the
  // format from then on rather than something that reverts on restart.
  readonly property string activeFormat: configuredFormat
  readonly property string displayText: formatted(displayDate)
  readonly property var verticalLines: displayText.split("\n")

  function refresh() {
    displayDate = new Date()
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function cycleFormat() {
    var current = String(configuredFormat)
    var next = Model.nextClockFormat(formatRing, current)
    if (next === "" || next === current) return

    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    entry[vertical ? "verticalFormat" : "format"] = next

    // Applied locally first so the label changes on the click itself; the
    // shell.json write comes back through the bar as the same value.
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  // Day and month names in the system language, without the dot some
  // locales (pt_BR) put after abbreviations, and the first letter capitalized.
  readonly property var ptLocale: Qt.locale()
  function formatted(date) {
    var text = date.toLocaleString(ptLocale, activeFormat.replace(/ww/g, Model.isoWeekLiteral(date.getFullYear(), date.getMonth(), date.getDate())))
    text = String(text).replace(/([A-Za-zÀ-ÿ])\./g, "$1")
    return text.charAt(0).toUpperCase() + text.slice(1)
  }

  // ---- Calendar popup. Shape contract for shell.summon/hide/toggle
  //      routing: Bar.findPanelWidget requires open/close/opened on the
  //      bar-widget root.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function toggleWeekStart() {
    if (panelLoader.item) panelLoader.item.toggleWeekStart()
  }

  // The clock fills more slot than it paints a mark for, at both
  // orientations: horizontally it is a text label in a padded slot, so the
  // dot takes the label width; vertically it is a stack of icon-sized lines,
  // so the dot takes one line — the same mark every icon widget gets, rather
  // than a rule running the height of the whole stack.
  readonly property real openPanelIndicatorWidth: clockRow.implicitWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  // Forwarded so this widget can stand in for the panel as the bar's popout
  // identity: Bar.requestPopout prefers closeForPopoutSwitch over close, and
  // KeyboardPanel reads popoutSwitchClosing back off its owner.
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: root.displayDate = date
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "io.github.hugorolimf.clock"

    function refresh(): void { root.broadcast("refresh") }
    function cycleFormat(): void { root.cycleFormat() }
    function toggleWeekStart(): void { root.toggleWeekStart() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  // Glass Clock: when the minute (or the format) changes, the old time lifts
  // away and the new one rises in, instead of the text just swapping.
  property string shownText: ""
  onDisplayTextChanged: {
    if (shownText === "" || root.vertical) shownText = displayText
    else flip.restart()
  }
  Component.onCompleted: shownText = displayText

  // "anatomy" look: the date small, upper case and muted, the time bright,
  // both monospaced ("QUI 29 OUT  00:52"). The time is the last H:mm run of
  // the active format; the rest is the date.
  readonly property var shownParts: {
    var m = /^(.*?)[,\s]*(\d{1,2}:\d{2}(:\d{2})?)\s*$/.exec(shownText)
    return m ? { date: m[1].trim().toUpperCase(), time: m[2] } : { date: "", time: shownText }
  }
  SequentialAnimation {
    id: flip
    ParallelAnimation {
      NumberAnimation { target: flipShift; property: "y"; to: -5; duration: 130; easing.type: Easing.InCubic }
      NumberAnimation { target: clockRow; property: "opacity"; to: 0; duration: 130 }
    }
    ScriptAction { script: { root.shownText = root.displayText; flipShift.y = 6 } }
    ParallelAnimation {
      NumberAnimation { target: flipShift; property: "y"; to: 0; duration: 420; easing.type: Easing.Bezier; easing.bezierCurve: [0.32, 0.72, 0, 1, 1, 1] }
      NumberAnimation { target: clockRow; property: "opacity"; to: 1; duration: 300 }
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    fixedWidth: root.vertical ? -1 : clockRow.implicitWidth + 17.5
    labelVisible: false
    hasVisualContent: root.vertical ? root.verticalLines.length > 0 : root.shownText !== ""
    fixedHeight: root.vertical ? root.verticalLines.length * Style.bar.iconSlot : -1
    horizontalMargin: 8.75
    verticalPadding: 8.75

    onPressed: function(b) {
      if (b === Qt.RightButton) root.cycleFormat()
      else if (b === Qt.MiddleButton) { if (root.bar) root.bar.run("omarchy-menu-timezone") }
      else root.togglePanel()
    }

    Row {
      id: clockRow
      visible: !root.vertical
      anchors.centerIn: parent
      spacing: 7
      transform: Translate { id: flipShift }
      Text {
        visible: text !== ""
        anchors.baseline: timeText.baseline
        text: root.shownParts.date
        color: "#8a8a8f"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 10
        font.letterSpacing: 0.4
      }
      Text {
        id: timeText
        text: root.shownParts.time
        color: button.foreground
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        font.weight: Font.Medium
      }
    }

    Column {
      visible: root.vertical
      anchors.fill: parent

      Repeater {
        model: root.verticalLines

        OpticalGlyph {
          required property string modelData
          width: button.width
          height: Style.bar.iconSlot
          text: modelData
          fontFamily: button.fontFamily
          fontSize: modelData.length > 3
            ? button.fontSize * 0.9
            : button.fontSize
          color: button.foreground
        }
      }
    }
  }
}
