#!/usr/bin/env bash
# Route laptop pengguna -> VPS (video /test dan memo /ndn/memo)
VPS="udp4://10.10.10.1"
for i in $(seq 1 30); do nfdc status > /dev/null 2>&1 && break; sleep 1; done
nfdc face create "$VPS" persistency permanent mtu 1380 \
  || nfdc face create "$VPS" persistency permanent
nfdc route add /test "$VPS"
nfdc route add /ndn/memo "$VPS"
