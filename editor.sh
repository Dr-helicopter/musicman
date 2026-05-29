#!/usr/bin/env bash



MM_HOME="${XDG_STATE_HOME:-$HOME/.local/state}/muicman"
tmpfile="${MM_HOME}/tmpfile"

mkdir -p "$MM_HOME"


edit_meta() {
	cat > "$tmpfile" << EOF
# file ${1}
# edit the vars as you please

mmARTIST="$mmARTIST"
mmTITLE="$mmTITLE"
mmALBUM="$mmALBUM"
mmTRACK="$mmTRACK"
EOF
"${EDITOR:=vi}" "$tmpfile"

}



case "$1" in
	'meta') edit_meta "$2";;
	're') echo '' > "$tmpfile" ;;
	*) ehco eeeeeeeeeeeeeee ;;
esac
