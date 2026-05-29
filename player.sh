#!/usr/bin/env bash


SOCAT_NAME=musicman
MM_HOME="${XDG_STATE_HOME:-$HOME/.local/state}/muicman"

control() {
echo "$1"  | 
		socat - ABSTRACT-CONNECT:"$SOCAT_NAME" &> /dev/null ||
		exit 2
}


command=$1
shift


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
		mpv --no-video --input-ipc-server=@"$SOCAT_NAME" --quiet $MM_HOME/queue/
		;;
	play)
		mpv --no-video --input-ipc-server=@"$SOCAT_NAME" --quiet "$1" ;;
	pause) control '{ "command": ["cycle", "pause"] }' ;;
	forward) control '{ "command": ["seek", "+2"] }' ;;
	backward) control '{ "command": ["seek", "-2"] }' ;;
	vdown) control '{ "command": ["add", "volume", "-2"] }' ;;
	vup) control '{ "command": ["add", "volume", "+2"] }' ;;
esac
