package Hash::Util::Join;
use strict;
use warnings;

use Exporter qw[import];

BEGIN {
  our $VERSION   = '0.07';
  our @EXPORT_OK = qw[ hash_inner_join
                       hash_left_join
                       hash_right_join
                       hash_outer_join
                       hash_left_anti_join
                       hash_right_anti_join
                       hash_full_anti_join 
                       hash_partition
                       hash_partition_by ];

  our %EXPORT_TAGS = (
    all       => \@EXPORT_OK,
    joins     => [qw[ hash_inner_join
                      hash_left_join
                      hash_right_join
                      hash_outer_join
                      hash_left_anti_join
                      hash_right_anti_join
                      hash_full_anti_join ]],
    partition => [qw[ hash_partition
                      hash_partition_by ]],
  );

  my $use_pp = $ENV{HASH_UTIL_JOIN_PP};
  if (!$use_pp) {
    eval {
      require Hash::Util::Join::XS;
    };
    $use_pp = !!$@;
  }

  if ($use_pp) {
    require Hash::Util::Join::PP;
    Hash::Util::Join::PP->import(@EXPORT_OK);
    our $IMPLEMENTATION = 'PP';
  }
  else {
    Hash::Util::Join::XS->import(@EXPORT_OK);
    our $IMPLEMENTATION = 'XS';
  }
}

1;
