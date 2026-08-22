import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// Volume icon + percentage. Scroll adjusts volume. Left click opens a full
// mixer popup (master slider + output device picker); right click is a
// quick mute toggle without opening anything.
Item {
    id: vol

    required property var bar

    readonly property var sink: Pipewire.ready ? Pipewire.defaultAudioSink : null
    readonly property real level: vol.sink && vol.sink.audio ? vol.sink.audio.volume : 0
    readonly property bool muted: vol.sink && vol.sink.audio ? vol.sink.audio.muted : false
    readonly property var sinks: Pipewire.ready ? Pipewire.nodes.values.filter(n => n.isSink && !n.isStream) : []

    readonly property var source: Pipewire.ready ? Pipewire.defaultAudioSource : null
    readonly property real srcLevel: vol.source && vol.source.audio ? vol.source.audio.volume : 0
    readonly property bool srcMuted: vol.source && vol.source.audio ? vol.source.audio.muted : false
    readonly property var sources: Pipewire.ready ? Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio) : []

    width: rowLayout.implicitWidth + 12
    height: 22

    // keep the default sink/source and every device bound so their
    // properties (volume, mute, names) stay live
    PwObjectTracker {
        objects: vol.sinks
    }

    PwObjectTracker {
        objects: vol.sources
    }

    function setVolume(v) {
        if (vol.sink && vol.sink.audio)
            vol.sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    function toggleMute() {
        if (vol.sink && vol.sink.audio)
            vol.sink.audio.muted = !vol.sink.audio.muted;
    }

    function setSourceVolume(v) {
        if (vol.source && vol.source.audio)
            vol.source.audio.volume = Math.max(0, Math.min(1, v));
    }

    function toggleSourceMute() {
        if (vol.source && vol.source.audio)
            vol.source.audio.muted = !vol.source.audio.muted;
    }

    function icon() {
        if (vol.muted || vol.level === 0)
            return "\u{f0581}"; // 󰖁 volume off
        if (vol.level > 0.66)
            return "\u{f057e}"; // 󰕾 high
        if (vol.level > 0.33)
            return "\u{f0580}"; // 󰖀 medium
        return "\u{f057f}";     // 󰕿 low
    }

    function micIcon() {
        return vol.srcMuted ? "\u{f036d}" : "\u{f036c}"; // 󰍭 mic / 󰍬 mic-off
    }

    function sinkLabel(n) {
        return n.nickname || n.description || n.name;
    }

    function sourceLabel(n) {
        return n.nickname || n.description || n.name;
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: volMouse.containsMouse ? Theme.hover : "transparent"

        Row {
            id: rowLayout
            anchors.centerIn: parent
            spacing: 5

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconSize
                color: vol.muted ? Theme.fgDim : Theme.fg
                text: vol.icon()
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: vol.muted ? "MUTE" : Math.round(vol.level * 100) + "%"
                color: vol.muted ? Theme.fgDim : Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }

        MouseArea {
            id: volMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    vol.toggleMute();
                    return;
                }
                if (popup.visible) {
                    popup.visible = false;
                    return;
                }
                const p = vol.mapToItem(null, 0, 0);
                popup.anchor.rect.x = Math.max(8, p.x + vol.width - popup.implicitWidth);
                popup.anchor.rect.y = Theme.barHeight;
                PopupGuard.claim(popup);
                popup.visible = true;
            }
            onWheel: wheel => vol.setVolume(vol.level + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
        }
    }

    PopupWindow {
        id: popup

        anchor.window: vol.bar
        implicitWidth: 300
        implicitHeight: popupBox.implicitHeight
        visible: false
        color: "transparent"

        HoverHandler {
            id: popupHover
        }

        Timer {
            interval: 3500
            running: popup.visible && !popupHover.hovered
            onTriggered: popup.visible = false
        }

        Rectangle {
            id: popupBox
            anchors.fill: parent
            implicitHeight: popupCol.implicitHeight + 24
            radius: 12
            color: Theme.popupBg
            border.color: Theme.popupBorder
            border.width: 1

            Column {
                id: popupCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                spacing: 8

                Item {
                    width: parent.width
                    height: 20

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Volume"
                        color: Theme.fgSel
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: vol.muted ? "muted" : Math.round(vol.level * 100) + "%"
                        color: Theme.fgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }

                // mute button + volume slider
                Row {
                    width: parent.width
                    height: 24
                    spacing: 10

                    Rectangle {
                        width: 24
                        height: 24
                        radius: 6
                        anchors.verticalCenter: parent.verticalCenter
                        color: muteMouse.containsMouse ? Theme.hover : "transparent"

                        Text {
                            anchors.centerIn: parent
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize
                            text: vol.icon()
                            color: vol.muted ? Theme.fgDim : Theme.fg
                        }

                        MouseArea {
                            id: muteMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: vol.toggleMute()
                        }
                    }

                    Item {
                        width: parent.width - 34
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            id: track
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 4
                            radius: 2
                            color: Theme.hover

                            Rectangle {
                                width: parent.width * Math.min(1, vol.level)
                                height: parent.height
                                radius: 2
                                color: vol.muted ? Theme.fgDim : Theme.accent
                            }
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(parent.width - width, track.width * Math.min(1, vol.level) - width / 2))
                            width: 14
                            height: 14
                            radius: 7
                            color: Theme.fgSel
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPressed: mouse => vol.setVolume(mouse.x / width)
                            onPositionChanged: mouse => {
                                if (pressed)
                                    vol.setVolume(mouse.x / width);
                            }
                            onWheel: wheel => vol.setVolume(vol.level + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.popupBorder
                }

                Text {
                    text: "Output"
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }

                Repeater {
                    model: vol.sinks

                    delegate: Rectangle {
                        required property var modelData

                        readonly property bool current: Pipewire.defaultAudioSink === modelData

                        width: popupCol.width
                        height: 30
                        radius: 8
                        color: outMouse.containsMouse ? Theme.hover : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 30
                            anchors.verticalCenter: parent.verticalCenter
                            text: vol.sinkLabel(modelData)
                            color: current ? Theme.accent : Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            elide: Text.ElideRight
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            visible: current
                            font.family: Theme.iconFont
                            font.pixelSize: 12
                            text: "\u{f012c}" // 󰄬 check
                            color: Theme.accent
                        }

                        MouseArea {
                            id: outMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Pipewire.preferredDefaultAudioSink = modelData
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.popupBorder
                }

                Item {
                    width: parent.width
                    height: 20

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Microphone"
                        color: Theme.fgSel
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: !vol.source ? "none" : vol.srcMuted ? "muted" : Math.round(vol.srcLevel * 100) + "%"
                        color: Theme.fgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }

                // mute button + input volume slider
                Row {
                    width: parent.width
                    height: 24
                    spacing: 10
                    enabled: !!vol.source
                    opacity: vol.source ? 1 : 0.4

                    Rectangle {
                        width: 24
                        height: 24
                        radius: 6
                        anchors.verticalCenter: parent.verticalCenter
                        color: micMuteMouse.containsMouse ? Theme.hover : "transparent"

                        Text {
                            anchors.centerIn: parent
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize
                            text: vol.micIcon()
                            color: vol.srcMuted ? Theme.fgDim : Theme.fg
                        }

                        MouseArea {
                            id: micMuteMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: vol.toggleSourceMute()
                        }
                    }

                    Item {
                        width: parent.width - 34
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            id: micTrack
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 4
                            radius: 2
                            color: Theme.hover

                            Rectangle {
                                width: parent.width * Math.min(1, vol.srcLevel)
                                height: parent.height
                                radius: 2
                                color: vol.srcMuted ? Theme.fgDim : Theme.accent
                            }
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(parent.width - width, micTrack.width * Math.min(1, vol.srcLevel) - width / 2))
                            width: 14
                            height: 14
                            radius: 7
                            color: Theme.fgSel
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPressed: mouse => vol.setSourceVolume(mouse.x / width)
                            onPositionChanged: mouse => {
                                if (pressed)
                                    vol.setSourceVolume(mouse.x / width);
                            }
                            onWheel: wheel => vol.setSourceVolume(vol.srcLevel + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
                        }
                    }
                }

                Text {
                    text: "Input"
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }

                Repeater {
                    model: vol.sources

                    delegate: Rectangle {
                        required property var modelData

                        readonly property bool current: Pipewire.defaultAudioSource === modelData

                        width: popupCol.width
                        height: 30
                        radius: 8
                        color: inMouse.containsMouse ? Theme.hover : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 30
                            anchors.verticalCenter: parent.verticalCenter
                            text: vol.sourceLabel(modelData)
                            color: current ? Theme.accent : Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            elide: Text.ElideRight
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            visible: current
                            font.family: Theme.iconFont
                            font.pixelSize: 12
                            text: "\u{f012c}" // 󰄬 check
                            color: Theme.accent
                        }

                        MouseArea {
                            id: inMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Pipewire.preferredDefaultAudioSource = modelData
                        }
                    }
                }
            }
        }
    }
}
