This is a [Vagrant](https://www.vagrantup.com/) Environment for a [SonarQube](https://www.sonarsource.com/open-source-editions/sonarqube-community-edition/) based Source Code Analysis service.

This will:

* Install a SonarQube instance and configure it through its [Web API](https://docs.sonarsource.com/sonarqube-community-build/extension-guide/web-api/).
* Install PostgreSQL as a database server for SonarQube.
* Install nginx as a proxy to SonarQube.
* Install iptables firewall.
* Install and use the [SonarQube Scanner for Java](https://docs.sonarsource.com/sonarqube-community-build/analyzing-source-code/scanners/sonarscanner/) on a [raw Java project](https://github.com/rgl/test-ssl-connection).
* Install and use the [SonarQube Scanner for Maven](https://docs.sonarsource.com/sonarqube-community-build/analyzing-source-code/scanners/sonarscanner-for-maven/) on a [Maven based Java project](https://github.com/SonarSource/sonar-scanning-examples/tree/master/sonar-scanner-maven).

**NB** There is also a [Windows based SonarQube Vagrant Environment](https://github.com/rgl/sonarqube-windows-vagrant).


# Usage

Build and install the [Ubuntu Base UEFI Box](https://github.com/rgl/ubuntu-vagrant).

Install Vagrant 2.4.6+.

If you want to use LDAP for user authentication, you have to:

1. have [rgl/windows-domain-controller-vagrant](https://github.com/rgl/windows-domain-controller-vagrant) up and running at `../windows-domain-controller-vagrant`.
1. uncomment the `config_authentication='ldap'` line inside [provision.sh](provision.sh).

Add the following entry to your `/etc/hosts` file:

```
10.10.10.103 sonarqube.example.com
```

Launch the environment:

```bash
vagrant up --provider=libvirt --no-destroy-on-error --no-tty
```

View the SonarQube home page at:

https://sonarqube.example.com

**NB** nginx is setup with a self-signed certificate that you have to trust before being able to access the local SonarQube page.

And login as `admin`/`HeyH0Password!`.

When using the default LDAP settings you can also use the following users:

| Username    | Password        | Groups                                                    |
|-------------|-----------------|-----------------------------------------------------------|
| `jane.doe`  | `HeyH0Password` | `sonar-users`                                             |
| `john.doe`  | `HeyH0Password` | `sonar-administrators`, `sonar-users`, `Domain Admins`    |


# LDAP username to SonarQube username mapping

At some point in time, SonarQube started supporting multiple external identity providers, but unfortunately, for my simple use-case of using a single identity provider (LDAP), it means that the SonarQube username is now randomly generated and does not directly map to the LDAP username.

This means that, for example, the LDAP username `jane.doe` ends up with a SonarQube username like `jane-doe35582` (which is derived from the LDAP user display name and a random number).

This means that from the SonarQube viewpoint, the LDAP user will have an external SonarQube user with the following properties:

```bash
config_sonarqube_admin_password='HeyH0Password!'
curl --silent --fail --show-error \
    --user "admin:$config_sonarqube_admin_password" \
    -X GET \
    'localhost:9000/api/users/search?q=jane.doe' \
    | jq
```
```json
{
    "paging": {
        "pageIndex": 1,
        "pageSize": 50,
        "total": 1
    },
    "users": [
        {
            "login": "jane-doe35582",
            "name": "Jane Doe",
            "active": true,
            "email": "jane.doe@example.com",
            "groups": [
                "sonar-users"
            ],
            "tokensCount": 0,
            "local": false,
            "externalIdentity": "jane.doe",
            "externalProvider": "LDAP_default",
            "avatar": "0cba00ca3da1b283a57287bcceb17e35",
            "lastConnectionDate": "2023-04-14T06:29:42+0000"
        }
    ]
}
```

Though, the SonarQube username can be later modified with:

```bash
curl --silent --fail --show-error \
    --user "admin:$config_sonarqube_admin_password" \
    -X POST \
    localhost:9000/api/users/update_login \
    -d login=jane-doe35582 \
    -d newLogin=jane.doe
```


# References

* [SonarQube Documentation](https://docs.sonarqube.org/latest/)
* [SonarQube: Analysis Parameters](https://docs.sonarqube.org/latest/analysis/analysis-parameters/)
* [SonarQube: Web Api Documentation](https://sonarqube.example.com/web_api)
* [Maven: POM Reference](https://maven.apache.org/pom.html)
