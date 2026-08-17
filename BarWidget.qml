import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.janhesters.focus"

  property bool blocking: false
  readonly property bool showWhenInactive: setting("showWhenInactive", true) === true
  readonly property string helperPath: localPath(Qt.resolvedUrl("focus"))

  function localPath(url) {
    var value = String(url)
    if (value.indexOf("file://") === 0) return decodeURIComponent(value.substring(7))
    return value
  }

  function refresh() {
    if (!statusProcess.running) statusProcess.running = true
  }

  function toggle() {
    if (actionProcess.running) return
    actionProcess.command = [root.helperPath, root.blocking ? "off" : "on"]
    actionProcess.running = true
  }

  visible: blocking || showWhenInactive || actionProcess.running
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: visible ? button.implicitHeight : 0

  IpcHandler {
    target: "io.github.janhesters.focus"

    function refresh(): void {
      root.broadcast("refresh")
    }
  }

  Process {
    id: statusProcess
    command: [root.helperPath, "status"]
    onExited: function(exitCode) {
      root.blocking = exitCode === 0
    }
  }

  Process {
    id: actionProcess
    onExited: function() {
      root.refresh()
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uDB80\uDD76"
    active: root.blocking
    activeColor: Color.urgent
    useActiveColor: true
    dimmed: !root.blocking
    interactive: !actionProcess.running
    tooltipText: actionProcess.running
      ? "Updating focus mode..."
      : (root.blocking ? "Focus mode active; click to unblock" : "Focus mode off; click to block distractions")
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }
}
