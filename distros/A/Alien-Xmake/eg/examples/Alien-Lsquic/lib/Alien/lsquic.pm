use v5.40;
use feature 'class';
no warnings 'experimental::class';
use Alien::Xrepo::Base;
#
class Alien::lsquic : isa(Alien::Xrepo::Base) {
    method package_name {'lsquic'}
}
#
1;
