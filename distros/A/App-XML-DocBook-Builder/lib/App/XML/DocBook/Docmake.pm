package App::XML::DocBook::Docmake;
$App::XML::DocBook::Docmake::VERSION = '0.1101';
use 5.014;
use strict;
use warnings;

use Getopt::Long qw/ GetOptionsFromArray /;
use File::Path   qw/ mkpath /;
use Pod::Usage   qw/ pod2usage /;

use File::ShouldUpdate v0.2.0 qw/ should_update_multi /;

use App::XML::DocBook::Docmake::CmdComponent ();


use Class::XSAccessor {
    accessors => [
        qw(
            _base_path
            _has_output
            _input_path
            _make_like
            _mode
            _output_path
            _stylesheet
            _trailing_slash
            _use_xsl_ns
            _verbose
            _real_mode
            _xslt_mode
            _xslt_stringparams
        )
    ]
};

use Test::Trap
    qw( trap $trap :flow:stderr(systemsafe):stdout(systemsafe):warn );


my %modes = (
    'fo'   => {},
    'help' => {
        standalone => 1,
    },
    'manpages'  => {},
    'xhtml'     => {},
    'xhtml-1_1' => {
        real_mode => "xhtml",
    },
    'xhtml5' => {
        real_mode => "xhtml",
    },
    'rtf' => {
        xslt_mode => "fo",
    },
    'pdf' => {
        xslt_mode => "fo",
    },
);

sub new
{
    my $class = shift;
    my $self  = {};

    bless $self, $class;

    $self->_init(@_);

    return $self;
}

sub _calc_modes_hash
{
    my ( $self, ) = @_;

    return \%modes;
}

sub _lookup_mode_struct
{
    my ( $self, $mode ) = @_;

    return $self->_calc_modes_hash()->{$mode};
}

sub _init
{
    my ( $self, $args ) = @_;

    my $argv = $args->{'argv'};

    my $output_path;
    my $verbose = 0;
    my $stylesheet;
    my @in_stringparams;
    my $base_path;
    my $make_like   = 0;
    my $_use_xsl_ns = 0;
    my ( $help, $man );
    my $trailing_slash = 1;

    my $ret = GetOptionsFromArray(
        $argv,
        "o=s"              => \$output_path,
        "v|verbose"        => \$verbose,
        "x|stylesheet=s"   => \$stylesheet,
        "stringparam=s"    => \@in_stringparams,
        "basepath=s"       => \$base_path,
        "make"             => \$make_like,
        'help|h'           => \$help,
        'man'              => \$man,
        'ns'               => \$_use_xsl_ns,
        'trailing-slash=i' => \$trailing_slash,
    );

    if ( !$ret )
    {
        pod2usage(2);
    }
    if ($help)
    {
        pod2usage(1);
    }
    if ($man)
    {
        pod2usage( -exitstatus => 0, -verbose => 2 );
    }

    my @stringparams;
    foreach my $param (@in_stringparams)
    {
        if ( $param =~ m{\A([^=]+)=(.*)\z}ms )
        {
            push @stringparams, [ $1, $2 ];
        }
        else
        {
            die "Wrong stringparam argument '$param'! Does not contain a '='!";
        }
    }

    $self->_has_output( $self->_output_path($output_path) ? 1 : 0 );

    $self->_verbose($verbose);
    $self->_stylesheet($stylesheet);
    $self->_xslt_stringparams( \@stringparams );
    $self->_make_like($make_like);
    $self->_base_path($base_path);
    $self->_trailing_slash($trailing_slash);
    $self->_use_xsl_ns($_use_xsl_ns);

    my $mode = shift(@$argv);

    my $mode_struct = $self->_lookup_mode_struct($mode);

    if ($mode_struct)
    {
        $self->_mode($mode);

        my $assign_secondary_mode = sub {
            my ( $struct_field, $attr ) = @_;
            $self->$attr( $mode_struct->{$struct_field} || $mode );
        };

        $assign_secondary_mode->( 'real_mode', '_real_mode' );
        $assign_secondary_mode->( 'xslt_mode', '_xslt_mode' );
    }
    else
    {
        die "Unknown mode \"$mode\"";
    }

    my $input_path = shift(@$argv);

    if ( !( defined($input_path) || $mode_struct->{standalone} ) )
    {
        die "Input path not specified on command line";
    }
    else
    {
        $self->_input_path($input_path);
    }

    return;
}


sub _exec_command
{
    my ( $self, $args ) = @_;

    my $cmd = $args->{cmd};

    if ( $self->_verbose() )
    {
        print( join( " ", @$cmd ), "\n" );
    }

    my $exit_code;
    trap
    {
        local $ENV{LC_ALL} = "C.utf-8";
        $exit_code = system(@$cmd);
    };

    my $stderr = $trap->stderr();

    if ( not( defined($exit_code) and ( !$exit_code ) ) )
    {
        if ( $stderr =~ m#Attempt to load network entity# )
        {
            if ( $args->{xsltproc} )
            {
                die <<"EOF";
Running xsltproc failed due to lacking local DocBook 5/XSL stylesheets and data.
See: https://github.com/shlomif/fortune-mod/issues/45 and
https://github.com/docbook/wiki/wiki/DocBookXslStylesheets

Command was <<@$cmd>>;
EOF
            }
        }
        die qq/$stderr\n<<@$cmd>> failed./;
    }

    return 0;
}

sub run
{
    my $self = shift;

    my $real_mode = $self->_real_mode();

    my $mode_func = '_run_mode_' . $self->_real_mode;

    return $self->$mode_func(@_);
}

sub _run_mode_help
{
    my $self = shift;

    print <<"EOF";
Docmake version $App::XML::DocBook::Docmake::VERSION
A tool to convert DocBook/XML to other formats

Available commands:

    help - this help screen.

    fo - convert to XSL-FO.
    manpages - convert to Unix manpage (nroff)
    rtf - convert to RTF (MS Word).
    pdf - convert to PDF (Adobe Acrobat).
    xhtml - convert to XHTML.
    xhtml-1_1 - convert to XHTML-1.1.
    xhtml5 - convert to XHTML5
EOF
}

sub _is_older
{
    my ( $self, $result_fn, $source_fn ) = @_;

    return should_update_multi( [ $result_fn, ], ':', [ $source_fn, ] );
}

sub _should_update_output
{
    my ( $self, $args ) = @_;

    return $self->_is_older( $args->{output}, $args->{input} );
}

sub _run_mode_fo
{
    my $self = shift;
    return $self->_run_xslt();
}

sub _mkdir
{
    my ( $self, $dir ) = @_;

    mkpath($dir);

    return;
}

sub _run_mode_manpages
{
    my $self = shift;

    # Create the directory, because xsltproc requires it.
    if ( $self->_trailing_slash )
    {
        # die "don't add trailing_slash";

        # $self->_mkdir( $self->_output_path() );
    }

    return $self->_run_xslt();
}

sub _run_mode_xhtml
{
    my $self = shift;

    # Create the directory, because xsltproc requires it.
    if ( $self->_trailing_slash )
    {
        $self->_mkdir( $self->_output_path() );
    }

    return $self->_run_xslt();
}

sub _calc_default_xslt_stylesheet
{
    my $self = shift;

    my $mode = $self->_xslt_mode();

    return
        sprintf(
        "http://docbook.sourceforge.net/release/%s/current/%s/docbook.xsl",
        ( $self->_use_xsl_ns() ? "xsl-ns" : "xsl" ), $mode, );
}

sub _is_xhtml
{
    my $self = shift;

    return (   ( $self->_mode() eq "xhtml" )
            || ( $self->_mode() eq "xhtml-1_1" )
            || ( $self->_mode() eq "xhtml5" ) );
}

sub _calc_output_param_for_xslt
{
    my ( $self, $args ) = @_;

    my $output_path = $self->_output_path();
    if ( defined( $args->{output_path} ) )
    {
        $output_path = $args->{output_path};
    }

    if ( !defined($output_path) )
    {
        die "Output path not specified!";
    }

    # If it's XHTML, then it's a directory and xsltproc requires that
    # it will have a trailing slash.
    if ( $self->_is_xhtml )
    {
        if ( $self->_trailing_slash )
        {
            if ( $output_path !~ m{/\z} )
            {
                $output_path .= "/";
            }
        }
    }

    return $output_path;
}

sub _calc_make_output_param_for_xslt
{
    my ( $self, $args ) = @_;

    my $output_path = $self->_calc_output_param_for_xslt($args);

    # If it's XHTML, then we need to compare against the index.html
    # because the directory is freshly made.
    if ( $self->_is_xhtml )
    {
        $output_path .= "index.html";
    }

    return $output_path;
}

sub _pre_proc_command
{
    my ( $self, $args ) = @_;

    my $input_fn  = $args->{input};
    my $output_fn = $args->{output};
    my $template  = $args->{template};
    my $xsltproc  = ( $args->{xsltproc} // ( die "no xsltproc key" ) );

    return +{
        xsltproc => $xsltproc,
        cmd      => [
            map {
                      ( ref($_) eq '' ) ? $_
                    : $_->is_output()   ? $output_fn
                    : $_->is_input()    ? $input_fn

                    # Not supposed to happen
                    : do { die "Unknown Argument in Command Template."; }
            } @$template
        ]
    };
}

sub _run_input_output_cmd
{
    my ( $self, $args ) = @_;

    my $input_fn       = $args->{input};
    my $output_fn      = $args->{output};
    my $make_output_fn = $args->{make_output} // $output_fn;

    if (
        ( !$self->_make_like() )
        || $self->_should_update_output(
            {
                input  => $input_fn,
                output => $make_output_fn,
            }
        )
        )
    {
        $self->_exec_command( $self->_pre_proc_command($args), );
    }
}

sub _on_output
{
    my ( $self, $meth, $args ) = @_;

    return $self->_has_output() ? $self->$meth($args) : ();
}

sub _calc_output_params
{
    my ( $self, $args ) = @_;

    return (
        output      => $self->_calc_output_param_for_xslt($args),
        make_output => $self->_calc_make_output_param_for_xslt($args),
    );
}

sub _calc_template_o_flag
{
    my ( $self, $args ) = @_;

    return ( "-o", $self->_output_cmd_comp() );
}

sub _calc_template_string_params
{
    my ($self) = @_;

    return [ map { ( "--stringparam", @$_ ) }
            @{ $self->_xslt_stringparams() } ];
}

sub _run_xslt
{
    my ( $self, $args ) = @_;

    my @stylesheet_params = ( $self->_calc_default_xslt_stylesheet() );

    if ( defined( $self->_stylesheet() ) )
    {
        @stylesheet_params = ( $self->_stylesheet() );
    }

    my @base_path_params;

    if ( defined( $self->_base_path() ) )
    {
        @base_path_params =
            ( "--path", ( $self->_base_path() . '/' . $self->_xslt_mode() ), );
    }

    return $self->_run_input_output_cmd(
        {
            input => $self->_input_path(),
            $self->_on_output( '_calc_output_params', $args ),
            xsltproc => 1,
            template => [
                "xsltproc",
                "--nonet",
                $self->_on_output( '_calc_template_o_flag', $args ),
                @{ $self->_calc_template_string_params() },
                @base_path_params,
                @stylesheet_params,
                $self->_input_cmd_comp(),
            ],
        },
    );
}

sub _run_xslt_and_from_fo
{
    my ( $self, $args ) = @_;

    my $xslt_output_path = $self->_output_path();

    if ( !defined($xslt_output_path) )
    {
        die "No -o flag was specified. See the help.";
    }

    # TODO : do something meaningful if a period (".") is not present
    if ( $xslt_output_path !~ m{\.}ms )
    {
        $xslt_output_path .= ".fo";
    }
    else
    {
        $xslt_output_path =~ s{\.([^\.]*)\z}{\.fo}ms;
    }

    $self->_run_xslt( { output_path => $xslt_output_path } );

    return $self->_run_input_output_cmd(
        {
            input    => $xslt_output_path,
            output   => $self->_output_path(),
            template => [
                "fop", ( "-" . $args->{fo_out_format} ),
                $self->_output_cmd_comp(), $self->_input_cmd_comp(),
            ],
            xsltproc => 0,
        },
    );
}

sub _run_mode_pdf
{
    my $self = shift;

    return $self->_run_xslt_and_from_fo(
        {
            fo_out_format => "pdf",
        },
    );
}

sub _run_mode_rtf
{
    my $self = shift;

    return $self->_run_xslt_and_from_fo(
        {
            fo_out_format => "rtf",
        },
    );
}

sub _input_cmd_comp
{
    my $self = shift;

    return App::XML::DocBook::Docmake::CmdComponent->new(
        {
            is_input  => 1,
            is_output => 0,
        }
    );
}

sub _output_cmd_comp
{
    my $self = shift;

    return App::XML::DocBook::Docmake::CmdComponent->new(
        {
            is_input  => 0,
            is_output => 1,
        }
    );
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

App::XML::DocBook::Docmake - translate DocBook/XML to other formats

=head1 VERSION

version 0.1101

=head1 SYNOPSIS

    use App::XML::DocBook::Docmake ();

    my $docmake = App::XML::DocBook::Docmake->new({argv => [@ARGV]});

    $docmake->run()

=head1 FUNCTIONS

=head2 my $obj = App::XML::DocBook::Docmake->new({argv => [@ARGV]})

Instantiates a new object.

=head2 $docmake->run()

Runs the object.

=head1 AUTHOR

Shlomi Fish, C<< <shlomif at cpan.org> >>

=for :stopwords cpan testmatrix url bugtracker rt cpants kwalitee diff irc mailto metadata placeholders metacpan

=head1 SUPPORT

=head2 Websites

The following websites have more information about this module, and may be of help to you. As always,
in addition to those websites please use your favorite search engine to discover more resources.

=over 4

=item *

MetaCPAN

A modern, open-source CPAN search engine, useful to view POD in HTML format.

L<https://metacpan.org/release/App-XML-DocBook-Builder>

=item *

RT: CPAN's Bug Tracker

The RT ( Request Tracker ) website is the default bug/issue tracking system for CPAN.

L<https://rt.cpan.org/Public/Dist/Display.html?Name=App-XML-DocBook-Builder>

=item *

CPANTS

The CPANTS is a website that analyzes the Kwalitee ( code metrics ) of a distribution.

L<http://cpants.cpanauthors.org/dist/App-XML-DocBook-Builder>

=item *

CPAN Testers

The CPAN Testers is a network of smoke testers who run automated tests on uploaded CPAN distributions.

L<http://www.cpantesters.org/distro/A/App-XML-DocBook-Builder>

=item *

CPAN Testers Matrix

The CPAN Testers Matrix is a website that provides a visual overview of the test results for a distribution on various Perls/platforms.

L<http://matrix.cpantesters.org/?dist=App-XML-DocBook-Builder>

=item *

CPAN Testers Dependencies

The CPAN Testers Dependencies is a website that shows a chart of the test results of all dependencies for a distribution.

L<http://deps.cpantesters.org/?module=App::XML::DocBook::Builder>

=back

=head2 Bugs / Feature Requests

Please report any bugs or feature requests by email to C<bug-app-xml-docbook-builder at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/Public/Bug/Report.html?Queue=App-XML-DocBook-Builder>. You will be automatically notified of any
progress on the request by the system.

=head2 Source Code

The code is open to the world, and available for you to hack on. Please feel free to browse it and play
with it, or whatever. If you want to contribute patches, please send me a diff or prod me to pull
from your repository :)

L<https://github.com/shlomif/docmake>

  git clone git://github.com/shlomif/docmake.git

=head1 AUTHOR

Shlomi Fish <shlomif@cpan.org>

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
L<https://github.com/shlomif/docmake/issues>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2024 by Shlomi Fish.

This is free software, licensed under:

  The MIT (X11) License

=cut
