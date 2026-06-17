#!/usr/bin/env bash

# ==============================================================================
# innitial setup
source ~/scripts/MusicMan/main.sh
playescript=~/scripts/MusicMan/player.new.sh

SHM_DIR=/dev/shm/musicman
FILEPATHFILE="$SHM_DIR"/file_path
MAXTIMEFILE=$SHM_DIR/maxtime
NAMEFILE=$SHM_DIR/name
ARTISTFILE=$SHM_DIR/artist
ARLBUMFILE=$SHM_DIR/album

title_bar_position=1
song_bar_position=2
time_bar_position=3
vol_bar_position=4
tab_bar_position=5

time=50
maxtime=100

MM_TITLE="MUSIC-MAN"
# ==============================================================================

# the terminal likes to auto update the COLUMNS and LINES variables
# but i found that to be unreliable and rether work with my own 
get_vars() {
	tLINES=$1 
	tCOLUMNS=$(($2-1))
}
get_terminal_size() {
#    read -r LINES COLUMNS < <(stty size)
	get_vars $(stty size)
	((max_items=tLINES - 7))
}


clear_screan() {
	printf '\e[%sH\e[1J' $tLINES
}


resized() {
	get_terminal_size
	clear_screan
	update_title_bar
	update_song_bar
	update_tab_bar
	update_vol_bar
	print_page
}
read_stats() {
	TAB=$(cat "$MM_HOME/tab" 2>/dev/null)
	TAB=${TAB%%[!0-9]*}	# Remove everything after first non-digit
	TAB=${TAB:-0}		# Default to 0 if empty
}

read_artists() {
	artist_list=("$MUSICDIR"/*)
}

read_albums() {
	album_list=("$MUSICDIR"/*/*)
	album_display_list=("${album_list[@]#$MUSICDIR/}")
	album_display_list=("${album_display_list[@]/\// - }")
}

read_songs() {
	song_list=("$MUSICDIR"/*/*/*.mp3)
	song_display_list=("${song_list[@]#$MUSICDIR/}")
	song_display_list=("${song_display_list[@]/\/*\// - }")
}


print_line() {
	if [[ $1 == $cursor_item ]] ; then
		color_code="\e[${fg4:=32};${bg5:=101}m"
	else 
		unset color_code
	fi

	printf "\e[$(($1+6))H${color_code}%3d    %s\n\e[m" $(($1+1)) "${display_list[$1]}"
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
	echo "$TITLE_BAR$SONG_BAR$TIME_BAR$VOL_BAR$TAB_BAR"
	case $TAB in
		0) 
			display_list=("${artist_list[@]#$MUSICDIR/}")
			display_update
			;;
		1) 
			display_list=("${album_display_list[@]}")
			display_update
			;;
		2) 
			display_list=("${song_display_list[@]}")
			#display_list=("${display_list[@]%.mp3}")
			display_update
			;;

		*) true ;;
	esac
}



# ==============================================================================
# this part is mostly escape code wizardry
# we bake the variables and echo them when we need to
update_tab_bar(){ 
	local code0="\e[${fg0:=37};${bg0:=104}m"
	local code1="\e[${fg1:=37};${bg1:=105}m"
	local aritst_tab=" ${code0} artist"
	local album_tab=" ${code0} album"
	local song_tab=" ${code0} song"
	case $TAB in
		0) aritst_tab=" ${code1}>artist" ;;
		1) album_tab=" ${code1}>album" ;;
		2) song_tab=" ${code1}>song" ;;
	esac

	TAB_BAR=$(printf "\
\e[${tab_bar_position}H\
$code0%*s\r%s \
${aritst_tab}${album_tab}${song_tab}\
\e[m" \
"$tCOLUMNS" "|" "" )
}

update_title_bar() {
	local code0="\e[${MM_TITLE_FG:=31};${MM_TITLE_BG:=40}m"
	local len="${#MM_TITLE}"
	local spaces=$(( (tCOLUMNS-len) / 2 ))
	
	TITLE_BAR=$(printf "\
\e[${title_bar_position}H\
$code0%*s%s%*s" \
"$spaces" "" "$MM_TITLE" $((tCOLUMNS-spaces-len)) "")
}

update_song_bar() {
	local code0="\e[${MM_SONG_FG:=34};${MM_SONG_BG:=40}m"
	SONG_BAR=$(printf "\
\e[${song_bar_position}H\
${code0}%*s\r%s" \
"$tCOLUMNS" "" "$display_format")
}

update_vol_bar() {
	local code2="\e[${fg2:=31};${MM_VOLBAR_EMPTY_BG:=100}m"
	local code3="\e[${fg3:=37};${bg3:=42}m"
	local filled=$(($tCOLUMNS*volume/130))

	VOL_BAR=$( printf "\
\e[${vol_bar_position}H\
$code2%*s\r$code3%*s\r ${volume}\
\e[m" \
"$(($tCOLUMNS))" '|' "$filled" '|')
}

update_time_bar() {
	[[ -f $SHM_TIME ]] && time=$(<$SHM_TIME)
	[[ -z $time ]] && return
	local code2="\e[${fg2:=34};${MM_SEEKBAR_EMPTY_BG:=40}m"
	local code1="\e[${fg3:=37};${MM_SEEKBAR_FILED_BG:=44}m"
	time_bar_filled=$(($tCOLUMNS*$time/$maxtime))

	TIME_BAR=$( printf "\
\e[${time_bar_position}H\
$code2%*s\r$code1%*s\r ${time}\
\e[m" \
"$(($tCOLUMNS))" '|' "$time_bar_filled" '|')
}


# this is for the data that changes once whenever the ong changes
song_status_check() {
	[[ -f "$FILEPATHFILE" && "$file_path" != "$(<$FILEPATHFILE)" ]] && {

		display_format="playing : $(<$NAMEFILE) - $(<$ARTISTFILE) - $(<$ARLBUMFILE)"
		[[ -f $MAXTIMEFILE ]] && maxtime=$(<$MAXTIMEFILE)
		[[ -z $maxtime ]] && maxtime=100
		file_path=$(<$FILEPATHFILE)

		update_song_bar
		echo "$SONG_BAR"
	}
}
# ==============================================================================

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

	(( 0 > "$1" || "$1" > 2 )) && return 0

	TAB=$1
	echo $TAB > $MM_HOME/tab
	update_tab_bar
	print_page
}

select_item() {
	case "$TAB" in
		0)
			album_list=( "${artist_list[$1]}"/* )
			album_display_list=("${album_list[@]##*/}")
			t1cursor_item=0 
			go_tab 1
			;;
		1)
			song_list=( "${album_list[$1]}"/*.mp3 )
			song_display_list=( "${song_list[@]##*/*:}" )
			t2cursor_item=0
			go_tab 2
			;;
		2)
			$playescript enqueue $(($1+1)) "${song_list[@]}" &> /dev/null &
			;;
		*)
			command ...
			;;
	esac
}

select_all() {
	case "$TAB" in
		0)
			read_albums
			t1cursor_item=0 
			go_tab 1
			;;
		1)

			song_list=()
			for a in "${album_list[@]}"; do
				song_list+=( "$a"/*.mp3 )
			done
			song_display_list=( "${song_list[@]#$MUSICDIR/}" )
			song_display_list=("${song_display_list[@]/\/*:/ - }")
			t2cursor_item=0
			go_tab 2
			;;
		2)
			~/scripts/MusicMan/player.sh  queue "${song_list[@]}" &> /dev/null &
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
			if [[ $TAB == 1 ]]; then
				local alb_path="${album_list[$cursor_item]}"
				local alb=${alb_path##*/}
				local art_path=${alb_path%/*}
				local art=${art_path##*/}

				~/scripts/MusicMan/editor.sh reord "$art" "$alb"
			elif [[ $TAB == 2 ]]; then
				_mmGetTags "${song_list[$cursor_item]}"
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
			select_all
			;;
		
		c)
			open_cmd
			run_command "$last_cmd_reply"
			;;
		# playback Handle  VVV
		#
		$'\e2'|$'\e ') $playescript pause-play ;;
		$'\e1'|$'\es') 
			volume=$(($(cat /dev/shm/musicman/vol)-3))
			$playescript vdown 3 
			update_vol_bar
			echo "$VOL_BAR"
			;;
		$'\e3'|$'\ew') 
			volume=$(($(cat /dev/shm/musicman/vol)+3))
			$playescript vup 3
			update_vol_bar
			echo "$VOL_BAR"
			;;
		$'\ed') $playescript forward ;;
		$'\ea') $playescript backward ;;

		$'\ex') killall aplay ;;

		*)
			true
	esac
}

main() {
	mkdir -p $SHM_DIR
    ((BASH_VERSINFO[0] > 3)) &&
        read_flags=(-t 1)


	get_terminal_size
	clear_screan
	read_artists
	read_albums
	read_songs
	read_stats
	_mmGetVol
	update_title_bar
	update_song_bar
	update_tab_bar
	update_vol_bar
	update_time_bar
	print_page

	trap 'resized' WINCH

	while :; do
		read "${read_flags[@]}" -rsn1 && key "$REPLY"
        [[ -t 1 ]] || exit 1
		song_status_check
		update_vol_bar
		update_time_bar
		echo "$TIME_BAR"
		echo "$VOL_BAR"
		echo "$TAB_BAR"
	done
}

cursor_item=0
t0cursor_item=0
t1cursor_item=0
t2cursor_item=0

main "$@"
