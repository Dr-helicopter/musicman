#!/bin/bash

source ~/scripts/MusicMan/main.sh


bar_position=4

get_vars() {
	LINES=$1 
	COLUMNS=$(($2-1))
}
get_terminal_size() {
#    read -r LINES COLUMNS < <(stty size)
	get_vars $(stty size)
	((max_items=LINES - 7))
}

resized() {
	get_terminal_size
	get_vars $(stty size)
	clear_screan
	update_tab_bar
	print_page
}


clear_screan() {
	printf '\e[60H\e[1J'
}

read_stats() {
	TAB=$(cat "$MM_HOME/tab" 2>/dev/null)
	TAB=${TAB%%[!0-9]*}	# Remove everything after first non-digit
	TAB=${TAB:-0}		# Default to 0 if empty
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

print_line() {
	if [[ $1 == $cursor_item ]] ; then
		color_code="\e[${bar_fg3:=32};${bar_bg3:=101}m"
	else 
		unset color_code
	fi

	printf "\e[$(($1+6))H${color_code}%3d    %s\n\e[m" $1 "${display_list[$1]}"
}

display_update() {
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
			display_list=("${albums_list[@]#$t1prefix/}")
			display_update
			;;
		2) 
			display_list=("${songs_list[@]#$t2prefix/}")
			display_list=("${display_list[@]%.mp3}")
			display_update
			;;

		*) true ;;
	esac
}



# this will only update the tab bar value
# in order to display the bar we echo the TAB_BAR variable (has to be quted)
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

cursor_up() {
	if ((cursor_item > 0)); then
		((cursor_item--)) 
		print_line $cursor_item
		print_line $(($cursor_item+1))
	fi
	case $TAB in
		0)
			t0cursor_item=$cursor_item
			;;
		1)
			t1cursor_item=$cursor_item
			;;
		2)
			t2cursor_item=$cursor_item
			;;
		*)
			exit 40
			;;
	esac
	printf '\e[5H'
}

cursor_down() {
	if ((cursor_item < ${#display_list[@]}-1)); then
		((cursor_item++)) 
		print_line $cursor_item
		print_line $(($cursor_item-1))
	fi
	case $TAB in
		0)
			t0cursor_item=$cursor_item
			;;
		1)
			t1cursor_item=$cursor_item
			;;
		2)
			t2cursor_item=$cursor_item
			;;
		*)
			exit 40
			;;
	esac
	printf '\e[5H'
}

go_tab() {
	case "$1" in 
		'+') go_tab $(($TAB+1)) && return 0 ;;
		'-') go_tab $(($TAB-1)) && return 0 ;;
		0)
			((cursor_item=$t0cursor_item))
			;;
		1)
			((cursor_item=$t1cursor_item))
			;;
		2)
			((cursor_item=$t2cursor_item))
			;;
		*) ;;
	esac

	if (( 0 > "$1" || "$1" > 2 )); then
		return 0
	fi

	TAB=$1
	echo $TAB > $MM_HOME/tab
	update_tab_bar
	print_page
}

select_item() {
	case "$TAB" in
		0)
			albums_list=( "${artists_list[$1]}"/* )
			t1cursor_item=0 
			t1prefix="${artists_list[$1]}"
			go_tab 1
			;;
		1)
			songs_list=( "${albums_list[$1]}"/* )
			t2cursor_item=0
			t2prefix="${albums_list[$1]}"
			go_tab 2
			;;
		2)
			~/scripts/MusicMan/player.sh play "${songs_list[$1]}" &> /dev/null &
			;;
		*)
			command ...
			;;
	esac
}


in_cmd=0
open_cmd(){
	if [[ $1 == '-n' ]]; then
		local mode=num
		shift
	fi
	for ((;;)); {
		printf '\e[5H%s%s ' "$1" "$cmd_line"

        read "${read_flags[@]}" -srn 1 && 
		{
			char=$REPLY
			[[ "$REPLY" == $'\e' ]] && {
				read "${read_flags[@]}" -rsn 1

				# Handle a normal escape key press.
				[[ $'\e'${REPLY} == $'\e\e['* ]] &&
					read "${read_flags[@]}" -rsn 1 _

				char=$'\e'${REPLY}
			}

			case ${char:=$REPLY} in
				$'\177')
					local cmd_line=${cmd_line%?}
					;;
				'')
					last_cmd_reply="$cmd_line"
					printf '\e[1J'
					echo "$TAB_BAR"
					return 0
					;;
				*)
					if [[ $mode = 'num' && $char =~ ^[0-9]$ ]]; then
						local cmd_line=$cmd_line$char
					elif [[ $char =~ ^([0-9]|[a-z]|[A-Z]|' ')$ ]]; then
						local cmd_line=$cmd_line$char
					fi
					;;
			esac
			# very chaotic indeed
		}
        [[ -t 1 ]] || exit 1
	}
}

run_command() {
	case "$1" in
		q) 
			exit 0 
			;;
		"chg tn")
			if [[ $TAB == 1 ]] then
				
				local alb_path="${albums_list[$cursor_item]}"
				local alb=${alb_path##*/}
				local art_path=${alb_path%/*}
				local art=${art_path##*/}

				~/scripts/MusicMan/editor.sh reord "$art" "$alb"
			elif [[ $TAB == 2 ]]; then
				_mmGetTags "${songs_list[$cursor_item]}"
				open_cmd -n 'give number '
				if [[ "$last_cmd_reply" =~ ^[0-9]+$ ]]; then
					mmChangeTrackNo "$mmARTIST" "$mmALBUM" "$mmTITLE" "$last_cmd_reply"
				else
					printf '\e[5H%s ' "not a number"
					read -sn 1 nul
				fi
			else
				printf '\e[5H%s ' "no song or album is elected"
				read -sn 1 nul
			fi
			;;
		*) true ;;
	esac
}

key() {
    # Handle special key presses.
    [[ $1 == $'\e' ]] && {
        read "${read_flags[@]}" -rsn 1

        # Handle a normal escape key press.
        [[ ${1}${REPLY} == $'\e\e['* ]] &&
            read "${read_flags[@]}" -rsn 1 _

        local special_key=${1}${REPLY}
    }

    case ${special_key:-$1} in
			q) exit 0 ;;
			d) go_tab + ;;
			a) go_tab - ;;
			ar) go_tab 0 ;;
			al) go_tab 1 ;;
			sg) go_tab 2 ;;
			s) 
				cursor_down
				printf '\e[5H'
				;;
			w) 
				cursor_up
				printf '\e[5H'
				;;
			e|' ') 
				select_item $cursor_item
				unset selection
				;;
			'')
				selection="${selection%?}"
				printf '\e[5H %s ' $selection
				;;
			A)
				~/scripts/MusicMan/player.sh  queue "${songs_list[@]}" &> /dev/null &
				;;
			
			c)
				open_cmd
				run_command "$last_cmd_reply"
				;;
			# playback Handle  VVV
			#
			$'\e2'|$'\e ') ~/scripts/MusicMan/player.sh pause ;;
			$'\e1'|$'\es') ~/scripts/MusicMan/player.sh vdown ;;
			$'\e3'|$'\ew') ~/scripts/MusicMan/player.sh vup ;;
			$'\ed') ~/scripts/MusicMan/player.sh forward ;;
			$'\ea') ~/scripts/MusicMan/player.sh backward ;;

			$'\ex') killall mpv ;;

			*)
				true
		esac
}

main() {
    ((BASH_VERSINFO[0] > 3)) &&
        read_flags=(-t 1.5)


	get_terminal_size
	clear_screan
	read_artists
	read_albums
	read_songs
	read_stats
	update_tab_bar
	print_page

	trap 'resized' WINCH

	while :; do
		read "${read_flags[@]}" -rsn1 && key "$REPLY"
        [[ -t 1 ]] || exit 1
	done
}

cursor_item=0
t0cursor_item=0
t1cursor_item=0
t2cursor_item=0

t1prefix=$MUSICDIR
t2prefix=$MUSICDIR

main "$@"
