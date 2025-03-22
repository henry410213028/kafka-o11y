#!/bin/sh

CONFIG_TEMPLATE_FILE="/etc/jmx_exporter/config.yaml.template"
CONFIG_FILE="/tmp/config.yaml"

required_vars="JMX_HOST JMX_PORT"

for var in $required_vars; do
    eval "value=\${$var}"
    if [ -z "$value" ]; then
        echo "$var Environment variable is required!!"
        exit 1
    fi
done

sed_args=""
for var in $required_vars; do
    eval "value=\${$var}"
    sed_args="$sed_args -e 's|\\\${$var}|$value|g'"
done

eval "sed $sed_args \"$CONFIG_TEMPLATE_FILE\" > \"$CONFIG_FILE\""

java -jar jmx_prometheus_standalone.jar 7071 "$CONFIG_FILE"
