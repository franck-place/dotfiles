pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Palette defaults to the rust/espresso scheme below, then gets
// overridden live from pywal's output whenever the wallpaper picker
// runs `apply-theme` (~/.local/bin/apply-theme) -- same colors.json
// wal writes for st (via its Xresources patch) and dwm (via its own
// xrdb patch), so the bar, terminals, and window borders all stay
// one consistent system tied to whatever wallpaper is active.
Singleton {
    id: root

    readonly property int barHeight: 30

    property color barBg: "#1c1714"
    property color fg: "#c9b79c"
    property color fgSel: "#f2e8d5"
    property color fgDim: "#8a7460"
    property color accent: "#b5651d"
    property color urgent: "#d1495b"
    readonly property color hover: Qt.rgba(fg.r, fg.g, fg.b, 0.2)

    readonly property string fontFamily: "JetBrains Mono"
    readonly property int fontSize: 13

    readonly property string iconFont: "Symbols Nerd Font Mono"
    readonly property int iconSize: 15

    property color popupBg: "#241d17"
    readonly property color popupBorder: Qt.rgba(fg.r, fg.g, fg.b, 0.24)

    FileView {
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.barBg = d.special.background;
                root.popupBg = d.special.background;
                root.fg = d.special.foreground;
                root.fgSel = d.colors.color15;
                root.fgDim = d.colors.color8;
                root.accent = d.colors.color4;
                root.urgent = d.colors.color1;
            } catch (e) {
                // partial write or no pywal run yet -- keep current values
            }
        }
    }
}
