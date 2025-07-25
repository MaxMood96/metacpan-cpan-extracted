use 5.005;
use strict;
use warnings;

# ABSTRACT: Module signature file manipulation
package Module::Signature;
our $VERSION = '0.93'; #VERSION

use vars qw($VERSION $SIGNATURE @ISA @EXPORT_OK);
use vars qw($Preamble $Cipher $Debug $Verbose $Timeout $AUTHOR);
use vars qw($KeyServer $KeyServerPort $AutoKeyRetrieve $CanKeyRetrieve);
use vars qw($LegacySigFile);

use constant CANNOT_VERIFY       => '0E0';
use constant SIGNATURE_OK        => 0;
use constant SIGNATURE_MISSING   => -1;
use constant SIGNATURE_MALFORMED => -2;
use constant SIGNATURE_BAD       => -3;
use constant SIGNATURE_MISMATCH  => -4;
use constant MANIFEST_MISMATCH   => -5;
use constant CIPHER_UNKNOWN      => -6;

use ExtUtils::Manifest ();
use Exporter;
use File::Spec;

@EXPORT_OK      = (
    qw(sign verify),
    qw($SIGNATURE $AUTHOR $KeyServer $Cipher $Preamble),
    (grep { /^[A-Z_]+_[A-Z_]+$/ } keys %Module::Signature::),
);
@ISA            = 'Exporter';

$AUTHOR         = $ENV{MODULE_SIGNATURE_AUTHOR};
$SIGNATURE      = 'SIGNATURE';
$Timeout        = $ENV{MODULE_SIGNATURE_TIMEOUT} || 3;
$Verbose        = $ENV{MODULE_SIGNATURE_VERBOSE} || 0;
$KeyServer      = $ENV{MODULE_SIGNATURE_KEYSERVER} || 'keyserver.ubuntu.com';
$KeyServerPort  = $ENV{MODULE_SIGNATURE_KEYSERVERPORT} || '11371';
$Cipher         = $ENV{MODULE_SIGNATURE_CIPHER} || 'SHA256';
$Preamble       = << ".";
This file contains message digests of all files listed in MANIFEST,
signed via the Module::Signature module, version $VERSION.

To verify the content in this distribution, first make sure you have
Module::Signature installed, then type:

    % cpansign -v

It will check each file's integrity, as well as the signature's
validity.  If "==> Signature verified OK! <==" is not displayed,
the distribution may already have been compromised, and you should
not run its Makefile.PL or Build.PL.

.

$AutoKeyRetrieve    = 1;
$CanKeyRetrieve     = undef;
$LegacySigFile      = 0;

sub _cipher_map {
    my($sigtext) = @_;
    my @lines = split /\015?\012/, $sigtext;
    my %map;
    for my $line (@lines) {
        last if $line eq '-----BEGIN PGP SIGNATURE-----';
        next if $line =~ /^---/ .. $line eq '';
        next if $line eq '';
        my($cipher,$digest,$file) = split " ", $line, 3;
        return unless defined $file;
        $map{$file} = [$cipher, $digest];
    }
    return \%map;
}

sub verify {
    my %args = ( skip => $ENV{TEST_SIGNATURE}, @_ );
    my $rv;

    (-r $SIGNATURE) or do {
        warn "==> MISSING Signature file! <==\n";
        return SIGNATURE_MISSING;
    };

    (my $sigtext = _read_sigfile($SIGNATURE)) or do {
        warn "==> MALFORMED Signature file! <==\n";
        return SIGNATURE_MALFORMED;
    };

    (my ($cipher_map) = _cipher_map($sigtext)) or do {
        warn "==> MALFORMED Signature file! <==\n";
        return SIGNATURE_MALFORMED;
    };

    (defined(my $plaintext = _mkdigest($cipher_map))) or do {
        warn "==> UNKNOWN Cipher format! <==\n";
        return CIPHER_UNKNOWN;
    };

    $rv = _verify($SIGNATURE, $sigtext, $plaintext);

    if ($rv == SIGNATURE_OK) {
        my ($mani, $file) = _fullcheck($args{skip});

        if (@{$mani} or @{$file}) {
            warn "==> MISMATCHED content between MANIFEST and distribution files! <==\n";
            return MANIFEST_MISMATCH;
        }
        else {
            warn "==> Signature verified OK! <==\n" if $Verbose;
        }
    }
    elsif ($rv == SIGNATURE_BAD) {
        warn "==> BAD/TAMPERED signature detected! <==\n";
    }
    elsif ($rv == SIGNATURE_MISMATCH) {
        warn "==> MISMATCHED content between SIGNATURE and distribution files! <==\n";
    }

    return $rv;
}

sub _verify {
    my $signature = shift || $SIGNATURE;
    my $sigtext   = shift || '';
    my $plaintext = shift || '';

    # Avoid loading modules from relative paths in @INC.
    local @INC = grep { File::Spec->file_name_is_absolute($_) } @INC;
    local $SIGNATURE = $signature if $signature ne $SIGNATURE;

    if ($AutoKeyRetrieve and !$CanKeyRetrieve) {
        if (!defined $CanKeyRetrieve) {
            require IO::Socket::INET;
            my $sock = IO::Socket::INET->new(
                Timeout => $Timeout,
                PeerAddr => "$KeyServer:$KeyServerPort",
            );
            $CanKeyRetrieve = ($sock ? 1 : 0);
            $sock->shutdown(2) if $sock;
        }
        $AutoKeyRetrieve = $CanKeyRetrieve;
    }

    if (my $version = _has_gpg()) {
        return _verify_gpg($sigtext, $plaintext, $version);
    }
    elsif (eval {require Crypt::OpenPGP; 1}) {
        return _verify_crypt_openpgp($sigtext, $plaintext);
    }
    else {
        warn "Cannot use GnuPG or Crypt::OpenPGP, please install either one first!\n";
        return _compare($sigtext, $plaintext, CANNOT_VERIFY);
    }
}

sub _has_gpg {
    my $gpg = _which_gpg() or return;
    `$gpg --version` =~ /GnuPG.*?(\S+)\s*$/m or return;
    return $1;
}

sub _fullcheck {
    my $skip = shift;
    my @extra;

    local $^W;
    local $ExtUtils::Manifest::Quiet = 1;

    my($mani, $file);
    if( _legacy_extutils() ) {
        my $_maniskip;
        if ( _public_maniskip() ) {
            $_maniskip = &ExtUtils::Manifest::maniskip;
        } else {
            $_maniskip = &ExtUtils::Manifest::_maniskip;
        }

        local *ExtUtils::Manifest::_maniskip = sub { sub {
            return unless $skip;
            my $ok = $_maniskip->(@_);
            if ($ok ||= (!-e 'MANIFEST.SKIP' and _default_skip(@_))) {
                print "Skipping $_\n" for @_;
                push @extra, @_;
            }
            return $ok;
        } };

        ($mani, $file) = ExtUtils::Manifest::fullcheck();
    }
    else {
        my $_maniskip = &ExtUtils::Manifest::maniskip;
        local *ExtUtils::Manifest::maniskip = sub { sub {
            return unless $skip;
            return $_maniskip->(@_);
        } };
        ($mani, $file) = ExtUtils::Manifest::fullcheck();
    }

    foreach my $makefile ('Makefile', 'Build') {
        warn "==> SKIPPED CHECKING '$_'!" .
                (-e "$_.PL" && " (run $_.PL to ensure its integrity)") .
                " <===\n" for grep $_ eq $makefile, @extra;
    }

    @{$mani} = grep {$_ ne 'SIGNATURE'} @{$mani};

    warn "Not in MANIFEST: $_\n" for @{$file};
    warn "No such file: $_\n" for @{$mani};

    return ($mani, $file);
}

sub _legacy_extutils {
    # ExtUtils::Manifest older than 1.58 does not handle MYMETA.
    return (ExtUtils::Manifest->VERSION < 1.58);
}

sub _public_maniskip {
    # ExtUtils::Manifest 1.54 onwards have public maniskip
    return (ExtUtils::Manifest->VERSION > 1.53);
}

sub _default_skip {
    local $_ = shift;
    return 1 if /\bRCS\b/ or /\bCVS\b/ or /\B\.svn\b/ or /,v$/
             or /^MANIFEST\.bak/ or /^Makefile$/ or /^blib\//
             or /^MakeMaker-\d/ or /^pm_to_blib/ or /^blibdirs/
             or /^_build\// or /^Build$/ or /^pmfiles\.dat/
             or /^MYMETA\./
             or /~$/ or /\.old$/ or /\#$/ or /^\.#/;
}

my $which_gpg;
sub _which_gpg {
    # Cache it so we don't need to keep checking.
    return $which_gpg if $which_gpg;

    for my $gpg_bin ('gpg', 'gpg2', 'gnupg', 'gnupg2') {
        my $version = `$gpg_bin --version 2>&1`;
        if( $version && $version =~ /GnuPG/ ) {
            $which_gpg = $gpg_bin;
            return $which_gpg;
        }
    }
}

sub _verify_gpg {
    my ($sigtext, $plaintext, $version) = @_;

    local $SIGNATURE = Win32::GetShortPathName($SIGNATURE)
        if defined &Win32::GetShortPathName and $SIGNATURE =~ /[^-\w.:~\\\/]/;

    my $keyserver = _keyserver($version);

    require File::Temp;
    my $fh = File::Temp->new();
    print $fh $sigtext || _read_sigfile($SIGNATURE);
    close $fh;

    my $gpg = _which_gpg();
    my @quiet = $Verbose ? () : qw(-q --logger-fd=1);
    my @cmd = (
        $gpg, qw(--verify --batch --no-tty), @quiet, ($KeyServer ? (
            "--keyserver=$keyserver",
            ($AutoKeyRetrieve and $version ge '1.0.7')
                ? '--keyserver-options=auto-key-retrieve'
                : ()
        ) : ()), $fh->filename
    );

    my $output = '';
    if( $Verbose ) {
        warn "Executing @cmd\n";
        system @cmd;
    }
    else {
        my $cmd = join ' ', @cmd;
        $output = `$cmd`;
    }
    unlink $fh->filename;

    if( $? ) {
        print STDERR $output;
    }
    elsif ($output =~ /((?: +[\dA-F]{4}){10,})/) {
        warn "WARNING: This key is not certified with a trusted signature!\n";
        warn "Primary key fingerprint:$1\n";
    }

    return SIGNATURE_BAD if ($? and $AutoKeyRetrieve);
    return _compare($sigtext, $plaintext, (!$?) ? SIGNATURE_OK : CANNOT_VERIFY);
}

sub _keyserver {
    my $version = shift;
    my $scheme = 'x-hkp';
    $scheme = 'hkp' if $version ge '1.2.0';

    return "$scheme://$KeyServer:$KeyServerPort";
}

sub _verify_crypt_openpgp {
    my ($sigtext, $plaintext) = @_;

    require Crypt::OpenPGP;
    my $pgp = Crypt::OpenPGP->new(
        ($KeyServer) ? ( KeyServer => $KeyServer, AutoKeyRetrieve => $AutoKeyRetrieve ) : (),
    );
    my $rv = $pgp->handle( Data => $sigtext )
        or die $pgp->errstr;

    return SIGNATURE_BAD if (!$rv->{Validity} and $AutoKeyRetrieve);

    if ($rv->{Validity}) {
        warn 'Signature made ', scalar localtime($rv->{Signature}->timestamp),
             ' using key ID ', substr(uc(unpack('H*', $rv->{Signature}->key_id)), -8), "\n",
             "Good signature from \"$rv->{Validity}\"\n" if $Verbose;
    }
    else {
        warn "Cannot verify signature; public key not found\n";
    }

    return _compare($sigtext, $plaintext, $rv->{Validity} ? SIGNATURE_OK : CANNOT_VERIFY);
}

sub _read_sigfile {
    my $sigfile = shift;
    my $signature = '';
    my $well_formed;

    my $sigfile_fh;
    open ($sigfile_fh, '<', $sigfile) or die "Could not open $sigfile: $!";

    if ($] >= 5.006 and <$sigfile_fh> =~ /\r/) {
        close $sigfile_fh;
        open ($sigfile_fh, '<', $sigfile) or die "Could not open $sigfile: $!";
        binmode $sigfile_fh, ':crlf';
    } else {
        close $sigfile_fh;
        open ($sigfile_fh, '<', $sigfile) or die "Could not open $sigfile: $!";
    }

    my $begin = "-----BEGIN PGP SIGNED MESSAGE-----\n";
    my $end = "-----END PGP SIGNATURE-----\n";
    my $found = 0;
    while (<$sigfile_fh>) {
        if (1 .. ($_ eq $begin)) {
            if (!$found and /signed via the Module::Signature module, version ([0-9\.]+)\./) {
                $found = 1;
                if (eval { require version; version->parse($1) < version->parse("0.82") }) {
                    $LegacySigFile = 1;
                    warn "Old $SIGNATURE detected. Please inform the module author to regenerate " .
                         "$SIGNATURE using Module::Signature version 0.82 or newer.\n";
                }
            }
            next;
        }
        $signature .= $_;
        return "$begin$signature" if $_ eq $end;
    }

    return;
}

sub _compare {
    my ($str1, $str2, $ok) = @_;

    # normalize all linebreaks
    $str1 =~ s/^-----BEGIN PGP SIGNED MESSAGE-----\n(?:.+\n)*\n//;
    $str1 =~ s/[^\S ]+/\n/g; $str2 =~ s/[^\S ]+/\n/g;
    $str1 =~ s/-----BEGIN PGP SIGNATURE-----\n(?:.+\n)*$//;

    return $ok if $str1 eq $str2;

    if (eval { require Text::Diff; 1 }) {
        warn "--- $SIGNATURE ".localtime((stat($SIGNATURE))[9])."\n";
        warn '+++ (current) '.localtime()."\n";
        warn Text::Diff::diff( \$str1, \$str2, { STYLE => 'Unified' } );
    }
    else {
        my $diff_fh;
        my $signature_fh;
        open ($signature_fh, '<', $SIGNATURE) or die "Could not open $SIGNATURE: $!";
        open ($diff_fh, '|-', "diff -u --strip-trailing-cr $SIGNATURE -")
            or (warn "Could not call diff: $!", return SIGNATURE_MISMATCH);
        while (<$signature_fh>) {
            print $diff_fh $_ if (1 .. /^-----BEGIN PGP SIGNED MESSAGE-----/);
            print $diff_fh if (/^Hash: / .. /^$/);
            next if (1 .. /^-----BEGIN PGP SIGNATURE/);
            print $diff_fh $str2, "-----BEGIN PGP SIGNATURE-----\n", $_ and last;
        }
        print $diff_fh (<$signature_fh>);
        close $diff_fh;
    }

    return SIGNATURE_MISMATCH;
}

sub sign {
    my %args = ( skip => 1, @_ );
    my $overwrite = $args{overwrite};
    my $plaintext = _mkdigest();

    my ($mani, $file) = _fullcheck($args{skip});

    if (@{$mani} or @{$file}) {
        warn "==> MISMATCHED content between MANIFEST and the distribution! <==\n";
        warn "==> Please correct your MANIFEST file and/or delete extra files. <==\n";
    }

    if (!$overwrite and -e $SIGNATURE and IO::Interactive::is_interactive()) {
        local $/ = "\n";
        print "$SIGNATURE already exists; overwrite [y/N]? ";
        return unless <STDIN> =~ /[Yy]/;
    }

    if (my $version = _has_gpg()) {
        _sign_gpg($SIGNATURE, $plaintext, $version);
    }
    elsif (eval {require Crypt::OpenPGP; 1}) {
        _sign_crypt_openpgp($SIGNATURE, $plaintext);
    }
    else {
        die 'Cannot use GnuPG or Crypt::OpenPGP, please install either one first!';
    }

    warn "==> SIGNATURE file created successfully. <==\n";
    return SIGNATURE_OK;
}

sub _sign_gpg {
    my ($sigfile, $plaintext, $version) = @_;

    die "Could not write to $sigfile"
        if -e $sigfile and (-d $sigfile or not -w $sigfile);

    my $gpg = _which_gpg();

    my $gpg_fh;
    my $set_key = '';
    $set_key = qq{--default-key "$AUTHOR"} if($AUTHOR);
    open ($gpg_fh, '|-', "$gpg $set_key --clearsign --openpgp --personal-digest-preferences RIPEMD160 >> $sigfile.tmp")
        or die "Could not call $gpg: $!";
    print $gpg_fh $plaintext;
    close $gpg_fh;

    (-e "$sigfile.tmp" and -s "$sigfile.tmp") or do {
        unlink "$sigfile.tmp";
        die "Cannot find $sigfile.tmp, signing aborted.\n";
    };

    my $sigfile_tmp_fh;
    open ($sigfile_tmp_fh, '<', "$sigfile.tmp") or die "Cannot open $sigfile.tmp: $!";

    my $sigfile_fh;
    open ($sigfile_fh, '>', $sigfile) or do {
        unlink "$sigfile.tmp";
        die "Could not write to $sigfile: $!";
    };

    print $sigfile_fh $Preamble;
    print $sigfile_fh (<$sigfile_tmp_fh>);

    close $sigfile_fh;
    close $sigfile_tmp_fh;

    unlink("$sigfile.tmp");

    my $key_id;
    my $key_name;
    # This doesn't work because the output from verify goes to STDERR.
    # If I try to redirect it using "--logger-fd 1" it just hangs.
    # WTF?
    my @verify = `$gpg --batch --verify $SIGNATURE`;
    while (@verify) {
        if (/key ID ([0-9A-F]+)$/) {
            $key_id = $1;
        } elsif (/signature from "(.+)"$/) {
            $key_name = $1;
        }
    }

    my $found_name;
    my $found_key;
    if (defined $key_id && defined $key_name) {
        my $keyserver = _keyserver($version);
        while (`$gpg --batch --keyserver=$keyserver --search-keys '$key_name'`) {
            if (/^\(\d+\)/) {
                $found_name = 0;
            } elsif ($found_name) {
                if (/key \Q$key_id\E/) {
                    $found_key = 1;
                    last;
                }
            }

            if (/\Q$key_name\E/) {
                $found_name = 1;
                next;
            }
        }

        unless ($found_key) {
            _warn_non_public_signature($key_name);
        }
    }

    return 1;
}

sub _sign_crypt_openpgp {
    my ($sigfile, $plaintext) = @_;

    require Crypt::OpenPGP;
    my $pgp = Crypt::OpenPGP->new;
    my $ring = Crypt::OpenPGP::KeyRing->new(
        Filename => $pgp->{cfg}->get('SecRing')
    ) or die $pgp->error(Crypt::OpenPGP::KeyRing->errstr);

    my $uid = '';
    $uid = $AUTHOR if($AUTHOR);

    my $kb;
    if ($uid) {
        $kb = $ring->find_keyblock_by_uid($uid)
          or die $pgp->error(qq{Can't find '$uid': } . $ring->errstr);
        }
    else {
        $kb = $ring->find_keyblock_by_index(-1)
          or die $pgp->error(q{Can't find last keyblock: } . $ring->errstr);
        }

    my $cert = $kb->signing_key;
    $uid = $cert->uid($kb->primary_uid);
    warn "Debug: acquiring signature from $uid\n" if $Debug;

    my $signature = $pgp->sign(
        Data       => $plaintext,
        Detach     => 0,
        Clearsign  => 1,
        Armour     => 1,
        Key        => $cert,
        PassphraseCallback => \&Crypt::OpenPGP::_default_passphrase_cb,
    ) or die $pgp->errstr;

    my $sigfile_fh;
    open ($sigfile_fh, '>', $sigfile) or die "Could not write to $sigfile: $!";
    print $sigfile_fh $Preamble;
    print $sigfile_fh $signature;
    close $sigfile_fh;

    require Crypt::OpenPGP::KeyServer;
    my $server = Crypt::OpenPGP::KeyServer->new(Server => $KeyServer);

    unless ($server->find_keyblock_by_keyid($cert->key_id)) {
        _warn_non_public_signature($uid);
    }

    return 1;
}

sub _warn_non_public_signature {
    my $uid = shift;

    warn <<"EOF"
You have signed this distribution with a key ($uid) that cannot be
found on the public key server at $KeyServer.

This will probably cause signature verification to fail if your module
is distributed on CPAN.
EOF
}

sub _mkdigest {
    my $digest = _mkdigest_files(@_) or return;
    my $plaintext = '';

    foreach my $file (sort keys %$digest) {
        next if $file eq $SIGNATURE;
        $plaintext .= "@{$digest->{$file}} $file\n";
    }

    return $plaintext;
}

sub _digest_object {
    my($algorithm) = @_;

    # Avoid loading Digest::* from relative paths in @INC.
    local @INC = grep { File::Spec->file_name_is_absolute($_) } @INC;

    # Constrain algorithm name to be of form ABC123.
    my ($base, $variant) = ($algorithm =~ /^([_a-zA-Z]+)([0-9]+)$/g)
        or die "Malformed algorithm name: $algorithm (should match /\\w+\\d+/)";

    my $obj = eval { Digest->new($algorithm) } || eval {
        my $module = "Digest/$base.pm";
        require $module; "Digest::$base"->new($variant)
    } || eval {
        my $module = "Digest/$algorithm.pm";
        require $module; "Digest::$algorithm"->new
    } || eval {
        my $module = "Digest/$base/PurePerl.pm";
        require $module; "Digest::$base\::PurePerl"->new($variant)
    } || eval {
        my $module = "Digest/$algorithm/PurePerl.pm";
        require $module; "Digest::$algorithm\::PurePerl"->new
    } or do { eval {
        warn "Unknown cipher: $algorithm, please install Digest::$base, Digest::$base$variant, or Digest::$base\::PurePerl\n";
    } and return } or do {
        warn "Unknown cipher: $algorithm, please install Digest::$algorithm\n"; return;
    };
    $obj;
}

sub _mkdigest_files {
    my $verify_map = shift;
    my $dosnames = (defined(&Dos::UseLFN) && Dos::UseLFN()==0);
    my $read = ExtUtils::Manifest::maniread() || {};
    my $found = ExtUtils::Manifest::manifind();
    my(%digest) = ();
    my($default_obj) = _digest_object($Cipher);
 FILE: foreach my $file (sort keys %$read){
        next FILE if $file eq $SIGNATURE;
        my($obj,$this_cipher,$this_hexdigest,$verify_digest);
        if ($verify_map) {
            if (my $vmf = $verify_map->{$file}) {
                ($this_cipher,$verify_digest) = @$vmf;
                if ($this_cipher eq $Cipher) {
                    $obj = $default_obj;
                } else {
                    $obj = _digest_object($this_cipher);
                }
            } else {
                $this_cipher = $Cipher;
                $obj = $default_obj;
            }
        } else {
            $this_cipher = $Cipher;
            $obj = $default_obj;
        }
        warn "Debug: collecting digest from $file\n" if $Debug;
        if ($dosnames){
            $file = lc $file;
            $file =~ s!(\.(\w|-)+)!substr ($1,0,4)!ge;
            $file =~ s!((\w|-)+)!substr ($1,0,8)!ge;
        }
        unless ( exists $found->{$file} ) {
            warn "No such file: $file\n" if $Verbose;
        }
        else {
            my $file_fh;
            open( $file_fh, '<', $file ) or die "Cannot open $file for reading: $!";
            if ($LegacySigFile) {
                if (-B $file) {
                    binmode($file_fh);
                    $obj->addfile($file_fh);
                    $this_hexdigest = $obj->hexdigest;
                }
                else {
                    # Normalize by hand...
                    local $/;
                    binmode($file_fh);
                    my $input = <$file_fh>;
                VERIFYLOOP: for my $eol ("","\015\012","\012") {
                        my $lax_input = $input;
                        if (! length $eol) {
                            # first try is binary
                        } else {
                            my @lines = split /$eol/, $input, -1;
                            if (grep /[\015\012]/, @lines) {
                                # oops, apparently not a text file, treat as binary, forget @lines
                            } else {
                                my $other_eol = $eol eq "\012" ? "\015\012" : "\012";
                                $lax_input = join $other_eol, @lines;
                            }
                        }
                        $obj->add($lax_input);
                        $this_hexdigest = $obj->hexdigest;
                        if ($verify_digest) {
                            if ($this_hexdigest eq $verify_digest) {
                                last VERIFYLOOP;
                            }
                            $obj->reset;
                        } else {
                            last VERIFYLOOP;
                        }
                    }
                }
            } else {
                binmode($file_fh, ((-B $file) ? ':raw' : ':crlf'));
                $obj->addfile($file_fh);
                $this_hexdigest = $obj->hexdigest;
            }
            $digest{$file} = [$this_cipher, $this_hexdigest];
            $obj->reset;
        }
    }

    return \%digest;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Module::Signature - Module signature file manipulation

=head1 VERSION

version 0.93

=head1 SYNOPSIS

As a shell command:

    % cpansign              # verify an existing SIGNATURE, or
                            # make a new one if none exists

    % cpansign sign         # make signature; overwrites existing one
    % cpansign -s           # same thing

    % cpansign verify       # verify a signature
    % cpansign -v           # same thing
    % cpansign -v --skip    # ignore files in MANIFEST.SKIP

    % cpansign help         # display this documentation
    % cpansign -h           # same thing

In programs:

    use Module::Signature qw(sign verify SIGNATURE_OK);
    sign();
    sign(overwrite => 1);       # overwrites without asking

    # see the CONSTANTS section below
    (verify() == SIGNATURE_OK) or die "failed!";

=head1 DESCRIPTION

B<Module::Signature> adds cryptographic authentications to CPAN
distributions, via the special F<SIGNATURE> file.

If you are a module user, all you have to do is to remember to run
C<cpansign -v> (or just C<cpansign>) before issuing C<perl Makefile.PL>
or C<perl Build.PL>; that will ensure the distribution has not been
tampered with.

Module authors can easily add the F<SIGNATURE> file to the distribution
tarball; see L</NOTES> below for how to do it as part of C<make dist>.

If you I<really> want to sign a distribution manually, simply add
C<SIGNATURE> to F<MANIFEST>, then type C<cpansign -s> immediately
before C<make dist>.  Be sure to delete the F<SIGNATURE> file afterwards.

Please also see L</NOTES> about F<MANIFEST.SKIP> issues, especially if
you are using B<Module::Build> or writing your own F<MANIFEST.SKIP>.

Signatures made with Module::Signature prior to version 0.82 used the
SHA1 algorithm by default. SHA1 is now considered broken, and therefore
module authors are strongly encouraged to regenerate their F<SIGNATURE>
files. Users verifying old SHA1 signature files will receive a warning.

=head1 NAME

Module::Signature - Module signature file manipulation

=head1 VARIABLES

No package variables are exported by default.

=over 4

=item $Verbose

If true, Module::Signature will give information during processing including
gpg output.  If false, Module::Signature will be as quiet as possible as
long as everything is working ok.  Defaults to false.

=item $SIGNATURE

The filename for a distribution's signature file.  Defaults to
C<SIGNATURE>.

=item $AUTHOR

The key ID used for signature. If empty/null/0, C<gpg>'s configured default ID,
or the most recently added key within the secret keyring for C<Crypt::OpenPGP>,
will be used for the signature.

=item $KeyServer

The OpenPGP key server for fetching the author's public key
(currently only implemented on C<gpg>, not C<Crypt::OpenPGP>).
May be set to a false value to prevent this module from
fetching public keys.

=item $KeyServerPort

The OpenPGP key server port, defaults to C<11371>.

=item $Timeout

Maximum time to wait to try to establish a link to the key server.
Defaults to C<3>.

=item $AutoKeyRetrieve

Whether to automatically fetch unknown keys from the key server.
Defaults to C<1>.

=item $Cipher

The default cipher used by the C<Digest> module to make signature
files.  Defaults to C<SHA256>, but may be changed to other ciphers
via the C<MODULE_SIGNATURE_CIPHER> environment variable if the SHA256
cipher is undesirable for the user.

The cipher specified in the F<SIGNATURE> file's first entry will
be used to validate its integrity.  For C<SHA256>, the user needs
to have any one of these modules installed: B<Digest::SHA>,
B<Digest::SHA256>, or B<Digest::SHA::PurePerl>.

=item $Preamble

The explanatory text written to newly generated F<SIGNATURE> files
before the actual entries.

=back

=head1 ENVIRONMENT

B<Module::Signature> honors these environment variables:

=over 4

=item MODULE_SIGNATURE_AUTHOR

Works like C<$AUTHOR>.

=item MODULE_SIGNATURE_CIPHER

Works like C<$Cipher>.

=item MODULE_SIGNATURE_VERBOSE

Works like C<$Verbose>.

=item MODULE_SIGNATURE_KEYSERVER

Works like C<$KeyServer>.

=item MODULE_SIGNATURE_KEYSERVERPORT

Works like C<$KeyServerPort>.

=item MODULE_SIGNATURE_TIMEOUT

Works like C<$Timeout>.

=back

=head1 CONSTANTS

These constants are not exported by default.

=over 4

=item CANNOT_VERIFY (C<0E0>)

Cannot verify the OpenPGP signature, maybe due to the lack of a network
connection to the key server, or if neither gnupg nor Crypt::OpenPGP
exists on the system.

=item SIGNATURE_OK (C<0>)

Signature successfully verified.

=item SIGNATURE_MISSING (C<-1>)

The F<SIGNATURE> file does not exist.

=item SIGNATURE_MALFORMED (C<-2>)

The signature file does not contains a valid OpenPGP message.

=item SIGNATURE_BAD (C<-3>)

Invalid signature detected -- it might have been tampered with.

=item SIGNATURE_MISMATCH (C<-4>)

The signature is valid, but files in the distribution have changed
since its creation.

=item MANIFEST_MISMATCH (C<-5>)

There are extra files in the current directory not specified by
the MANIFEST file.

=item CIPHER_UNKNOWN (C<-6>)

The cipher used by the signature file is not recognized by the
C<Digest> and C<Digest::*> modules.

=back

=head1 NOTES

=head2 Signing your module as part of C<make dist>

The easiest way is to use B<Module::Install>:

    sign;       # put this before "WriteAll"
    WriteAll;

For B<ExtUtils::MakeMaker> (version 6.18 or above), you may do this:

    WriteMakefile(
        (MM->can('signature_target') ? (SIGN => 1) : ()),
        # ... original arguments ...
    );

Users of B<Module::Build> may do this:

    Module::Build->new(
        (sign => 1),
        # ... original arguments ...
    )->create_build_script;

=head2 F<MANIFEST.SKIP> Considerations

(The following section is lifted from Iain Truskett's B<Test::Signature>
module, under the Perl license.  Thanks, Iain!)

It is B<imperative> that your F<MANIFEST> and F<MANIFEST.SKIP> files be
accurate and complete. If you are using C<ExtUtils::MakeMaker> and you
do not have a F<MANIFEST.SKIP> file, then don't worry about the rest of
this. If you do have a F<MANIFEST.SKIP> file, or you use
C<Module::Build>, you must read this.

Since the test is run at C<make test> time, the distribution has been
made. Thus your F<MANIFEST.SKIP> file should have the entries listed
below.

If you're using C<ExtUtils::MakeMaker>, you should have, at least:

    #defaults
    ^Makefile$
    ^blib/
    ^pm_to_blib
    ^blibdirs

These entries are part of the default set provided by
C<ExtUtils::Manifest>, which is ignored if you provide your own
F<MANIFEST.SKIP> file.

If you are using C<Module::Build>, you should have two extra entries:

    ^Build$
    ^_build/

If you don't have the correct entries, C<Module::Signature> will
complain that you have:

    ==> MISMATCHED content between MANIFEST and distribution files! <==

You should note this during normal development testing anyway.

=head2 Testing signatures

You may add this code as F<t/0-signature.t> in your distribution tree:

    #!/usr/bin/perl

    use strict;
    print "1..1\n";

    if (!$ENV{TEST_SIGNATURE}) {
        print "ok 1 # skip Set the environment variable",
                    " TEST_SIGNATURE to enable this test\n";
    }
    elsif (!-s 'SIGNATURE') {
        print "ok 1 # skip No signature file found\n";
    }
    elsif (!eval { require Module::Signature; 1 }) {
        print "ok 1 # skip ",
                "Next time around, consider install Module::Signature, ",
                "so you can verify the integrity of this distribution.\n";
    }
    elsif (!eval { require Socket; Socket::inet_aton('keyserver.ubuntu.com') }) {
        print "ok 1 # skip ",
                "Cannot connect to the keyserver\n";
    }
    else {
        (Module::Signature::verify() == Module::Signature::SIGNATURE_OK())
            or print "not ";
        print "ok 1 # Valid signature\n";
    }

    __END__

If you are already using B<Test::More> for testing, a more
straightforward version of F<t/0-signature.t> can be found in the
B<Module::Signature> distribution.

Note that C<MANIFEST.SKIP> is considered by default only when
C<$ENV{TEST_SIGNATURE}> is set to a true value.

Also, if you prefer a more full-fledged testing package, and are
willing to inflict the dependency of B<Module::Build> on your users,
Iain Truskett's B<Test::Signature> might be a better choice.

=for Pod::Coverage sign verify

=head1 SEE ALSO

L<Digest>, L<Digest::SHA>, L<Digest::SHA::PurePerl>

L<ExtUtils::Manifest>, L<Crypt::OpenPGP>, L<Test::Signature>

L<Module::Install>, L<ExtUtils::MakeMaker>, L<Module::Build>

L<Dist::Zilla::Plugin::Signature>

=head1 AUTHORS

Audrey Tang E<lt>cpan@audreyt.orgE<gt>

=head1 LICENSE

This work is under a B<CC0 1.0 Universal> License, although a portion
of the documentation (as detailed above) is under the Perl license.

To the extent possible under law, 唐鳳 has waived all copyright and related
or neighboring rights to Module-Signature.

This work is published from Taiwan.

L<http://creativecommons.org/publicdomain/zero/1.0>

=head1 AUTHOR

Audrey Tang <cpan@audreyt.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2025 by waved.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
