#!/bin/bash

source ./main.sh


bar_position=4

clear_screan() {
	printf '\e[2J'
}


read_artists() {
	artists_list=("$MUSICDIR"/*)
}

read_albums() {
	albums_list=("$MUSICDIR"/*/*)
}

read_songs() {
	songs_list=("$MUSICDIR"/*/*/*)
}



display_update() {
	printf '\e[6H'
	for i in $(seq 0 "$((${#display_list[@]}-1))")
	do
		printf '%s > %s\n' $i "${display_list[$i]}"
	done
}

print_page() {
	case $TAB in
		0) 
			display_list=("${artists_list[@]#$MUSICDIR/}")
			clear_screan
			display_update
			;;
		1) 
			display_list=("${albums_list[@]#$MUSICDIR/}")
			clear_screan
			display_update
			;;
		2) 
			display_list=("${songs_list[@]#$MUSICDIR/}")
			clear_screan
			display_update
			;;

		*) true ;;
	esac
	echo "$TAB_BAR"
}


update_tab_bar(){
	local code0="\e[${bar_fg0:=31};${bar_bg0:=104}m"
	local code1="\e[${bar_fg1:=31};${bar_bg1:=105}m"
	local aritst_tab=" ${code0} artist"
	local album_tab=" ${code0} album"
	local song_tab=" ${code0} song"
	case $TAB in
		0) aritst_tab=" ${code1}>artist" ;;
		1) album_tab=" ${code1}>album" ;;
		2) song_tab=" ${code1}>song" ;;
	esac

	TAB_BAR=$(printf "\
\e[${bar_position}H\
$code0%*s\r%s \
${aritst_tab}${album_tab}${song_tab}\
\e[m" \
"80" "|" "" )
}


main() {
	clear_screan
	TAB=0
	page=art
	read_artists
	read_albums
	read_songs
	update_tab_bar
	display_list=()
	for ((;;)); {
		print_page
			
		read key


		case $key in 
			q) exit 0 ;;
			ar)
				TAB=0
				update_tab_bar
				;;
			al)
				TAB=1
				update_tab_bar

				;;
			sg)
				TAB=2
				update_tab_bar
				;;
			*)
				true
		esac
	}
}


main "$@"
