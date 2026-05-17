#!/bin/bash

source ~/scripts/MusicMan/main.sh


bar_position=4

get_terminal_size() {
    read -r LINES COLUMNS < <(stty size)
	((max_items=LINES - 7))
}


clear_screan() {
	printf '\e[60H\e[1J'
}

read_stats() {
	TAB=$(( $(cat $MM_HOME/tab) ))
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

cursor_item=0
print_line() {
	if [[ $1 == $cursor_item ]] ; then
		color_code="\e[${bar_fg3:=32};${bar_bg3:=101}m"
	else 
		unset color_code
	fi

	printf "\e[$(($1+6))H${color_code}%s > %s\n\e[m" $1 "${display_list[$1]}"
}

display_update() {
	printf '\e[5H %s' $selection
	printf '\e[6H'
	for i in $(seq 0 $(($max_items < "${#display_list[@]}"-1 ? $max_items : "${#display_list[@]}"-1)) )
	do
		print_line $i
	done
	printf '\e[5H'
}

print_page() {
	clear_screan
	echo "$TAB_BAR"
	case $TAB in
		0) 
			display_list=("${artists_list[@]#$MUSICDIR/}")
			display_update
			;;
		1) 
			display_list=("${albums_list[@]#$MUSICDIR/}")
			display_update
			;;
		2) 
			display_list=("${songs_list[@]#$MUSICDIR/}")
			display_update
			;;

		*) true ;;
	esac
}


update_tab_bar(){
	local code0="\e[${bar_fg0:=37};${bar_bg0:=104}m"
	local code1="\e[${bar_fg1:=37};${bar_bg1:=105}m"
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
"$COLUMNS" "|" "" )
}

go_tab() {
	case $1 in 
		'+')
			if (($TAB < 2)); then
				TAB=$((TAB+1))
				update_tab_bar
				print_page
			fi
			;;
		'-')
			if (($TAB > 0)); then
				TAB=$((TAB-1))
				update_tab_bar
				print_page
			fi
			;;
		[0-2])
			TAB=$1
			update_tab_bar
			print_page
			;;
	esac
	echo $TAB > $MM_HOME/tab
}

select_item() {
	case "$TAB" in
		0)
			echo "${artists_list[$1]}"
			;;
		1)
			songs_list=( "${albums_list[$1]}"/* )
			go_tab 2
			;;
		2)
			~/scripts/MusicMan/player.sh play "${songs_list[$1]}"
			;;
		*)
			command ...
			;;
	esac
}

main() {
	get_terminal_size
	clear_screan
	read_artists
	read_albums
	read_songs
	read_stats
	update_tab_bar
	print_page
	for ((;;)); {
			
		read -srn 1


		case $REPLY in 
			q) exit 0 ;;
			d) go_tab + ;;
			a) go_tab - ;;
			ar) go_tab 0 ;;
			al) go_tab 1 ;;
			sg) go_tab 2 ;;
			s) 
				((cursor_item++))
				print_line $cursor_item
				print_line $(($cursor_item-1))
				printf '\e[5H'
				;;
			w) 
				((cursor_item--)) 
				print_line $cursor_item
				print_line $(($cursor_item+1))
				printf '\e[5H'
				;;
			'') 
				select_item $cursor_item
				unset selection
				;;
			e)
				selection="${selection%?}"
				printf '\e[5H %s ' $selection
				;;
			A)
				~/scripts/MusicMan/player.sh  queue "${songs_list[@]}"
				;;
			[0-9]*)
				selection=$selection$REPLY
				printf '\e[5H %s ' $selection
				;;
			[a-z])
				printf '\e[5H  %s ' $REPLY
				;;
			*)
				true
		esac
	}
}


main "$@"
