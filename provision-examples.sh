#!/bin/bash
set -euxo pipefail

sonarqube_edition="$(curl --user admin:password --silent --fail --show-error localhost:9000/api/navigation/global | jq --raw-output .edition)"

#
# build some Java projects and send them to SonarQube.
# see https://docs.sonarqube.org/8.9/analysis/scan/sonarscanner/

apt-get install -y --no-install-recommends git-core
apt-get install -y --no-install-recommends openjdk-11-jdk-headless
apt-get install -y --no-install-recommends maven

# download and install SonarQube Scanner.
mkdir /opt/sonar-scanner
pushd /opt/sonar-scanner
sonarqube_scanner_version=4.6.2.2472
sonarqube_scanner_directory_name=sonar-scanner-$sonarqube_scanner_version-linux
sonarqube_scanner_artifact=sonar-scanner-cli-$sonarqube_scanner_version-linux.zip
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
# see https://docs.sonarqube.org/8.9/analysis/analysis-parameters/
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
    -Dsonar.login=admin \
    -Dsonar.password=password \
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
git checkout 1ed66a331d1a7fb54f138ab4c21c01195f06413c
cd sonarqube-scanner-maven/maven-basic
mvn --batch-mode install
# the sonar:sonar goal will pick most of things from pom.xml, but
# you can also define them on the command line.
# see https://maven.apache.org/pom.html
# see https://docs.sonarqube.org/8.9/analysis/analysis-parameters/
mvn --batch-mode \
    sonar:sonar \
    -Dsonar.login=admin \
    -Dsonar.password=password \
    -Dsonar.qualitygate.wait=true \
    "-Dsonar.links.scm=$(git remote get-url origin)"
popd
