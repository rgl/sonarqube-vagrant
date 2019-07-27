#!/bin/bash
set -eux

config_fqdn=$(hostname --fqdn)

#
# show summary.

sonarqube_version="$(curl -s localhost:9000/api/navigation/global | jq --raw-output '[.edition, .version] | join(" ")')"
echo "SonarQube $sonarqube_version is running at https://$config_fqdn"
echo 'The default user and password are admin'
echo "Check for updates at https://$config_fqdn/updatecenter/installed"
echo 'Check the logs with journalctl -u sonarqube and at /opt/sonarqube/logs'
