# encoding: HP15
# This file is encoded in HP-15.
die "This file is not encoded in HP-15.\n" if q{あ} ne "\x82\xa0";

use HP15;
print "1..1\n";

my $__FILE__ = __FILE__;

if ($^O eq 'MacOS') {
    print "ok - 1 # SKIP $^X $0\n";
    exit;
}

# CORE::dbmopen broken
if (
    ($^O =~ /MSWin32/) and
    ($] =~ /^5\.028/)
) {
    print "ok - 1 # SKIP CORE::dbmopen() maybe broken $__FILE__ $^X $] $^O $ENV{'PROCESSOR_ARCHITECTURE'}\n";
    exit;
}

my $chcp = '';
if ($^O =~ /\A (?: MSWin32 | NetWare | symbian | dos ) \z/oxms) {
    $chcp = `chcp`;
}
if ($chcp !~ /932/oxms) {
    print "ok - 1 # SKIP $^X $0\n";
    exit;
}

if (($ENV{'PERL5SHELL'}||$ENV{'COMSPEC'}) =~ / \\COMMAND\.COM \z/oxmsi) {
    system('del F*.* >NUL');
}
else {
    system('del F*.* >NUL 2>NUL');
}
unlink('F機能');

# dbmopen
eval {
    my %DBM;
    if (dbmopen(%DBM,'F機能',0777)) {
        print "ok - 1 dbmopen $^X $__FILE__\n";
        dbmclose(%DBM);
    }
    else {
        print "not ok - 1 dbmopen: $! $^X $__FILE__\n";
    }
};
if ($@) {
    print "ok - 1 # SKIP dbmopen() maybe broken $^X $__FILE__\n";
}

if (($ENV{'PERL5SHELL'}||$ENV{'COMSPEC'}) =~ / \\COMMAND\.COM \z/oxmsi) {
    system('del F*.* >NUL');
}
else {
    system('del F*.* >NUL 2>NUL');
}
unlink('F機能');

__END__
