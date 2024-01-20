#!/bin/bash

set -e

if [ "${DNSSEC}" = true ] ; then
    DNSMASQ_DNSSEC="dnssec"
    DNSMASQ_DNSSEC_UNSIGNED="dnssec-check-unsigned"
    DNSMASQ_DNSSEC_TRUST="conf-file=/etc/dnsmasq-trust-anchors.conf"
fi

if [ "${DHCP}" = true ] ; then
    if [ -z ${DNSMASQ_DHCP_START_RANGE+x} ]; then echo "DNSMASQ_DHCP_START_RANGE is not set. Exiting"; exit 1 ; fi
    if [ -z ${DNSMASQ_DHCP_END_RANGE+x} ]; then echo "DNSMASQ_DHCP_END_RANGE is not set. Exiting"; exit 1 ; fi
    if [ -z ${DNSMASQ_DHCP_NETMASK_RANGE+x} ]; then echo "DNSMASQ_DHCP_NETMASK_RANGE is not set. Exiting"; exit 1 ; fi
    if [ -z ${DNSMASQ_DHCP_GATEWAY+x} ]; then echo "DNSMASQ_DHCP_GATEWAY is not set. Exiting"; exit 1 ; fi
    DNSMASQ_DHCP_RANGE="dhcp-range=${DNSMASQ_DHCP_START_RANGE},${DNSMASQ_DHCP_END_RANGE},${DNSMASQ_DHCP_NETMASK_RANGE},${DNSMASQ_DHCP_LEASE_TIME:-12h}"
    DNSMASQ_DHCP_ROUTER="dhcp-option=option:router,${DNSMASQ_DHCP_GATEWAY}"
    if [ ! -z ${DNSMASQ_DHCP_NTP+x} ]; then DNSMASQ_DHCP_NTP_OPTION="dhcp-option=option:ntp-server,${DNSMASQ_DHCP_NTP}" ; fi
    if [ ! -z ${DNSMASQ_DHCP_WPAD+x} ]; then DNSMASQ_DHCP_WPAD_OPTION="dhcp-option=252,\"${DNSMASQ_DHCP_WPAD}\"" ; else DNSMASQ_DHCP_WPAD_OPTION="dhcp-option=252,\"\n\"" ; fi
    DNSMASQ_DHCP_MS_RELEASE='dhcp-option=vendor:MSFT,2,1i'
    DNSMASQ_MAX_LEASE_OPTION=${DNSMASQ_MAX_LEASE_OPTION:-150}
    if [ "${DNSMASQ_RAPID_COMMIT}" = true ] ; then
        DNSMASQ_RAPID_COMMIT_OPTION="dhcp-rapid-commit"
    fi
    if [ "${DNSMASQ_AUTHORITATIVE}" = true ] ; then
        DNSMASQ_AUTHORITATIVE_OPTION="dhcp-authoritative"
    fi
fi

cat <<EOF >/etc/dnsmasq-base.conf
${DNSMASQ_DNSSEC:-}
${DNSMASQ_DNSSEC_UNSIGNED:-}
${DNSMASQ_DNSSEC_TRUST:-}
port=${DNS_PORT:-53}
server=${DNS_FORWARD_SERVER:-8.8.8.8}
domain=${DNS_LOCAL_DOMAIN:-local}
domain-needed
bogus-priv
no-hosts
no-resolv
no-poll
except-interface=nonexisting
log-facility=-
dhcp-leasefile=/var/lib/misc/dnsmasq.leases
dhcp-name-match=set:wpad-ignore,wpad
dhcp-ignore-names=tag:wpad-ignore
stop-dns-rebind
no-negcache
rebind-domain-ok=${DNS_LOCAL_DOMAIN:-local}
${DNSMASQ_DHCP_RANGE:-}
${DNSMASQ_DHCP_ROUTER:-}
${DNSMASQ_DHCP_NTP_OPTION:-}
${DNSMASQ_DHCP_WPAD_OPTION:-}
${DNSMASQ_DHCP_MS_RELEASE:-}
${DNSMASQ_MAX_LEASE_OPTION:-}
${DNSMASQ_RAPID_COMMIT_OPTION:-}
${DNSMASQ_AUTHORITATIVE_OPTION:-}

EOF

exec -c /usr/sbin/dnsmasq -k
