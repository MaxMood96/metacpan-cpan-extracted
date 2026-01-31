# Suricata::Ping

The purpose of send a ping packet on each interface being monitorined by suricata.

This can then be checked for further down the processing pipe for alerts to ensure that
everything is being processed as expected.

## Usage

```
suricata_ping -f <suricata config> [-p <pattern>] [-i <ip>] [-c <count>] [-s <section>]

suricata_ping -h/--help

suricata_ping -v/--version
```

### Flags

#### -f suricata_config

This is the suricata config to read. This will include the configs in
.include .

This is a required flag.

#### -p pattern

The pattern to use with the ping.

default: e034o31qwe9034oldlAd31qdgf3

#### -i ip

The IP to send the ping request to.

default: 8.8.8.8

## Install

### Generic

```
cpanm Suricata::Ping
```

### Debian

```
apt-get install libyaml-libyaml-perl libfile-slurp-perl libhash-merge-perl cpanminus
cpanm Suricata::Ping
```

### FreeBSD
```
pkg install p5-YAML-LibYAML p5-File-Slurp p5-Regexp-IPv6 p5-Hash-Merge p5-App-cpanminus
cpanm Suricata::Ping
```

### Source

```
perl Makefile.PL
make
make install
```
