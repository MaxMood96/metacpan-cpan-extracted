package Grizzly;

# ABSTRACT: Grizzly - A command-line interface for looking up stock quote.

our $VERSION = '0.111';

use v5.36;

use App::Cmd::Setup -app;
1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Grizzly - Grizzly - A command-line interface for looking up stock quote.

=head1 VERSION

version 0.111

=head1 SYNOPSIS

    grizzly [options]

        Options:

            news [stock symbol]
            quote [stock symbol]
            help
            version

=head2 Options

news - Displays the stock news of a given symbol.

quote - Displays the stock quote of a given symbol.

help - Displays a help message on how to use Grizzly.

version - Displays Grizzly's version number.

=head1 DESCRIPTION

Grizzly will output the stock quote of the given symbol.

=head1 NAME

Grizzly - A command-line interface for looking up stock quote.

=head1 Setup

=head2 Installation

=head3 Through cpanm

    cpanm Grizzly

=head3 Through the Project Directory

    cpanm --installdeps .
    perl Makefile.PL
    make
    make install

=head2 API Key

You will need to get a free API key from L<NewsAPI|https://newsapi.org/>. Afterwards you will need to set the NEWS_API_KEY environment variable to the API key.

=head1 AUTHOR

Nobunaga <nobunaga@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2022 by Nobunaga.

This is free software, licensed under:

  The MIT (X11) License

=cut
