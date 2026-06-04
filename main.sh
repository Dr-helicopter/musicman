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

_has_id3v2_tags() {
    if id3v2 -l "$1" 2>&1 | grep -q "No ID3 tag"; then
        return 1  # no tags
	fi
	return 0  # has tags (v1, v2, or both)
}

format_number() {
    [[ "$1" =~ ^[0-9]+$ ]] &&
        printf "%02d" "$1" ||
        echo "xx"
}

__mmGetTags_idv1_falback() {
	data=$(ffprobe -v quiet -show_entries format_tags=artist,title,album,track \
		-of default=noprint_wrappers=1:nokey=0 "$1")
	if [[ -z $data ]] then 
		return 2
	fi

	echo $data
	export mmARTIST=$(echo $data | grep -oP '^TAG:artist=\K.*')
	export mmTITLE=$(echo $data | grep -oP '^TAG:title=\K.*')
	export mmALBUM=$(echo $data | grep -oP '^TAG:album=\K.*')
	export mmTRACK=$(echo $data | grep -oP 'TAG:track=\K.*')
} 

_mmGetTags() {
	if ! _has_id3v2_tags "$1" ; then
		__mmGetTags_idv1_falback "$1" || 
			echo $? no id3 tag was found >&2 
		return
	fi

	local data=$(id3v2 -l "$1")

	export mmARTIST=$(echo "$data" | grep -oP '^TPE1.*?: \K.*')
	export mmTITLE=$(echo "$data" | grep -oP '^TIT2.*?: \K.*')
	export mmALBUM=$(echo "$data" | grep -oP '^TALB.*?: \K.*')
	export mmTRACK=$(echo "$data" | grep -oP '^TRCK.*?: \K.*')


	return 0
}

_mmSetSongMeta() {
	[[ ! -f  "$1" ]] && {
		echo file $1 not found 
		return 1
	}

	[[ -n $2 ]] &&
		id3v2 --TPE1 "$2" "$1"

	[[ -n $3 ]] &&
		id3v2 --TALB "$3" "$1"

	[[ -n $4 ]] &&
		id3v2 --TRCK "$4" "$1"

	[[ -n $5 ]] &&
		id3v2 --TIT2 "$5" "$1"
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

_mmAddSong() {
	! _mmGetTags "$1" && {
		[[ ! -f "$1" ]] && 
			return 1
		_mmOpenEditor "$1"
	} || [[ $2 = '-e' ]] && _mmOpenEditor "$1"

	mkdir -p "$MUSICDIR/$mmARTIST/$mmALBUM"
	local file_name="$MUSICDIR/$mmARTIST/$mmALBUM/$(format_number $mmTRACK):$mmTITLE".mp3
	cp $1 "$file_name"

	id3v2 -D "$file_name"
	
	_mmSetSongMeta "$file_name" "$mmARTIST" "$mmALBUM" "$mmTRACK" "$mmTITLE"
}

mmChangeTrackNo() {
	if ! ( ls "$MUSICDIR/$1/$2" | grep -E "^..:$3.mp3$" &> /tmp/mmfnm ); then
		return 1
	fi

	local file_name="$MUSICDIR/$1/$2/$(head -n 1 /tmp/mmfnm)"
	! _mmGetTags "$file_name" && 
		return 1

	mmTRACK="$4"


	local new_file_name="$MUSICDIR/$mmARTIST/$mmALBUM/$(format_number $mmTRACK):$mmTITLE".mp3
	cp "$file_name" "$new_file_name"

	id3v2 -D "$new_file_name" &> /dev/null

	_mmSetSongMeta "$new_file_name" "$mmARTIST" "$mmALBUM" "$mmTRACK" "$mmTITLE"

	rm "$file_name"
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



mmPlay() {
	artists=( "$MUSICDIR"/* )
	artists=(${artists[@]#$MUSICDIR/})

	list_select "${artists[@]}"
	
	[[ $select_result = 'q' ]] && return 0

	if ((select_result < ${#artists})); then
		artist="${artists[$select_result]}"
	else 
		artist="${artists[${#artists}]}"
	fi

	albums=( "$MUSICDIR/$artist"/* )
	albums=( "${albums[@]#$MUSICDIR/$artist/}" )

	list_select "${albums[@]}"

	if [[ $select_result < ${#albums} ]]; then
		~/scripts/MusicMan/player.sh play "$MUSICDIR/$artist/${albums[select_result]}/" &
	else 
		~/scripts/MusicMan/player.sh play "$MUSICDIR/$artist/${albums[${#albums}]}/" &
	fi
}


