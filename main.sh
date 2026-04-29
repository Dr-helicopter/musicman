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


_mmGetTags() {
	if ! _has_id3_tags $1 ; then
		echo no id3 tag was found >&2 
		return 1
	fi

	local data=$(id3v2 -l $1)


	mmARTIST=$(echo $data | grep -oP '^TPE.*?: \K.*')
	mmTITLE=$(echo $data | grep -oP '^TIT.*?: \K.*')
	mmALBUM=$(echo $data | grep -oP '^TALB.*?: \K.*')
	mmTRACK=$(echo $data | grep -oP '^TRCK.*?: \K.*')
}


mmAddSong() {
	! _mmGetTags $1 &&
		return 1


	mkdir -p "$MUSICDIR/$mmARTIST/$mmALBUM"
	cp $1 "$MUSICDIR/$mmARTIST/$mmALBUM/$mmTITLE"
}


mmLsArt() {
	ls $MUSICDIR | cat -n
}
