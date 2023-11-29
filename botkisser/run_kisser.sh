#!/bin/bash

while true; do
	../luvit main.lua
	
	command=$(<bot_command.txt)

	if [[ $command == "update" ]]; then
		git pull --quiet
	 	continue
	elif [[ $command == "stop" ]]; then
		exit 0
	elif [[ $command == "error" ]]; then
		echo "bruh"
	fi
	sleep 1
done

