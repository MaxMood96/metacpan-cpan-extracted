package file_api_test;
use strict;
use warnings;

our $VERSION = '0.01';

require XSLoader;
XSLoader::load('file_api_test', $VERSION);

1;

__END__

=head1 NAME

file_api_test - Test module for file hooks C API

=head1 SYNOPSIS

    use file_api_test;

    # Install hooks from C
    file_api_test::install_uppercase_hook('read');
    file_api_test::install_lowercase_hook('write');

    # Check hooks
    if (file_api_test::has_hook('read')) { ... }

    # Clear hooks
    file_api_test::clear_hook('read');

    # Direct string transformation (for testing)
    my $upper = file_api_test::transform_string('uppercase', 'hello');

=head1 DESCRIPTION

This module tests the file_hooks.h C API by providing XS functions
that register and manage hooks using the C interface.

=cut
