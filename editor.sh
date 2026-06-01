#!/usr/bin/env bash

source ~/scripts/MusicMan/main.sh

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

change_album_order() {
cat > "$tmpfile" << EOF
# album ${2} - ${1}
# 

EOF

	for i in "${MUSICDIR}/${1}/${2}/"* ; do
		_mmGetTags "$i"
		printf '%s\t%s\n' "${mmTRACK}" "${i#$MUSICDIR/${1}/${2}/}" >> "$tmpfile"
	done

	"${EDITOR:=vi}" "$tmpfile"

	while IFS= read -r line; do
		# Skip blank lines
		[ -z "$line" ] && continue

		# Skip comments
		case "$line" in
			\#*) continue ;;
		esac

IFS='	' read -r number filename <<EOF
$line
EOF
		filename="${MUSICDIR}/${1}/${2}/${filename}"

		if [[ -f "$filename" ]]; then
			_mmGetTags "$filename"
			mmChangeTrackNo "$mmARTIST" "$mmALBUM" "$mmTITLE" "$number"
		fi
	done < "$tmpfile"
}


case "$1" in
	'meta') edit_meta "$2";;
	'reord') change_album_order "$2" "$3" ;;
	're') echo '' > "$tmpfile" ;;
	*) echo eeeeeeeeeeeeeee ;;
esac
