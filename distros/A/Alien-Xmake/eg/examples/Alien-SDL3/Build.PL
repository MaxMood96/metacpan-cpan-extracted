use v5.40;
use FindBin;
use Alien::Xrepo::Base;

# We pass the class name so the installer knows what packages to build
Build_PL('Alien::SDL3');