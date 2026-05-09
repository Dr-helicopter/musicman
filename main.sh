# MusicMan 
# by dr.helicopter
# 2026/04/28

export MUSICDIR=~/Music



_has_id3_tags() {
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
_mmGetTags() {
	if ! _has_id3_tags $1 ; then
		echo no id3 tag was found >&2 
		return 1
	fi

	local data=$(id3v2 -l $1)


	mmARTIST=$(echo $data | grep -oP '^TPE1.*?: \K.*')
	mmTITLE=$(echo $data | grep -oP '^TIT2.*?: \K.*')
	mmALBUM=$(echo $data | grep -oP '^TALB.*?: \K.*')
	mmTRACK=$(echo $data | grep -oP '^TRCK.*?: \K.*')
	return 0
}

_mmSetSongMeta() {
	[[ ! -f  "$1" ]] && {
		echo file $1 not found 
		return 1
	}

	echo $1
	echo $2
	echo $3
	echo $4
	echo $5
	
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
		echo $i
		_mmSetSongMeta "$i" "$3" "$4" "" ""
		mv "$i" "$MUSICDIR/$3/$4"
	done
	rmdir "$MUSICDIR/$1/$2"
}

_mmAddSong() {
	! _mmGetTags "$1" &&
		return 1


	mkdir -p "$MUSICDIR/$mmARTIST/$mmALBUM"
	local file_name="$MUSICDIR/$mmARTIST/$mmALBUM/$(format_number $mmTRACK):$mmTITLE".mp3
	cp $1 "$file_name"

	id3v2 -D "$file_name"
	
	echo $file_name

	_mmSetSongMeta "$file_name" "$mmARTIST" "$mmALBUM" "$mmTRACK" "$mmTITLE"
}

mmChangeTrackNo() {
	if ! ( ls "$MUSICDIR/$1/$2" | grep -E "^..:$3.mp3$" &> /tmp/mmfnm ); then
		echo file "$MUSICDIR/$1/$2/00:$3" doesnt exist
		return 1
	fi

	local file_name="$MUSICDIR/$1/$2/$(head -n 1 /tmp/mmfnm)"
	! _mmGetTags "$file_name" &&
		return 1

	mmTRACK="$4"


	local new_file_name="$MUSICDIR/$mmARTIST/$mmALBUM/$(format_number $mmTRACK):$mmTITLE".mp3
	cp "$file_name" "$new_file_name"

	id3v2 -D "$new_file_name"

	_mmSetSongMeta "$new_file_name" "$mmARTIST" "$mmALBUM" "$mmTRACK" "$mmTITLE"

	rm "$file_name"

}

mmAddSong() {
	for i in $@
	do
		echo "$i"
		_mmAddSong "$i"
	done
}


mmLsArt() {
	ls $MUSICDIR | nl
}
