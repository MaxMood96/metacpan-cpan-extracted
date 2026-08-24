use strict;
use warnings;
use Test::More;

package My::Custom::Driver;
use parent 'Uniform::Upload';

sub new {
    my ($class, $req, %args) = @_;
    return $class->SUPER::new(in => $req, %args);
}

sub extract {
    my ($self) = @_;
    my $req = $self->{in};

    my @files;
    for my $item (@{ $req->{files} || [] }) {
        push @files, $self->wrap(%$item);
    }
    return \@files;
}

package main;

my $mock_req = {
    files => [
        {
            name     => 'doc',
            filename => 'file.pdf',
            tmp_path => '/tmp/pdf_123',
            size     => 1024,
            type     => 'application/pdf',
        }
    ]
};

my $driver = My::Custom::Driver->new($mock_req, max_size => '1MB');

isa_ok($driver, 'My::Custom::Driver');
isa_ok($driver, 'Uniform::Upload');

my $extracted = $driver->extract;
is(scalar @$extracted, 1, 'subclass extract() parses mock request');
isa_ok($extracted->[0], 'Uniform::Upload::File');
is($extracted->[0]->sanitized_filename, 'file.pdf', 'extracted file object functions normally');

done_testing();
