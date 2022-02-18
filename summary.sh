#!/bin/bash
set -euxo pipefail

config_fqdn=$(hostname --fqdn)

#
# show summary.

curl --silent --fail --show-error --user admin:password localhost:9000/api/plugins/installed \
    | jq --raw-output '.plugins[].key' \
    | sort \
    | xargs -n 1 -I % echo 'installed plugin: %'
sonarqube_version="$(curl --silent --fail --show-error --user admin:password localhost:9000/api/navigation/global | jq --raw-output '[.edition, .version] | join(" ")')"
echo "SonarQube $sonarqube_version is running at https://$config_fqdn"
echo 'The default user and password are admin'
echo "Check for updates at https://$config_fqdn/updatecenter/installed"
echo 'Check the logs with journalctl -u sonarqube and at /opt/sonarqube/logs'
