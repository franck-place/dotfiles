import Quickshell
import Quickshell.Io
import QtQuick

// Screen-centered settings window, opened by clicking the Geeko icon in the
// bar (SettingsMenu.qml) or via `qs ipc -p ~/.config/quickshell/dwmbar call
// settings toggle`. A hub screen with category rows drills into one
// category at a time. Network/mouse/display/theme live-apply through the
// usual command-line tools (nmcli/xrandr/xset/xinput/gsettings) rather than
// any dedicated service -- there's no bluetooth section since nothing's
// installed to back one, and network is status/toggle only (no wifi
// network picker).
PanelWindow {
    id: root

    visible: false
    focusable: true
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    property string currentView: "main"   // main | network | notifications | display | mouse | theme
    readonly property var viewTitles: ({
        network: "Network",
        notifications: "Notifications",
        display: "Display",
        mouse: "Mouse",
        theme: "Theme"
    })

    // same rationale as Launcher.qml: dwm never focuses dock windows, so grab
    // X input focus ourselves once mapped, and restore it on hide. This is
    // the only floating window in this width band.
    readonly property string grabFocusCmd:
        "rd=${XDG_RUNTIME_DIR:-/tmp}; " +
        "xdotool getwindowfocus > \"$rd/qs-settings-prevfocus\" 2>/dev/null; " +
        "qpid=$(pgrep -o -x qs); " +
        "for i in $(seq 40); do " +
        "for id in $(xdotool search --onlyvisible --pid \"$qpid\" 2>/dev/null); do " +
        "eval \"$(xdotool getwindowgeometry --shell \"$id\")\"; " +
        "if [ \"$WIDTH\" -gt 420 ] && [ \"$WIDTH\" -lt 600 ]; then " +
        "xdotool windowfocus \"$id\"; exit 0; fi; " +
        "done; sleep 0.05; done"

    readonly property string restoreFocusCmd:
        "rd=${XDG_RUNTIME_DIR:-/tmp}; " +
        "[ -f \"$rd/qs-settings-prevfocus\" ] && " +
        "xdotool windowfocus \"$(cat \"$rd/qs-settings-prevfocus\")\" 2>/dev/null"

    onVisibleChanged: {
        if (visible) {
            root.currentView = "main";
            refreshAll();
            Quickshell.execDetached(["sh", "-c", grabFocusCmd]);
        } else {
            Quickshell.execDetached(["sh", "-c", restoreFocusCmd]);
        }
    }

    anchors.top: true
    margins.top: Math.round((screen.height - implicitHeight) / 2)

    implicitWidth: 460
    implicitHeight: Math.min(screen.height * 0.85, col.implicitHeight + 28)

    function setShown(shown) {
        visible = shown;
    }

    function refreshAll() {
        pollNetwork();
        refreshAbout();
        uptimeFile.reload();
        refreshDisplay();
        refreshMouse();
        refreshTheme();
    }

    IpcHandler {
        target: "settings"

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

    // ==================== network ====================

    property string wifiRadio: "enabled"       // "enabled" | "disabled"
    property string wifiState: "disconnected"
    property string wifiConn: ""
    property string ethState: "disconnected"
    property string ethDevice: ""

    function pollNetwork() {
        radioProc.running = true;
        deviceProc.running = true;
    }

    Process {
        id: radioProc
        command: ["nmcli", "-t", "-f", "WIFI", "radio"]
        stdout: StdioCollector {
            onStreamFinished: root.wifiRadio = text.trim()
        }
    }

    Process {
        id: deviceProc
        command: ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION,DEVICE", "device"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                let wifiFound = false, ethFound = false;
                for (const line of lines) {
                    const parts = line.split(":");
                    if (parts.length < 4)
                        continue;
                    const type = parts[0], state = parts[1], conn = parts[2];
                    if (type === "wifi" && !wifiFound) {
                        wifiFound = true;
                        root.wifiState = state;
                        root.wifiConn = state === "connected" ? conn : "";
                    } else if (type === "ethernet" && !ethFound) {
                        ethFound = true;
                        root.ethState = state;
                        root.ethDevice = parts[3];
                    }
                }
            }
        }
    }

    function setWifiRadio(on) {
        Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"]);
        root.wifiRadio = on ? "enabled" : "disabled";
        pollDelay.restart();
    }

    Timer {
        id: pollDelay
        interval: 800
        onTriggered: root.pollNetwork()
    }

    Timer {
        interval: 5000
        running: root.visible
        repeat: true
        onTriggered: root.pollNetwork()
    }

    // ==================== display ====================

    readonly property real brightnessMin: 0.3
    readonly property real brightnessMax: 1.5

    property string displayOutput: ""
    property var displayResolutions: []   // ["3440x1440", "2560x1440", ...]
    property var displayRatesByRes: ({})  // { "3440x1440": [{rate, current}, ...] }
    property string selectedRes: ""
    property string selectedRate: ""
    property real brightness: 1.0

    readonly property var currentRateItems: {
        const rates = root.displayRatesByRes[root.selectedRes] || [];
        return rates.map(r => Math.round(parseFloat(r.rate)) + " Hz");
    }

    function rateLabelToRaw(label) {
        const rates = root.displayRatesByRes[root.selectedRes] || [];
        for (const r of rates) {
            if (Math.round(parseFloat(r.rate)) + " Hz" === label)
                return r.rate;
        }
        return root.selectedRate;
    }

    function refreshDisplay() {
        modesProc.running = true;
    }

    Process {
        id: modesProc
        command: ["xrandr", "--query"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                let output = "";
                const resList = [];
                const ratesByRes = {};
                let inBlock = false;
                let curRes = "", curRate = "";
                for (const line of lines) {
                    const head = line.match(/^(\S+) connected/);
                    if (head) {
                        if (inBlock)
                            break;
                        output = head[1];
                        inBlock = true;
                        continue;
                    }
                    if (!inBlock)
                        continue;
                    if (!/^\s+\d+x\d+/.test(line))
                        break;
                    const resMatch = line.match(/^\s*(\d+x\d+)/);
                    if (!resMatch)
                        continue;
                    const res = resMatch[1];
                    resList.push(res);
                    const rates = [];
                    const rateRe = /(\d+\.\d+)(\*)?(\+)?/g;
                    let m;
                    while ((m = rateRe.exec(line)) !== null) {
                        const isCurrent = m[2] === "*";
                        rates.push({ rate: m[1], current: isCurrent });
                        if (isCurrent) { curRes = res; curRate = m[1]; }
                    }
                    ratesByRes[res] = rates;
                }
                root.displayOutput = output;
                root.displayResolutions = resList;
                root.displayRatesByRes = ratesByRes;
                if (!root.selectedRes || !ratesByRes[root.selectedRes])
                    root.selectedRes = curRes || (resList.length ? resList[0] : "");
                const rates = ratesByRes[root.selectedRes] || [];
                const best = rates.find(r => r.current) || rates[0];
                root.selectedRate = curRate || (best ? best.rate : "");
            }
        }
    }

    function applyMode(res, rate) {
        if (!root.displayOutput || !rate)
            return;
        Quickshell.execDetached(["xrandr", "--output", root.displayOutput, "--mode", res, "--rate", rate]);
        modeRefreshDelay.restart();
    }

    function pickResolution(res) {
        root.selectedRes = res;
        const rates = root.displayRatesByRes[res] || [];
        const best = rates.find(r => r.current) || rates[0];
        root.selectedRate = best ? best.rate : "";
        if (best)
            root.applyMode(res, best.rate);
    }

    function pickRate(label) {
        const rate = root.rateLabelToRaw(label);
        root.selectedRate = rate;
        root.applyMode(root.selectedRes, rate);
    }

    Timer {
        id: modeRefreshDelay
        interval: 600
        onTriggered: root.refreshDisplay()
    }

    function setBrightness(v) {
        root.brightness = Math.max(root.brightnessMin, Math.min(root.brightnessMax, v));
        if (root.displayOutput)
            Quickshell.execDetached(["xrandr", "--output", root.displayOutput, "--brightness", root.brightness.toFixed(2)]);
    }

    // ==================== mouse ====================

    readonly property int accelMin: 1
    readonly property int accelMax: 5
    property int accelSpeed: 2
    property bool naturalScroll: false

    function refreshMouse() {
        xsetProc.running = true;
        scrollProc.running = true;
    }

    Process {
        id: xsetProc
        command: ["xset", "q"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/acceleration:\s*(\d+)\/(\d+)/);
                if (m)
                    root.accelSpeed = Math.max(root.accelMin, Math.min(root.accelMax, Math.round(parseInt(m[1]) / parseInt(m[2]))));
            }
        }
    }

    Process {
        id: scrollProc
        command: ["sh", "-c", "xinput list | grep -i 'slave  pointer' | grep -oE 'id=[0-9]+' | cut -d= -f2 | while read -r id; do xinput list-props \"$id\" 2>/dev/null | grep -m1 'Natural Scrolling Enabled ('; done | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/:\s*(\d)/);
                if (m)
                    root.naturalScroll = m[1] === "1";
            }
        }
    }

    function setAccelSpeed(v) {
        root.accelSpeed = Math.max(root.accelMin, Math.min(root.accelMax, v));
        Quickshell.execDetached(["xset", "m", String(root.accelSpeed), "4"]);
    }

    function setNaturalScroll(on) {
        root.naturalScroll = on;
        const script =
            "xinput list | grep -i 'slave  pointer' | grep -oE 'id=[0-9]+' | cut -d= -f2 | " +
            "while read -r id; do xinput set-prop \"$id\" 'libinput Natural Scrolling Enabled' " + (on ? "1" : "0") + " 2>/dev/null; done";
        Quickshell.execDetached(["sh", "-c", script]);
    }

    // ==================== theme ====================

    readonly property string gtkSettingsPath: Quickshell.env("HOME") + "/.config/gtk-3.0/settings.ini"

    property var gtkThemes: []
    property var iconThemes: []
    property var cursorThemes: []
    property string currentGtkTheme: ""
    property string currentIconTheme: ""
    property string currentCursorTheme: ""

    function refreshTheme() {
        gtkThemeListProc.running = true;
        iconThemeListProc.running = true;
        cursorThemeListProc.running = true;
        currentThemeProc.running = true;
    }

    Process {
        id: gtkThemeListProc
        command: ["sh", "-c", "for d in /usr/share/themes/*/ ~/.local/share/themes/*/ ~/.themes/*/; do [ -d \"${d}gtk-3.0\" ] && basename \"$d\"; done 2>/dev/null | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: root.gtkThemes = text.trim().split("\n").filter(s => s !== "")
        }
    }

    Process {
        id: iconThemeListProc
        command: ["sh", "-c", "for d in /usr/share/icons/*/ ~/.local/share/icons/*/ ~/.icons/*/; do [ -f \"${d}index.theme\" ] && basename \"$d\"; done 2>/dev/null | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: root.iconThemes = text.trim().split("\n").filter(s => s !== "")
        }
    }

    Process {
        id: cursorThemeListProc
        command: ["sh", "-c", "for d in /usr/share/icons/*/ ~/.local/share/icons/*/ ~/.icons/*/; do [ -d \"${d}cursors\" ] && basename \"$d\"; done 2>/dev/null | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: root.cursorThemes = text.trim().split("\n").filter(s => s !== "")
        }
    }

    Process {
        id: currentThemeProc
        command: ["sh", "-c", "gsettings get org.gnome.desktop.interface gtk-theme; gsettings get org.gnome.desktop.interface icon-theme; gsettings get org.gnome.desktop.interface cursor-theme"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").map(s => s.replace(/^'|'$/g, ""));
                root.currentGtkTheme = lines[0] || "";
                root.currentIconTheme = lines[1] || "";
                root.currentCursorTheme = lines[2] || "";
            }
        }
    }

    function setGtkTheme(name) {
        root.currentGtkTheme = name;
        applyTheme("gtk-theme", "gtk-theme-name", name);
    }

    function setIconTheme(name) {
        root.currentIconTheme = name;
        applyTheme("icon-theme", "gtk-icon-theme-name", name);
    }

    function setCursorTheme(name) {
        root.currentCursorTheme = name;
        applyTheme("cursor-theme", "gtk-cursor-theme-name", name);
    }

    function applyTheme(gsettingsKey, iniKey, value) {
        const script =
            "gsettings set org.gnome.desktop.interface " + gsettingsKey + " '" + value + "'; " +
            "f='" + root.gtkSettingsPath + "'; " +
            "mkdir -p \"$(dirname \"$f\")\"; touch \"$f\"; " +
            "if grep -q '^" + iniKey + "=' \"$f\"; then " +
            "sed -i 's|^" + iniKey + "=.*|" + iniKey + "=" + value + "|' \"$f\"; " +
            "else printf '%s\\n' \"" + iniKey + "=" + value + "\" >> \"$f\"; fi";
        Quickshell.execDetached(["sh", "-c", script]);
    }

    // ==================== about ====================

    property string hostName: ""
    property string kernelVer: ""
    property string prettyName: "openSUSE Tumbleweed"
    property string uptimeStr: ""

    function refreshAbout() {
        aboutProc.running = true;
    }

    Process {
        id: aboutProc
        command: ["sh", "-c", "uname -n; uname -r"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                root.hostName = lines[0] || "";
                root.kernelVer = lines[1] || "";
            }
        }
    }

    FileView {
        id: osRelease
        path: "/etc/os-release"
        onLoaded: {
            const m = text().match(/^PRETTY_NAME="?([^"\n]*)"?/m);
            if (m)
                root.prettyName = m[1];
        }
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        watchChanges: false
        onLoaded: root.updateUptime()
    }

    function updateUptime() {
        const secs = parseFloat(uptimeFile.text().trim().split(" ")[0]);
        if (isNaN(secs))
            return;
        const d = Math.floor(secs / 86400);
        const h = Math.floor((secs % 86400) / 3600);
        const m = Math.floor((secs % 3600) / 60);
        const parts = [];
        if (d > 0) parts.push(d + "d");
        if (h > 0 || d > 0) parts.push(h + "h");
        parts.push(m + "m");
        root.uptimeStr = parts.join(" ");
    }

    Timer {
        interval: 60000
        running: root.visible
        repeat: true
        onTriggered: { uptimeFile.reload(); root.refreshAbout(); }
    }

    // ==================== shared inline components ====================

    component ToggleSwitch: Rectangle {
        id: sw
        property bool checked: false
        signal toggled()

        width: 34
        height: 18
        radius: 9
        color: checked ? Theme.accent : Theme.hover
        border.color: Theme.popupBorder
        border.width: 1

        Rectangle {
            width: 14
            height: 14
            radius: 7
            color: Theme.fgSel
            anchors.verticalCenter: parent.verticalCenter
            x: sw.checked ? sw.width - width - 2 : 2
            Behavior on x { NumberAnimation { duration: 120 } }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: sw.toggled()
        }
    }

    component SectionLabel: Text {
        color: Theme.fgDim
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.bold: true
    }

    component Divider: Rectangle {
        width: parent ? parent.width : 0
        height: 1
        color: Theme.popupBorder
    }

    // one row on the hub screen; drills into a sub-view on click
    component CategoryRow: Rectangle {
        id: catRow
        property string iconGlyph: ""
        property string label: ""
        property string subtitle: ""
        signal clicked()

        width: parent ? parent.width : 0
        height: 46
        radius: 8
        color: catMouse.containsMouse ? Theme.hover : "transparent"

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.iconFont
                font.pixelSize: 19
                color: Theme.fg
                text: catRow.iconGlyph
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: catRow.label
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                Text {
                    visible: catRow.subtitle !== ""
                    text: catRow.subtitle
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            font.family: Theme.iconFont
            font.pixelSize: 14
            color: Theme.fgDim
            text: "\u{f0142}" // chevron right
        }

        MouseArea {
            id: catMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: catRow.clicked()
        }
    }

    // click-to-expand-in-place picker; a plain string list, current one
    // accented, used for resolution/rate/theme pickers
    component Dropdown: Item {
        id: dd
        property var items: []
        property string current: ""
        property bool expanded: false
        signal picked(string name)

        width: parent ? parent.width : 0
        height: ddButton.height + (expanded ? listCol.implicitHeight + 6 : 0)
        clip: true

        Rectangle {
            id: ddButton
            width: parent.width
            height: 32
            radius: 8
            color: ddMouse.containsMouse ? Theme.hover : Theme.barBg
            border.color: Theme.popupBorder
            border.width: 1

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.right: chevron.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: dd.current || "—"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                elide: Text.ElideRight
            }

            Text {
                id: chevron
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.iconFont
                font.pixelSize: 13
                color: Theme.fgDim
                text: dd.expanded ? "\u{f0143}" : "\u{f0140}"
            }

            MouseArea {
                id: ddMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: dd.expanded = !dd.expanded
            }
        }

        Column {
            id: listCol
            anchors.top: ddButton.bottom
            anchors.topMargin: 6
            width: parent.width

            Repeater {
                model: dd.items

                delegate: Rectangle {
                    id: optItem
                    required property string modelData

                    width: dd.width
                    height: 28
                    radius: 6
                    color: optItem.modelData === dd.current ? Theme.accent
                         : optMouse.containsMouse ? Theme.hover : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: optItem.modelData
                        color: optItem.modelData === dd.current ? Theme.fgSel : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    MouseArea {
                        id: optMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            dd.picked(optItem.modelData);
                            dd.expanded = false;
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: 14
        color: Theme.popupBg
        border.color: Theme.popupBorder
        border.width: 1
        clip: true

        // dismiss on outside click: root grabbed X focus on open (see
        // grabFocusCmd above), so clicking anywhere else -- another window,
        // or the desktop -- moves X focus away and fires this.
        Window.onActiveChanged: {
            if (!Window.active && root.visible)
                root.setShown(false);
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: 14
            contentWidth: width
            contentHeight: col.implicitHeight
            clip: true

            Column {
                id: col
                width: parent.width
                spacing: 10

                // ---- header: title, or back + sub-view name ----
                Row {
                    width: parent.width
                    height: 28
                    spacing: 10
                    visible: root.currentView !== "main"

                    Rectangle {
                        width: 28
                        height: 28
                        radius: 8
                        color: backMouse.containsMouse ? Theme.hover : "transparent"

                        Text {
                            anchors.centerIn: parent
                            font.family: Theme.iconFont
                            font.pixelSize: 15
                            color: Theme.fg
                            text: "\u{f004d}"
                        }

                        MouseArea {
                            id: backMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.currentView = "main"
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.viewTitles[root.currentView] || ""
                        color: Theme.fgSel
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        font.bold: true
                    }
                }

                Text {
                    visible: root.currentView === "main"
                    text: "Settings"
                    color: Theme.fgSel
                    font.family: Theme.fontFamily
                    font.pixelSize: 17
                    font.bold: true
                }

                // ==================== main hub ====================
                Column {
                    width: parent.width
                    spacing: 2
                    visible: root.currentView === "main"

                    CategoryRow {
                        iconGlyph: root.wifiRadio === "enabled" ? "\u{f05a9}" : "\u{f05aa}"
                        label: "Network"
                        subtitle: (root.wifiRadio === "enabled" ? (root.wifiConn || "Wi-Fi on") : "Wi-Fi off")
                            + " · " + (root.ethState === "connected" ? "Ethernet connected" : "Ethernet disconnected")
                        onClicked: root.currentView = "network"
                    }

                    CategoryRow {
                        iconGlyph: NotificationStore.dndEnabled ? "\u{f009b}" : "\u{f009a}"
                        label: "Notifications"
                        subtitle: NotificationStore.dndEnabled ? "Do Not Disturb" : "On"
                        onClicked: root.currentView = "notifications"
                    }

                    CategoryRow {
                        iconGlyph: "\u{f0379}"
                        label: "Display"
                        subtitle: root.selectedRes ? (root.selectedRes + " @ " + Math.round(parseFloat(root.selectedRate)) + "Hz") : "—"
                        onClicked: root.currentView = "display"
                    }

                    CategoryRow {
                        iconGlyph: "\u{f037d}"
                        label: "Mouse"
                        subtitle: "Speed " + root.accelSpeed + "/" + root.accelMax + (root.naturalScroll ? " · Natural scroll" : "")
                        onClicked: root.currentView = "mouse"
                    }

                    CategoryRow {
                        iconGlyph: "\u{f03d8}"
                        label: "Theme"
                        subtitle: root.currentGtkTheme || "—"
                        onClicked: root.currentView = "theme"
                    }
                }

                Divider { visible: root.currentView === "main" }

                Row {
                    width: parent.width
                    height: 40
                    spacing: 10
                    visible: root.currentView === "main"

                    Rectangle {
                        width: (parent.width - 10) / 2
                        height: parent.height
                        radius: 8
                        color: wallMouse.containsMouse ? Theme.hover : Theme.barBg
                        border.color: Theme.popupBorder
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                font.family: Theme.iconFont
                                font.pixelSize: 15
                                color: Theme.fg
                                text: "\u{f0e09}"
                            }
                            Text {
                                text: "Wallpaper"
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                        }

                        MouseArea {
                            id: wallMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.setShown(false);
                                Quickshell.execDetached(["qs", "ipc", "-p", Quickshell.env("HOME") + "/.config/quickshell/dwmbar", "call", "wallpaper", "toggle"]);
                            }
                        }
                    }

                    Rectangle {
                        width: (parent.width - 10) / 2
                        height: parent.height
                        radius: 8
                        color: powMouse.containsMouse ? Theme.hover : Theme.barBg
                        border.color: Theme.popupBorder
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                font.pixelSize: 15
                                color: Theme.fg
                                text: "⏻"
                            }
                            Text {
                                text: "Power"
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                        }

                        MouseArea {
                            id: powMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.setShown(false);
                                Quickshell.execDetached(["qs", "ipc", "-p", Quickshell.env("HOME") + "/.config/quickshell/dwmbar", "call", "power", "toggle"]);
                            }
                        }
                    }
                }

                Divider { visible: root.currentView === "main" }

                Row {
                    width: parent.width
                    spacing: 12
                    visible: root.currentView === "main"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: Theme.iconFont
                        font.pixelSize: 32
                        color: "#73ba25"
                        text: "\u{f314}"
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            text: root.prettyName
                            color: Theme.fgSel
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                        }
                        Text {
                            text: (root.hostName || "?") + " · " + (root.kernelVer || "?")
                            color: Theme.fgDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }
                        Text {
                            text: "Up " + (root.uptimeStr || "?")
                            color: Theme.fgDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }
                    }
                }

                // ==================== network sub-view ====================
                Column {
                    width: parent.width
                    spacing: 10
                    visible: root.currentView === "network"

                    Row {
                        width: parent.width
                        height: 34
                        spacing: 10

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: Theme.iconFont
                            font.pixelSize: 18
                            color: root.wifiRadio === "enabled" ? Theme.fg : Theme.fgDim
                            text: root.wifiRadio === "enabled" ? "\u{f05a9}" : "\u{f05aa}"
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 34 - 44
                            spacing: 0

                            Text {
                                text: "Wi-Fi"
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                            Text {
                                text: root.wifiRadio !== "enabled" ? "Off"
                                    : root.wifiConn !== "" ? root.wifiConn
                                    : "Disconnected"
                                color: Theme.fgDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        ToggleSwitch {
                            anchors.verticalCenter: parent.verticalCenter
                            checked: root.wifiRadio === "enabled"
                            onToggled: root.setWifiRadio(!checked)
                        }
                    }

                    Row {
                        width: parent.width
                        height: 34
                        spacing: 10

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: Theme.iconFont
                            font.pixelSize: 18
                            color: root.ethState === "connected" ? Theme.fg : Theme.fgDim
                            text: "\u{f0200}"
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 34
                            spacing: 0

                            Text {
                                text: "Ethernet"
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                            Text {
                                text: root.ethState === "connected"
                                    ? "Connected" + (root.ethDevice ? " (" + root.ethDevice + ")" : "")
                                    : "Disconnected"
                                color: Theme.fgDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }
                        }
                    }
                }

                // ==================== notifications sub-view ====================
                Column {
                    width: parent.width
                    spacing: 10
                    visible: root.currentView === "notifications"

                    Row {
                        width: parent.width
                        height: 34
                        spacing: 10

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: Theme.iconFont
                            font.pixelSize: 18
                            color: NotificationStore.dndEnabled ? Theme.accent : Theme.fg
                            text: "\u{f009b}"
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 34 - 44
                            text: "Do Not Disturb"
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }

                        ToggleSwitch {
                            anchors.verticalCenter: parent.verticalCenter
                            checked: NotificationStore.dndEnabled
                            onToggled: NotificationStore.dndEnabled = !checked
                        }
                    }
                }

                // ==================== display sub-view ====================
                Column {
                    width: parent.width
                    spacing: 10
                    visible: root.currentView === "display"

                    Text {
                        text: root.displayOutput || "No display detected"
                        color: Theme.fgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    SectionLabel { text: "RESOLUTION" }
                    Dropdown {
                        items: root.displayResolutions
                        current: root.selectedRes
                        onPicked: name => root.pickResolution(name)
                    }

                    SectionLabel { text: "REFRESH RATE" }
                    Dropdown {
                        items: root.currentRateItems
                        current: root.selectedRate ? Math.round(parseFloat(root.selectedRate)) + " Hz" : ""
                        onPicked: name => root.pickRate(name)
                    }

                    Row {
                        width: parent.width
                        height: 24
                        spacing: 10

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Brightness"
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            width: 90
                        }

                        Item {
                            width: parent.width - 100
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                id: brTrack
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 4
                                radius: 2
                                color: Theme.hover

                                Rectangle {
                                    readonly property real frac: (root.brightness - root.brightnessMin) / (root.brightnessMax - root.brightnessMin)
                                    width: parent.width * Math.max(0, Math.min(1, frac))
                                    height: parent.height
                                    radius: 2
                                    color: Theme.accent
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onPressed: mouse => root.setBrightness(root.brightnessMin + (mouse.x / width) * (root.brightnessMax - root.brightnessMin))
                                onPositionChanged: mouse => {
                                    if (pressed)
                                        root.setBrightness(root.brightnessMin + (mouse.x / width) * (root.brightnessMax - root.brightnessMin));
                                }
                            }
                        }
                    }
                }

                // ==================== mouse sub-view ====================
                Column {
                    width: parent.width
                    spacing: 10
                    visible: root.currentView === "mouse"

                    Row {
                        width: parent.width
                        height: 24
                        spacing: 10

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Pointer speed"
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            width: 100
                        }

                        Item {
                            width: parent.width - 110
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                id: accelTrack
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 4
                                radius: 2
                                color: Theme.hover

                                Rectangle {
                                    width: parent.width * ((root.accelSpeed - root.accelMin) / (root.accelMax - root.accelMin))
                                    height: parent.height
                                    radius: 2
                                    color: Theme.accent
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                function applyFromX(x) {
                                    const frac = Math.max(0, Math.min(1, x / width));
                                    root.setAccelSpeed(Math.round(root.accelMin + frac * (root.accelMax - root.accelMin)));
                                }
                                onPressed: mouse => applyFromX(mouse.x)
                                onPositionChanged: mouse => { if (pressed) applyFromX(mouse.x); }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        height: 24
                        spacing: 10

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 44
                            text: "Natural scrolling"
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }

                        ToggleSwitch {
                            anchors.verticalCenter: parent.verticalCenter
                            checked: root.naturalScroll
                            onToggled: root.setNaturalScroll(!checked)
                        }
                    }
                }

                // ==================== theme sub-view ====================
                Column {
                    width: parent.width
                    spacing: 10
                    visible: root.currentView === "theme"

                    SectionLabel { text: "GTK THEME" }
                    Dropdown {
                        items: root.gtkThemes
                        current: root.currentGtkTheme
                        onPicked: name => root.setGtkTheme(name)
                    }

                    SectionLabel { text: "ICON THEME" }
                    Dropdown {
                        items: root.iconThemes
                        current: root.currentIconTheme
                        onPicked: name => root.setIconTheme(name)
                    }

                    SectionLabel { text: "CURSOR THEME" }
                    Dropdown {
                        items: root.cursorThemes
                        current: root.currentCursorTheme
                        onPicked: name => root.setCursorTheme(name)
                    }

                    Text {
                        text: "GTK apps must be restarted to pick up a theme change (no XSETTINGS manager runs under dwm)."
                        color: Theme.fgDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        wrapMode: Text.Wrap
                        width: parent.width
                    }
                }
            }
        }
    }
}
