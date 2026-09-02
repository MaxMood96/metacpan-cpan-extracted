use Test2::V1
  -pragmas,
  -target => { CLASS => 'Version::Semantic' },
  qw( ok plan );
use Test::API import => [ qw( class_api_ok ) ];

use constant SUPER_CLASS => 'Version::Core'; ## no critic ( ProhibitConstantPragma )

use Module::Loaded qw( mark_as_loaded );

plan 3;

ok mark_as_loaded( SUPER_CLASS ), "${ \SUPER_CLASS } has to be marked as loaded because it is a cuckoo package";

my @methods =
  qw( parse corever_re new prefix major minor patch version_core has_prefix increment compare_to to_string );
class_api_ok SUPER_CLASS, @methods;

class_api_ok CLASS, @methods, qw( semver_re pre_release build has_pre_release has_build is_core )
