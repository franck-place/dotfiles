import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// Now-playing icon + truncated "Artist -- Title". Click opens a popup with
// album art, track info, a click-to-seek progress bar, and prev/play-
// pause/next controls. Zero-width (nothing shown at all) when there's no
// MPRIS player, same convention as the systray Repeater in Bar.qml.
Item {
    id: media

    required property var bar

    readonly property var players: Mpris.players ? Mpris.players.values : []
    readonly property var activePlayer: {
        for (const p of media.players)
            if (p.playbackState === MprisPlaybackState.Playing)
                return p;
        return media.players.length > 0 ? media.players[0] : null;
    }
    readonly property bool playing: media.activePlayer !== null && media.activePlayer.playbackState === MprisPlaybackState.Playing

    property real currentPosition: 0
    onActivePlayerChanged: media.currentPosition = media.activePlayer ? media.activePlayer.position : 0

    visible: media.activePlayer !== null
    width: media.visible ? rowLayout.implicitWidth + 12 : 0
    height: 22

    // keeps the seek bar live while the popup's open and something's
    // actually playing; idle otherwise so it's not polling for nothing
    Timer {
        interval: 1000
        running: popup.visible && media.playing
        repeat: true
        onTriggered: {
            if (media.activePlayer)
                media.currentPosition = media.activePlayer.position;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: mediaMouse.containsMouse ? Theme.hover : "transparent"

        Row {
            id: rowLayout
            anchors.centerIn: parent
            spacing: 5

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconSize
                color: media.playing ? Theme.accent : Theme.fgDim
                text: "\u{f075a}" // 󰝚 music note
            }

            // clipped viewport, ticker-style: when the title doesn't fit, a
            // second copy of the text sits right after the first (offset by
            // titleClip.gap) and the whole row scrolls left forever. Once
            // it's scrolled exactly one copy-width + gap, copy #2 is sitting
            // exactly where copy #1 started -- so the loop restart (jumping
            // back to x:0) is visually seamless instead of a snap-back.
            Item {
                id: titleClip
                anchors.verticalCenter: parent.verticalCenter
                readonly property real gap: 30
                readonly property bool overflowing: titleText1.implicitWidth > 180
                width: Math.min(titleText1.implicitWidth, 180)
                height: titleText1.implicitHeight
                clip: true

                Row {
                    id: titleRow
                    spacing: titleClip.gap

                    Text {
                        id: titleText1
                        text: media.activePlayer
                              ? (media.activePlayer.trackArtist ? media.activePlayer.trackArtist + " — " + media.activePlayer.trackTitle : media.activePlayer.trackTitle)
                              : ""
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Text {
                        visible: titleClip.overflowing
                        text: titleText1.text
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    NumberAnimation on x {
                        id: marquee
                        running: titleClip.overflowing
                        from: 0
                        to: -(titleText1.implicitWidth + titleClip.gap)
                        duration: Math.max(3000, titleText1.implicitWidth * 45)
                        loops: Animation.Infinite
                        easing.type: Easing.Linear
                        onRunningChanged: if (!running)
                                              titleRow.x = 0
                    }
                }
            }
        }

        MouseArea {
            id: mediaMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                if (popup.visible) {
                    popup.visible = false;
                    return;
                }
                const p = media.mapToItem(null, 0, 0);
                popup.anchor.rect.x = Math.max(8, p.x + media.width - popup.implicitWidth);
                popup.anchor.rect.y = Theme.barHeight;
                PopupGuard.claim(popup);
                popup.visible = true;
            }
        }
    }

    PopupWindow {
        id: popup

        anchor.window: media.bar
        implicitWidth: 300
        implicitHeight: popupBox.implicitHeight
        visible: false
        color: "transparent"

        HoverHandler {
            id: popupHover
        }

        Timer {
            interval: 5000
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
                spacing: 10

                Item {
                    width: parent.width
                    height: 90

                    Rectangle {
                        id: artBox
                        width: 90
                        height: 90
                        radius: 10
                        color: Theme.hover
                        clip: true

                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            source: media.activePlayer && media.activePlayer.trackArtUrl ? media.activePlayer.trackArtUrl : ""
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !media.activePlayer || !media.activePlayer.trackArtUrl
                            font.family: Theme.iconFont
                            font.pixelSize: 28
                            color: Theme.fgDim
                            text: "\u{f075a}"
                        }
                    }

                    Column {
                        anchors.left: artBox.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: media.activePlayer ? media.activePlayer.trackTitle : "Nothing playing"
                            color: Theme.fgSel
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.bold: true
                        }

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            visible: media.activePlayer && !!media.activePlayer.trackArtist
                            text: media.activePlayer ? media.activePlayer.trackArtist : ""
                            color: Theme.fgDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            visible: media.activePlayer && !!media.activePlayer.trackAlbum
                            text: media.activePlayer ? media.activePlayer.trackAlbum : ""
                            color: Theme.fgDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 20
                    visible: media.activePlayer && media.activePlayer.length > 0

                    Rectangle {
                        id: seekTrack
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Theme.hover

                        Rectangle {
                            width: media.activePlayer && media.activePlayer.length > 0
                                   ? parent.width * Math.min(1, media.currentPosition / media.activePlayer.length)
                                   : 0
                            height: parent.height
                            radius: 2
                            color: Theme.accent
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: media.activePlayer && media.activePlayer.canSeek
                        onClicked: mouse => {
                            if (media.activePlayer && media.activePlayer.canSeek && media.activePlayer.length > 0) {
                                const pos = (mouse.x / width) * media.activePlayer.length;
                                media.activePlayer.position = pos;
                                media.currentPosition = pos;
                            }
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 22

                    Text {
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.iconSize
                        color: media.activePlayer && media.activePlayer.canGoPrevious ? Theme.fg : Theme.fgDim
                        text: "\u{f04ae}" // 󰒮 previous

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            enabled: media.activePlayer && media.activePlayer.canGoPrevious
                            onClicked: media.activePlayer.previous()
                        }
                    }

                    Text {
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.iconSize + 2
                        color: Theme.fg
                        text: media.playing ? "\u{f03e4}" : "\u{f040a}" // 󰏤 pause / 󰐊 play

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            enabled: media.activePlayer && (media.playing ? media.activePlayer.canPause : media.activePlayer.canPlay)
                            onClicked: media.playing ? media.activePlayer.pause() : media.activePlayer.play()
                        }
                    }

                    Text {
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.iconSize
                        color: media.activePlayer && media.activePlayer.canGoNext ? Theme.fg : Theme.fgDim
                        text: "\u{f04ad}" // 󰒭 next

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            enabled: media.activePlayer && media.activePlayer.canGoNext
                            onClicked: media.activePlayer.next()
                        }
                    }
                }
            }
        }
    }
}
