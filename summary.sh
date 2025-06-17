#!/bin/bash
set -euxo pipefail

config_fqdn=$(hostname --fqdn)
config_sonarqube_admin_password=$1; shift

#
# show summary.

curl --silent --fail --show-error --user "admin:$config_sonarqube_admin_password" localhost:9000/api/plugins/installed \
    | jq --raw-output '.plugins[].key' \
    | sort \
    | xargs -I % echo 'installed plugin: %'
sonarqube_version="$(curl --silent --fail --show-error --user "admin:$config_sonarqube_admin_password" localhost:9000/api/navigation/global | jq --raw-output '[.edition, .version] | join(" ")')"
cat <<EOF
SonarQube $sonarqube_version

Access SonarQube at:

https://$config_fqdn

With the credentials:

Username: admin
Password: $config_sonarqube_admin_password

Check for updates at https://$config_fqdn/updatecenter/installed
Check the logs with journalctl -u sonarqube and at /opt/sonarqube/logs
EOF
