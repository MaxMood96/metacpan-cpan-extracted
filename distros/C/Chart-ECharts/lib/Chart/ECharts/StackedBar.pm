package Chart::ECharts::StackedBar;

use feature ':5.10';
use strict;
use utf8;
use warnings;

use base 'Chart::ECharts::Bar';

sub default_options { {series => {stack => {}}} }

1;

__END__

=encoding utf-8

=head1 NAME

Chart::ECharts::StackedBar - Stacked Bar chart

=head1 SYNOPSIS


=head2 METHODS

L<Chart::ECharts::StackedBar> inherits all methods from L<Chart::ECharts::Base>.


=head1 SUPPORT

=head2 Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at L<https://github.com/giterlizzi/perl-Chart-ECharts/issues>.
You will be notified automatically of any progress on your issue.

=head2 Source Code

This is open source software.  The code repository is available for
public review and contribution under the terms of the license.

L<https://github.com/giterlizzi/perl-Chart-ECharts>

    git clone https://github.com/giterlizzi/perl-Chart-ECharts.git


=head1 AUTHOR

=over 4

=item * Giuseppe Di Terlizzi <gdt@cpan.org>

=back


=head1 LICENSE AND COPYRIGHT

This software is copyright (c) 2024 by Giuseppe Di Terlizzi.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
