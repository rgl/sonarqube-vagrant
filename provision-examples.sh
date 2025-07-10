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
    --user 'sonar-scanner:password' \
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

# create the test-ssl-connection project and analyze it.
project_git_url='https://github.com/rgl/test-ssl-connection'
project_key='test-ssl-connection'
project_name='test-ssl-connection'
curl \
    --user "admin:$config_sonarqube_admin_password" \
    --silent \
    --fail \
    --show-error \
    localhost:9000/api/projects/create \
    -d "project=$project_key" \
    -d "name=$project_name" \
    -d 'mainBranch=master' \
    -d 'visibility=public'
# NB we should not use one of the links names that are already defined for
#    SonarQube analyses (e.g. `scm`), as, for some odd reason, those will
#    override these project level ones.
curl \
    --user "admin:$config_sonarqube_admin_password" \
    --silent \
    --fail \
    --show-error \
    localhost:9000/api/project_links/create \
    -d "projectKey=$project_key" \
    -d 'name=Git Repository' \
    -d "url=$project_git_url"
pushd ~
git clone --quiet "$project_git_url" test-ssl-connection
cd test-ssl-connection
rm -rf build && mkdir -p build
javac -version
javac -Werror -d build src/com/ruilopes/*.java
jar cfm test-ssl-connection.jar src/META-INF/MANIFEST.MF -C build .
jar tf test-ssl-connection.jar
# see https://docs.sonarsource.com/sonarqube-community-build/analyzing-source-code/analysis-parameters/
sonarqube_scanner_extra_args=()
if [ "$sonarqube_edition" != 'community' ]; then
    sonarqube_scanner_extra_args+=("-Dsonar.branch.name=$(git rev-parse --abbrev-ref HEAD)")
fi
sonar-scanner \
    "-Dsonar.token=$sonarqube_token" \
    '-Dsonar.qualitygate.wait=true' \
    "${sonarqube_scanner_extra_args[@]}" \
    "-Dsonar.links.scm=$(git remote get-url origin)" \
    "-Dsonar.projectKey=$project_key" \
    "-Dsonar.projectVersion=$(git rev-parse HEAD)" \
    '-Dsonar.java.source=8' \
    '-Dsonar.sources=src'
popd


# create the sonar-scanning-examples project and analyze it.
project_git_url='https://github.com/SonarSource/sonar-scanning-examples'
project_key='sonar-scanning-examples'
project_name='sonar-scanning-examples'
curl \
    --user "admin:$config_sonarqube_admin_password" \
    --silent \
    --fail \
    --show-error \
    localhost:9000/api/projects/create \
    -d "project=$project_key" \
    -d "name=$project_name" \
    -d 'mainBranch=master' \
    -d 'visibility=public'
# NB we should not use one of the links names that are already defined for
#    SonarQube analyses (e.g. `scm`), as, for some odd reason, those will
#    override these project level ones.
curl \
    --user "admin:$config_sonarqube_admin_password" \
    --silent \
    --fail \
    --show-error \
    localhost:9000/api/project_links/create \
    -d "projectKey=$project_key" \
    -d 'name=Git Repository' \
    -d "url=$project_git_url"
pushd ~
git clone "$project_git_url" sonar-scanning-examples
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
    '-Dsonar.qualitygate.wait=true' \
    "-Dsonar.links.scm=$(git remote get-url origin)" \
    "-Dsonar.projectKey=$project_key"
popd


#
# create the sonarqube-vagrant project and analyze it.
# NB this should trigger the shellcheck plugin.
project_git_url='https://github.com/rgl/sonarqube-vagrant'
project_key='sonarqube-vagrant'
project_name='sonarqube-vagrant'
curl \
    --user "admin:$config_sonarqube_admin_password" \
    --silent \
    --fail \
    --show-error \
    localhost:9000/api/projects/create \
    -d "project=$project_key" \
    -d "name=$project_name" \
    -d 'mainBranch=master' \
    -d 'visibility=public'
# NB we should not use one of the links names that are already defined for
#    SonarQube analyses (e.g. `scm`), as, for some odd reason, those will
#    override these project level ones.
curl \
    --user "admin:$config_sonarqube_admin_password" \
    --silent \
    --fail \
    --show-error \
    localhost:9000/api/project_links/create \
    -d "projectKey=$project_key" \
    -d 'name=Git Repository' \
    -d "url=$project_git_url"
pushd ~
git clone --quiet "$project_git_url" sonarqube-vagrant
cd sonarqube-vagrant
# see https://docs.sonarsource.com/sonarqube-community-build/analyzing-source-code/analysis-parameters/
sonarqube_scanner_extra_args=()
if [ "$sonarqube_edition" != 'community' ]; then
    sonarqube_scanner_extra_args+=("-Dsonar.branch.name=$(git rev-parse --abbrev-ref HEAD)")
fi
sonar-scanner \
    "-Dsonar.token=$sonarqube_token" \
    '-Dsonar.qualitygate.wait=true' \
    "${sonarqube_scanner_extra_args[@]}" \
    "-Dsonar.links.scm=$(git remote get-url origin)" \
    "-Dsonar.projectKey=$project_key" \
    "-Dsonar.projectVersion=$(git rev-parse HEAD)" \
    '-Dsonar.sources=.'
popd
