package Facebook::Graph::Publish::PageTab;
$Facebook::Graph::Publish::PageTab::VERSION = '1.1205';
use Moo;
extends 'Facebook::Graph::Publish';

use constant object_path => '/tabs';

has app_id => (
	is => 'rw',
	required => 1,
);

around get_post_params => sub {
    my ($orig, $self) = @_;
    my $post = $orig->($self);
    push @$post, app_id => $self->app_id;
    return $post;
};

1;


=head1 NAME

Facebook::Graph::Publish::PageTab - Add a page tab.

=head1 VERSION

version 1.1205

=head1 SYNOPSIS

 my $fb = Facebook::Graph->new;

 $fb->add_page_tab($page_id, $app_id)->publish;

=head1 DESCRIPTION

This module gives you quick and easy access to publish an app as a page tab.

B<ATTENTION:> You must have the C<manage_pages> privilege to use this module.

=head1 METHODS

=head2 app_id ( id )

Specify an app id for the app to add as the page tab.

=head2 publish ( )

Posts the data and returns a L<Facebook::Graph::Response> object. The response object should contain the id:

 {"id":"1647395831_130068550371568"}

=head1 LEGAL

Facebook::Graph is Copyright 2010 - 2017 Plain Black Corporation (L<http://www.plainblack.com>) and is licensed under the same terms as Perl itself.

=cut
