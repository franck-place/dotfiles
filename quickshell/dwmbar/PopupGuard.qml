pragma Singleton
import Quickshell
import QtQuick

// Only one bar popup may be open at a time. The previous popup is hidden
// shortly AFTER the new one maps (new windows stack on top), so the swap
// is a single visual change instead of an unmap/map flicker.
Singleton {
    id: root

    property var current: null
    property var pending: null

    function claim(p) {
        // the wallpaper picker isn't tracked here (it doesn't unmap/remap on
        // open like these do, so swapping it via the pending-hide dance
        // below would fight its own close animation) -- just courtesy-close
        // it whenever a real popup is claimed instead.
        WallpaperState.hide();

        if (current === p)
            return;
        if (pending && pending !== p)
            pending.visible = false;
        pending = current;
        current = p;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: 80
        onTriggered: {
            if (root.pending && root.pending !== root.current)
                root.pending.visible = false;
            root.pending = null;
        }
    }
}
