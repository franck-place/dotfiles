import Quickshell
import Quickshell.Io
import QtQuick

// Application launcher, replacing dmenu. Toggled from dwm's keybind via:
//   qs -p ~/.config/quickshell/dwmbar ipc call launcher toggle
PanelWindow {
    id: root

    readonly property int searchBarHeight: 58
    readonly property int rowHeight: 44
    readonly property int maxResults: 8

    property var results: []
    property int selectedIndex: 0

    visible: false
    focusable: true
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // dwm maps dock windows unmanaged and never focuses them, so grab X input
    // focus ourselves once the window is mapped, and restore the previously
    // focused window on hide (dwm won't notice our unmap either).
    // quickshell windows set only _NET_WM_NAME (xdotool search --name reads
    // WM_NAME, which is empty), so find our windows by pid; the launcher is
    // the only one between 500 and 1000px wide (the bar is full-width, popups
    // are ~300-380px).
    readonly property string grabFocusCmd:
        "rd=${XDG_RUNTIME_DIR:-/tmp}; " +
        "xdotool getwindowfocus > \"$rd/qs-launcher-prevfocus\" 2>/dev/null; " +
        "qpid=$(pgrep -o -x qs); " +
        "for i in $(seq 40); do " +
        "for id in $(xdotool search --onlyvisible --pid \"$qpid\" 2>/dev/null); do " +
        "eval \"$(xdotool getwindowgeometry --shell \"$id\")\"; " +
        "if [ \"$WIDTH\" -gt 500 ] && [ \"$WIDTH\" -lt 1000 ]; then " +
        "xdotool windowfocus \"$id\"; exit 0; fi; " +
        "done; sleep 0.05; done"

    readonly property string restoreFocusCmd:
        "rd=${XDG_RUNTIME_DIR:-/tmp}; " +
        "[ -f \"$rd/qs-launcher-prevfocus\" ] && " +
        "xdotool windowfocus \"$(cat \"$rd/qs-launcher-prevfocus\")\" 2>/dev/null"

    onVisibleChanged: {
        if (visible) {
            queryField.forceActiveFocus();
            Quickshell.execDetached(["sh", "-c", grabFocusCmd]);
        } else {
            Quickshell.execDetached(["sh", "-c", restoreFocusCmd]);
        }
    }

    anchors.top: true
    margins.top: Math.round(screen.height * 0.22)

    implicitWidth: 620
    implicitHeight: searchBarHeight
        + (results.length > 0 ? results.length * rowHeight + 14 : 0)

    // dwm's focused monitor, mapped to the matching quickshell screen.
    // Resolved at show time so the launcher opens where the user is working.
    function focusedScreen() {
        const mons = DwmState.monitors;
        for (let i = 0; i < mons.length; i++) {
            if (!mons[i].selected)
                continue;
            const screens = Quickshell.screens;
            for (let j = 0; j < screens.length; j++) {
                if (screens[j].x === mons[i].x && screens[j].y === mons[i].y)
                    return screens[j];
            }
        }
        return Quickshell.screens[0];
    }

    function setShown(shown) {
        if (shown) {
            screen = focusedScreen();
            queryField.text = "";
            results = [];
            selectedIndex = 0;
            visible = true;
            queryField.forceActiveFocus();
        } else {
            visible = false;
        }
    }

    function refilter() {
        const q = queryField.text.trim().toLowerCase();
        if (q.length === 0) {
            results = [];
            selectedIndex = 0;
            return;
        }
        const scored = [];
        const apps = DesktopEntries.applications.values;
        for (let i = 0; i < apps.length; i++) {
            const app = apps[i];
            if (app.noDisplay)
                continue;
            const name = app.name.toLowerCase();
            let s = 0;
            if (name.startsWith(q))
                s = 100;
            else if (name.split(/\s+/).some(w => w.startsWith(q)))
                s = 80;
            else if (name.includes(q))
                s = 60;
            else if ((app.genericName || "").toLowerCase().includes(q))
                s = 40;
            else if ((app.keywords || []).some(k => k.toLowerCase().startsWith(q)))
                s = 30;
            else if ((app.comment || "").toLowerCase().includes(q))
                s = 10;
            if (s > 0)
                scored.push({ app: app, s: s });
        }
        scored.sort((a, b) => b.s - a.s || a.app.name.localeCompare(b.app.name));
        results = scored.slice(0, maxResults).map(e => e.app);
        selectedIndex = 0;
    }

    function launch() {
        if (results.length === 0)
            return;
        const app = results[Math.min(selectedIndex, results.length - 1)];
        setShown(false);
        app.execute();
    }

    IpcHandler {
        target: "launcher"

        function toggle() {
            root.setShown(!root.visible);
        }

        function show() {
            root.setShown(true);
        }

        function hide() {
            root.setShown(false);
        }
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: 14
        color: Theme.popupBg
        border.color: Theme.popupBorder
        border.width: 1

        // Search bar
        Item {
            id: searchBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.searchBarHeight

            Text {
                id: searchIcon
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 18
                text: "\u{f0349}" // 󰍉 magnify
                color: Theme.fgDim
                font.family: Theme.iconFont
                font.pixelSize: 22
            }

            TextInput {
                id: queryField
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: searchIcon.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 18
                font.family: Theme.fontFamily
                font.pixelSize: 20
                color: Theme.fgSel
                selectionColor: Theme.accent
                clip: true

                onTextChanged: root.refilter()

                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Escape:
                        root.setShown(false);
                        event.accepted = true;
                        break;
                    case Qt.Key_Down:
                        if (root.selectedIndex < root.results.length - 1)
                            root.selectedIndex++;
                        event.accepted = true;
                        break;
                    case Qt.Key_Up:
                        if (root.selectedIndex > 0)
                            root.selectedIndex--;
                        event.accepted = true;
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        root.launch();
                        event.accepted = true;
                        break;
                    }
                }

                Text {
                    visible: queryField.text.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Search apps..."
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 20
                }
            }
        }

        Rectangle {
            id: separator
            visible: root.results.length > 0
            anchors.top: searchBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            height: 1
            color: Theme.popupBorder
        }

        // Results
        Column {
            visible: root.results.length > 0
            anchors.top: separator.bottom
            anchors.topMargin: 6
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 8
            anchors.rightMargin: 8

            Repeater {
                model: root.results

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: parent.width
                    height: root.rowHeight
                    radius: 9
                    color: index === root.selectedIndex ? Theme.accent : "transparent"

                    Image {
                        id: appIcon
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        width: 28
                        height: 28
                        sourceSize.width: 28
                        sourceSize.height: 28
                        asynchronous: true
                        source: {
                            const p = Quickshell.iconPath(modelData.icon, true);
                            return p !== "" ? p : Quickshell.iconPath("application-x-executable", true);
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: appIcon.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 10

                        Text {
                            width: parent.width
                            text: modelData.name
                            color: index === root.selectedIndex ? Theme.fgSel : Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            visible: (modelData.genericName || "") !== ""
                                && modelData.genericName !== modelData.name
                            text: modelData.genericName || ""
                            color: index === root.selectedIndex ? Theme.fgSel : Theme.fgDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.selectedIndex = index
                        onClicked: root.launch()
                    }
                }
            }
        }
    }
}
