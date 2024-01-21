FROM alpine:latest as trust-anchor

RUN apk --no-cache add curl gawk grep \
    && curl -sSL https://data.iana.org/root-anchors/root-anchors.xml | gawk -F'[<>]' '/KeyTag/  { printf "trust-anchor=.,%s", $3 ; next } /Algorithm/ { printf ",%s", $3 ; next } /DigestType/ { printf ",%s", $3 ; next } /Digest/ { printf ",%s\n", $3 ; next } ' | grep ^trust-anchor | tail -n1  > /trust-anchors.conf 

FROM alpine:latest

# Why bash, not sh? sh exec exits on signals like HUP and TERM. bash does not.

RUN apk --no-cache add bash catatonit dnsmasq-dnssec iproute2-minimal jq \
    && echo -en 'conf-file=/etc/dnsmasq-base.conf\nconf-dir=/etc/dnsmasq.d,*.conf' > /etc/dnsmasq.conf

COPY --from=trust-anchor --chmod=0644 /trust-anchors.conf /etc/dnsmasq-trust-anchors.conf
COPY --chown=root:root --chmod=0755 ./entrypoint.sh /entrypoint.sh

EXPOSE 53/tcp 53/udp 67/tcp 67/udp

VOLUME /etc/dnsmasq.d/
VOLUME /var/lib/misc/
ENTRYPOINT ["/usr/bin/catatonit", "--", "/entrypoint.sh"]
