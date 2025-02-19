use strict;
use warnings FATAL => 'all';
use if $ENV{AUTOMATED_TESTING}, 'Test::DiagINC'; use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil qw(t_cmp);
use lib 't';
use File::Slurp qw(slurp);

# Test minification with an explicitly specified minifier.
plan tests => 2, need_lwp;

# CSS::Minifier
css_minifier: {
    my $body = GET_BODY '/explicit/pp';
    my $min  = slurp('t/htdocs/minified.txt');
    chomp($min);

    ok( t_cmp($body, $min) );
}

# CSS::Minifier::XS
css_minifier_xs: {
    eval { require CSS::Minifier::XS };
    if ($@) {
        skip "CSS::Minifier::XS not installed";
    }
    else {
        my $body = GET_BODY '/explicit/xs';
        my $min  = slurp('t/htdocs/minified-xs.txt');
        chomp($min);

        ok( t_cmp($body, $min) );
    }
}
