use Test;
BEGIN { plan tests => 4 }
use DBI;

open(DEF, "<dbd.def ") || die "File dbd.def not found\n";
$line= <DEF>;
chop $line;
my ($host, $port, $prot, $tableset,$user,$pwd) = split(/:/, $line );
close(DEF);

my $dbh = DBI->connect("dbi:Cego:tableset=$tableset;hostname=$host;port=$port;protocol=$prot;logfile=cegoDBD.log;logmode=debug", "$user", "$pwd");
ok($dbh);
$dbh->{AutoCommit} = 1;

my $sth = $dbh->prepare("insert into tab1 values ( 1, 'erwin');");
ok($sth);

ok($sth->execute, "1");
$sth->finish();

$dbh->disconnect;
ok($sth);
