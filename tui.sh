#!/bin/bash

source ./main.sh



clear_screan() {
	printf '\e[2J'
}

print_artist() {
	printf '\e[6H'
	i=0
	for art in $MUSICDIR/*
	do
		printf '%s > %s\n' $((i++)) "${art#$MUSICDIR/}"
		
	done
}

print_album() {
	printf '\e[6H'
	i=0
	for art in $MUSICDIR/*/*
	do
		printf '%s > %s\n' $((i++)) "${art#$MUSICDIR/}"
		
	done
}


print_page() {
	clear_screan
	case $page in
		'art') print_artist ;;
		'alb') print_album ;;
		*) true ;;
	esac
}





main() {
	page=art
		for ((;;)); {
		print_page
			
		read key


		if [[ $key = 'q' ]]; then
			exit 0
		fi

		if [[ $key = 'al' ]]; then
			page=alb
		fi

		if [[ $key = 'ar' ]]; then
			page=art
		fi
	}
}


main "$@"
