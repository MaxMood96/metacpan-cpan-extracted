use strict;
use warnings;

my $file = shift @ARGV // q{coverage.txt};
open my $fh, q{<}, $file or die qq{Can't open '$file': $!\n};

my $total;
while ( my $line = <$fh> ) {
    next if $line !~ /^Total\s+/;
    $total = $line;
}
close $fh;

die qq{Unable to find Devel::Cover Total row in '$file'\n} if !defined $total;

my @column = split /\s+/, $total;
shift @column if defined $column[0] && $column[0] eq q{};
shift @column;    # Total

my @metric = (
    [ statement  => 0 ],
    [ subroutine => 3 ],
);

for my $metric (@metric) {
    my ( $name, $index ) = @$metric;
    my $value = $column[$index];
    die qq{Coverage report did not contain $name coverage\n}
      if !defined $value || $value eq q{n/a};
    $value =~ s/%$//;
    die sprintf qq{%s coverage is %s%%; 100%% is required\n}, $name, $value
      if $value + 0 < 100;
}

print qq{100% statement and subroutine coverage confirmed.\n};
