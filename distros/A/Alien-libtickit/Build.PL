use strict;
use warnings;

use lib 'inc';
use Alien::make::Module::Build;

my $build = Alien::make::Module::Build->new(
   module_name => 'Alien::libtickit',
   tarball => 'libtickit-0.4.5.tar.gz',
   pkgconfig_module => "tickit",
   pkgconfig_version => "0.4.5",
   use_bundled => ( scalar grep { $_ eq "--use-bundled" } @ARGV ),

   alien_requires => [
      [ any =>
         [ pkgconfig => "unibilium", atleast_version => "1.0.0" ],
         [ alien => "Alien::unibilium" => '0.15' ],
      ],
      [ any =>
         [ pkgconfig => "termkey", atleast_version => "0.22" ],
         [ alien => "Alien::libtermkey" => "0.22" ],
      ],
   ],
   build_requires => {
      'File::Basename' => 0,
      'File::Path' => '2.07',
      'File::Spec' => 0,
   },
   configure_requires => {
      'perl' => '5.010', # //
   },
   license => 'perl',
   create_license => 1,
   create_readme  => 1,
);

$build->create_build_script;
