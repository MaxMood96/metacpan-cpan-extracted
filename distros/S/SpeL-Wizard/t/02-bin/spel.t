# -*- cperl -*-
use Test::More;

use IO::File;
use File::Compare;

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent = 1;

$0 =~ qr{(?<path>.*)\.(?<ext>[^\.]+)$};
$path = $+{path};
$path =~ s/\.\///;

say STDERR $path;

my @testfiles = glob "$path/*.spelidx";

plan tests => scalar @testfiles;

foreach my $file ( sort @testfiles ) {
  $file =~ qr{(?<base>.*)\.(?<ext>[^\.]+)$};
  $base = $+{base};
  system( "perl bin/spel-wizard.pl -v -v --test $base > $base.brown 2> $base.stderr" );
  eval {
    if( File::Compare::compare_text( "$base.brown", "$base.golden",
				     sub { $_[0] =~ s/\015$//; $_[0] ne $_[1] } ) ) {
      # Added this to get more info from fails reported by CPAN testers
      if ( $base =~ /^bracket|docstrip|i18n/ ) {
       	say STDERR "== GOLDEN ==== $base =======================";
       	system( "cat $base.golden" );
       	say STDERR "== BROWN ===================================";
       	system( "cat $base.brown" );
       	say STDERR "== STDERR===================================";
       	system( "cat $base.stderr" );
       	say STDERR "============================================";
      }
      fail( $file );
    }
    else {
      pass( "$file" );
    }
    1;
  } or do {
    fail( "$file: no golden file available" );
  };
}
