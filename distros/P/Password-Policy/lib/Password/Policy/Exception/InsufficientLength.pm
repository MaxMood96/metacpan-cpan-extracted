package Password::Policy::Exception::InsufficientLength;
$Password::Policy::Exception::InsufficientLength::VERSION = '0.06';
use strict;
use warnings;

use parent 'Password::Policy::Exception';

sub error { return "The specified password was not long enough"; }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Password::Policy::Exception::InsufficientLength

=head1 VERSION

version 0.06

=head1 AUTHOR

Andrew Nelson <anelson@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Andrew Nelson.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
