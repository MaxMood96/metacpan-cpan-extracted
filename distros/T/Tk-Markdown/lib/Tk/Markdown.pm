package Tk::Markdown;

use 5.006;
use strict;
use warnings FATAL => 'all';

=head1 NAME

Tk::Markdown - display Markdown in a Text

=cut

our $VERSION = '0.08';

use base qw(Tk::Derived Tk::Text);
use Tk::Font;
#use Tk::Carp qw/fatalsToDialog warningsToDialog tkDeathsNonFatal/;
## commented out Tk::carp because it is not available in ppm.

Construct Tk::Widget 'Markdown';


=head1 SYNOPSIS

  use Tk;
  use Tk::Markdown;
  
  my $mw = Tk::MainWindow->new();
  my $mdt = $mw->Markdown();
  
  my $markdown = q~# Heading 1
  ## Heading 2
  ### Heading 3
  #### Heading 4
  ##### Heading 5
  ###### Heading 6
  
  * list 1
  ** list 2
  *** list 3
  **** list 4
  ***** list 5
  ****** list 6
  
      Source shown in monofont
      another line of source code here
  ~;
  
  $mdt->insert('0.0', $markdown);

  
=head1 DESCRIPTION

Tk::Markdown is a widget to render L<Markdown|https://en.wikipedia.org/wiki/Markdown> in a L<Tk::Text> widget.


=head1 METHODS

=head2 insert

Whenever insert is called on the Markdown widget, some translation is done on the text in order to display it nicely as Markdown.
Tables are reformatted (if the line starts with a bar) and headers are tagged with different fonts.

This module has very basic support for Markdown and there is still plenty to do, e.g. links, images, etc.

=cut

### add the processing functionality to the insert method
sub insert {
    my ($self,$index,$content) = @_;
    my $res = $self->SUPER::insert($index,FormatMarkdown($content));
    if(! $self->{inserting}) { ### don't allow recursion...
        $self->{inserting} = 1;
        $self->PaintMarkdown();
        # $self->TransformTk();
        $self->see("1.0");
        $self->{inserting} = 0;
    }
    return $res;
}



### these few subs are taken directly from ROText...

=head2 defaultStyles 

Called internally. You can access the styles like this:

    use Data::Dumper;
    print Dumper $o->{styles};

To set styles, use C<$o-E<gt>setStyles>

=cut

### named styles, used in _rules_ below.
sub defaultStyles { 
    my $self = shift;   
    my @sans = qw/-family Helvetica -size/;
    my @serif = qw/-family Times -size/;
    my @mono = qw/-family Courier -size/;
    my @bold = qw/-weight bold/;
    my @italic = qw/-slant italic/;
    my @under = qw/-underline 1/;
    my @over = qw/-overstrike 1/;
    my %ss = (
        body => ['black',@serif,12],
        h1 => ['navy',@sans,18,@bold,@italic],
        h2 => ['firebrick',@sans,18,@bold],
        h3 => ['darkgreen',@sans,16,@bold,@italic],
        h4 => ['brown',@sans,16,@bold],
        h5 => ['seagreen',@sans,14,@bold,@italic],
        h6 => ['darkslateblue',@sans,14,@bold],
        code => ['DarkSlateGray',@mono,10],
        list => ['black', @sans, 10],
    );
    #foreach(keys %ss){
    #    print @{$ss{$_}} % 2, "\n";
    #}
    $self->{'styles'} = \%ss;
    $self->setStyles(%ss);
}


=head2 setStyles

The argument is a hash of styles. The keys are predefined names, currently:

=over

=item body

=item h1

=item h2

=item h3

=item h4

=item h5

=item h6

=item code

=item list

=back

And the values are listrefs, in which the first element is the C<-foreground> color, and the remainder are options for the L<Tk::Font> object.
For example:

    $o->setStyles(
        'h1' => [ qw/ red -family Times -weight bold -size 32 / ],
    )

=cut


### add styles as tags to the text
sub setStyles {
    my ($self,%styles) = @_;
    %{$self->{styles}} = (%{$self->{styles}},%styles);
    foreach (keys %styles) {
        my ($color,@font) = @{$styles{$_}};
        $self->tagConfigure($_, -foreground=>$color, -font=>$self->Font(@font));
    }
    my ($color,@font) = @{$styles{body}};
    $self->configure(-font=>$self->Font(@font),-foreground=>$color);
}


=head2 FormatMarkdown

This is called internally. It prettifies Markdown prior to insertion.

<% Perl code here %> is interpreted here.
So if you want to have Perl code that results in formatted Markdown, you'll need to put it inside C<<% %>> (as opposed to the C<<? ?>> that will get run by L<Tk::MarkdownTk>)

=cut

### reformat the text of certain Markdown components to make them prettier...
sub FormatMarkdown {
    my $markdown = shift;
    $markdown =~ s/<\%=(.*?)\%>/ my $v=$1; eval("\$v = sub{ $v }"); &$v()/ges;
    $markdown =~ s/<\%(.*?)\%>/ eval($1); ''/ges;
    my @lines = split /\n/, $markdown;
    my $i = 0;
    while($i < @lines) {
        if($lines[$i] =~ /^\|/){ # tables!
            my $j = $i;
            while($lines[$j+1] =~ /^\||^-+$/){ $j++; }
            @lines[$i..$j] = FormatMarkdownTable(@lines[$i..$j]);
            $i = $j;
        }
        $i++;
    }
    $markdown = join("\n", @lines);
    return $markdown;
}


=head2 FormatMarkdownTable

This is called internally. It prettifies Markdown tables.

=cut

### reformat the text of tables to make them prettier...
sub FormatMarkdownTable {
    s/\s*\|\s*/|/g foreach @_;
    s/^\s*\|\s*// foreach @_;
    s/\s*\|\s*$// foreach @_;
    my @colwidths = map {0} split /\|/, $_[0];
    foreach my $row (@_) {
        next if $row =~ /^-+$/;
        my @row = split /\|/, $row;
        @colwidths = map {$colwidths[$_] > length($row[$_]) ? $colwidths[$_] : length($row[$_])} 0..$#row;
    }
    my $sum = 0;
    foreach (@colwidths) {
        $sum += $_;
        $sum += 3;
    }
    my $hr = '-' x $sum;
    my @table;
    foreach my $row (@_) {
        if($row =~ /^-+$/){
            push @table, $hr;
            next;
        }
        my @row = split /\|/, $row;
        foreach my $j(0..$#row) {
            my $diff = $colwidths[$j] - length($row[$j]);
            my $spaces = ' ' x $diff;
            # if a number...
            if($row[$j] =~ /^[-+]?(?:0[bx]|)\d+\.?\d*[fe][+-]?\d*$/){
                $row[$j] = $spaces . $row[$j];
            }
            else {
                $row[$j] .= $spaces;
            }
            $row[$j] = " $row[$j] ";
        }
        push @table, "|".join('|', @row)."|";
    }
    return @table;
}


=head2 PaintMarkdown

This is called internally. It applies the styles.

=cut

### Add tags and substitute some characters to format the Markdown.
sub PaintMarkdown {
    my $self = shift;
    my @rules = (
        ### HEADERS
        [qr/^#[^#].*$/m, 'h1', qr/^#\s*(?=[^#])/m ,''],
        [qr/^##[^#].*$/m, 'h2', qr/^##\s*(?=[^#])/m, ''],
        [qr/^###[^#].*$/m, 'h3', qr/^###\s*(?=[^#])/m, ''],
        [qr/^####[^#].*$/m, 'h4', qr/^####\s*(?=[^#])/m, ''],
        [qr/^#####[^#].*$/m, 'h5', qr/^#####\s*(?=[^#])/m, ''],
        [qr/^######[^#].*$/m, 'h6', qr/^######\s*(?=[^#])/m, ''],
        
        ### TABLES
        [qr/^\|.*\|$|^-+$|^\s\s\s\s/m, 'code', '', ''],
        
        ### LISTS
        [qr/^\*[^*].*$/m, 'list', qr/^\*(?=[^*])/, "   \x{2022} "],
        [qr/^\*\*[^*].*$/m, 'list', qr/^\*\*(?=[^*])/, "      \x{25E6} "],
        [qr/^\*\*\*[^*].*$/m, 'list', qr/^\*\*\*(?=[^*])/, "         \x{2022} "],
        [qr/^\*\*\*\*[^*].*$/m, 'list', qr/^\*\*\*\*(?=[^*])/, "            \x{25E6} "],
        [qr/^\*\*\*\*\*[^*].*$/m, 'list', qr/^\*\*\*\*\*(?=[^*])/, "               \x{2022} "],
        [qr/^\*\*\*\*\*\*[^*].*$/m, 'list', qr/^\*\*\*\*\*\*(?=[^*])/, "                  \x{25E6} "],
      
        ### CODE
        [qr/^\s\s\s\s.*$/m, 'code', '', ''],
    );
    
    foreach(@rules) {
        my ($re,$tag,$search,$replace) = @$_;
        $self->FindAll('-regexp','-case', $re );
        my @i = $self->tagRanges('sel');
        $self->tagAdd($tag,@i) if @i;
        if($search){
            #print "$search\n";
            $self->FindAndReplaceAll('-regexp','-case', $search, $replace);
        }
    }
}


=head2 clipEvents

This copied directly from L<Tk::ROText>.

=cut

sub clipEvents {
    return qw[Copy];
}


=head2 ClassInit

This is copied directly from L<Tk::ROText>.

=cut

sub ClassInit {
    my ($class,$mw) = @_;
    my $val = $class->bindRdOnly($mw);
    my $cb = $mw->bind($class,'<Next>');
    $mw->bind($class,'<space>',$cb) if (defined $cb);
    $cb = $mw->bind($class,'<Prior>');
    $mw->bind($class,'<BackSpace>', $cb) if (defined $cb);
    $class->clipboardOperations($mw,'Copy');
    return $val;
}


=head2 Populate

This is copied and modified from L<Tk::ROText>. The modification is the addition of a call to C<setDefaultStyles>. That's all.

=cut

sub Populate {
    my ($self,$args) = @_;
    $self->SUPER::Populate($args);
    my $m = $self->menu->entrycget($self->menu->index('Search'), '-menu');
    $m->delete($m->index('Replace'));
    $self->ConfigSpecs(-background=>['SELF'], -foreground=>['SELF'],);
    $self->defaultStyles(); ### Jimi added this line... does a bit more setup.
}


=head2 Tk::Widget::ScrlMarkdown

Copied and adapted from L<Tk::ROText>.

=cut

sub Tk::Widget::ScrlMarkdown { shift->Scrolled('Markdown' => @_) }


=head1 SEE ALSO

L<Tk::MarkdownTk>, L<Tk::Text>


=head1 AUTHOR

Jimi Wills.

Currently maintained by Alexander Becker.

=head1 BUGS

Known issue: Tables do not work.

Please report any bugs or feature requests via GitHub: L<https://github.com/asb-capfan/Tk-Markdown>




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Tk::Markdown


You can also look for information at:

=over 4

=item * GitHub (report bugs here):

L<https://github.com/asb-capfan/Tk-Markdown>

=back


=head1 LICENSE AND COPYRIGHT

Copyright 2013 JimiWills.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of Tk::Markdown