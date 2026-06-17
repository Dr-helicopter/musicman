#!/usr/bin/env bash


SOCAT_NAME=musicman
MM_HOME="${XDG_STATE_HOME:-$HOME/.local/state}/musicman"
SHM_VOL="/dev/shm/musicman_volume"


control() {
echo "$1"  |
	socat - ABSTRACT-CONNECT:"$SOCAT_NAME" &> /dev/null ||
	return 2
}


command=$1
shift

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



volup() {
	if  (($volume >= 200)); then
		return
	fi

	((volume+=2))
	control '{ "command": ["set", "volume", "'${volume}'"] }' 
	echo $volume > $SHM_VOL
}

voldown() {
	if  (($volume <= 0)); then
		return
	fi
	((volume+=-2))
	control '{ "command": ["set", "volume", "'${volume}'"] }' 
	echo $volume > $SHM_VOL
}


save_to_disk() {
	[[ ! -f "$SHM_VOL" ]] && return

	mkdir -p "$MM_HOME"
	cat "$SHM_VOL" > "$MM_HOME/volume"
}

case $command in
	cf) 
		if [[ -S "$SOCAT_NAME" ]]; then
			echo yes 
		else 
			echo no 
		fi
		;;
	queue)
		mkdir -p $MM_HOME/queue
		rm $MM_HOME/queue/*
		for i in $(seq "$#"); do
			echo "${!i}"
			ln -s "${!i}" "$MM_HOME/queue/$(printf '%08d.mp4' "$i")"
		done
		mpv --no-video --volume="$volume" --input-ipc-server=@"$SOCAT_NAME" --quiet $MM_HOME/queue/
		save_to_disk
		;;
	play)
		mpv --no-video --volume="$volume" --input-ipc-server=@"$SOCAT_NAME" --quiet "$1"
		save_to_disk
		;;
	pause) control '{ "command": ["cycle", "pause"] }' ;;
	forward) control '{ "command": ["seek", "+2"] }' ;;
	backward) control '{ "command": ["seek", "-2"] }' ;;
	vdown) voldown ;;
	vup) volup ;;
esac
