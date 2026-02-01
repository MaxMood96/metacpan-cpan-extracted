package nvec_api_test;

use strict;
use warnings;

our $VERSION = '0.01';

require XSLoader;
XSLoader::load('nvec_api_test', $VERSION);

1;

__END__

=head1 NAME

nvec_api_test - Test module for nvec C API

=head1 SYNOPSIS

    use nvec_api_test;

=head1 DESCRIPTION

This module tests the nvec C API by calling it from another XS module.

=cut
