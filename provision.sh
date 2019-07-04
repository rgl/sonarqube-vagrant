#!/bin/bash
set -eux

config_fqdn=$(hostname --fqdn)

# use the built-in user database.
config_authentication='sonarqube'
# OR also use LDAP.
# NB this assumes you are running the Active Directory from https://github.com/rgl/windows-domain-controller-vagrant.
# NB AND you must manually copy its tmp/ExampleEnterpriseRootCA.der file to this environment tmp/ directory.
#config_authentication='ldap'


#
# configure apt.

echo 'Defaults env_keep += "DEBIAN_FRONTEND"' >/etc/sudoers.d/env_keep_apt
chmod 440 /etc/sudoers.d/env_keep_apt
export DEBIAN_FRONTEND=noninteractive
apt-get update


#
# disable IPv6.

cat>/etc/sysctl.d/98-disable-ipv6.conf<<'EOF'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
systemctl restart procps
sed -i -E 's,(GRUB_CMDLINE_LINUX=.+)",\1 ipv6.disable=1",' /etc/default/grub
update-grub2


#
# configure the firewall.

apt-get install -y iptables iptables-persistent
# reset the firewall.
# see https://wiki.archlinux.org/index.php/iptables
for table in raw filter nat mangle; do
    iptables -t $table -F
    iptables -t $table -X
done
for chain in INPUT FORWARD OUTPUT; do
    iptables -P $chain ACCEPT
done
# set the default policy to block incomming traffic.
iptables -P INPUT DROP
iptables -P FORWARD DROP
# allow incomming traffic on the loopback interface.
iptables -A INPUT -i lo -j ACCEPT
# allow incomming established sessions.
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
# allow incomming ICMP.
iptables -A INPUT -p icmp --icmp-type any -j ACCEPT
# allow incomming SSH connections.
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
# allow incomming HTTP(S) connections.
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
# load iptables rules on boot.
iptables-save >/etc/iptables/rules.v4


#
# provision vim.

apt-get install -y --no-install-recommends vim

cat>~/.vimrc<<'EOF'
syntax on
set background=dark
set esckeys
set ruler
set laststatus=2
set nobackup
EOF


#
# configure the shell.

cat>~/.bash_history<<'EOF'
vim /opt/sonarqube/conf/sonar.properties
systemctl stop sonarqube
systemctl restart sonarqube
journalctl -u sonarqube --follow
tail -f /opt/sonarqube/logs/access.log
tail -f /opt/sonarqube/logs/sonar.log
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
EOF

cat>~/.bashrc<<'EOF'
# If not running interactively, don't do anything
[[ "$-" != *i* ]] && return

export EDITOR=vim
export PAGER=less

alias l='ls -lF --color'
alias ll='l -a'
alias h='history 25'
alias j='jobs -l'
EOF

cat>~/.inputrc<<'EOF'
"\e[A": history-search-backward
"\e[B": history-search-forward
"\eOD": backward-word
"\eOC": forward-word
set show-all-if-ambiguous on
set completion-ignore-case on
EOF


#
# create a self-signed certificate.

pushd /etc/ssl/private
openssl genrsa \
    -out $config_fqdn-keypair.pem \
    2048 \
    2>/dev/null
chmod 400 $config_fqdn-keypair.pem
openssl req -new \
    -sha256 \
    -subj "/CN=$config_fqdn" \
    -key $config_fqdn-keypair.pem \
    -out $config_fqdn-csr.pem
openssl x509 -req -sha256 \
    -signkey $config_fqdn-keypair.pem \
    -extensions a \
    -extfile <(echo "[a]
        subjectAltName=DNS:$config_fqdn
        extendedKeyUsage=serverAuth
        ") \
    -days 365 \
    -in  $config_fqdn-csr.pem \
    -out $config_fqdn-crt.pem
popd


#
# setup nginx proxy to SonarQube that is running at localhost:9000.

apt-get install -y --no-install-recommends nginx
cat >/etc/nginx/sites-available/sonarqube <<EOF
ssl_session_cache shared:SSL:4m;
ssl_session_timeout 6h;
#ssl_stapling on;
#ssl_stapling_verify on;
server {
    listen 80;
    server_name _;
    return 301 https://$config_fqdn\$request_uri;
}
server {
    listen 443 ssl http2;
    server_name $config_fqdn;
    ssl_certificate /etc/ssl/private/$config_fqdn-crt.pem;
    ssl_certificate_key /etc/ssl/private/$config_fqdn-keypair.pem;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    # see https://github.com/cloudflare/sslconfig/blob/master/conf
    # see https://blog.cloudflare.com/it-takes-two-to-chacha-poly/
    # see https://blog.cloudflare.com/do-the-chacha-better-mobile-performance-with-cryptography/
    # NB even though we have CHACHA20 here, the OpenSSL library that ships with Ubuntu 16.04 does not have it. so this is a nop. no problema.
    ssl_ciphers EECDH+CHACHA20:EECDH+AES128:RSA+AES128:EECDH+AES256:RSA+AES256:EECDH+3DES:RSA+3DES:!aNULL:!MD5;
    add_header Strict-Transport-Security "max-age=31536000; includeSubdomains";
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    client_max_body_size 50m;
    location = /favicon.ico {
        return 204;
        access_log off;
        log_not_found off;
    }
    location / {
        root /opt/sonarqube/web;
        try_files \$uri @sonarqube;
    }
    location @sonarqube {
        proxy_pass http://localhost:9000;
        proxy_redirect http://localhost:9000/ /;    # needed for the SonarQube Runners to push the report to this SonarQube instance.
        proxy_redirect https://localhost:9000/ /;   # needed for the SonarQube Web Application links.
    }
}
EOF
rm /etc/nginx/sites-enabled/default
ln -s ../sites-available/sonarqube /etc/nginx/sites-enabled/sonarqube
systemctl restart nginx


#
# install postgres.

apt-get install -y --no-install-recommends postgresql

# create user and database.
postgres_sonarqube_password=$(openssl rand -hex 32)
sudo -sHu postgres psql -c "create role sonarqube login password '$postgres_sonarqube_password'"
sudo -sHu postgres createdb -E UTF8 -O sonarqube sonarqube


#
# install SonarQube.

# install dependencies.
apt-get install -y openjdk-8-jre-headless
apt-get install -y unzip
apt-get install -y dos2unix
apt-get install -y --no-install-recommends gnupg

# add the sonarqube user.
groupadd --system sonarqube
adduser \
    --system \
    --disabled-login \
    --no-create-home \
    --gecos '' \
    --ingroup sonarqube \
    --home /opt/sonarqube \
    sonarqube
install -d -o root -g sonarqube -m 751 /opt/sonarqube

# import sonarqube key. gpg --list-keys --fingerprint should output:
#   pub   rsa2048 2015-05-25 [SC]
#         F118 2E81 C792 9289 21DB  CAB4 CFCA 4A29 D264 68DE
#   uid           [ unknown] sonarsource_deployer (Sonarsource Deployer) <infra@sonarsource.com>
#   sub   rsa2048 2015-05-25 [E]
gpg --keyserver ha.pool.sks-keyservers.net --recv-keys F1182E81C792928921DBCAB4CFCA4A29D26468DE \
    || gpg --keyserver ipv4.pool.sks-keyservers.net --recv-keys F1182E81C792928921DBCAB4CFCA4A29D26468DE

# download and install SonarQube LTS.
pushd /opt/sonarqube
sonarqube_version=6.7.7
sonarqube_directory_name=sonarqube-$sonarqube_version
sonarqube_artifact=$sonarqube_directory_name.zip
sonarqube_download_url=https://binaries.sonarsource.com/Distribution/sonarqube/$sonarqube_artifact
sonarqube_download_sig_url=$sonarqube_download_url.asc
wget -q $sonarqube_download_url
wget -q $sonarqube_download_sig_url
gpg --batch --verify $sonarqube_artifact.asc $sonarqube_artifact
unzip -q $sonarqube_artifact
mv $sonarqube_directory_name/* .
rm -rf $sonarqube_directory_name bin $sonarqube_artifact*
for d in data logs temp extensions; do
    chmod 700 $d
    chown -R sonarqube:sonarqube $d
done
chown -R root:sonarqube conf
chmod 750 conf
chmod 640 conf/*
dos2unix conf/*
popd

# configure it to use PostgreSQL
sed -i -E 's,^#?(sonar.jdbc.username=).*,\1sonarqube,' /opt/sonarqube/conf/sonar.properties
sed -i -E "s,^#?(sonar.jdbc.password=).*,\1$postgres_sonarqube_password," /opt/sonarqube/conf/sonar.properties
sed -i -E 's,^#?(sonar.jdbc.url=jdbc:postgresql://).*,\1localhost/sonarqube,' /opt/sonarqube/conf/sonar.properties
# configure it to only listen at localhost (nginx will proxy to it).
sed -i -E 's,^#?(sonar.web.host=).*,\1127.0.0.1,' /opt/sonarqube/conf/sonar.properties

# start it.
cat >/etc/systemd/system/sonarqube.service <<EOF
[Unit]
Description=sonarqube
After=network.target

[Service]
Type=simple
User=sonarqube
Group=sonarqube
WorkingDirectory=/opt/sonarqube
ExecStart=/usr/bin/java \
    -jar /opt/sonarqube/lib/sonar-application-$sonarqube_version.jar \
    -Dsonar.log.console=true
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl enable sonarqube
systemctl start sonarqube

# wait for it to come up.
apt-get install -y --no-install-recommends curl
apt-get install -y --no-install-recommends jq
function wait_for_ready {
    sleep 5
    bash -c 'while [[ "$(curl -s localhost:9000/api/system/status | jq --raw-output ''.status'')" != "UP" ]]; do sleep 5; done'
}
wait_for_ready

# list out-of-box installed plugins. at the time of writing they were:
#   csharp
#   flex
#   java
#   javascript
#   php
#   python
#   scmgit
#   scmsvn
#   typescript
#   xml
curl -s -u admin:admin localhost:9000/api/plugins/installed \
    | jq --raw-output '.plugins[].key' \
    | sort \
    | xargs -n 1 -I % echo 'out-of-box installed plugin: %'

# update the existing plugins.
curl -s -u admin:admin localhost:9000/api/plugins/updates \
    | jq --raw-output '.plugins[].key' \
    | xargs -n 1 -I % curl -s -u admin:admin -X POST localhost:9000/api/plugins/update -d 'key=%'

# install new plugins.
plugins=(
    'ldap'            # https://docs.sonarqube.org/display/PLUG/LDAP+Plugin
    'checkstyle'      # https://github.com/checkstyle/sonar-checkstyle
)
for plugin in "${plugins[@]}"; do
    echo "installing the $plugin plugin..."
    curl -s -u admin:admin -X POST localhost:9000/api/plugins/install -d "key=$plugin"
done
echo 'restarting SonarQube...'
curl -s -u admin:admin -X POST localhost:9000/api/system/restart
wait_for_ready

#
# use LDAP for user authentication (when enabled).
# NB this assumes you are running the Active Directory from https://github.com/rgl/windows-domain-controller-vagrant.
# see https://docs.sonarqube.org/display/PLUG/LDAP+Plugin
if [ "$config_authentication" = 'ldap' ]; then
echo '192.168.56.2 dc.example.com' >>/etc/hosts
openssl x509 -inform der -in /vagrant/tmp/ExampleEnterpriseRootCA.der -out /usr/local/share/ca-certificates/ExampleEnterpriseRootCA.crt
update-ca-certificates
cat >>/opt/sonarqube/conf/sonar.properties <<'EOF'


#--------------------------------------------------------------------------------------------------
# LDAP

# General Configuration.
sonar.security.realm=LDAP
ldap.url=ldaps://dc.example.com
ldap.bindDn=jane.doe@example.com
ldap.bindPassword=HeyH0Password

# User Configuration.
ldap.user.baseDn=CN=Users,DC=example,DC=com
ldap.user.request=(&(sAMAccountName={login})(objectClass=person)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))
ldap.user.realNameAttribute=displayName
ldap.user.emailAttribute=mail

# Group Configuration.
ldap.group.baseDn=CN=Users,DC=example,DC=com
ldap.group.request=(&(objectClass=group)(member={dn}))
ldap.group.idAttribute=sAMAccountName

EOF
echo 'restarting SonarQube...'
systemctl restart sonarqube
wait_for_ready

echo 'creating the Domain Admins group...'
curl -s -u admin:admin -X POST localhost:9000/api/user_groups/create -d 'name=Domain Admins'
domain_admins_permissions=(
    'admin'
    'profileadmin'
    'gateadmin'
    'provisioning'
)
for permission in "${domain_admins_permissions[@]}"; do
    echo "adding the $permission permission to the Domain Admins group..."
    curl -s -u admin:admin -X POST localhost:9000/api/permissions/add_group -d 'groupName=Domain Admins' -d "permission=$permission"
done
fi

#
# build some Java projects and send them to SonarQube.
# see https://docs.sonarqube.org/display/SCAN/Analyzing+with+SonarQube+Scanner

apt-get install -y --no-install-recommends git-core
apt-get install -y --no-install-recommends openjdk-8-jdk-headless
apt-get install -y --no-install-recommends maven

# download and install SonarQube Scanner.
mkdir /opt/sonar-scanner
pushd /opt/sonar-scanner
sonarqube_scanner_version=3.3.0.1492
sonarqube_scanner_directory_name=sonar-scanner-$sonarqube_scanner_version-linux
sonarqube_scanner_artifact=sonar-scanner-cli-$sonarqube_scanner_version-linux.zip
sonarqube_scanner_download_url=https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/$sonarqube_scanner_artifact
sonarqube_scanner_download_sig_url=$sonarqube_scanner_download_url.asc
wget -q $sonarqube_scanner_download_url
wget -q $sonarqube_scanner_download_sig_url
gpg --batch --verify $sonarqube_scanner_artifact.asc $sonarqube_scanner_artifact
unzip -q $sonarqube_scanner_artifact
mv $sonarqube_scanner_directory_name/* .
rm -rf $sonarqube_scanner_directory_name $sonarqube_scanner_artifact* bin/*.bat
dos2unix conf/sonar-scanner.properties
sed -i -E 's,^#?(sonar.host.url=).*,\1http://localhost:9000,' conf/sonar-scanner.properties
export PATH="$PATH:$PWD/bin"
popd

# get, compile, scan and submit a raw project to SonarQube.
pushd ~
git clone --quiet https://github.com/rgl/test-ssl-connection.git
cd test-ssl-connection
rm -rf build && mkdir -p build
javac -version
javac -Werror -d build src/com/ruilopes/*.java
jar cfm test-ssl-connection.jar src/META-INF/MANIFEST.MF -C build .
jar tf test-ssl-connection.jar
# see https://docs.sonarqube.org/display/SONAR/Analysis+Parameters
sonar-scanner \
    -Dsonar.links.scm=https://github.com/rgl/test-ssl-connection \
    -Dsonar.projectKey=com.ruilopes_rgl_test-ssl-connection \
    -Dsonar.projectName=com.ruilopes/rgl/test-ssl-connection \
    -Dsonar.projectVersion=master \
    -Dsonar.java.source=8 \
    -Dsonar.sources=src
popd


# get, compile, scan and submit a maven based project to SonarQube.
pushd ~
git clone https://github.com/SonarSource/sonar-scanning-examples
cd sonar-scanning-examples/sonarqube-scanner-maven
mvn --batch-mode install
# the sonar:sonar goal will pick most of things from pom.xml, but
# you can also define them on the command line.
# see https://maven.apache.org/pom.html
# see https://docs.sonarqube.org/display/SONAR/Analysis+Parameters
mvn --batch-mode \
    sonar:sonar \
    -Dsonar.links.scm=https://github.com/SonarSource/sonar-scanning-examples
popd


#
# show summary.

echo "You can now access the SonarQube Web UI at https://$config_fqdn"
echo 'The default user and password are admin'
echo "Check for updates at https://$config_fqdn/updatecenter/installed"
echo 'Check the logs with journalctl -u sonarqube and at /opt/sonarqube/logs'
