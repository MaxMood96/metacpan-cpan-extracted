package Export::XS;
use 5.012;
use XS::Loader;

our $VERSION = '3.0.8';

XS::Loader::load();

require Export::XS::Auto;

1;
