use strict;
use warnings;
use utf8;
use Encode ();
use Test::More;
use IO::Divert;

subtest 'basic capture and autoprint' => sub {
    my $output = '';
    {
	local *STDOUT;
	open STDOUT, '>', \$output;
	{
	    my $d = IO::Divert->new;
	    print "Hello\n";
	}
    }
    is $output, "Hello\n", 'output captured and printed';
};

subtest 'FINAL callback' => sub {
    my $output = '';
    {
	local *STDOUT;
	open STDOUT, '>', \$output;
	{
	    my $d = IO::Divert->new(FINAL => sub { s/^/> /mg });
	    print "Line1\n";
	    print "Line2\n";
	}
    }
    is $output, "> Line1\n> Line2\n", 'FINAL callback applied';
};

subtest 'autoprint => 0' => sub {
    my $output = '';
    my $captured;
    {
	local *STDOUT;
	open STDOUT, '>', \$output;
	{
	    my $d = IO::Divert->new(autoprint => 0);
	    print "captured";
	    $captured = $d->content;
	}
    }
    is $output, '', 'no autoprint';
    is $captured, 'captured', 'content retrieved';
};

subtest 'content method' => sub {
    my $content;
    {
	local *STDOUT;
	open STDOUT, '>', \my $dummy;
	{
	    my $d = IO::Divert->new(autoprint => 0);
	    print "test";
	    $content = $d->content;
	}
    }
    is $content, 'test', 'content method works';
};

subtest 'clear method' => sub {
    my $output = '';
    {
	local *STDOUT;
	open STDOUT, '>', \$output;
	{
	    my $d = IO::Divert->new;
	    print "first";
	    $d->clear;
	    print "second";
	}
    }
    is $output, 'second', 'clear works';
};

subtest 'UTF-8 handling' => sub {
    my $output = '';
    {
	local *STDOUT;
	open STDOUT, '>:encoding(utf-8)', \$output;
	{
	    my $d = IO::Divert->new;
	    print "日本語\n";
	}
    }
    is Encode::decode('utf-8', $output), "日本語\n", 'UTF-8 handled correctly';
};

subtest 'flush method' => sub {
    my $content;
    {
	local *STDOUT;
	open STDOUT, '>', \my $dummy;
	{
	    my $d = IO::Divert->new(autoprint => 0);
	    print "buffered";
	    $d->flush;
	    $content = $d->{BUFFER};
	}
    }
    is $content, 'buffered', 'flush writes to buffer';
};

subtest 'buffer method' => sub {
    my $bufref;
    {
	local *STDOUT;
	open STDOUT, '>', \my $dummy;
	{
	    my $d = IO::Divert->new(autoprint => 0);
	    print "data";
	    $d->flush;
	    $bufref = $d->buffer;
	    is ref($bufref), 'SCALAR', 'buffer returns scalar ref';
	    is $$bufref, 'data', 'buffer content is correct';
	}
    }
};

subtest 'nested IO::Divert' => sub {
    my $output = '';
    {
	local *STDOUT;
	open STDOUT, '>', \$output;
	{
	    my $d1 = IO::Divert->new(FINAL => sub { s/^/outer: /mg });
	    print "A\n";
	    {
		my $d2 = IO::Divert->new(FINAL => sub { s/^/inner: /mg });
		print "B\n";
	    }
	    print "C\n";
	}
    }
    is $output, "outer: A\nouter: inner: B\nouter: C\n",
	'nested divert works correctly';
};

subtest 'cancel method' => sub {
    my $output = '';
    {
	local *STDOUT;
	open STDOUT, '>', \$output;
	{
	    my $d = IO::Divert->new;
	    print "should be cancelled";
	    $d->cancel;
	}
    }
    is $output, '', 'cancel suppresses output';
};

subtest 'cancel with FINAL' => sub {
    my $final_called = 0;
    my $output = '';
    {
	local *STDOUT;
	open STDOUT, '>', \$output;
	{
	    my $d = IO::Divert->new(
		FINAL => sub { $final_called = 1 }
	    );
	    print "test";
	    $d->cancel;
	}
    }
    is $output, '', 'cancel suppresses output';
    is $final_called, 0, 'FINAL not called after cancel';
};

done_testing;
