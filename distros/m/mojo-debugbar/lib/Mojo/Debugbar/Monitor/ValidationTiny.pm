package Mojo::Debugbar::Monitor::ValidationTiny;
use Mojo::Base "Mojo::Debugbar::Monitor";

has 'icon' => '<i class="icon-flag"></i>';
has 'name' => 'Validation';

=head2 render

    Returns the html

=cut

sub render {
    my $self = shift;

    return sprintf(
        '<table class="debugbar-templates table" data-debugbar-ref="%s">
            <thead>
                <tr>
                    <th width="30%%">Field</th>
                    <th>Error</th>
                </tr>
            </thead>
            <tbody>
                %s
            </tbody>
        </table>',
        ref($self), $self->rows
    );
}

=head2 rows

    Build the rows

=cut

sub rows {
    my $self = shift;

    my $time = time;
    my ($sec, $min, $hour) = localtime($time);

    my $rows = sprintf('<tr><td colspan="2">Validation at %s:%s:%s (%s)</td></tr>', $hour, $min, $sec, scalar @{ $self->items });

    foreach my $item (@{ $self->items }) {
        $rows .= sprintf(
            '<tr>
                <td><a href="javascript:jQuery(\'[name=%s]\').css({ background: \'red\'}).focus();">%s</a></td>
                <td>%s</td>
            </tr>',
            $item->{ field }, $item->{ field }, $item->{ message }
        );
    }

    return $rows;
}

=head2 start

    Listen for "after_dispatch" event and if there's anything in stash for validate_tiny.errors key,
    store the field name and the error

=cut

sub start {
    my $self = shift;

    $self->app->hook(after_dispatch => sub {
        my $c = shift;

        my $errors = $c->stash('validate_tiny.errors');

        my @items;
        
        push(@items, { field => $_, message => $errors->{ $_ } }) for keys(%$errors);

        $self->items(\@items);
    });
}

1;
