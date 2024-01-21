#!/bin/bash

set -e

if [ ! "${DNSMASQ_USE_RESOLV}" = true ]; then 
    DNSMASQ_USE_RESOLV_OPTION="no-resolv"
    DNSMASQ_USE_POLL_OPTION="no-poll"
    if [ -z ${DNS_FORWARD_SERVER+x} ]; then
        DNS_FORWARD_SERVER_OPTION="server=8.8.8.8"
    else
    dnsserver_first_loop=1
        # $'\n' is a bashism
        for dnsserver in ${DNS_FORWARD_SERVER//,/ }; do
            (( ${dnsserver_first_loop} )) &&	
            DNS_FORWARD_SERVER_OPTION="server=${dnsserver}" ||
            DNS_FORWARD_SERVER_OPTION="${DNS_FORWARD_SERVER_OPTION}"$'\n'"server=${dnsserver}"
            unset dnsserver_first_loop
        done
        unset dnsserver
    fi
else
    if [ ! -z ${DNS_FORWARD_SERVER+x} ]; then
        dnsserver_first_loop=1
        # $'\n' is a bashism
        for dnsserver in ${DNS_FORWARD_SERVER//,/ }; do
            (( ${dnsserver_first_loop} )) &&	
            DNS_FORWARD_SERVER_OPTION="server=${dnsserver}" ||
            DNS_FORWARD_SERVER_OPTION="${DNS_FORWARD_SERVER_OPTION}"$'\n'"server=${dnsserver}"
            unset dnsserver_first_loop
        done
        unset dnsserver
    fi
fi


if [ "${DNSSEC}" = true ] ; then
    DNSMASQ_DNSSEC="dnssec"
    if [ "${DNSMASQ_DNSSEC_CHECK_UNSIGNED}" = true ]; then DNSMASQ_DNSSEC_CHECK_UNSIGNED_OPTION="dnssec-check-unsigned"; fi
    DNSMASQ_DNSSEC_TRUST="conf-file=/etc/dnsmasq-trust-anchors.conf"
fi

if [ "${DHCP}" = true ] ; then
    if [ -z ${DNSMASQ_DHCP_START_RANGE+x} ]; then echo "DNSMASQ_DHCP_START_RANGE is not set. Exiting"; exit 1 ; fi
    if [ -z ${DNSMASQ_DHCP_END_RANGE+x} ]; then echo "DNSMASQ_DHCP_END_RANGE is not set. Exiting"; exit 1 ; fi
    if [ -z ${DNSMASQ_DHCP_NETMASK_RANGE+x} ]; then echo "DNSMASQ_DHCP_NETMASK_RANGE is not set. Exiting"; exit 1 ; fi
    if [ -z ${DNSMASQ_DHCP_GATEWAY+x} ]; then echo "DNSMASQ_DHCP_GATEWAY is not set. Exiting"; exit 1 ; fi
    if [ -z ${DNSMASQ_DHCP_DNS+x} ]; then echo "DNSMASQ_DHCP_DNS is not set. Exiting"; exit 1 ; fi
    DNSMASQ_DHCP_HOSTSFILE="dhcp-hostsfile=/var/lib/misc/dhcp-hostsfile"
    DNSMASQ_DHCP_RANGE="dhcp-range=${DNSMASQ_DHCP_START_RANGE},${DNSMASQ_DHCP_END_RANGE},${DNSMASQ_DHCP_NETMASK_RANGE},${DNSMASQ_DHCP_LEASE_TIME:-12h}"
    DNSMASQ_DHCP_ROUTER="dhcp-option=option:router,${DNSMASQ_DHCP_GATEWAY}"
    DNSMASQ_DHCP_DNS_OPTION="dhcp-option=option:dns-server,${DNSMASQ_DHCP_DNS}"
    DNSMASQ_DHCP_DOMAINNAME_OPTION="dhcp-option=option:domain-name,${DNS_LOCAL_DOMAIN:-local}"
    DNSMASQ_DHCP_DOMAINNAME_SEARCH_OPTION="dhcp-option=option:domain-search,${DNS_LOCAL_DOMAIN:-local}"
    if [ ! -z ${DNSMASQ_DHCP_NTP+x} ]; then DNSMASQ_DHCP_NTP_OPTION="dhcp-option=option:ntp-server,${DNSMASQ_DHCP_NTP}" ; fi
    if [ ! -z ${DNSMASQ_DHCP_WPAD+x} ]; then DNSMASQ_DHCP_WPAD_OPTION="dhcp-option=252,\"${DNSMASQ_DHCP_WPAD}\"" ; else DNSMASQ_DHCP_WPAD_OPTION="dhcp-option=252,\"\n\"" ; fi
    DNSMASQ_DHCP_MS_RELEASE="dhcp-option=vendor:MSFT,2,1i"
    DNSMASQ_MAX_LEASE_OPTION="dhcp-lease-max=${DNSMASQ_MAX_LEASE_OPTION:-150}"
    if [ "${DNSMASQ_RAPID_COMMIT}" = true ] ; then
        DNSMASQ_RAPID_COMMIT_OPTION="dhcp-rapid-commit"
    fi
    if [ "${DNSMASQ_AUTHORITATIVE}" = true ] ; then
        DNSMASQ_AUTHORITATIVE_OPTION="dhcp-authoritative"
    fi
fi

touch /var/lib/misc/dhcp-hostsfile

cat <<EOF | grep -v ^$ > /etc/dnsmasq-base.conf
keep-in-foreground
${DNSMASQ_DNSSEC:-}
${DNSMASQ_DNSSEC_CHECK_UNSIGNED_OPTION:-}
${DNSMASQ_DNSSEC_TRUST:-}
port=${DNS_PORT:-53}
${DNS_FORWARD_SERVER_OPTION:-}
all-servers
domain=${DNS_LOCAL_DOMAIN:-local}
domain-needed
bogus-priv
no-hosts
${DNSMASQ_USE_RESOLV_OPTION:-}
${DNSMASQ_USE_POLL_OPTION:-}
log-facility=-
dhcp-leasefile=/var/lib/misc/dnsmasq.leases
dhcp-name-match=set:wpad-ignore,wpad
dhcp-ignore-names=tag:wpad-ignore
stop-dns-rebind
no-round-robin
no-negcache
no-ident
rebind-domain-ok=${DNS_LOCAL_DOMAIN:-local}
${DNSMASQ_DHCP_RANGE:-}
${DNSMASQ_DHCP_ROUTER:-}
${DNSMASQ_DHCP_HOSTSFILE:-}
${DNSMASQ_DHCP_DNS_OPTION:-}
${DNSMASQ_DHCP_DOMAINNAME_OPTION:-}
${DNSMASQ_DHCP_DOMAINNAME_SEARCH_OPTION:-}
${DNSMASQ_DHCP_NTP_OPTION:-}
${DNSMASQ_DHCP_WPAD_OPTION:-}
${DNSMASQ_DHCP_MS_RELEASE:-}
${DNSMASQ_MAX_LEASE_OPTION:-}
${DNSMASQ_RAPID_COMMIT_OPTION:-}
${DNSMASQ_AUTHORITATIVE_OPTION:-}
EOF

echo -n "container-dnsmasq ip adddresses: /"

for ip in $(ip -json addr list dev $(ip -json route list default | jq -r .[].dev) | jq -r .[].addr_info[].local); do
    echo -n "/ ${ip} /"
done

echo "/"

exec -c /usr/sbin/dnsmasq
