use v5.40;

use Test2::V0;

use Test2::Require::Module 're::engine::RE2';

use String::Copyright {
	format => sub { join ':', $_->[0] || '', $_->[1] || '' }
};

ok $INC{'re/engine/RE2.pm'}, 'RE2 engine loaded by default';

done_testing;
