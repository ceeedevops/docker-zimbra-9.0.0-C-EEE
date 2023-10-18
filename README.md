# Docker Image with Zimbra 9.0.0  OSE by C-EEE.ORG

## Overview

This image contains everything required to download, install, and run the [Zimbra](https://www.zimbra.com/) collaboration suite [FOSS]() Edition built by [C-EEE.ORG](https://c-eee.org) from source code accessible at [zm-build](https://github.com/Zimbra/zm-build) at [GitHub](https://github.com/). Zimbra is not present in the image. 

1. The container initially installs a basic Ubuntu 20.04 LTS into a docker volume. This installation serves as Zimbra's root filesystem, allowing Zimbra to interact with the environment while keeping everything consistent and permanent - even if the container is upgraded. This also indicates that downloading a new image version does not update the Ubuntu installation on the docker volume.
  
2. To decrease the possibility of security vulnerabilities, the container configures Ubuntu's *unattended upgrades* package to automatically install official updates. To find out how and why should you do it, [learn more here](https://www.kolide.com/features/checks/ubuntu-unattended-upgrades).

3. The container supports IPv6 and has a global IPv6 address. It also has packet filtering configured to prevent common attacks and access to non-public ports.

## Deploying Zimbra on Docker Host

### Overview

This section explains how to start the Zimbra container on a standard Docker host.

### Step 1: - Configuring a User-Defined Network

- If you don't already have a user-defined network for public services, you can establish a simple bridge network (named `frontend` in the example below) and define the subnets from which Docker will assign IP addresses to containers.

- As you will most likely only have one IPv4 address for your server, you should select a subnet from the site-local ranges (`10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16`).

- Docker handles connecting published services to the server's public IPv4 address.

- Any IPv6-enabled server nowadays has at least a /64 subnet assigned, thus any single container can have its own IPv6 address without the need for network address translation (NAT). As a result, you should select an IPv6 subnet that is part of the subnet that your server is assigned to.
  
- Docker advises using a subnet of at least /80 so that it can assign IP addresses by ORing the container's (virtual) MAC address with the provided subnet.

```bash
docker network create -d bridge \
  --subnet 192.168.0.0/24 \
  --subnet 2001:xxxx:xxxx:xxxx::/80 \
  --ipv6 \
  frontend
```
### Step 2 - Create a Volume for the Zimbra Container

The zimbra container installs a minimalistic Ubuntu 20.04 LTS and Zimbra onto a docker volume. You can create a named volume using the following command:

```bash
docker volume create zimbra-data
````

### Step 3 - Install Zimbra

- Before installing Zimbra, you should ensure that your DNS contains the following records:

- An A record mapping the FQDN of the Zimbra container to the public `IPv4` address of the docker host (e.g. `mail.c-eee.org`), the docker host maps the service ports to the container.

- An  `AAAA` record mapping the `FQDN` of the Zimbra container to its public `IPv6` address (e.g. `mail.c-eee.org`)

- A `MX` record with the hostname of the Zimbra container (as specified by the `A/AAAA` records)

- The command below will install Zimbra on the newly created volume.

- You will be able to configure Zimbra utilizing the menu-driven installation script. 

- You can install all features except the `DNS` Cache, which will interfere with the container's  `DNS` cache. 

- Please replace the hostname in the  `A/AAAA` DNS entries with the hostname you selected.

- Because the `IPv4` address through which the container would be publicly accessible is really assigned to the docker host, the installation process will complain about a DNS problem. Ignore the warning and continue. It will eventually function.

- Clone the reposotory to you Ubuntu 20.04 doker host

```bash
git clone https://github.com/ceeedevops/docker-zimbra-9.0.0-C-EEE.git
```

```bash
docker run -it \
           --rm \
           --ip6=2001:xxxx:xxxx:xxxx::2 \
           --network frontend \
           --hostname mail.c-eee.org \
           -p 25:25 \
           -p 80:80 \
           -p 110:110 \
           -p 143:143 \
           -p 443:443 \
           -p 465:465 \
           -p 587:587 \
           -p 993:993 \
           -p 995:995 \
           -p 5222:5222 \
           -p 5223:5223 \
           -p 7071:7071 \
           --volume zimbra-data:/data \
           --cap-add NET_ADMIN \
           --cap-add SYS_ADMIN \
           --cap-add SYS_PTRACE \
           --security-opt apparmor=unconfined \
           c-eee.org/zimbra \
           run-and-enter
```

- To function correctly, the container requires a few more characteristics. 

- To configure network interfaces and the iptables firewall, the `NET_ADMIN` capability is required. 

- The `SYS_ADMIN` capability is required to configure the chrooted environment in which Zimbra runs.

- To for `rsyslog` to `start/stop` effectively, the `SYS_PTRAC`E capability is required.
  
- `AppArmor` protection must also be disabled in order to set up the `chrooted` environment.

- The  `run-and-enter` command instructs the container to open a shell within the container at the end. 

- You can also access the Ubuntu installation with Zimbra directly by typing `run-and-enter-zimbra`.

- The default command is executed.

- It simply starts a script that initializes the container and waits for the container to be closed before gracefully shutting down Zimbra (and related services).

- Once the manual configuration is complete, you will most likely merely execute the container in the background with the `run` command:

```bash
docker run --name zimbra \ 
           --detach \
           --rm \
           --ip6=2001:xxxx:xxxx:xxxx::2 \
           --network frontend \
           --hostname mail.c-eee.org \
           -p 25:25 \
           -p 80:80 \
           -p 110:110 \
           -p 143:143 \
           -p 443:443 \
           -p 465:465 \
           -p 587:587 \
           -p 993:993 \
           -p 995:995 \
           -p 5222:5222 \
           -p 5223:5223 \
           -p 7071:7071 \
           --volume zimbra-data:/data \
           --cap-add NET_ADMIN \
           --cap-add SYS_ADMIN \
           --cap-add SYS_PTRACE \
           --security-opt apparmor=unconfined \
           c-eee.org/zimbra \
           run
```

## Maintenance

1. If the associated volume is empty, the container installs a full Ubuntu 20.04 LTS installation along with Zimbra. This also implies that executing an updated docker image does not update the installation on the disk.
   
2.  The installation is kept up to date because Ubuntu's `unattended upgrades` program automatically installs official updates. If you do not want the installation to be automatically updated,
   
3.  To stop unattended upgrades after the installation by setting, in case if you don't want to have it some reason.

- Open the configuration file:

```bash
 nano /etc/apt/apt.conf.d/20auto-upgrades
```

- Add the following configuration parameter:
  
 ```bash
 APT::Periodic::Unattended-Upgrade "0"; 
 ```

4. To manually install updates, launch a shell in the container using the following command:

```bash 
docker exec -it zimbra /bin/bash
```

5.  The entire Ubuntu installation is kept in `/data`, so you need to `chroot` to dive into the environment:

```bash
chroot /data /bin/bash
```

You can now deal with the installation as you would a conventional Ubuntu installation, with some limitations. Some kernel calls are restricted by the default `seccomp` profile in Docker, therefore you may need to alter this. Furthermore,`systemd` is broken, thus you must use init scripts to `start/stop` services.

5. First and foremost, you should keep your Ubuntu installation up to date by running the following tasks on a regular basis:

```bash
apt-get update
apt-get upgrade
```

6. If a new Zimbra installation is available, you must manually update it to ensure that any adjustments made since the first setup are appropriately re-applied. A new image that installs a new version of Zimbra **WILL NOT** upgrade an existing installation.

## Security

### Transport Security (TLS)

- By default Zimbra generates a self-signed certificate for TLS. As self-signed certificates are not trusted web browsers will complain about it.

-   To use a certificate issued by a trusted certification authority (CA),  you can tell the container to set it in by providing the private key at `/data/app/tls/zimbra.key` and the certificate at `/data/app/tls/zimbra.crt`.

- The container keeps track of changes to the certificate file and re-configures Zimbra, if necessary.

- It is recommended to mount a volume with the key and the certificate at `/data/app/tls` and use it for exchanging the certificate.

- The certificate *should* contain the certificate chain up to the root certificate.

- If a certificate of an intermediate CA or root CA is missing, the container will try to download the missing certificates using the *Authority Information Access* extension (if available).

- Furthermore 4096 bit DH parameters are generated improving the security level of the key exchange.

#### HTTP Transport Security (HSTS)

If the container is `directly` linked to the internet (without the use of a reverse proxy), HTTP Transport Security (`HSTS`) should be enabled to instruct web browsers to only connect to Zimbra through HTTPS. This can be accomplished as follows:

```bash
sudo -u zimbra -- /opt/zimbra/bin/zmprov mcf +zimbraResponseHeader "Strict-Transport-Security: max-age=31536000"
```

The configuration passes the popular SSL/TLS server tests:
- [SSL Labs](https://www.ssllabs.com/ssltest/) (supports HTTPS only)
- [Online Domain Tools](http://ssl-checker.online-domain-tools.com/) (supports HTTPS, SMTP, IMAP, POP)
- [High-Tech-Bridge](https://www.htbridge.com/ssl/) (supports HTTPS, SMTP, IMAP, POP)

### Firewall

The container configures the firewall allowing only the following services to be accessed from the public internet.

| Port     | Description                             |
| :------- | :-------------------------------------- |
| 25/tcp   | SMTP                                    |
| 80/tcp   | HTTP                                    |
| 110/tcp  | POP3                                    |
| 143/tcp  | IMAP                                    |
| 443/tcp  | HTTP over TLS                           |
| 465/tcp  | SMTP over SSL                           |
| 587/tcp  | SMTP (submission, for mail clients)     |
| 993/tcp  | IMAP over TLS                           |
| 995/tcp  | POP3 over TLS                           |
| 5222/tcp | XMPP                                    |
| 5223/tcp | XMPP (default legacy port)              |
| 7071/tcp | HTTPS (admin panel)                     |

- The packet filter prevents access to backend services such as LDAP, MariaDB, or the Jetty server. 

- Access to webmail via HTTP(S) as well as mail access via POP(S) and IMAP(S) are proxied by NGINX shipped with Zimbra adding an extra layer of security.

- Secure inter-process communication will be enabled if you install Zimbra using this image with the default settings.

- You can turn off the above feature. Because Zimbra components communicate without encryption, it improves overall system performance. This isn't a problem because everything runs on the same host, even within the same container.
 
- Furthermore, the packet filter includes a few rules that guard against common threats:
  
  - TCP floods (except SYN floods)
    
  - Bogus flags in TCP packets

  - RH0 packets (can be used for DoS attacks)

  - Ping of Death

### Mitigating Denial of Service (DoS) Attacks

#### HTTP Request Rate Limiting

Zimbra provides a simple mechanism to mitigate DoS attacks by rate-limiting HTTP requests per IP address.

At first the `zimbraHttpDosFilterDelayMillis` setting determines how to handle requests exceeding the rate-limit.
`-1` simply rejects the request (default). Any other positive value applys a delay (in ms) to the request to throttle it down. The setting can be configured as follows:

```
sudo -u zimbra -- zmprov mcf zimbraHttpDosFilterDelayMillis -1
```

The `zimbraHttpDosFilterMaxRequestsPerSec` setting determines the maximum number of requests that are allowed per second. The default value is `30`. The setting can be configured as follows:

```
sudo -u zimbra -- zmprov mcf zimbraHttpDosFilterMaxRequestsPerSec 30
```

At last the `zimbraHttpThrottleSafeIPs` setting determines IP addresses or IP address ranges (in CIDR notation) that should not be throttled. By default the whitelist is empty, but loopback adresses are always whitelisted. The setting can be configured as follows:

```
sudo -u zimbra -- zmprov mcf zimbraHttpThrottleSafeIPs 10.1.2.3/32 zimbraHttpThrottleSafeIPs 192.168.4.0/24
```

Alternatively you can add values to an existing list:

```
sudo -u zimbra -- zmprov mcf +zimbraHttpThrottleSafeIPs 10.1.2.3/32
sudo -u zimbra -- zmprov mcf +zimbraHttpThrottleSafeIPs 192.168.4.0/24
```

### Mitigating Brute Force Attacks

Zimbra comes with a mechanism that blocks IP addresses, if there are too many failed login attempts coming from the address. The default values are usually a good starting point, but depending on the deployment it might be useful to adjust the settings.

At first the `zimbraInvalidLoginFilterDelayInMinBetwnReqBeforeReinstating` setting determines the time (in minutes) to block an IP address that has caused too many login attempts. The default value is `15`. The setting can be adjusted as follows:

```
sudo -u zimbra -- zmprov mcf zimbraInvalidLoginFilterDelayInMinBetwnReqBeforeReinstating 15
```

The setting `zimbraInvalidLoginFilterMaxFailedLogin` determines the number of failed login attempts before an IP address gets blocked. The default value is `10`. It can be adjusted as follows:

```
sudo -u zimbra -- zmprov mcf zimbraInvalidLoginFilterMaxFailedLogin 10
```

At last the setting `zimbraInvalidLoginFilterReinstateIpTaskIntervalInMin` determines the interval (in minutes) betwen running the process to unblock IP addresses. The default value is `5`. Usually there is no need to tweak it, but it can be adjusted as follows:

```
sudo -u zimbra -- zmprov mcf zimbraInvalidLoginFilterReinstateIpTaskIntervalInMin 5
```

### Monitoring Authentication Activity

The container configures Zimbra's brute-force detection *zmauditswatch*. It monitors authentication activity and sends an email to a configured recipient notifying the recipient of a possible attack. The default recipient is the administrator (as returned by `zmlocalconfig smtp_destination`). It does not block the attack!

The initial parameter set is as follows:

| Parameter                         | Value   | Description                       
| :-------------------------------- | :-----: | :--------------------------------------------------------------------------------------
| zimbra_swatch_notice_user         | *admin* | The email address of the person receiving notifications about possible brute-force attacks.
| zimbra_swatch_threshold_seconds   | 3600    | Detection time the thresholds below refer to (in seconds).
| zimbra_swatch_ipacct_threshold    | 10      | IP/Account hash check which warns on *xx* auth failures from an IP/Account combo within the specified time.
| zimbra_swatch_acct_threshold      | 15      | Account check which warns on *xx* auth failures from any IP within the specified time. Attempts to detect a distributed hijack based attack on a single account.
| zimbra_swatch_ip_threshold        | 20      | IP check which warns on *xx* auth failures to any account within the specified time. Attempts to detect a single host based attack across multiple accounts.
| zimbra_swatch_total_threshold     | 100     | Total auth failure check which warns on *xx* auth failures from any IP to any account within the specified time.

In most cases the parameters should be ok, but if you need to tune them, the following commands can be used to change the parameters:
```
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_notice_user=admin@my-domain.com
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_threshold_seconds=3600
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_ipacct_threshold=10
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_acct_threshold=15
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_ip_threshold=20
sudo -u zimbra -- /opt/zimbra/bin/zmlocalconfig -e zimbra_swatch_total_threshold=100
```

## Manual Adjustments Improving Security

### Enabling Domain Key Identified Mail (DKIM)

- `DKIM` (Domain Keys Identified Mail) is an email authentication technology used to identify email spoofing.
  
- It enables the receiver to verify that an email claiming to be from a given domain was truly allowed by the domain's owner.

- Its purpose is to prevent counterfeit sender addresses in emails, which are commonly exploited in phishing and email spam.

- `DKIM` allows a domain to associate its name with an email message by attaching a digital signature to it. 

- The signer's public key, which is published in the DNS, is used for verification. 

- A valid signature ensures that specific sections of the email (potentially including attachments) have not been altered since the signature was placed. 

- `DKIM` signatures are typically not visible to end users since they are affixed or validated by the infrastructure rather than the message's creators and recipients.

- `DKIM` varies from end-to-end digital signatures in this regard.

To enable `DKIM` signing you only need to run the following command (replace the domain name accordingly):

```bash
sudo -u zimbra -- /opt/zimbra/libexec/zmdkimkeyutil -a -d c-ceee.org
```
- This will generate a 2048-bit RSA key and enable DKIM signing for the domain supplied. 

- To complete the setting, you must publish the TXT record produced by 'zmdkimkeyutil' in your DNS. 

- The `TXT` record has the name `AB6EFD30-2AA8-11E8-ACDA-A71CCC6989A6._domainkey`, whilst the DKIM selector is `AB6EFD30-2AA8-11E8-ACDA-A71CCC6989A6` 

The `DKIM` record has the following value:

```bash
v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAmQ0nDvzpJn4b6nvvTDw2N0/Glcj24w0ZyTgNW1h5zNEEmxiH+7TuTcRvCVmBIHrY/anAtdiMZ60leQqo2USjI3ixE7Y1AewvjP95yS/WRq3Khoi7E2JsucreMcrf5WkVPsJd6G1Aw2uBGG/h/lyfjGYtpOjjnNqEb9Nxh3eMwATYNFUI55PVuTI405yR12SUPRomI2QvqiqTW2
```

- After a few minutes, you should be able to use the [DKIM Test](http://www.appmaildev.com/en/dkim) to see if DKIM signing works.
  
- Simply send an email to the generated address and wait for the report.

### Sender Policy Framework (SPF)

- The `Sender Policy Framework (SPF)` is a simple email-validation system designed to identify email spoofing by providing a means for receiving mail exchangers to verify that incoming mail from a domain originates from a host approved by the domain's administrators. 

- The list of approved transmitting hosts for a domain is published in the domain's Domain Name System (DNS) records as a specially structured `TXT` record.
  
- Because email spam and phishing frequently use forged "from" addresses, publishing and validating SPF records are anti-spam measures.
  
- To enable `SPF` you need to add a `TXT` record to your `DNS`. 

- The name of the `TXT` record must be the name of the `domain` the SPF policy refers to. 

- The value of the `TXT` record defines the policy. 

- A simple, but effective policy is:

```
v=spf1 mx a ~all
```

This instructs other mail servers to accept mail from a mail server whose IP address is listed by `A` or `AAAA` records in the DNS of the same domain. Furthermore all mail exchangers of the domain (identified by `MX` records) are allowed to send mail for the domain. At the end `~all` tells other mail servers to treat violations of the policy as *soft fails*, i.e. the mail is tagged, but not rejected. This is primarily useful in conjunction with a DMARC policy (see below). The [SPF syntax documentation](http://www.openspf.org/SPF_Record_Syntax) shows how to craft a custom SPF policy.

A few minutes after setting the SPF record you can use one of the following tools to check it:
- [MxToolbox](https://mxtoolbox.com/spf.aspx)
- [Dmarcian SPF Surveyer](https://dmarcian.com/spf-survey/)

### Domain-based Message Authentication, Reporting and Conformance (DMARC)

*Domain-based Message Authentication, Reporting and Conformance (DMARC)* is an email-validation system designed to detect and prevent email spoofing. It is intended to combat certain techniques often used in phishing and email spam, such as emails with forged sender addresses that appear to originate from legitimate organizations. Specified in RFC 7489, DMARC counters the illegitimate usage of the exact domain name in the `From:` field of email message headers.

DMARC is built on top of the two mechanisms discussed above, *DomainKeys Identified Mail (DKIM)* and the *Sender Policy Framework (SPF)*. It allows the administrative owner of a domain to publish a policy on which mechanism (DKIM, SPF or both) is employed when sending email from that domain and how the receiver should deal with failures. Additionally, it provides a reporting mechanism of actions performed under those policies. It thus coordinates the results of DKIM and SPF and specifies under which circumstances the `From:` header field, which is often visible to end users, should be considered legitimate.

To enable DMARC you need to add a TXT record to your DNS. The name of the TXT record must be `_dmarc`. The value of the TXT record defines how mail servers receiving mail from your domain should act. A simple, but proven record is...

```
v=DMARC1; p=quarantine; rua=mailto:dmarc@my-domain.com; ruf=mailto:dmarc@my-domain.com; sp=quarantine
```

This instructs other mail servers to accept mails only, if the DKIM signature is present and valid and/or the SPF policy is met. If both checks fail, the mail should not be delivered and put aside (quarantined). Mail servers will send aggregate reports (`rua`) and forensic data (`ruf`) to `dmarc@my-domain.com`. The official [DMARC website](https://dmarc.org) provides a comprehensive documentation how DMARC works and how it can be configured to suit your needs (if you need more fine-grained control over DMARC parameters). [Kitterman's DMARC Assistent](http://www.kitterman.com/dmarc/assistant.html) helps with setting up a custom DMARC policy.

A few minutes after setting the DMARC record in your DNS, you can check it using one of the following tools:
- [MxToolbox](https://mxtoolbox.com/DMARC.aspx)
- [Dmarcian DMARC Inspector](https://dmarcian.com/dmarc-inspector/)
- [Proofpoint DMARC Check](https://stopemailfraud.proofpoint.com/dmarc/)

### Rejecting false "Mail From" addresses

Zimbra is configured to allow any sender address when receiving mail. This can be a security problem as an attacker could send mails to Zimbra users impersonating other users. The following links provide good guides to improve security:
- [Rejecting false "mail from" addresses](https://wiki.zimbra.com/wiki/Rejecting_false_%22mail_from%22_addresses)
- [Enforcing a match between FROM address and sasl username](https://wiki.zimbra.com/wiki/Enforcing_a_match_between_FROM_address_and_sasl_username_8.5)

To sum it up, you need to do the following things to reject false "mail from" addresses and allow authenticated users to use their own identities (mail adresses) only:

```
sudo -u zimbra -- /opt/zimbra/bin/zmprov mcf zimbraMtaSmtpdRejectUnlistedRecipient yes
sudo -u zimbra -- /opt/zimbra/bin/zmprov mcf zimbraMtaSmtpdRejectUnlistedSender yes
sudo -u zimbra -- /opt/zimbra/bin/zmprov mcf zimbraMtaSmtpdSenderLoginMaps proxy:ldap:/opt/zimbra/conf/ldap-slm.cf +zimbraMtaSmtpdSenderRestrictions reject_authenticated_sender_login_mismatch
```

Furthermore you need to edit the file `/opt/zimbra/conf/zmconfigd/smtpd_sender_restrictions.cf` and add `reject_sender_login_mismatch` after the `permit_mynetworks` line. It should look like the following:

```
%%exact VAR:zimbraMtaSmtpdSenderRestrictions reject_authenticated_sender_login_mismatch%%
%%contains VAR:zimbraMtaSmtpdSenderRestrictions check_sender_access lmdb:/opt/zimbra/conf/postfix_reject_sender%%
%%contains VAR:zimbraServiceEnabled cbpolicyd^ check_policy_service inet:localhost:%%zimbraCBPolicydBindPort%%%%
%%contains VAR:zimbraServiceEnabled amavis^ check_sender_access regexp:/opt/zimbra/common/conf/tag_as_originating.re%%
permit_mynetworks
reject_sender_login_mismatch
permit_sasl_authenticated
permit_tls_clientcerts
%%contains VAR:zimbraServiceEnabled amavis^ check_sender_access regexp:/opt/zimbra/common/conf/tag_as_foreign.re%%
```

**As all manual changes done to Zimbra's configuration files changes to `smtpd_sender_restrictions.cf` are overwritten when Zimbra is upgraded. The change must be re-applied after an upgrade!**

The server needs to be restarted to apply the changes:

```
sudo -u zimbra -- /opt/zimbra/bin/zmcontrol restart
```
