#
# This file is part of Config-Model
#
# This software is Copyright (c) 2005-2022 by Dominique Dumont.
#
# This is free software, licensed under:
#
#   The GNU Lesser General Public License, Version 2.1, February 1999
#
package Config::Model::Lister 2.155;

use strict;
use warnings;
use Exporter;

use vars qw/@EXPORT/;

@EXPORT = qw(applications models);

sub available_models {
    my $test = shift || 0;

    my ( %categories, %appli_info, %applications );
    my %done_cat;
    my @dir_to_scan = $test ? qw/lib/ : @INC;

    foreach my $dir ( map { glob("$_/Config/Model/*.d") } @dir_to_scan ) {
        my ($cat) = ( $dir =~ m!.*/([\w\-]+)\.d! );

        if ( $cat !~ /^user|system|application$/ ) {
            warn "available_models: skipping unexpected category: $cat\n";
            next;
        }

        foreach my $file ( sort glob("$dir/*") ) {
            next if $file =~ m!/README!;
            next if $file =~ /(~|\.bak|\.orig)$/;
            my ($appli) = ( $file =~ m!.*/([\w\-]+)! );

            # ensure that an appli file of a cat is not parsed twice
            # (useful in dev, where system appli file may clobber
            # appli file in dvelopment
            next if $done_cat{$cat}{$appli};

            $appli_info{$appli}{_file} = $file;
            $appli_info{$appli}{_category} = $cat;
            open my $fh, '<', $file || die "Can't open file $file:$!";
            while (<$fh>) {
                chomp;
                s/^\s+//;
                s/\s+$//;
                s/#.*//;
                my ( $k, $v ) = split /\s*=\s*/;
                next unless $v;
                if ( $k =~ /model/i ) {
                    push @{ $categories{$cat} }, $appli unless $done_cat{$cat}{$appli};
                    $done_cat{$cat}{$appli} = 1;
                }

                $appli_info{$appli}{$k} = $v;
                $applications{$appli} = $v if $k =~ /model/i;
            }
            die "Missing model line in file $file\n" unless $done_cat{$cat}{$appli};
        }
    }
    return \%categories, \%appli_info, \%applications;
}

sub models {
    my @i = available_models(@_);
    return join( ' ', sort values %{ $i[2] } ) . "\n";
}

sub applications {
    my @i = available_models(@_);
    return join( ' ', sort keys %{ $i[2] } ) . "\n";
}

1;

# ABSTRACT: List available models and applications

__END__

=pod

=encoding UTF-8

=head1 NAME

Config::Model::Lister - List available models and applications

=head1 VERSION

version 2.155

=head1 SYNOPSIS

 perl -MConfig::Model::Lister -e'print Config::Model::Lister::models;'

 perl -MConfig::Model::Lister -e'print Config::Model::Lister::applications;'

=head1 DESCRIPTION

Small modules to list available models or applications whose config
can be edited by L<cme>. This module is designed to be used by bash
completion.

All functions accept an optional boolean parameter. When true, only
the local C<lib> dir is scanned.

=head1 FUNCTIONS

=head1 available_models

Returns an array of 3 hash refs:

=over

=item *

category (system or user or application) => application list. E.g.

 { system => [ 'popcon' , 'fstab'] }

=item *

application name to model information. E.g.

 { 'multistrap' => { model => 'Multistrap', require_config_file => 1 }

=item *

application name to model name. E.g.

 { popcon => 'Popcon', 'multistrap' => 'Multistrap' }

=back

=head1 models

Returns a string with the list of models.

=head1 applications

Returns a string with the list of editable applications.

=head1 AUTHOR

Dominique Dumont

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2005-2022 by Dominique Dumont.

This is free software, licensed under:

  The GNU Lesser General Public License, Version 2.1, February 1999

=cut
