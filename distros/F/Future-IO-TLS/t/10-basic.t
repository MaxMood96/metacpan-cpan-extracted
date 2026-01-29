#! perl

use 5.020;
use warnings;

use Test::More;

use Future::AsyncAwait;
use Future::IO;
# Future::IO->load_best_impl;
Future::IO->load_impl('Uring');
use Future::IO::TLS;
use Socket qw/AF_UNIX SOCK_STREAM PF_UNSPEC/;
use IO::Socket::UNIX;

my $context = Crypt::OpenSSL3::SSL::Context->new;
$context->load_verify_file('t/server.crt');

my ($left, $right) = IO::Socket::UNIX->socketpair(AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die "$!";
$_->blocking(0) for $left, $right;

async sub main() {
	my $connecting = Future::IO::TLS->start_TLS($left, context => $context, hostname => 'server');
	my $accepting = Future::IO::TLS->start_TLS($right, server => 1, private_key_file => 't/server.key', certificate_chain_file => 't/server.crt');
	my $io = await $connecting;
	ok await $io->write($left, "Hello, world!");

	my $io2 = await $accepting;
	my $received = await $io2->read($right, 1024);
	is $received, 'Hello, world!';
}

alarm 3;
main()->get;

done_testing;
