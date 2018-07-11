#!/bin/sh
##
## Setup ip6tables rules for forwarding trafic counters.
## Llorenç Cerdà-Alabern, July 2018

pid=$$

usage() {
    cat<<EOF
    Usage $(basename $0) [options] 
    options
        -h this help
        -d delete traffic rules
EOF
        exit 1
}

echoerr() { 
    echo "$@" 1>&2;
}

while getopts :hd a ; do
    case $a in
        \:|\?)  case $OPTARG in
            c) echo "-c requires <case> parameter" ;;
        *)  echo "Unknown option: -$OPTARG"
            echo "Try `basename $0` -h" ;;
    esac
    exit 1 ;;
    h) usage ;;
    d) DEL="true" ;;
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

add_chain() {
    local chain; chain=$(no_empty "$1")
    local user_chain; user_chain=$(no_empty "$2")
    if ip6tables -S | egrep -q "$user_chain" ; then
	echo "$user_chain already defined"
    else
	echo "adding chain $user_chain"
	ip6tables -N "$user_chain"
	ip6tables -A "$chain" -j "$user_chain"
    fi
}

del_chain() {
    local chain; chain=$(no_empty "$1")
    local user_chain; user_chain=$(no_empty "$2")
    if ip6tables -S | egrep -q "$user_chain" ; then
	echo "deleting chain $user_chain"
	ip6tables -F "$user_chain"
	ip6tables -D "$chain" -j "$user_chain"
	ip6tables -X "$user_chain"
    else
	echo "$user_chain not defined"
    fi
}

add_rule() {
    local user_chain; user_chain=$(no_empty "$1")
    local rule; rule=$(no_empty "$2")
    local ipv6; ipv6=$(no_empty "$3")
    if ip6tables -S | egrep -q "$rule $ipv6" ; then
	echo "rule '$rule $ipv6' already defined"
    else
	echo "adding rule '$rule $ipv6'"
	ip6tables -A "$user_chain" -$rule "$ipv6"
    fi
}

del_rule() {
    local user_chain; user_chain=$(no_empty "$1")
    local rule; rule=$(no_empty "$2")
    local ipv6; ipv6=$(no_empty "$3")
    if ip6tables -S | egrep -q "$rule $ipv6" ; then
	echo "deleting rule '$rule $ipv6'"
	ip6tables -D "$user_chain" -$rule "$ipv6"
    else
	echo "rule '$rule $ipv6' not defined"
    fi
}

get_ipv6_from_originators() { 
    bmx6 -c show=originators | sed -n "s/^.*\(fd66:[^ ]*\) .*fe80.*\$/\1/p"
}

setup_user_chains() {
    add_chain "FORWARD" "TRAFFIC_FORWARD_FROM"
}

del_user_chains() {
    del_chain "FORWARD" "TRAFFIC_FORWARD_FROM"
}

setup_forwarding_rules() {
    for ipv6 in $(get_ipv6_from_originators) ; do
	add_rule "TRAFFIC_FORWARD_FROM" "s" "$ipv6"
    done
}

del_forwarding_rules() {
    for ipv6 in $(get_ipv6_from_originators) ; do
	del_rule "TRAFFIC_FORWARD_FROM" "s" "$ipv6"
    done
}

if [ "$DEL" = "true" ] ; then
    del_forwarding_rules
    del_user_chains
else
    setup_user_chains
    setup_forwarding_rules
fi

# Local Variables:
# coding: utf-8
# mode: Shell-script
# End:
