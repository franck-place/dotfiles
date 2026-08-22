xrdb -merge ~/.Xresources
[ -f ~/.fehbg ] && ~/.fehbg &
picom --config ~/.config/picom.conf -b

# flatpak apps export their .desktop/icon files here; not in XDG_DATA_DIRS by
# default outside a full desktop session, so the launcher wouldn't see them
export XDG_DATA_DIRS="$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

# Quickshell bar: tags/layout/title/clock/volume/tray/power -- the only bar.
# dwm's own bar is fully disabled (showbar=0, showsystray=0 in config.h) but
# still reserves the same barheight strip of screen space for it.
# NotificationStore.qml owns org.freedesktop.Notifications (dunst retired).
#
# A quickshell instance whose X11 connection dies (e.g. the previous session
# was killed rather than exited cleanly) doesn't reliably exit on its own --
# it keeps holding the single-instance lock, so the next session's launch
# silently no-ops and the bar never appears. Force-kill any leftover instance
# first; pkill rather than `quickshell kill` since that goes over the same
# (possibly wedged) IPC socket the stale process isn't answering on.
pkill -9 -f "qs -p .*/quickshell/dwmbar/shell\.qml" 2>/dev/null
sleep 0.3
qs -p ~/.config/quickshell/dwmbar/shell.qml &

exec dwm
