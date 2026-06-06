# MusicMan 
# by dr.helicopter
# 2026/04/28

export MUSICDIR=~/Music

MM_HOME="${XDG_STATE_HOME:-$HOME/.local/state}/musicman"
SHM_VOL="/dev/shm/musicman_volume"
tmpfile="${MM_HOME}/tmpfile"

mkdir -p "$MM_HOME"


_mmGetVol() {
	# try reading from ram first
	# fallback to disk if ram cache doesnt exist
	if [[ -f "$SHM_VOL" ]]; then
		volume=$(cat "$SHM_VOL")
	else 
		volume=50
		[[ -f "$MM_HOME/volume" ]] &&
			volume=$(cat "$MM_HOME/volume")
		echo "$volume" > "$SHM_VOL" # create the ram cache
	fi
}

_debug_data() {
	echo "$mmARTIST"
	echo "$mmTITLE"
	echo "$mmALBUM"
	echo "$mmTRACK"
}


_mmOpenEditor() {
	_debug_data
	bash ~/scripts/MusicMan/editor.sh meta "$1"
	source "$tmpfile"
	bash ~/scripts/MusicMan/editor.sh re
}

format_number() {
    [[ "$1" =~ ^[0-9]+$ ]] &&
        printf "%02d" "$1" ||
        echo "xx"
}

 _mmGetTags() {
        [[ ! -f "$1" ]] && return 1

        mmARTIST="" mmTITLE="" mmALBUM="" mmTRACK="" mmYEAR="" mmLYRICS=""

        while IFS='=' read -r key value; do
                case "$key" in
                        "TAG:artist")	mmARTIST=$value ;;
                        "TAG:title"	)	mmTITLE=$value ;;
                        "TAG:album"	)	mmALBUM=$value ;;
                        "TAG:date"	)	mmYEAR=$value ;;
                        "TAG:track"	)	mmTRACK=${value%%/*}
                                ;;
                esac
        done < <(ffprobe -v quiet -show_entries format_tags=artist,title,album,track,date\
                         -of default=noprint_wrappers=1:nokey=0 "$1")

        [[ -z "$mmARTIST" || -z "$mmTITLE" ]] && return 2

        return 0
}

_mmSetSongMeta() {
	[[ ! -f "$1" ]] && { echo "file $1 not found"; return 1; }

	local tmp_out="/tmp/${1}.tmp.mp3"
	local album_dir="${1%/*}"
	local album_cover="$album_dir/cover.jpg"
	local img_input=()

	# set cover if it exists
	[[ -f "$album_cover" ]] && img_input=(-i "$album_cover" -c:v mjpeg -map 1:v)


	ffmpeg -v quiet -y -i "$1" "${img_input[@]}" \
		-map_metadata -1 \
		-map_metadata:s:a -1 \
		-c:a copy -map 0:a \
		${2:+-metadata artist="$2"} \
		${3:+-metadata album="$3"} \
		${4:+-metadata track="$(format_number "$4")"} \
		${5:+-metadata title="$5"} \
		${6:+-metadata date="$6"} \
		-id3v2_version 3 \
		"$tmp_out"

	mv "$tmp_out" "$1"
}

_mmMergeAlbums() { # artist $1 album $2 to artist $3 album $4
	[[ ! -d "$MUSICDIR/$1/$2" ]] && {
		echo album $2 doesnt exist
		return 1
	}

	[[ ! -d "$MUSICDIR/$3/$4" ]] && {
		echo album $4 doesnt exist
		return 1
	}


	for i in "$MUSICDIR/$1/$2"/* 
	do
		_mmSetSongMeta "$i" "$3" "$4" "" ""
		mv "$i" "$MUSICDIR/$3/$4"
	done
	rmdir "$MUSICDIR/$1/$2"
}

#  old thig  VV
####_mmAddSong() {
####	! _mmGetTags "$1" && {
####		[[ ! -f "$1" ]] && 
####			return 1
####		_mmOpenEditor "$1"
####	} || [[ $2 = '-e' ]] && _mmOpenEditor "$1"

####	mkdir -p "$MUSICDIR/$mmARTIST/$mmALBUM"
####	local file_name="$MUSICDIR/$mmARTIST/$mmALBUM/$(format_number $mmTRACK):$mmTITLE".mp3
####	cp $1 "$file_name"

####	id3v2 -D "$file_name"
####	
####	_mmSetSongMeta "$file_name" "$mmARTIST" "$mmALBUM" "$mmTRACK" "$mmTITLE"
####}

_mmHandleCoverArt() {
	local album_dir="$MUSICDIR/$mmARTIST/$mmALBUM"
	local tmp_cover="/tmp/musicman/incoming_cover.jpg"

	# delete the cover file if it exists
	rm -f "$tmp_cover"
	mkdir -p /tmp/musicman

	ffmpeg -v quiet -i "$1" -an -c:v copy "$tmp_cover" -y 2>/dev/null
	[[ ! -s "$tmp_cover" ]] && return 0
	
	if [[ ! -f "$album_dir"/cover.jpg ]]; then
		mkdir -p "$album_dir"
		mv "$tmp_cover" "$album_dir"/cover.jpg
		return 0
	fi

	# exit if the covers match
	diff -q "$album_dir"/cover.jpg "$tmp_cover" &>/dev/null && { rm -f "$tmp_cover"; return 0; }

	# ask user if the covers conflict
	while :; do
		printf "\n cover art conflict found for %s - %s\n" "$mmARTIST" "$mmALBUM"
		printf "1) keep existing cover (force song to match album)\n"
		printf "2) overwrite cover with this song's cover\n"
		printf "3) Compare images using %s\n" ${IMGVIEWR:='nsxiv'}

		printf "Choice [1-3]: "
		read -rn1 choice
		echo ""

		case "$choice" in
			1)
				rm -f "$tmp_cover"
				;;
			2)
				mv "$tmp_cover" "$album_dir"/cover.jpg
				;;
			3)
				"$IMGVIEWR" "$album_dir"/cover.jpg "$tmp_cover" &
				;;
		esac
	done
}

_mmAddSong() {
	! _mmGetTags "$1" && {
		[[ ! -f "$1" ]] && return 1
		_mmOpenEditor "$1"
	} || [[ $2 = '-e' ]] && _mmOpenEditor "$1"


	_mmHandleCoverArt "$1"

	local album_dir="$MUSICDIR/$mmARTIST/$mmALBUM"
	local file_name="$album_dir/$(format_number $mmTRACK):$mmTITLE.mp3"

	local img_input=()

	mkdir -p "$album_dir"

	[[ -f "$album_dir"/cover.jpg ]] && img_input=(-i "$album_dir"/cover.jpg -c:v mjpeg -map 1:v)

	ffmpeg -v quiet -y -i "$1" "${img_input[@]}" \
		-map_metadata -1 \
		-map_metadata:s:a -1 \
		-c:a copy -map 0:a \
		-metadata artist="$mmARTIST" \
		-metadata album="$mmALBUM" \
		-metadata track="$(format_number $mmTRACK)" \
		-metadata title="$mmTITLE" \
		-metadata date="$mmYEAR" \
		-id3v2_version 3 \
		"$file_name"
}

mmChangeTrackNo() {
	if ! ( ls "$MUSICDIR/$1/$2" | grep -E "^..:$3.mp3$" &> /tmp/mmfnm ); then
		return 1
	fi

	local file_name="$MUSICDIR/$1/$2/$(head -n 1 /tmp/mmfnm)"

	# get tags else return 
	_mmGetTags "$file_name" || return 1

	mmTRACK="$4"


	local new_file_name="$MUSICDIR/$mmARTIST/$mmALBUM/$(format_number $mmTRACK):$mmTITLE".mp3
	mv "$file_name" "$new_file_name"

	_mmSetSongMeta "$new_file_name" "$mmARTIST" "$mmALBUM" "$mmTRACK" "$mmTITLE" "$mmYEAR"
}

mmAddSong() {
	args=("$@")
	for i in `seq $#args`; do [[ "${args[$i]}" = "-e" ]] && unset "args[$i]" && eflag='-e' ; done
	set -- "${args[@]}"

	for i in $@
	do
		_mmAddSong "$i" $eflag
	done
}

mmLsArt() {
	ls $MUSICDIR | nl
}

list_select() {
	for i in `seq "$#"`
	do
		echo $i	"$@[$i]"
	done

	read select_result
}
