#!/usr/bin/env bash

source ~/scripts/MusicMan/main.sh

MM_HOME="${XDG_STATE_HOME:-$HOME/.local/state}/muicman"

mkdir -p "$MM_HOME"




case "$1" in
	'meta') edit_meta "$2";;
	'reord') change_album_order "$2" "$3" ;;
	're') echo '' > "$tmpfile" ;;
	*) echo eeeeeeeeeeeeeee ;;
esac
