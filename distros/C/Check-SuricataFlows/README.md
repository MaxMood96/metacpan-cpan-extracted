# Check-SuricataFlows

This reads the Suricata EVE JSON flow data file.

    .timestamp :: Used for double checking to make sure we don't read farther
        back than we need to.

If the following is found, the entry is checked.

    .dest_ip
    .src_ip
    .flow.pkts_toclient
    .flow.pkts_toserver

Bi-directional is when .flow.pkts_toclient and .flow.pkts_toserver are both greater
than zero.

Uni-directional is when only .flow.pkts_toclient or .flow.pkts_toserver is greater
than zero and the other is zero.

If all entries found are uni-directional then it is safe to assume the monitored span
is misconfigured.

## FLAGS

```
check_suricataflows [-f <flows.json>] [-a <alert count>] [-w <warn
    count>] [-t <seconds>] [<-m> <max lines>]

check_suricataflows -h/--help

check_suricataflows -v/--version
```

### -f flows.json

The flows EVE JSON location.

Default: /var/log/suricata/flows/current/flow.json

### -a alert_count

Alert if the number of bidirectional flows are less than this.

Default: 10

### head2 -w warn_count

Warn if the number of directional flows are less than this.

Default: 20

### -t seconds

How far back into the file to read in seconds.

Default: 300

### -m max_lines

Max number of lines to read in.

# INSTALLATION

## FreeBSD

```
pkg install p5-JSON p5-File-ReadBackwards p5-App-cpanminus
cpanm Check::CheckSuricataFlows
```

## Debian

```
apt-get install libjson-perl libfile-readbackwards-perl cpanminus
cpanm Check::SuricataFlows
```

## From Source

To install this module, run the following commands:

	perl Makefile.PL
	make
	make test
	make instal
