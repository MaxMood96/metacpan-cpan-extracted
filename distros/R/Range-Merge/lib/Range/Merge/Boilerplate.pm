#
# Copyright (C) 2015-2019 Joelle Maslak
# All Rights Reserved - See License
#

package Range::Merge::Boilerplate;
# ABSTRACT: Generic Boilerplate (copied from JTM::Bootstrap)
$Range::Merge::Boilerplate::VERSION = '2.242740';

use v5.22;
use strict;
use warnings;

use feature 'signatures';
no warnings 'experimental::signatures';

use English;
use Import::Into;
use Smart::Comments;

sub import($self, $type='script') {
    ### assert: ($type =~ m/^(?:class|role|script)$/ms)

    my $target = caller;

    strict->import::into($target);
    warnings->import::into($target);
    autodie->import::into($target);

    feature->import::into($target, ':5.22');

    utf8->import::into($target); # Allow UTF-8 Source

    if ($type eq 'class') {
        Moose->import::into($target);
        Moose::Util::TypeConstraints->import::into($target);
        MooseX::StrictConstructor->import::into($target);
        namespace::autoclean->import::into($target);
    } elsif ($type eq 'role') {
        Moose::Role->import::into($target);
        Moose::Util::TypeConstraints->import::into($target);
        MooseX::StrictConstructor->import::into($target);
        namespace::autoclean->import::into($target);
    }

    Carp->import::into($target);
    English->import::into($target);
    Smart::Comments->import::into($target, '-ENV', '###');

    feature->import::into($target, 'postderef');    # Not needed if feature budle >= 5.23.1

    # We haven't been using this
    # feature->import::into($target, 'refaliasing');
    feature->import::into($target, 'signatures');

    feature->import::into($target, 'unicode_strings');
    # warnings->unimport::out_of($target, 'experimental::refaliasing');
    warnings->unimport::out_of($target, 'experimental::signatures');

    if ($PERL_VERSION lt v5.24.0) {
        warnings->unimport::out_of($target, 'experimental::postderef');
    }

    return;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Range::Merge::Boilerplate - Generic Boilerplate (copied from JTM::Bootstrap)

=head1 VERSION

version 2.242740

=head1 SYNOPSIS

  use Range::Merge::Boilerplate 'script';

=head1 DESCRIPTION

This module optionally takes one of two parameters, 'script', 'class',
or 'role'. If 'script' is specified, the module assumes that you do not
need Moose or MooseX modules.

=head1 WARNINGS

This module makes significant changes in the calling package!

In addition, this module should be incorporated into any project by
copying it into the project's library tree. This protects the project from
outside dependencies that may be undesired.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016-2021 by Joelle Maslak.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
