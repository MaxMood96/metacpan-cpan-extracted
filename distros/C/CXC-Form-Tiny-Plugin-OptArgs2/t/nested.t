#! perl

use v5.20;

use Test2::V0;
use Test::Lib;

use My::Test::AutoCleanHash;
use Data::Dumper;
use OptArgs2;

use experimental 'signatures', 'postderef';

package My::SubForm {

    use Form::Tiny plugins => ['+CXC::Form::Tiny::Plugin::OptArgs2'];

    use Types::Standard       qw( ArrayRef Bool Enum HashRef Str );
    use Types::Common::String qw( NonEmptyStr );

    form_field 'upload' => ( type => HashRef [Str], );
    option(
        isa     => 'HashRef',
        comment => 'table name/filename pairs to upload',
    );

    form_field 'vars' => (
        type    => HashRef [Str],
        default => sub { { a => 1 } },
    );
    option(
        isa     => 'HashRef',
        comment => 'variables to interpolate into query template',
    );

}

package My::Form {

    use Form::Tiny plugins => ['+CXC::Form::Tiny::Plugin::OptArgs2'];

    use Types::Standard       qw( ArrayRef Bool Enum HashRef Str );
    use Types::Common::String qw( NonEmptyStr );

    form_field 'file' => ( type => Str, );
    option(
        isa      => 'Str',
        comment  => 'Query in a file',
        isa_name => 'ADQL in a file',
    );

    form_field 'adql' => ( type => NonEmptyStr, );
    option(
        isa      => 'Str',
        comment  => 'Query on the command line',
        isa_name => 'ADQL',
    );

    form_field 'url' => (
        type    => Str,
        default => sub { 'https://cda.cfa.harvard.edu/csc2tap' },
    );

    option(
        isa          => 'Str',
        comment      => 'CSC TAP endpoint',
        isa_name     => 'URL',
        show_default => 1,
    );

    form_field 'output.file' => ( type => Str, );
    option(
        name     => 'output',
        isa      => 'Str',
        comment  => 'File to store parsed results',
        isa_name => 'filename',
    );

    form_field 'output.encoding' => ( type => Enum [ 'json', 'yaml' ], );
    option(
        name    => 'encoding',
        isa     => 'Str',
        comment => sprintf( 'encoding format for --output [%s]', join( ' | ', qw( json yaml ) ) ),
    );

    form_field 'raw.encoding' => ( type => Enum [ 'foo', 'bar' ], );
    option(
        name    => 'raw-format',
        isa     => 'Str',
        comment => sprintf( 'requested VO format [%s]', join( ' | ', qw( foo bar ) ) ),
    );

    form_field 'raw.file' => ( type => Str, );
    option(
        name     => 'raw-output',
        isa      => 'Str',
        comment  => 'store raw results from CSC server in this file',
        isa_name => 'filename',
    );


    form_field 'use_db' => (
        type    => Bool,
        default => sub { 0 },
    );
    option(
        name    => 'db',
        isa     => 'Flag',
        comment => 'output to database instead of a file',
    );

    form_field 'stuff' => ( type => My::SubForm->new, );
    # add some arguments, in reverse order

    form_field 'arg2' => ( type => ArrayRef, );
    argument(
        isa     => 'ArrayRef',
        comment => 'every thing else',
        greedy  => 1,
        order   => 2,
    );

    form_field 'arg1' => ( type => NonEmptyStr, );
    argument(
        isa     => 'Str',
        comment => 'first argument',
        order   => 1,
    );
}

sub options {
    {
        'raw-output' => 3,
        'raw-format' => 'foo',
        encoding     => 'json',
        file         => 't/data/cscquery.csc',
        output       => 2,
        url          => 1,
        # files need to exist; test doesn't do anything with them.
        stuff => {
            upload => {
                table1 => 't/data/cscquery.csc',
                table2 => 't/data/cscquery.csc',
            },
        },
        arg1 => 'val1',
        arg2 => [ 'val2.1', 'val2.2' ],
    };
}

sub argv {
    @ARGV = (
        qw( --raw-output=3 --raw-format=foo --encoding=json --file t/data/cscquery.csc ),
        qw( --output 2 --url 1 ),
        qw( --stuff-upload table1=t/data/cscquery.csc ),
        qw( --stuff-upload table2=t/data/cscquery.csc ),
        qw( val1 val2.1 val2.2 ),
    );
}

my $form = My::Form->new;

argv();
my $args;
ok( lives { $args = optargs( comment => 'comment', optargs => $form->optargs ) },
    'form->optargs accepted by OptArgs2::optargs' )
  or bail_out( $@ );

{
    tie my %options, 'My::Test::AutoCleanHash', options();
    is(
        $args,
        hash {
            field arg1         => $options{arg1};
            field arg2         => $options{arg2};
            field file         => $options{file};
            field url          => $options{url};
            field output       => $options{output};
            field encoding     => $options{encoding};
            field 'raw-output' => $options{'raw-output'};
            field 'raw-format' => $options{'raw-format'};
            field stuff_upload => hash {
                my %upload = $options{stuff}{upload}->%*;
                field $_ => $upload{$_} for keys %upload;
                end;
            };
            end;
        },
        'optargs correctly parsed command line input',
    );

    bail_out( q{didn' t process all of the options : } . join q{,}, keys %options )
      if keys %options;
}


ok(
    lives {
        $form->set_input_from_optargs( $args )
    },
    'set input from optargs output',
);

ok( $form->valid, 'form validated input' )
  or bail_out Dumper( $form->errors_hash );

{
    tie my %options, 'My::Test::AutoCleanHash', options();
    is(
        $form->fields,
        hash {
            field arg1   => $options{arg1};
            field arg2   => $options{arg2};
            field file   => $options{file};
            field url    => $options{url};
            field output => hash {
                field file     => $options{output};
                field encoding => $options{encoding};
                end;
            };
            field raw => hash {
                field file     => $options{'raw-output'};
                field encoding => $options{'raw-format'};
                end;
            };
            end;
            field stuff => hash {
                field upload => hash {
                    my %upload = $options{stuff}{upload}->%*;
                    field $_ => $upload{$_} for keys %upload;
                    end;
                };
                field vars => hash {
                    field a => 1;
                    end;
                };
                end;
            };
            field use_db => F();
            end;
        },
        'form fields match expectations',
    );

    bail_out( q{didn't process all of the options: } . join q{,}, keys %options )
      if keys %options;
}


done_testing;
