#!/usr/bin/env bash


SOCAT_NAME=musicman

command=$1
shift


command() {
echo "$1"  | 
		socat - ABSTRACT-CONNECT:"$SOCAT_NAME" &> /dev/null && 
		echo OK ||
		echo FUCK >&2

}


case $command in
	cf) 
		if [[ -S "$SOCAT_NAME" ]]; then
			echo yes 
		else 
			echo no 
		fi
		;;
	play)
		mpv --no-video --input-ipc-server=@"$SOCAT_NAME" --quiet "$1" & ;;
	pause) command '{ "command": ["cycle", "pause"] }' ;;
	vdown) command '{ "command": ["add", "volume", "-2"] }' ;;
	vup) command '{ "command": ["add", "volume", "+2"] }' ;;
esac
