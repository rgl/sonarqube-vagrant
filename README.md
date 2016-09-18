This is a [Vagrant](https://www.vagrantup.com/) Environment for a [SonarQube](http://www.sonarqube.org) based Source Code Analysis service.

This will:

* Install a SonarQube instance and configure it through its [Web API](http://docs.sonarqube.org/display/DEV/Web+API).
* Install PostgreSQL as a database server for SonarQube.
* Install nginx as a proxy to SonarQube.
* Install iptables firewall.
* Install and use the [SonarQube Scanner for Java](http://docs.sonarqube.org/display/SCAN/Analyzing+with+SonarQube+Scanner) on a [raw Java project](https://github.com/rgl/test-ssl-connection).
* Install and use the [SonarQube Scanner for Maven](http://docs.sonarqube.org/display/SCAN/Analyzing+with+SonarQube+Scanner+for+Maven) on a [Maven based Java project](https://github.com/SonarSource/sonar-examples/tree/master/projects/languages/java/maven/java-maven-simple).

**NB** There is also a [Windows based SonarQube Vagrant Environment](https://github.com/rgl/sonarqube-windows-vagrant).


# Usage

Build and install the [Ubuntu Base Box](https://github.com/rgl/ubuntu-vagrant).

Add the following entry to your `/etc/hosts` file:

```
10.10.10.103 sonarqube.example.com
``` 

Run `vagrant up` to launch the server and view [SonarQube page](https://sonarqube.example.com).

The default username and password are `admin`.

**NB** nginx is setup with a self-signed certificate that you have to trust before being able to access the local SonarQube page.


# References

* [SonarQube Documentation](http://docs.sonarqube.org/display/SONAR/Documentation)
* [SonarQube: Analysis Parameters](http://docs.sonarqube.org/display/SONAR/Analysis+Parameters)
* [Maven: POM Reference](https://maven.apache.org/pom.html)
