This is a [Vagrant](https://www.vagrantup.com/) Environment for a [SonarQube](http://www.sonarqube.org) based Source Code Analysis service.

This will:

* Install a SonarQube instance and configure it through its [Web API](https://docs.sonarqube.org/9.9/extension-guide/web-api/).
* Install PostgreSQL as a database server for SonarQube.
* Install nginx as a proxy to SonarQube.
* Install iptables firewall.
* Install and use the [SonarQube Scanner for Java](https://docs.sonarqube.org/9.9/analyzing-source-code/scanners/sonarscanner/) on a [raw Java project](https://github.com/rgl/test-ssl-connection).
* Install and use the [SonarQube Scanner for Maven](https://docs.sonarqube.org/9.9/analyzing-source-code/scanners/sonarscanner-for-maven/) on a [Maven based Java project](https://github.com/SonarSource/sonar-scanning-examples/tree/master/sonarqube-scanner-maven).

**NB** There is also a [Windows based SonarQube Vagrant Environment](https://github.com/rgl/sonarqube-windows-vagrant).


# Usage

Build and install the [Ubuntu Base Box](https://github.com/rgl/ubuntu-vagrant).

Install Vagrant 2.1+.

If you want to use LDAP for user authentication, you have to:

1. have [rgl/windows-domain-controller-vagrant](https://github.com/rgl/windows-domain-controller-vagrant) up and running at `../windows-domain-controller-vagrant`.
1. uncomment the `config_authentication='ldap'` line inside [provision.sh](provision.sh).

Add the following entry to your `/etc/hosts` file:

```
10.10.10.103 sonarqube.example.com
```

Launch the environment:

```bash
# or --provider=virtualbox.
vagrant up --no-destroy-on-error --provider=libvirt
```

View the SonarQube home page at:

https://sonarqube.example.com

**NB** nginx is setup with a self-signed certificate that you have to trust before being able to access the local SonarQube page.

And login as `admin`/`password`.

When using the default LDAP settings you can also use the following users:

| Username    | Password        | Groups                                                    |
|-------------|-----------------|-----------------------------------------------------------|
| `jane.doe`  | `HeyH0Password` | `sonar-users`                                             |
| `john.doe`  | `HeyH0Password` | `sonar-administrators`, `sonar-users`, `Domain Admins`    |

# References

* [SonarQube Documentation](https://docs.sonarqube.org/latest/)
* [SonarQube: Analysis Parameters](https://docs.sonarqube.org/latest/analysis/analysis-parameters/)
* [SonarQube: Web Api Documentation](https://sonarqube.example.com/web_api)
* [Maven: POM Reference](https://maven.apache.org/pom.html)
