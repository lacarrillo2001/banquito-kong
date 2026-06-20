#!/bin/sh
set -eu

template="$(cat /kong/kong.yml.template)"

eval "cat <<EOF
$template
EOF
" > /tmp/kong.yml

deck gateway sync /tmp/kong.yml --kong-addr http://kng-gateway:8001
