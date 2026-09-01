package Punk::Command::Apikey;

use 5.010;
use strict;
use warnings;
use Punk::Command ();
use Punk::APIKey ();

our $VERSION = '0.01';

sub _app {
    my ($opt) = @_;
    die "punk apikey needs Punk 0.31 or newer for Punk::Command->load_app\n"
        unless Punk::Command->can('load_app');
    my $app = Punk::Command->load_app(dir => $opt->{dir}, chdir => 1);
    my $class = $app->{class};
    require Punk::Plugin::APIKey;
    Punk::Plugin::APIKey->state_for($class)
        or die "$class does not register the APIKey plugin\n";
    return ($class, $app);
}

sub _rows {
    my ($class, $owner) = @_;
    return Punk::Plugin::APIKey->keys_for($class, $owner);
}

sub _print_table {
    my ($rows, $cfg) = @_;
    my $f = $cfg->{fields};
    unless (@$rows) {
        print "no keys\n";
        return 0;
    }
    my @cols = ( [ id => $f->{id} ], [ owner => $f->{owner} ],
                 [ kind => $f->{kind} ], [ label => $f->{label} ],
                 [ prefix => $f->{prefix} ], [ scopes => $f->{scopes} ],
                 [ 'last used' => $f->{last_used} ],
                 [ state => undef ] );
    my @out;
    for my $r (@$rows) {
        my @cells;
        for my $c (@cols) {
            my ($head, $key) = @$c;
            if (!defined $key) {
                push @cells, $r->{ $f->{revoked} } ? 'revoked'
                           : ($r->{ $f->{expires} }
                              && $r->{ $f->{expires} } <= time) ? 'expired'
                           : 'live';
                next;
            }
            my $v = $r->{$key};
            $v = _ago($v) if $head eq 'last used';
            push @cells, defined $v && length $v ? $v : '-';
        }
        push @out, \@cells;
    }
    my @w = map { length $_->[0] } @cols;
    for my $row (@out) {
        $w[$_] = length $row->[$_] for grep { length $row->[$_] > $w[$_] }
                                            0 .. $#$row;
    }
    printf join('  ', map { "%-${_}s" } @w) . "\n", map { $_->[0] } @cols;
    printf join('  ', map { "%-${_}s" } @w) . "\n", @$_ for @out;
    return 0;
}

sub _ago {
    my ($t) = @_;
    return undef unless $t;
    my $d = time - $t;
    return "${d}s ago"                if $d < 90;
    return int($d / 60) . 'm ago'     if $d < 5400;
    return int($d / 3600) . 'h ago'   if $d < 172800;
    return int($d / 86400) . 'd ago';
}

sub _cmd_list {
    my ($opt) = @_;
    my ($class) = _app($opt);
    my $cfg = Punk::Plugin::APIKey->state_for($class);
    my $rows = _rows($class, $opt->{owner});
    if ($opt->{json}) {
        require File::Raw::JSON;
        print File::Raw::JSON::file_json_encode($rows, pretty => 1,
                                                sort_keys => 1);
        return 0;
    }
    return _print_table($rows, $cfg);
}

sub _cmd_issue {
    my ($opt) = @_;
    die { usage_error => '--owner is required' } unless defined $opt->{owner};
    die { usage_error => '--label is required' }
        unless defined $opt->{label} && length $opt->{label};

    my ($class) = _app($opt);
    my @scopes = $opt->{scopes} ? split(/[\s,]+/, $opt->{scopes}) : ();

    my ($key, $row) = Punk::Plugin::APIKey->issue_for($class,
        owner  => $opt->{owner},
        label  => $opt->{label},
        (@scopes ? (scopes => \@scopes) : ()),
        (defined $opt->{kind} ? (kind => $opt->{kind}) : ()),
        (defined $opt->{rate} ? (rate_per_min => $opt->{rate}) : ()),
    );

    print "$key\n\n";
    print "That is the only time this key is shown. Nothing stored it.\n";
    return 0;
}

sub _cmd_revoke {
    my ($opt, @args) = @_;
    my $id = shift @args;
    die { usage_error => 'an id is required' }
        unless defined $id && length $id;
    die { usage_error => "unexpected argument '$args[0]'" } if @args;

    my ($class) = _app($opt);
    my $row = Punk::Plugin::APIKey->revoke_for($class, $id)
        or die "no key with id $id\n";
    my $cfg = Punk::Plugin::APIKey->state_for($class);
    print "revoked key $id ($row->{ $cfg->{fields}{label} })\n";
    return 0;
}

Punk::Command->register(apikey => {
    abstract => 'API keys: list, issue, revoke',
    display  => 'apikey <command>',
    usage    => '<command> [options]',
    desc     => "Long-lived API credentials, through the application's own\n"
              . "Punk::Plugin::APIKey configuration - so the table, the\n"
              . 'kinds and the scope vocabulary are the ones it declares.',
    commands => {
        list => {
            abstract => 'list keys, newest first',
            usage    => '[--owner ID] [--json]',
            options  => [
                { spec => 'owner=s', arg => 'ID',
                  doc  => 'only this owner\'s keys' },
                { spec => 'json', doc => 'as JSON rather than a table' },
            ],
            code => \&_cmd_list,
        },
        issue => {
            abstract => 'mint a key and print it once',
            usage    => '--owner ID --label TEXT [options]',
            desc     => 'The key is printed once and stored only as a '
                      . "digest.\nThere is no way to show it again.",
            options  => [
                { spec => 'owner=s',  arg => 'ID',   doc => 'whose key' },
                { spec => 'label=s',  arg => 'TEXT', doc => 'what it is for' },
                { spec => 'scopes=s', arg => 'LIST',
                  doc  => 'comma separated, from the declared vocabulary' },
                { spec => 'kind=s',   arg => 'KIND',
                  doc  => 'which kind of key (default: live)' },
                { spec => 'rate=i',   arg => 'N',
                  doc  => 'requests a minute this key may make' },
            ],
            code => \&_cmd_issue,
        },
        revoke => {
            abstract => 'revoke a key by id',
            usage    => 'ID',
            desc     => 'Revoking sets a timestamp rather than deleting the '
                      . "row,\nso the key stays in the list and in the audit.",
            code     => \&_cmd_revoke,
        },
    },
}, __PACKAGE__) if Punk::Command->can('register');

1;

__END__

=head1 NAME

Punk::Command::Apikey - the punk apikey subcommand

=head1 SYNOPSIS

    punk apikey list [--owner ID] [--json]
    punk apikey issue --owner ID --label TEXT [--scopes read,write]
                      [--kind live] [--rate 60]
    punk apikey revoke ID

=head1 DESCRIPTION

An operator's view of L<Punk::Plugin::APIKey>. Every verb loads the
application through its own F<app.psgi>, so the table, the kinds and the scope
vocabulary are the ones it declares rather than anything repeated here.

C<issue> prints the key once. Nothing stored it and nothing can show it again;
that is the design, and the command says so rather than leaving it to be
found out.

C<revoke> sets a timestamp rather than deleting the row, so the key stays in
C<list> and in the audit of what was revoked when.

=head1 SEE ALSO

L<Punk::APIKey>, L<Punk::Plugin::APIKey>, L<Punk::Command>.

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION <email@lnation.org>.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut
