package Example::View::HTML::Contacts::List;

use Moo;
use Example::Syntax;
use Example::View::HTML
  -tags => qw(link_to div a fieldset legend br b u button form_for table thead tbody tfoot trow th td link_to),
  -helpers => qw(edit_uri build_uri list_uri $sf),
  -views => 'HTML::Page', 'HTML::Navbar';

has 'list' => (is=>'ro', required=>1, from=>'controller', handles=>['pager']);

sub render($self, $c) {
  html_page page_title=>'Contact List', sub($page) {
    html_navbar active_link=>'contact_list',
      div {class=>"col-5 mx-auto"}, [
        legend 'Contact List',
        $self->page_window_info,
        div { class=>"alert alert-warning", role=>"alert", if=>!$self->pager->total_entries },
          "No contacts found. Click on 'Create a new Contact' to get started.",
        table +{ if=>($self->pager->total_entries), class=>'table table-striped table-bordered' }, [
          thead
            trow [
              th +{ scope=>"col" }, 'Name',
            ],
          tbody { repeat=>$self->list }, sub ($self, $item, $idx) {
            trow [
              td link_to edit_uri($item), $item->$sf('{:first_name} {:last_name}'),
            ],
          },
          tfoot { if=>$self->pager->last_page > 1  },
            td {colspan=>2, style=>'background:white'},
              ["Page: ", $self->pagelist ],
        ],
        a { href=>build_uri(), role=>'button', class=>'btn btn-lg btn-primary btn-block' }, "Create a new Contact",
     ],
  };
}

sub page_window_info :Renders ($self) {
  return '' unless $self->pager->total_entries > 0;
  my $message = $self->pager->last_page == 1 ?
    "@{[ $self->pager->total_entries ]} @{[ $self->pager->total_entries > 1 ? 'todos':'todo' ]}" :
    $self->pager->$sf('{:first} to {:last} of {:total_entries} todos');
  return div {style=>'text-align:center; margin-top:0; margin-bottom: .5rem'}, $message;
}

sub pagelist :Renders ($self) {
  my @page_html = ();
  foreach my $page (1..$self->pager->last_page) {
    my $page_for_display = $page == $self->pager->current_page ? b u $page : $page;
    push @page_html, link_to list_uri(+{'contact.page'=>$page}), {style=>'margin: .5rem'}, $page_for_display; 
  }
  return @page_html;
}

1;
