# Sample .bashrc for SUSE Linux
# Copyright (c) SUSE Software Solutions Germany GmbH

# There are 3 different types of shells in bash: the login shell, normal shell
# and interactive shell. Login shells read ~/.profile and interactive shells
# read ~/.bashrc; in our setup, /etc/profile sources ~/.bashrc - thus all
# settings made here will also take effect in a login shell.
#
# NOTE: It is recommended to make language settings in ~/.profile rather than
# here, since multilingual X sessions would not work properly if LANG is over-
# ridden in every subshell.

test -s ~/.alias && . ~/.alias || true

# Basic-ANSI prompt -- these SGR codes (30-37/90-97) reference st's
# colorname[] by index, not fixed RGB, so this follows whatever palette
# ~/.local/bin/apply-theme last generated automatically. No regeneration
# step needed here, ever: unlike the truecolor (38;2;r;g;b) codes this
# used to hardcode, an indexed color just always resolves to "whatever
# that slot currently is." Same role mapping used everywhere else in this
# rice: accent = color4, dim = color8 (bright black), urgent = color1.
#
# Branch is green when clean, red+"*" when there are uncommitted changes
# to tracked files (`git diff --quiet HEAD`) -- untracked files don't
# count, same as most prompt plugins, since new files aren't "dirty" in
# the sense that matters here (nothing to lose).
__rustic_git_branch() {
	local b
	b=$(git symbolic-ref --short HEAD 2>/dev/null) || b=$(git rev-parse --short HEAD 2>/dev/null) || return
	if git diff --quiet --ignore-submodules HEAD 2>/dev/null; then
		printf ' \e[32m(%s)\e[0m' "$b"
	else
		printf ' \e[31m(%s*)\e[0m' "$b"
	fi
}

# Captured as the very first thing PROMPT_COMMAND runs, before the git
# check above (or anything else) has a chance to overwrite $? -- PS1
# reads this variable instead of $? directly for exactly that reason.
__rustic_capture_status() { __last_status=$?; }
PROMPT_COMMAND="__rustic_capture_status${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

__rustic_exit_marker() {
	[ "${__last_status:-0}" -ne 0 ] && printf '\e[31m✗ %s \e[0m' "$__last_status"
}

if [ -n "$PS1" ]; then
	__RUST='\[\e[34m\]'    # accent -- colorname[4]
	__SAND='\[\e[39m\]'    # default foreground -- colorname[258]
	__DIM='\[\e[90m\]'     # bright black / dim -- colorname[8]
	__RESET='\[\e[0m\]'
	__BOLD='\[\e[1m\]'

	PS1="${__DIM}┌─${__RUST}${__BOLD}\u${__RESET}${__DIM}@${__RUST}${__BOLD}\h${__RESET} ${__SAND}\w\[\$(__rustic_git_branch)\]${__RESET}\n${__DIM}└─\[\$(__rustic_exit_marker)\]${__RUST}${__BOLD}❯${__RESET} "

	# saner history: no immediate dupes, no dupes anywhere in the file,
	# appended (not overwritten) so multiple terminals don't clobber each
	# other's history on exit
	HISTCONTROL=ignoreboth:erasedups
	HISTSIZE=10000
	HISTFILESIZE=20000
	shopt -s histappend cmdhist autocd globstar checkwinsize

	# one glance at the machine on every new terminal window -- already
	# palette-driven (see ~/.config/fastfetch/config.jsonc), so this never
	# needs touching when the wallpaper changes either
	[ "$TERM" != dumb ] && command -v fastfetch >/dev/null 2>&1 && fastfetch
fi

# Palette-driven ls colors and man-page colors -- same reasoning as the
# prompt above: these are indexed SGR codes, not fixed RGB, so they
# follow the palette automatically. Role mapping: directories = accent
# (color4), executables = green (color2, matches the "success" role used
# elsewhere), symlinks/sockets = color6/color5, archives = urgent
# (color1), media = color5, everything else left at less/ls's own
# defaults rather than guessing at more roles than this rice actually has.
LS_COLORS='di=1;34:ln=1;36:so=1;35:pi=33:ex=1;32:bd=1;33:cd=1;33:su=37;41:sg=30;43:tw=30;42:ow=34;42'
LS_COLORS="$LS_COLORS:*.tar=31:*.tgz=31:*.zip=31:*.gz=31:*.bz2=31:*.xz=31:*.7z=31:*.rar=31"
LS_COLORS="$LS_COLORS:*.jpg=35:*.jpeg=35:*.png=35:*.gif=35:*.svg=35:*.mp4=35:*.mkv=35:*.mp3=35:*.flac=35"
export LS_COLORS

# "standout" (less's status line / search-match highlight) uses reverse
# video instead of a specific color pair -- that way it stays readable
# no matter what the current palette's fg/bg happen to be, instead of
# risking a color combo that washes out on some wallpaper.
export LESS_TERMCAP_md=$'\e[1;34m'  # bold headings -- accent
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_so=$'\e[1;7m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_us=$'\e[4;32m'  # underlined text -- green
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_mb=$'\e[1;31m'
