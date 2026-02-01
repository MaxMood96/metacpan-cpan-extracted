package vec_api_test;
use strict;
use warnings;

our $VERSION = '0.01';

require DynaLoader;
our @ISA = qw(DynaLoader);

# Need to load vec first since we depend on its symbols
require 'vec.pm';

bootstrap vec_api_test $VERSION;

1;

__END__

=head1 NAME

vec_api_test - Test module demonstrating vec C API usage

=head1 SYNOPSIS

    use vec_api_test;
    
    # Create vec from C
    my $v = vec_api_test::create_from_c(100);
    
    # Sum using C API
    my $sum = vec_api_test::sum_from_c($v);
    
    # Dot product using C API
    my $dot = vec_api_test::dot_from_c($v1, $v2);
    
    # Add using C API
    my $v3 = vec_api_test::add_from_c($v1, $v2);

=head1 DESCRIPTION

This module demonstrates how to use vec's C API from another XS module.
Include vec_api.h and link against vec to get SIMD-accelerated operations.

=cut
