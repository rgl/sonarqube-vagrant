#!/bin/bash
set -euxo pipefail

config_sonarqube_admin_password=$1; shift
sonarqube_edition="$(curl \
    --user "admin:$config_sonarqube_admin_password" \
    --silent \
    --fail \
    --show-error \
    localhost:9000/api/navigation/global \
    | jq --raw-output .edition)"
sonarqube_token="$(curl \
    --user "admin:$config_sonarqube_admin_password" \
    --silent \
    --fail \
    --show-error \
    localhost:9000/api/user_tokens/generate \
    -d name=example \
    -d "expirationDate=$(date -d "+1 day" +%Y-%m-%d)" \
    | jq --raw-output .token)"

#
# build some Java projects and send them to SonarQube.
# see https://docs.sonarsource.com/sonarqube-community-build/analyzing-source-code/scanners/sonarscanner/

apt-get install -y --no-install-recommends git-core
apt-get install -y --no-install-recommends openjdk-17-jdk-headless
apt-get install -y --no-install-recommends maven

# download and install SonarQube Scanner.
mkdir /opt/sonar-scanner
pushd /opt/sonar-scanner
sonarqube_scanner_version=7.1.0.4889
sonarqube_scanner_directory_name=sonar-scanner-$sonarqube_scanner_version-linux-x64
sonarqube_scanner_artifact=sonar-scanner-cli-$sonarqube_scanner_version-linux-x64.zip
sonarqube_scanner_download_url=https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/$sonarqube_scanner_artifact
wget -q $sonarqube_scanner_download_url
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
# see https://docs.sonarsource.com/sonarqube-community-build/analyzing-source-code/analysis-parameters/
sonarqube_scanner_extra_args=()
if [ "$sonarqube_edition" != 'community' ]; then
# TODO disable the automatic creation of projects on SQ
# TODO create the project in SQ and set its default branch name to
#      what is returned by:
#       git symbolic-ref refs/remotes/origin/HEAD | sed 's,^refs/remotes/origin/,,'
# TODO make sure the default branch is correctly set at the SQ project level.
sonarqube_scanner_extra_args+=("-Dsonar.branch.name=$(git rev-parse --abbrev-ref HEAD)")
fi
sonar-scanner \
    "-Dsonar.token=$sonarqube_token" \
    -Dsonar.qualitygate.wait=true \
    "${sonarqube_scanner_extra_args[@]}" \
    "-Dsonar.links.scm=$(git remote get-url origin)" \
    -Dsonar.projectKey=com.ruilopes_rgl_test-ssl-connection \
    -Dsonar.projectName=com.ruilopes/rgl/test-ssl-connection \
    "-Dsonar.projectVersion=$(git rev-parse HEAD)" \
    -Dsonar.java.source=8 \
    -Dsonar.sources=src
popd


# get, compile, scan and submit a maven based project to SonarQube.
pushd ~
git clone https://github.com/SonarSource/sonar-scanning-examples
cd sonar-scanning-examples
git checkout 425a18d76926ca0ff7a00824ba022b782cf4ee58
cd sonar-scanner-maven/maven-basic
mvn --batch-mode install
# the sonar:sonar goal will pick most of things from pom.xml, but
# you can also define them on the command line.
# see https://maven.apache.org/pom.html
# see https://docs.sonarqube.org/latest/analysis/analysis-parameters/
mvn --batch-mode \
    sonar:sonar \
    "-Dsonar.token=$sonarqube_token" \
    -Dsonar.qualitygate.wait=true \
    "-Dsonar.links.scm=$(git remote get-url origin)"
popd
