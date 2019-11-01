#!/bin/bash
set -eux

sonarqube_edition="$(curl -s localhost:9000/api/navigation/global | jq --raw-output '.edition')"

#
# build some Java projects and send them to SonarQube.
# see https://docs.sonarqube.org/8.0/analysis/scan/sonarscanner/

apt-get install -y --no-install-recommends git-core
apt-get install -y --no-install-recommends openjdk-11-jdk-headless
apt-get install -y --no-install-recommends maven

# download and install SonarQube Scanner.
mkdir /opt/sonar-scanner
pushd /opt/sonar-scanner
sonarqube_scanner_version=4.2.0.1873
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
# see https://docs.sonarqube.org/8.0/analysis/analysis-parameters/
sonarqube_scanner_extra_args=()
if [ false && "$sonarqube_edition" != 'community' ]; then
# TODO disable the automatic creation of projects on SQ
# TODO create the project in SQ and set its default branch name to
#      what is returned by:
#       git symbolic-ref refs/remotes/origin/HEAD | sed 's,^refs/remotes/origin/,,'
# NB if this is the first time the project is being analysed, you cannot send the
#    sonar.branch.name property. if you do, the following error will be raised:
#       Project was never analyzed. A regular analysis is required before a branch analysis.
# TODO only send sonar.branch.* properties when the project was already analysed.
# TODO make sure the default branch is correctly set at the SQ project level.
sonarqube_scanner_extra_args+=("-Dsonar.branch.name=$(git rev-parse --abbrev-ref HEAD)")
#sonarqube_scanner_extra_args+=("-Dsonar.branch.target=master")
fi
sonar-scanner \
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
git checkout 81dc6cadd7ed98302eca04100d842712f3e68cd5
cd sonarqube-scanner-maven/maven-basic
mvn --batch-mode install
# the sonar:sonar goal will pick most of things from pom.xml, but
# you can also define them on the command line.
# see https://maven.apache.org/pom.html
# see https://docs.sonarqube.org/8.0/analysis/analysis-parameters/
mvn --batch-mode \
    sonar:sonar \
    "-Dsonar.links.scm=$(git remote get-url origin)"
popd
