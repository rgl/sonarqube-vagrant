#!/bin/bash
set -eux

config_fqdn=$(hostname --fqdn)

#
# show summary.

echo "You can now access the SonarQube Web UI at https://$config_fqdn"
echo 'The default user and password are admin'
echo "Check for updates at https://$config_fqdn/updatecenter/installed"
echo 'Check the logs with journalctl -u sonarqube and at /opt/sonarqube/logs'
