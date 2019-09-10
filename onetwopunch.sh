#!/bin/bash 

# Colors
ESC="\e["
RESET=$ESC"39m"
RED=$ESC"31m"
GREEN=$ESC"32m"
BLUE=$ESC"34m"

function banner {
echo "                             _                                          _       _ "
echo "  ___  _ __   ___           | |___      _____    _ __  _   _ _ __   ___| |__   / \\"
echo " / _ \| '_ \ / _ \          | __\ \ /\ / / _ \  | '_ \| | | | '_ \ / __| '_ \ /  /"
echo "| (_) | | | |  __/ ᕦ(ò_óˇ)ᕤ | |_ \ V  V / (_) | | |_) | |_| | | | | (__| | | /\_/ "
echo " \___/|_| |_|\___|           \__| \_/\_/ \___/  | .__/ \__,_|_| |_|\___|_| |_\/   "
echo "                                                |_|                               "
echo "                                                                   by superkojiman"
echo ""
}

function usage {
    echo "Usage: $0 -t target [-p tcp/udp/all] [-i interface] [-n nmap-options] [-h]"
    echo "       -h: Help"
    echo "       -t: Target"
    echo "       -p: Protocol. Defaults to tcp"
    echo "       -i: Network interface. Defaults to eth0"
    echo "       -n: NMAP options (-A, -O, etc). Defaults to no options."
    echo "       -v: Debug, see commands and be verbose"
}


banner

if [[ ! $(id -u) == 0 ]]; then
    echo -e "${RED}[!]${RESET} This script must be run as root"
    usage
    exit 1
fi

if [[ -z $(which nmap) ]]; then
    echo -e "${RED}[!]${RESET} Unable to find nmap. Install it and make sure it's in your PATH   environment"
    exit 1
fi

if [[ -z $(which unicornscan) ]]; then
    echo -e "${RED}[!]${RESET} Unable to find unicornscan. Install it and make sure it's in your PATH environment"
    exit 1
fi

# commonly used default options
proto="tcp"
iface="eth0"
nmap_opt=""
target=""
debug=""

while getopts "p:i:t:n:vh" OPT; do
    case $OPT in
        p) proto=${OPTARG};;
        i) iface=${OPTARG};;
        t) target=${OPTARG};;
        n) nmap_opt=${OPTARG};;
        v) debug="-v";;
        h) usage; exit 0;;
        *) usage; exit 0;;
    esac
done

if [[ -z $target ]]; then
    echo "[!] No target file provided"
    usage
    exit 1
fi

if [[ ${proto} != "tcp" && ${proto} != "udp" && ${proto} != "all" ]]; then
    echo "[!] Unsupported protocol"
    usage
    exit 1
fi

echo -e "${BLUE}[+]${RESET} Protocol : ${proto}"
echo -e "${BLUE}[+]${RESET} Interface: ${iface}"
echo -e "${BLUE}[+]${RESET} Nmap opts: ${nmap_opt}"
echo -e "${BLUE}[+]${RESET} Target  : ${target}"

# backup any old scans before we start a new one
log_dir="$(pwd)/scans"
mkdir $log_dir
log_ip=$(echo $target | sed 's/\//-/g')
echo -e "${BLUE}[+]${RESET} Scanning $target for $proto ports..."

# unicornscan identifies all open TCP ports
if [[ $proto == "tcp" || $proto == "all" ]]; then 
    echo -e "${BLUE}[+]${RESET} Obtaining all open TCP ports using unicornscan..."
    if [[ ! -z $debug ]]; then
        echo -e "${BLUE}[+]${RESET} unicornscan $debug -i ${iface} -mT $target:a -l ${log_dir}/unicornscan-tcp.txt"
    fi
    unicornscan $debug -i ${iface} -mT $target:a -l ${log_dir}/unicornscan-tcp.txt
    ports=$(cat "${log_dir}/unicornscan-tcp.txt" | grep open | cut -d"[" -f2 | cut -d"]" -f1 | sed 's/ //g' | tr '\n' ',')
    if [[ ! -z $ports ]]; then 
        # nmap follows up
        echo -e "${GREEN}[*]${RESET} TCP ports for nmap to scan: $ports"
        if [[ ! -z $debug ]]; then
            echo -e "${BLUE}[+]${RESET} nmap $debug -e ${iface} ${nmap_opt} -oN ${log_dir}/nmap-tcp.txt -p ${ports} $target"
        fi
        nmap $debug -e ${iface} ${nmap_opt} -oN ${log_dir}/nmap-tcp.txt -p ${ports} $target
    else
        echo -e "${RED}[!]${RESET} No TCP ports found"
    fi
fi

# unicornscan identifies all open UDP ports
if [[ $proto == "udp" || $proto == "all" ]]; then  
    echo -e "${BLUE}[+]${RESET} Obtaining all open UDP ports using unicornscan..."
    if [[ ! -z $debug ]]; then
        echo -e "${BLUE}[+]${RESET} unicornscan $debug -i ${iface} -mU $target:a -l ${log_dir}/unicornscan-udp.txt"
    fi
    unicornscan $debug -i ${iface} -mU $target:a -l ${log_dir}/unicornscan-udp.txt
    ports=$(cat "${log_dir}/unicornscan-udp.txt" | grep open | cut -d"[" -f2 | cut -d"]" -f1 | sed 's/ //g' | tr '\n' ',')
    if [[ ! -z $ports ]]; then
        # nmap follows up
        echo -e "${GREEN}[*]${RESET} UDP ports for nmap to scan: $ports"
        if [[ ! -z $debug ]]; then
            echo -e "${BLUE}[+]${RESET} nmap $debug -e ${iface} ${nmap_opt} -sU -oN ${log_dir}/nmap-udp.txt -p ${ports} $target"
        fi
        nmap $debug -e ${iface} ${nmap_opt} -sU -oN ${log_dir}/nmap-udp.txt -p ${ports} $target
    else
        echo -e "${RED}[!]${RESET} No UDP ports found"
    fi
fi

echo -e "${BLUE}[+]${RESET} Scans completed"
echo -e "${BLUE}[+]${RESET} Results saved to ${log_dir}"

