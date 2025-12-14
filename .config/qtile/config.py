#
# Franck Qtile Config
#

# imports
from libqtile import bar, layout, widget, hook, qtile
from libqtile.config import Click, Drag, Group, Key, Match, hook, Screen, KeyChord
from libqtile.lazy import lazy
from libqtile.utils import guess_terminal
from libqtile.dgroups import simple_key_binder
import subprocess
import os

# autostart


@hook.subscribe.startup_once
def autostart():
    home = os.path.expanduser('~/.config/qtile/scripts/autostart.sh')
    subprocess.Popen([home])


# Variables
mod = "mod4"
terminal = "kitty"
filemanager = "thunar"
code ="code"
wallpaper_select='/bin/bash -c "sxiv -b -r -q -o -t ~/.config/qtile/Wallpaper | xargs feh --bg-scale"' # Select an image then press "M" to mark it then press "Q" to apply the wallpaper and quit sxiv
screenshot='/bin/bash -c "flameshot gui -p ~/Screenshots/"'

# Keybinds
keys = [
    Key([mod], "q", lazy.window.kill(), desc="Kill window"),
    Key([mod], "r", lazy.reload_config(), desc="Reload config"), 
    Key([mod], "Space", lazy.spawn("rofi -theme Franck -show drun"), desc="rofi drun"),
    Key([mod], "Return", lazy.spawn(terminal), desc="terminal"),
    Key([mod], "e", lazy.spawn(filemanager), desc="file manager"),
    Key([mod], "c", lazy.group["5"].toscreen(), lazy.spawn(code), desc="code"),
    Key([mod], "w", lazy.spawn(wallpaper_select)),
    Key([mod], "s", lazy.spawn(screenshot)),
    Key([], "XF86AudioRaiseVolume", lazy.spawn("pactl set-sink-volume 0 +1%"), desc='Volume Up'),
    Key([], "XF86AudioLowerVolume", lazy.spawn("pactl set-sink-volume 0 -1%"), desc='volume down'),
    Key([], "XF86AudioMute", lazy.spawn("pactl set-sink-mute @DEFAULT_SINK@ toggle"), desc='Volume Mute'),
]

# layout

floating_layout = layout.Floating(
    border_focus='#D3D3D3',
    border_normal='#4A4A4A',
    border_width=2,
    float_rules=[
        Match(wm_class="sxiv"),]
)

layouts = [
    layout.MonadThreeCol(
        margin=[0, 10, 10, 10],
        border_focus='#D3D3D3',
        border_normal='#4A4A4A',
        border_width=2,
        border_on_single=True,
        main_centered=True,
        new_client_position='bottom', 
    ),
]

# Create a helper for consistent text widgets


def create_text_box(text, padding=8):
    return widget.TextBox(
        text=text,
        font="JetBrainsMono Nerd Font",
        fontsize=14,
        padding=padding,
        background='#1A1A1A',
        foreground='#FFFFFF',
    )

# bar
screens = [
    Screen(
        top=bar.Bar(
            [
                widget.Spacer(length=10),
                widget.Image(
                    filename="/home/franck/.config/qtile/Assets/archlinux.png",
                    scale="False",
                    mouse_callbacks={
                    'Button1': lazy.spawn('rofi -theme Franck -show drun'),
                    'Button3': lazy.spawn('rofi -show power-menu -modi power-menu:rofi-power-menu')
                    },
                ),
                widget.Spacer(length=10),
                widget.GroupBox(
                    background='#1A1A1A',
                    foreground='#FFFFFF',
                    active='#FFFFFF',
                    inactive='#4A4A4A',
                    highlight_method='line',
                    highlight_color=['#3A3A3A', '#3A3A3A'],
                    this_current_screen_border='#FFFFFF',
                    block_highlight_text_color='#FFFFFF',
                    borderwidth=3,
                    disable_drag=True,
                    font="SymbolsNerdFont",
                    fontsize=14,
                    padding_y=13,
                    padding_x=15,
                    
                ),
                widget.Spacer(length=10),
                widget.WindowName(
                    background='#1A1A1A',
                    foreground='#FFFFFF',
                    font="JetBrainsMono Nerd Font",
                    fontsize=14,
                    padding=5,
                ),
                create_text_box('|'),
                widget.GenPollText(
                    update_interval=300,
                    func=lambda: subprocess.check_output(
                        "printf $(uname -r)", shell=True, text=True),
                    background='#1A1A1A',
                    foreground='#FFFFFF',
                    font="JetBrainsMono Nerd Font",
                    fontsize=14,
                    padding=8,
                    fmt=' {}',
                ),
                create_text_box('|'),

                widget.CPU(
                    background='#1A1A1A',
                    foreground='#FFFFFF',
                    format=' {load_percent}%',
                    font="JetBrainsMono Nerd Font",
                    fontsize=14,
                    padding=8,
                ),
                create_text_box('|'),

                widget.Memory(
                    background='#1A1A1A',
                    foreground='#FFFFFF',
                    measure_mem='G',
                    format=' {MemUsed:.0f}{mm}/{MemTotal:.0f}{mm}',
                    font="JetBrainsMono Nerd Font",
                    fontsize=14,
                    padding=8,
                ),
                create_text_box('|'),

                widget.PulseVolume(
                    unmute_format='󰕾 {volume}%',
                    mute_format=' 0%',
                    background='#1A1A1A',
                    foreground='#FFFFFF',
                    volume_app='pavucontrol',
                    font="JetBrainsMono Nerd Font",
                    fontsize=14,
                    padding=8,
                ),
                create_text_box('|'),

                widget.Spacer(length=10),
                widget.Systray(
                    background='#1A1A1A',
                    padding=5,
                ),
                widget.Spacer(length=10),

                widget.Clock(
                    format='|  󰃭 %d/%m/%y  | |   %H:%M  |',
                    background='#1A1A1A',
                    foreground='#FFFFFF',
                    font="JetBrainsMono Nerd Font",
                    fontsize=14,
                    padding=8,
                ),
                widget.Spacer(length=10),

            ],
            35,  # Bar height
            margin=[10, 10, 14, 10],
            background='#1A1A1A'
        ),
        # wallpaper
        wallpaper='~/.config/qtile/Wallpaper/tanjiro.jpg',
        wallpaper_mode="fill",
    ),
]

@hook.subscribe.client_new
def float_sxiv(window):
    if window.window.get_wm_class() and "sxiv" in window.window.get_wm_class()[0].lower():
        window.floating = True
        window.center()
# groups
groups = [
    Group("1", label="", matches=[Match(wm_class=["firefox-developer-edition"])]),
    Group("2", label="", matches=[Match(wm_class=["vesktop"])]),
    Group("3", label="", matches=[Match(wm_class=["steam"])]),
    Group("4", label="", matches=[Match(wm_class=["tidal-hifi"])]),
    Group("5", label="", matches=[Match(wm_class=["code"])]),
]

for i in range(9):
    groups.append(
        Group(
            name=str(i+1),
            layout=["colomn"],
            label=str(i+1),
        ))

for group in groups:
    keys.extend(
        [
            Key(
                [mod],
                group.name,
                lazy.group[group.name].toscreen(),
                desc="Switch to group {}".format(group.name),
            ),
            Key(
                [mod, "shift"],
                group.name,
                lazy.window.togroup(group.name, switch_group=False),
                desc="Move focused window to group {}".format(group.name),
            ),
        ]
    )

# Required Qtile configurations
mouse = []
dgroups_key_binder = None
dgroups_app_rules = []
follow_mouse_focus = True
bring_front_click = False
cursor_warp = False
auto_fullscreen = True
focus_on_window_activation = "smart"
reconfigure_screens = True
auto_minimize = True
wmname = "Qtile"
