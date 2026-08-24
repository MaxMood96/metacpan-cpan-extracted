#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempfile);
use Scalar::Util qw(looks_like_number);

BEGIN {
	use_ok('Log::Munger') || print "Bail out!\n";
}

#
# The shipped postfix rules carry a file-level decompose that kv-splits
# postfix_keyvalue_data and re-groks the relay/delays/command-counter blobs.
#
my $m = Log::Munger->new( 'rules' => [ 'base', 'postfix' ] );

# a smtp delivery line: kv split, then relay + delays re-grokked
my $d = $m->process_item(
	'item' => {
		PROGRAM => 'postfix/smtp',
		MESSAGE => '3F8B2A9C1D5E: to=<other@example.org>, orig_to=<x@y.com>, '
			. 'relay=mx.example.com[1.2.3.4]:25, delay=0.12, delays=0.05/0/0/0.07, dsn=2.0.0, status=sent (250 ok)'
	}
);
# kv fields (trimmed of <>,)
is( $d->{'postfix_to'},      'other@example.org', 'kv: to trimmed of <>' );
is( $d->{'postfix_orig_to'}, 'x@y.com',           'kv: orig_to' );
is( $d->{'postfix_dsn'},     '2.0.0',             'kv: dsn' );
is( $d->{'postfix_delay'},   '0.12',              'kv: delay' );
# relay re-grokked from postfix_relay
is( $d->{'postfix_relay_hostname'}, 'mx.example.com', 'pattern: relay hostname' );
is( $d->{'postfix_relay_ip'},       '1.2.3.4',        'pattern: relay ip' );
is( $d->{'postfix_relay_port'},     '25',             'pattern: relay port' );
# delays re-grokked from postfix_delays
is( $d->{'postfix_delay_before_qmgr'},  '0.05', 'pattern: delay_before_qmgr' );
is( $d->{'postfix_delay_transmission'}, '0.07', 'pattern: delay_transmission' );
# source blobs removed
ok( !exists( $d->{'postfix_keyvalue_data'} ), 'kv source field removed' );
ok( !exists( $d->{'postfix_relay'} ),         'relay blob removed after re-grok' );
ok( !exists( $d->{'postfix_delays'} ),        'delays blob removed after re-grok' );
# main-pattern captures preserved
is( $d->{'postfix_queueid'}, '3F8B2A9C1D5E', 'main capture preserved (queueid)' );
is( $d->{'postfix_status'},  'sent',         'main capture preserved (status)' );

# a smtpd disconnect line: command-counter decompose
my $c = $m->process_item(
	'item' => {
		PROGRAM => 'postfix/smtpd',
		MESSAGE => 'disconnect from mail.example.com[1.2.3.4] ehlo=1 mail=1 rcpt=0/1 data=0/1 quit=1 commands=3/5'
	}
);
is( $c->{'postfix_cmd_ehlo'},          '1', 'command-counter: ehlo' );
is( $c->{'postfix_cmd_rcpt'},          '1', 'command-counter: rcpt' );
is( $c->{'postfix_cmd_rcpt_accepted'}, '0', 'command-counter: rcpt_accepted' );
is( $c->{'postfix_cmd_count'},         '5', 'command-counter: count' );
ok( !exists( $c->{'postfix_command_counter_data'} ), 'command-counter blob removed' );

# a line with no decomposable blob is unchanged
my $q = $m->process_item( 'item' => { PROGRAM => 'postfix/qmgr', MESSAGE => 'ABCDEF123456: removed' } );
is_deeply( $q, { postfix_queueid => 'ABCDEF123456' }, 'line without blobs is left untouched' );

#
# a self-contained rule exercising kv options directly (prefix/trim/splits) and
# the no-clobber rule
#
my ( $fh, $file ) = tempfile( 'lm_decompose_XXXXXX', SUFFIX => '.yaml', TMPDIR => 1, UNLINK => 1 );
print {$fh} <<'YAML';
---
includes:
- base
vars_templated:
  KVLINE: '(?<who>[% WORD %]) (?<kvdata>[% GREEDYDATA %])'
rules:
  - name: kv
    field: MESSAGE
    anchored: true
    decompose:
      - field: kvdata
        type: kv
        prefix: 'x_'
        trim: '"'
        remove: true
    patterns: [KVLINE]
    tests:
      positive:
        - string: 'bob a=1 b="two" who=nope'
          result:
            who: 'bob'
            kvdata: 'a=1 b="two" who=nope'
      negative: ['zzz']
YAML
close($fh);

my $km = Log::Munger->new( 'rules' => [$file] );
my $k  = $km->process_item( 'item' => { MESSAGE => 'bob a=1 b="two" who=nope' } );
is( $k->{'x_a'}, '1',   'kv custom prefix' );
is( $k->{'x_b'}, 'two', 'kv trim of quotes' );
is( $k->{'who'}, 'bob', 'existing capture not clobbered by kv (x_who added instead)' );
is( $k->{'x_who'}, 'nope', 'kv writes to prefixed key, leaving the original who intact' );
ok( !exists( $k->{'kvdata'} ), 'kv source removed' );

#
# the "json" decompose type: decode a JSON blob captured from MESSAGE and flatten
# it into prefixed keys (the MongoDB structured-logging use case).
#
my ( $jfh, $jfile ) = tempfile( 'lm_json_XXXXXX', SUFFIX => '.yaml', TMPDIR => 1, UNLINK => 1 );
print {$jfh} <<'YAML';
---
includes:
- base
vars_templated:
  MONGO_JSON: '(?<mongo_json>\{.*\})'
rules:
  - name: mongo
    gate:
      - field: PROGRAM
        values: [ '//^mongod?$//' ]
    field: MESSAGE
    anchored: true
    patterns: [MONGO_JSON]
    decompose:
      - field: mongo_json
        type: json
        prefix: 'mongo_'
        remove: true
    tests:
      positive:
        - string: '{"s":"I","c":"NETWORK","id":22943,"msg":"conn"}'
          result:
            mongo_s: 'I'
            mongo_c: 'NETWORK'
            mongo_id: 22943
            mongo_msg: 'conn'
      negative: ['not json at all']
YAML
close($jfh);

my $jm = Log::Munger->new( 'rules' => [$jfile] );
my $j  = $jm->process_item(
	'item' => {
		PROGRAM => 'mongod',
		MESSAGE => '{"t":{"$date":"2026-07-27T02:49:30.131+00:00"},"s":"I","c":"WTCHKPT","id":22430,'
			. '"ctx":"Checkpointer","msg":"WiredTiger message",'
			. '"attr":{"message":{"category":"WT_VERB_CHECKPOINT_PROGRESS","verbose_level_id":1,"debug":true,"note":null}}}'
	}
);
is( $j->{'mongo_s'},   'I',        'json: top-level scalar (s)' );
is( $j->{'mongo_c'},   'WTCHKPT',  'json: top-level scalar (c)' );
is( $j->{'mongo_ctx'}, 'Checkpointer', 'json: top-level scalar (ctx)' );
is( $j->{'mongo_t'}, '2026-07-27T02:49:30.131+00:00', 'json: MongoDB $date collapsed to the scalar' );
is( $j->{'mongo_attr_message_category'}, 'WT_VERB_CHECKPOINT_PROGRESS', 'json: nested key flattened with prefix+path' );
is( $j->{'mongo_attr_message_debug'}, 1, 'json: boolean true normalized to 1' );
ok( !exists( $j->{'mongo_attr_message_note'} ), 'json: null value skipped' );
ok( looks_like_number( $j->{'mongo_id'} ), 'json: numeric value stays a number' );
ok( !exists( $j->{'mongo_json'} ), 'json: source blob removed' );

# a MESSAGE that is not valid JSON leaves the captured blob untouched (never dies)
my $jbad = $jm->process_item( 'item' => { PROGRAM => 'mongod', MESSAGE => '{this is not json}' } );
is( $jbad->{'mongo_json'}, '{this is not json}', 'json: invalid JSON leaves the raw field in place' );

#
# nested mode: store the decoded structure whole under a single key
#
my ( $nfh, $nfile ) = tempfile( 'lm_jsonnest_XXXXXX', SUFFIX => '.yaml', TMPDIR => 1, UNLINK => 1 );
print {$nfh} <<'YAML';
---
includes:
- base
vars_templated:
  BLOB: '(?<blob>\{.*\})'
rules:
  - name: nested
    field: MESSAGE
    anchored: true
    patterns: [BLOB]
    decompose:
      - field: blob
        type: json
        nested: true
        prefix: 'doc_'
        remove: true
    tests:
      negative: ['nope']
YAML
close($nfh);

my $nm = Log::Munger->new( 'rules' => [$nfile] );
my $n  = $nm->process_item( 'item' => { MESSAGE => '{"a":1,"b":{"c":2}}' } );
is( ref( $n->{'doc'} ), 'HASH', 'json nested: decoded structure stored whole under prefix key (trailing sep trimmed)' );
is( $n->{'doc'}{'b'}{'c'}, 2, 'json nested: nested structure preserved' );
ok( !exists( $n->{'blob'} ), 'json nested: source blob removed' );

# nested mode with no prefix: the decoded structure replaces the source field
# itself, and remove: is ignored so it is not deleted right after being stored
my ( $npfh, $npfile ) = tempfile( 'lm_jsonnestnp_XXXXXX', SUFFIX => '.yaml', TMPDIR => 1, UNLINK => 1 );
print {$npfh} <<'YAML';
---
includes:
- base
vars_templated:
  BLOB: '(?<blob>\{.*\})'
rules:
  - name: nested_noprefix
    field: MESSAGE
    anchored: true
    patterns: [BLOB]
    decompose:
      - field: blob
        type: json
        nested: true
        remove: true
    tests:
      negative: ['nope']
YAML
close($npfh);

my $npm = Log::Munger->new( 'rules' => [$npfile] );
my $np  = $npm->process_item( 'item' => { MESSAGE => '{"a":1,"b":{"c":2}}' } );
is( ref( $np->{'blob'} ), 'HASH', 'json nested, no prefix: decoded structure replaces the source field' );
is( $np->{'blob'}{'b'}{'c'}, 2, 'json nested, no prefix: structure preserved' );

done_testing();
