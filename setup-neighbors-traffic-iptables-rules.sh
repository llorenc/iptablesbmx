#!/bin/sh
##
## Setup ip6tables rules for neighbor links trafic counters.
## Llorenç Cerdà-Alabern, July 2018

pid=$$

usage() {
    cat<<EOF
    Usage $(basename $0) [options] 
    options
        -h this help
        -d delete traffic rules
        -s show rules added to ip6tables
        -l print information of the bmx links
        -p print ip6tables counters
EOF
        exit 1
}

echoerr() { 
    echo "$@" 1>&2;
}

while getopts :hdslp a ; do
    case $a in
        \:|\?)  case $OPTARG in
            c) echo "-c requires <case> parameter" ;;
        *)  echo "Unknown option: -$OPTARG"
            echo "Try `basename $0` -h" ;;
    esac
    exit 1 ;;
    h) usage ;;
    d) DEL="true" ;;
    s) SHOWRULES="true" ;;
    l) PRINTLILNKS="true" ;;
    p) PRINTCOUNTERS="true"
    esac
done
shift $(expr $OPTIND - 1)
if [ $# -ne 0 ] ; then
    usage
fi

no_empty() {
    tag="$1"
    if [ "$tag" = "" ] ; then
	echoerr "empty tag?"
	kill "$pid"
	exit 1
    fi
    echo "$tag"
}

add_table_chain() {
    local table; table=$(no_empty "$1")
    local chain; chain=$(no_empty "$2")
    local user_chain; user_chain=$(no_empty "$3")
    if ip6tables -t $table -S | egrep -q "$user_chain" ; then
	echo "$user_chain already defined"
    else
	echo "adding chain $user_chain"
	ip6tables -t $table -N "$user_chain"
	ip6tables -t $table -A "$chain" -j "$user_chain"
    fi
}

del_table_chain() {
    local table; table=$(no_empty "$1")
    local chain; chain=$(no_empty "$2")
    local user_chain; user_chain=$(no_empty "$3")
    if ip6tables -t $table -S | egrep -q "$user_chain" ; then
	echo "deleting chain $user_chain"
	ip6tables -t $table -F "$user_chain"
	ip6tables -t $table -D "$chain" -j "$user_chain"
	ip6tables -t $table -X "$user_chain"
    else
	echo "$user_chain not defined"
    fi
}

add_table_mac_dev_rule() {
    local table; table=$(no_empty "$1")
    local user_chain; user_chain=$(no_empty "$2")
    local mac; mac=$(no_empty "$3")
    local dev; dev=$(no_empty "$4")
    if ip6tables -t $table -S | egrep -iq "$mac" ; then
	echo "mac rule '$mac' already defined"
    else
	echo "adding mac rule '$mac'"
	ip6tables -t $table -A "$user_chain" -m mac --mac-source "$mac" -i "$dev"
    fi
}

del_table_mac_dev_rule() {
    local table; table=$(no_empty "$1")
    local user_chain; user_chain=$(no_empty "$2")
    local mac; mac=$(no_empty "$3")
    local dev; dev=$(no_empty "$4")
    if ip6tables -t $table -S | egrep -iq "$mac" ; then
	echo "deleting mac rule '$mac'"
	echo ip6tables -t $table -D "$user_chain" -m mac --mac-source "$mac" -i "$dev"
    else
	echo "mac rule '$mac' not defined"
    fi
}

# return ipv6ll and device of every bmx6 link
get_bmx_links() {
    bmx6 -c links | awk '/fe80/{print $2 " " $3}'
}

# return the mac address of neighbor ipv6ll in interface dev 
get_neighbor_mac() {
    local ipll; ipll=$(no_empty "$1")
    local dev; dev=$(no_empty "$2")
    ip -s nei s to $ipll dev $dev | awk '{print $3}'
}

setup_prerouting_mac_rules() {
    get_bmx_links |
	while read ipll dev
	do 
	    mac=$(get_neighbor_mac "$ipll" "$dev")
	    add_table_mac_dev_rule "raw" "TRAFFIC_PREROUTING_FROM" "$mac" "$dev" 
	done
}

del_prerouting_mac_rules() {
    get_bmx_links |
	while read ipll dev
	do 
	    mac=$(get_neighbor_mac "$ipll" "$dev")
	    del_table_mac_dev_rule "raw" "TRAFFIC_PREROUTING_FROM" "$mac" "$dev" 
	done
}

if [ "$SHOWRULES" = "true" ] ; then
    ip6tables-save | sed -n /:TRAFFIC_PREROUTING_FROM/,/COMMIT/p
    exit 0
fi

if [ "$PRINTLILNKS" = "true" ] ; then
    bmx6 -c links | awk '/fe80/{print $1 " " $2 " " $3}' |
	while read node ipll dev
	do 
	    mac=$(get_neighbor_mac "$ipll" "$dev")
	    echo "link: $node, ipll: $ipll, mac: $mac, dev: $dev"
	done
    exit 0
fi

if [ "$PRINTCOUNTERS" = "true" ] ; then
    ip6tables -t raw -L TRAFFIC_PREROUTING_FROM -nvx
    exit 0
fi

if [ "$DEL" = "true" ] ; then
    del_prerouting_mac_rules
    del_table_chain "raw" "PREROUTING" "TRAFFIC_PREROUTING_FROM"
else
    add_table_chain "raw" "PREROUTING" "TRAFFIC_PREROUTING_FROM"
    setup_prerouting_mac_rules
fi

# Local Variables:
# coding: utf-8
# mode: Shell-script
# End:
