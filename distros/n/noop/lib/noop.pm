package noop;
use strict;
use warnings;
our $VERSION = '0.01';

require XSLoader;
XSLoader::load('noop', $VERSION);

use Exporter 'import';
our @EXPORT_OK = qw(noop);

1;
__END__

=head1 NAME

noop - A no-operation function, optimized to a single custom op

=head1 SYNOPSIS

    use noop 'noop';
    
    noop();  # Does nothing, very fast
    
    # Useful as default callback
    my $callback = $opts{on_complete} // \&noop;
    $callback->($result);

=head1 DESCRIPTION

C<noop> provides a function that does absolutely nothing, optimized
at compile time to a single custom op with minimal overhead.

=head1 FUNCTIONS

=head2 noop

    noop();

Does nothing. Returns nothing. Very fast.

=head1 AUTHOR

LNATION E<lt>email@lnation.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
