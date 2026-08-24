# Log-Munger

Extracts structured fields from log lines, akin to [grok](https://www.elastic.co/guide/en/logstash/current/plugins-filters-grok.html)
for Logstash, but as a standalone Perl distribution and a `log_munger` CLI, with
no Elasticsearch/Logstash stack required.

Feed it a decoded log record (a hash) or a raw log line, and it runs the record
through a set of YAML **rule files**. The first rule that matches returns the
named captures from its regexp, optionally broken down further (`decompose`),
coerced (`convert`), and enriched with GeoIP (`geoip`).

```
$ echo '{"PROGRAM":"sshd","MESSAGE":"Accepted publickey for neti from 192.0.2.5 port 54321 ssh2: RSA SHA256:AbCd"}' \
    | log_munger munge --rules sshd
---
ssh_key_fingerprint: SHA256:AbCd
ssh_key_type: RSA
ssh_method: publickey
ssh_src_ip: 192.0.2.5
ssh_src_port: 54321
ssh_user: neti
```

## Why

Logstash is a dumpster fire to deal with and this allows easy parsing of log stuff in a
reusable manner for Perl.

## Install

### From source

```sh
perl Makefile.PL
make
make test
make install
```

### FreeBSD

```sh
pkg install p5-App-cpanminus p5-YAML-LibYAML p5-JSON p5-File-ShareDir p5-File-Slurp \
    p5-Template-Toolkit p5-Hash-Merge p5-App-Cmd p5-Algorithm-Dependency
cpanm Log::Munger
```

### Debian

```sh
apt-get install cpanminus libyaml-libyaml-perl libjson-perl libfile-sharedir-perl \
    libfile-slurp-perl libtemplate-perl libhash-merge-perl libapp-cmd-perl \
    libalgorithm-dependency-perl
cpanm Log::Munger
```

### GeoIP

GeoIP enrichment additionally needs
[`IP::Geolocation::MMDB`](https://metacpan.org/pod/IP::Geolocation::MMDB). It is only
recommended rather than required, and is loaded only when you actually pass a database.

## Quick start

### As a CLI

```sh
# what rule files are available?
log_munger list

# run one item through a rule file and dump the fields
log_munger munge --rules sshd \
    --string '{"PROGRAM":"sshd","MESSAGE":"Failed password for root from 203.0.113.7 port 44444 ssh2"}'

# a gateless rule (like http_access_logs) works on a raw line with --raw
log_munger munge --rules http_access_logs --raw \
    --string '127.0.0.1 - frank [10/Oct/2000:13:55:36 -0700] "GET /a.gif HTTP/1.0" 200 2326'

# see WHICH rule/pattern fired
log_munger explain --rules sshd --string '{"PROGRAM":"sshd","MESSAGE":"..."}'

# stream NDJSON in, enriched NDJSON out
cat events.ndjson | log_munger enrich --rules sshd --rules postfix > enriched.ndjson
```

### As a library

```perl
use Log::Munger;

my $munger = Log::Munger->new( rules => [ 'sshd', 'postfix' ] );

# a decoded record (e.g. from journald / syslog-ng JSON output)
my $fields = $munger->process_item( item => {
    PROGRAM => 'sshd',
    MESSAGE => 'Failed password for root from 203.0.113.7 port 44444 ssh2',
} );
# $fields = { ssh_method => 'password', ssh_user => 'root', ssh_src_ip => '203.0.113.7', ... }

# a bare string is matched as the MESSAGE field
my $access = $munger->process_item( item => $raw_apache_line );
```

## Bundled rule files

The distribution ships a primitive library plus ready-to-use rule files
(installed into the dist share dir):

| Rule file | Matches                                                                                                     |
|-----------|-------------------------------------------------------------------------------------------------------------|
| `base`    | The primitive library (`IP`, `WORD`, `TIMESTAMP_ISO8601`, etc). No rules of its own; included by the others |

**Authentication and privilege**

| Rule file                       | Matches                                                            |
|---------------------------------|--------------------------------------------------------------------|
| `sshd`                          | OpenSSH auth events, plus the scan traffic that never reaches auth |
| `dropbear`                      | Dropbear SSH server auth events                                    |
| `pam` / `su` / `sudo` / `login` | PAM, `su`, `sudo`, and console login authentication                |
| `nslcd`                         | The LDAP name-service daemon behind `libnss_ldap` / `pam_ldap`     |
| `luci`                          | LuCI (the OpenWrt web interface) authentication                    |
| `xscreensaver`                  | XScreenSaver lock-screen unlock attempts                           |
| `polkit`                        | polkit authorization decisions — the third way to gain privilege   |
| `auditd`                        | Linux audit daemon records, including SELinux AVC and AppArmor     |
| `slapd`                         | OpenLDAP binds, searches, and result codes                         |
| `openvpn`                       | OpenVPN handshakes, certificate verification, and auth failures    |
| `strongswan`                    | strongSwan/charon IPsec tunnels, IKE, and EAP                      |
| `freeradius`                    | RADIUS logins — the auth behind 802.1X and many VPNs               |
| `samba`                         | Samba (`smbd`/`nmbd`/`winbindd`) auth audit and share access       |
| `nfs`                           | `rpc.mountd` mount requests, allowed and refused                   |

**Mail**

| Rule file                | Matches                                               |
|--------------------------|-------------------------------------------------------|
| `postfix`                | Postfix mail log (smtpd, qmgr, delivery, etc)         |
| `exim`                   | Exim mail log, including SMTP AUTH and TLS failures   |
| `dovecot`                | Dovecot IMAP/POP3                                     |
| `sendmail`               | Sendmail transactions, AUTH failures, and rejections  |
| `rspamd`                 | Rspamd scan results — score, action, and symbols      |
| `spamd`                  | SpamAssassin scan results                             |
| `clamav`                 | ClamAV detections and signature-database freshness    |
| `opendkim` / `opendmarc` | DKIM and DMARC results, joined to the MTA by queue id |
| `ssmtp`                  | sSMTP, the send-only MTA                              |
| `sympa`                  | The Sympa mailing list manager's daemons              |

**Web, proxy, and network services**

| Rule file                       | Matches                                                             |
|---------------------------------|---------------------------------------------------------------------|
| `http_access_logs`              | Apache/nginx Common, Combined, and the vhost-prefixed variants      |
| `http_error_logs`               | Apache/nginx error logs                                             |
| `haproxy`                       | HAProxy HTTP and TCP traffic, plus health-check state changes       |
| `squid`                         | Squid access.log (all three shipped logformats) and cache.log       |
| `vsftpd` / `proftpd`            | FTP logins and transfers                                            |
| `php_fpm`                       | PHP-FPM pool health: dying children, slow requests, exhaustion      |
| `cups`                          | CUPS printing — both `error_log` and `access_log`                   |
| `named` / `unbound`             | DNS server logs                                                     |
| `resolved`                      | `systemd-resolved` upstream health and DNSSEC failures              |
| `dnsmasq`                       | dnsmasq's DNS, DHCP, and TFTP logging                               |
| `dhcpd`                         | ISC DHCP server leases                                              |
| `hostapd`                       | hostapd wireless association events (the access-point side)         |
| `wpa_supplicant`                | Wireless client associations and auth failures                      |
| `networkmanager` / `networkd`   | Device state machines, carrier, and DHCP leases                     |
| `chrony` / `ntpd` / `timesyncd` | Time synchronization daemons                                        |
| `xinetd`                        | Superserver dispatch: who reached which service, and refusals       |
| `snmpd`                         | Net-SNMP connections — who is querying the agent                    |
| `asterisk`                      | Asterisk PBX                                                        |
| `avahi`                         | Avahi mDNS/DNS-SD responder                                         |
| `lldpd`                         | lldpd/lldpcli link-layer neighbor discovery                         |
| `netifd` / `odhcpd`             | OpenWrt's network interface and DHCPv6/router-advertisement daemons |
| `huawei`                        | Huawei VRP devices — S-series switches, AR routers, USG firewalls   |
| `tor`                           | Tor daemon                                                          |

**Firewalls**

| Rule file                 | Matches                                                                                     |
|---------------------------|---------------------------------------------------------------------------------------------|
| `netfilter`               | iptables/nftables/UFW kernel firewall logs                                                  |
| `ipfw`                    | FreeBSD ipfw firewall logs                                                                  |
| `pf`                      | OpenBSD/FreeBSD pf, read from `tcpdump -r /var/log/pflog`                                   |
| `fortinet`                | FortiGate/FortiOS key=value logs                                                            |
| `sonicwall`               | SonicWall/SonicOS key=value logs                                                            |
| `fail2ban`                | fail2ban ban/unban actions                                                                  |
| `kur` / `ereshkigal`      | Rules for ereshkigal and it's related backend bit, kur.                                     |
| `galla` / `baphomet`      | Rules for baphomet and it's related backend bit, galla.                                     |
| `daemonlogger`            | daemonlogger's rolling packet capture                                                       |
| `virani`                  | Virani, which carves per-request pcaps out of daemonlogger's capture set                    |
| `mojo_cape_submit`        | `mojo_cape_submit`/`nergal` rules for CAPEv2, submission endpoint receiving for CAPE::Utils |
| `suricata_extract_submit` | `suricata_extract_submit` rules for CAPEv2, sample suricata extract shipper for CAPE::Utils |

**Databases, storage, and the host itself**

| Rule file            | Matches                                                                 |
|----------------------|-------------------------------------------------------------------------|
| `mysql`              | MySQL/MariaDB access denials and aborted connections                    |
| `postgresql`         | PostgreSQL authentication and connection logging                        |
| `mongodb`            | MongoDB structured (JSON) logging                                       |
| `kernel`             | Linux and FreeBSD kernel ring buffer — OOM, filesystem, I/O, SYN floods |
| `smartd`             | Disk health: failing attributes, bad sectors, temperature               |
| `zed`                | ZFS Event Daemon — checksum errors, vdev states, resilvers              |
| `docker`             | Docker/containerd logfmt output                                         |
| `libvirt`            | libvirt daemons, monolithic and modular                                 |
| `systemd` / `logind` | systemd unit lifecycle and `systemd-logind` sessions                    |
| `dbus`               | D-Bus message bus (`dbus-daemon` and `dbus-broker`)                     |
| `cron` / `atd`       | Scheduled job execution                                                 |
| `shutdown`           | `shutdown` / `reboot` / `halt`                                          |
| `fwupd`              | fwupd firmware updates, daemon and clients                              |
| `pkg`                | FreeBSD `pkg(8)` package changes                                        |
| `rc`                 | FreeBSD `rc(8)` service-script warnings                                 |
| `syslog_daemon`      | rsyslog and syslog-ng internals — rate limiting and stalled outputs     |

## Documentation

Full documentation lives in [`docs/`](docs/):

- [Getting started](docs/getting-started.md) :: Install, first munge, the log-record model.
- [CLI reference](docs/cli.md) :: Every `log_munger` subcommand and option.
- [Rule-file format](docs/rule-files.md) :: The YAML schema — `vars`, `rules`, `gate`,
  `decompose`, `convert`, `geoip`, and `tests`.
- [Writing a rule file](docs/writing-rules.md) :: A step-by-step tutorial.
- [Primitive library](docs/primitives.md) :: The named patterns in `base.yaml`.
- [Perl API](docs/api.md) :: `Log::Munger` and the supporting modules.
- [Architecture](docs/architecture.md) :: How loading, templating, and matching fit
  together.
- [GeoIP enrichment](docs/geoip.md) :: Enriching captured addresses.
- [Grok migration](docs/grok.md) :: Converting existing grok patterns.

## Authors and license

Copyright (c) 2026 Zane C. Bowers-Hadley `<vvelox at vvelox.net>`.

This is free software, licensed under the GNU Lesser General Public License, Version 3.
See [`LICENSE`](LICENSE).

Bugs and feature requests: [GitHub issues](https://github.com/LilithSec/Log-Munger)
or `bug-log-munger at rt.cpan.org`.
