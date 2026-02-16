#!perl
use 5.008;
use strict;
use warnings FATAL => 'all';
use lib 't';
use Test::More;
use Test::Exception;

use lib 'lib';
use Mail::AuthenticationResults::Header;
use Mail::AuthenticationResults::Header::AuthServID;
use Mail::AuthenticationResults::Header::Base;
use Mail::AuthenticationResults::Header::Comment;
use Mail::AuthenticationResults::Header::Entry;
use Mail::AuthenticationResults::Header::Group;
use Mail::AuthenticationResults::Header::SubEntry;
use Mail::AuthenticationResults::Header::Version;

subtest helpers => sub{
  my $header = Mail::AuthenticationResults::Header->new;
  lives_ok( sub { $header->add_entry(test => 'pass') },        'can add entry to header' );
  lives_ok( sub { $header->add_comment('this is a comment') }, 'can add comment to header' );
  dies_ok(  sub { $header->add_sub_entry(invalid => 'fail') }, 'cannot add sub entry to header' );

  my $expected = "unknown;\n    test=pass; (this is a comment)";
  is($header->as_string, $expected, 'Stringifies as expected');
};

subtest helpers_deep => sub {
  my $header    = Mail::AuthenticationResults::Header->new;
  my $entry     = $header->add_entry(dkim => 'pass');
  my $sub_entry = $entry->add_sub_entry(foo => 'bar');
  my $comment   = $sub_entry->add_comment('this is a comment');

  my $expected = "unknown;\n    dkim=pass foo=bar (this is a comment)";
  is($header->as_string, $expected, 'Stringifies as expected');
};

done_testing;