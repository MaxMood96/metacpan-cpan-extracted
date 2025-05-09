#---------------------------------------------------------------------
# $Header: /Perl/OlleDB/t/B_filestream.t 11    24-07-23 22:45 Sommar $
#
# Tests for OpenSqlFilestream.
#
# $History: B_filestream.t $
# 
# *****************  Version 11  *****************
# User: Sommar       Date: 24-07-23   Time: 22:45
# Updated in $/Perl/OlleDB/t
# Rewritten the test of alloclen to avoid issues with bluescreen. Also,
# this test now passes with 32-bit Perl.
# 
# *****************  Version 10  *****************
# User: Sommar       Date: 19-07-05   Time: 21:48
# Updated in $/Perl/OlleDB/t
# Changed test texts in Swedish to texts in English to avoid ���-issues.
# 
# *****************  Version 9  *****************
# User: Sommar       Date: 18-04-11   Time: 21:08
# Updated in $/Perl/OlleDB/t
# Added protection on blue screen on my own machine at home.
# 
# *****************  Version 8  *****************
# User: Sommar       Date: 15-05-24   Time: 22:27
# Updated in $/Perl/OlleDB/t
# Changed condition for 64-bit integers.
# 
# *****************  Version 7  *****************
# User: Sommar       Date: 12-09-23   Time: 22:50
# Updated in $/Perl/OlleDB/t
# Added test for earlier providers, since we now check this in code.
# 
# *****************  Version 6  *****************
# User: Sommar       Date: 11-08-07   Time: 23:34
# Updated in $/Perl/OlleDB/t
# Added better test of the $alloclen parameter.
# 
# *****************  Version 5  *****************
# User: Sommar       Date: 08-05-04   Time: 18:47
# Updated in $/Perl/OlleDB/t
# Don't run the test without SQLNCLI10.
#
# *****************  Version 4  *****************
# User: Sommar       Date: 08-05-02   Time: 0:44
# Updated in $/Perl/OlleDB/t
# Changed the�check for whether FILESTREAM is enabled.
#
# *****************  Version 3  *****************
# User: Sommar       Date: 08-02-17   Time: 18:01
# Updated in $/Perl/OlleDB/t
# Added allocation length to the last call to OpenSqlFilestream.
#
# *****************  Version 2  *****************
# User: Sommar       Date: 07-12-02   Time: 21:41
# Updated in $/Perl/OlleDB/t
#
# *****************  Version 1  *****************
# User: Sommar       Date: 07-11-26   Time: 22:45
# Created in $/Perl/OlleDB/t
#---------------------------------------------------------------------

use strict;
use Config;
use Win32::SqlServer qw(:DEFAULT :consts);
use File::Basename qw(dirname);
use Win32API::File;

require &dirname($0) . '\testsqllogin.pl';


$^W = 1;
$| = 1;

my $X = testsqllogin();
my ($sqlver) = split(/\./, $X->{SQL_version});
my $x86 = not $Config{'use64bitint'};

if ($sqlver < 10) {
   print "1..0 # Skipped: FileStream not available on SQL 2005 and earlier.\n";
   exit;
}

# If we have an old provider, check that we produces an error message.
if ($X->{Provider} < PROVIDER_SQLNCLI10) {
   print "1..1\n";
   eval('$X->OpenSqlFilestream("undef", FILESTREAM_READ, "undef")');
   if ($@ =~ /must use the SQLNCLI10 provider/) {
       print "ok 1\n";
   }
   else {
       print "not ok 1 # $@\n"; 
   }
   exit;
}


my $fs_config = sql_one(<<SQLEND, SCALAR);
SELECT value_in_use FROM sys.configurations WHERE name = 'filestream access level'
SQLEND
if ($fs_config < 2) {
   print "1..0 # Skipped: Instance not configured for remote filestream access.\n";
   exit;
}

my ($username, $servername) = sql_one('SELECT SYSTEM_USER, @@servername', LIST);
if ($username !~ /\\/) {
   print "1..0 # Skipped: filestream requires Windows authentication.\n";
   exit;
}

print "1..9\n";

# Create a test database with a filestream filegroup.
$X->sql(<<'SQLEND');
CREATE DATABASE Olle$DB
ALTER DATABASE Olle$DB ADD FILEGROUP fs CONTAINS FILESTREAM
SQLEND

# We need to know path for data file to determine where to create the
# filestream container.
my $dbpath = $X->sql_one(<<'SQLEND', SCALAR);
SELECT physical_name
FROM   Olle$DB.sys.database_files
WHERE  file_id = 1
SQLEND
$dbpath =~ s/\.mdf$//;
$dbpath .= ".datadir";

# Now we can add the file group.
$X->sql(<<SQLEND);
ALTER DATABASE Olle\$DB ADD FILE
    (NAME = 'fs', FILENAME = '$dbpath') TO FILEGROUP fs
SQLEND

# This is our test strings.
my $yksi  = "The critics are falling over to tell themselves he's boring.\n" x 2000;
my $kaksi = "Who the hell can he be who's never had VD and does not even sit on toilet seats.\n" x 2000;
my $kolme = "His lame-brained antics and jumping in the air.\n" x 1000;
my $negy  = "And so it must be all a game of chess he's playing\n";

# Move to the database and create a table with three rows in it.
$X->sql('USE Olle$DB');
$X->sql(<<'SQLEND', {'@yksi' => ['varchar', $yksi], '@kolme' => ['varchar', $kolme]});
CREATE TABLE fstest (guid uniqueidentifier          NOT NULL ROWGUIDCOL UNIQUE,
                     name varchar(23)               NOT NULL PRIMARY KEY,
                     data varbinary(MAX) FILESTREAM NULL)

INSERT fstest (guid, name, data)
   VALUES(newid(), 'Yksi', cast(@yksi AS varbinary(MAX))),
         (newid(), 'Kaksi', 0x),
         (newid(), 'Kolme', cast(@kolme AS varbinary(MAX)))

SQLEND

# Testing set up. Set up message handling, so that the script does not stop
# on errors.
$X->{ErrInfo}{MaxSeverity} = 16;
$X->{ErrInfo}{PrintLines} = 17;
$X->{ErrInfo}{PrintText} = 17;
$X->{ErrInfo}{PrintMsg} = 17;
$X->{ErrInfo}{SaveMessages} = 1;



# We're all set for testing. Let's try reading data.
my ($path, $context, $fh, $buffer, $ret);
$X->{BinaryAsStr} = 1;
($path, $context) = $X->sql(<<SQLEND, LIST, SINGLEROW);
BEGIN TRANSACTION
SELECT data.PathName(), get_filestream_transaction_context()
FROM   fstest
WHERE  name = 'Yksi'
SQLEND

$fh = $X->OpenSqlFilestream($path, FILESTREAM_READ, $context);
if ($fh > 0) {
   print "ok 1\n";
}
else {
   print "not ok 1\n";
}

$ret = Win32API::File::ReadFile($fh, $buffer, 200000, [], []);
if ($ret) {
   print "ok 2\n";
}
else {
   print "not ok 2 # ReadFile failed with $^E\n";
}

if ($buffer eq $yksi) {
   print "ok 3\n";
}
else {
   print "not ok 3\n";
}

# Close this transaction.
Win32API::File::CloseHandle($fh);
$X->sql('ROLLBACK TRANSACTION');

# Try writing.
$X->{BinaryAsStr} = 0;
($path, $context) = $X->sql(<<SQLEND, LIST, SINGLEROW);
BEGIN TRANSACTION
SELECT data.PathName(), get_filestream_transaction_context()
FROM   fstest
WHERE  name = 'Kaksi'
SQLEND

# The option is just to test that options work.
$fh = $X->OpenSqlFilestream($path, FILESTREAM_WRITE, $context,
                            SQL_FILESTREAM_OPEN_FLAG_NO_WRITE_THROUGH);
if ($fh > 0) {
   print "ok 4\n";
}
else {
   print "not ok 4\n";
}

$ret = Win32API::File::WriteFile($fh, $kaksi, 0, [], []);
if ($ret) {
   print "ok 5\n";
}
else {
   print "not ok 5 # WriteFile failed with $^E\n";
}
# Close this transaction.
Win32API::File::CloseHandle($fh);
$X->sql('COMMIT TRANSACTION');

# And check the data.
$buffer = $X->sql_one(<<SQLEND, SCALAR);
SELECT convert(varchar(MAX), data)
FROM   fstest
WHERE  name = 'Kaksi'
SQLEND
if ($buffer eq $kaksi) {
   print "ok 6\n";
}
else {
   print "not ok 6\n";
}


$X->{BinaryAsStr} = 'x';
($path, $context) = $X->sql(<<SQLEND, LIST, SINGLEROW);
BEGIN TRANSACTION
SELECT data.PathName(), get_filestream_transaction_context()
FROM   fstest
WHERE  name = 'Kolme'
SQLEND

# Test some more flags and also a reasonable value for $alloclen.
$fh = $X->OpenSqlFilestream($path, FILESTREAM_READWRITE, $context,
                            SQL_FILESTREAM_OPEN_FLAG_RANDOM_ACCESS, 10000);
if ($fh > 0) {
   print "ok 7\n";
}
else {
   print "not ok 7\n";
}


# Close this transaction.
Win32API::File::CloseHandle($fh);
$X->sql('COMMIT TRANSACTION');

undef $buffer;

# And check the data.
$buffer = $X->sql_one(<<SQLEND, SCALAR);
SELECT convert(varchar(MAX), data)
FROM   fstest
WHERE  name = 'Kolme'
SQLEND
if ($buffer eq '') {
   print "ok 8\n";
}
else {
   print "not ok 8\n";
}

($path, $context) = $X->sql(<<SQLEND, LIST, SINGLEROW);
BEGIN TRANSACTION
SELECT data.PathName(), get_filestream_transaction_context()
FROM   fstest
WHERE  name = 'Kolme'
SQLEND

# Test that the $alloclen parameter really seem to work.
my $alloclen;
if ($x86) {
	$alloclen = {High => 1, Low => 0};
}
else {
    $alloclen = 4 * 1024 * 1024 * 1024;
}

# We need to know the free space on the drive before and after.
my $drive = $X->sql_one(<<SQLEND, Win32::SqlServer::SCALAR);
    SELECT left(physical_name, 1)
    FROM   sys.database_files
    WHERE  name = 'fs'
SQLEND

my %fixed_drives = $X->sql('EXEC master..xp_fixeddrives', 
                           Win32::SqlServer::KEYED, Win32::SqlServer::SCALAR, [1]);

my $before_size = $fixed_drives{$drive};

$fh = $X->OpenSqlFilestream($path, FILESTREAM_READWRITE, $context, 0,
                               $alloclen);
if ($fh > 0) {
   %fixed_drives = $X->sql('EXEC master..xp_fixeddrives', 
                           Win32::SqlServer::KEYED, Win32::SqlServer::SCALAR, [1]);
   
   my $size_delta = $before_size - $fixed_drives{$drive};

   if ($size_delta > 3 * 1024) {
      print "ok 9\n";
   } 
   else {
      print "not ok 9 # before - after = $size_delta\n";
   }
}
else {
   # Maybe there is no space on the disk?
   my $errmsg = $X->{ErrInfo}{Messages}[0];
   if ($errmsg and
      $errmsg->{Source} eq 'OpenSqlFilestream' and
       $errmsg->{Errno} = -112 and
      $errmsg->{Severity} = 16) { 
       print "ok 9\n";
   }
   else {
      print "not ok 9\n";
   }
}

# Close this transaction.
Win32API::File::CloseHandle($fh);
$X->sql('COMMIT TRANSACTION');

undef $buffer;


$X->sql('USE master');
$X->sql('DROP DATABASE Olle$DB');

exit;

