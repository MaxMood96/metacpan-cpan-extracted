#########################################################################
#
# Serż Minus (Sergey Lepenkov), <abalama@cpan.org>
#
# Copyright (C) 1998-2022 D&D Corporation. All Rights Reserved
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#########################################################################
use strict;
use warnings;
use Test::More tests => 2;

use CTK;
my $ctk = CTK->new(
        plugins => [qw/test/]
    );
ok($ctk->status, "CTK with plugins is ok");
note($ctk->error) unless $ctk->status;
my $msg = $ctk->foo;
ok(length($msg), "Length of response");
if (-d '.svn' || -d '.git') {
    note(explain($ctk));
    note($ctk->foo);
}

1;

__END__
