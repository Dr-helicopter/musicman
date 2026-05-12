#!/usr/bin/env bash


SOCAT_NAME=musicman

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
	play)
		mpv --no-video --input-ipc-server=@"$SOCAT_NAME" --quiet "$1" & ;;
	pause) 
		echo '{ "command": ["cycle", "pause"] }' | 
		socat - ABSTRACT-CONNECT:"$SOCAT_NAME" &> /dev/null && 
		echo OK ||
		echo FUCK >&2
		;;
esac
