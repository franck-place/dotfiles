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

# Basic-ANSI prompt -- these SGR codes (30-37) reference st's colorname[0-7]
# by index, not fixed RGB, so this follows whatever palette
# ~/.local/bin/apply-theme last generated automatically. No regeneration
# step needed here, ever: unlike the truecolor (38;2;r;g;b) codes this
# used to hardcode, an indexed color just always resolves to "whatever
# that slot currently is." Same role mapping used everywhere else in this
# rice: accent = color4, dim = color8 (bright black).
__rustic_git_branch() {
	local b
	b=$(git symbolic-ref --short HEAD 2>/dev/null) || b=$(git rev-parse --short HEAD 2>/dev/null) || return
	printf ' (%s)' "$b"
}

if [ -n "$PS1" ]; then
	__RUST='\[\e[34m\]'    # accent -- colorname[4]
	__SAND='\[\e[39m\]'    # default foreground -- colorname[258]
	__OLIVE='\[\e[32m\]'   # green -- colorname[2]
	__DIM='\[\e[90m\]'     # bright black / dim -- colorname[8]
	__RESET='\[\e[0m\]'
	__BOLD='\[\e[1m\]'

	PS1="${__DIM}┌─${__RUST}${__BOLD}\u${__RESET}${__DIM}@${__RUST}${__BOLD}\h${__RESET} ${__SAND}\w${__OLIVE}\$(__rustic_git_branch)${__RESET}\n${__DIM}└─${__RUST}${__BOLD}❯${__RESET} "
fi
