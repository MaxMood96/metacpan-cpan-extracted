package MockHTTP;

use strict;
use warnings;

sub new {
    my ( $class, %args ) = @_;
    return bless {
        routes       => $args{routes} || {},
        mirror       => $args{mirror} || {},
        calls        => [],
        mirror_calls => [],
        sleep        => $args{sleep} || 0,
    }, $class;
}

sub get {
    my ( $self, $url ) = @_;
    push @{ $self->{calls} }, $url;
    sleep $self->{sleep} if $self->{sleep};
    my $response = $self->{routes}->{$url};
    return ref $response eq q{CODE} ? $response->($url) : $response // { success => 0, status => 404, content => q{} };
}

sub mirror {
    my ( $self, $url, $file ) = @_;
    push @{ $self->{mirror_calls} }, [ $url, $file ];
    my $response = $self->{mirror}->{$url};
    $response = ref $response eq q{CODE} ? $response->( $url, $file ) : $response;
    $response //= { success => 1, status => 200, content => q{mock data} };
    if ( $response->{success} && defined $file ) {
        open my $fh, q{>}, $file or die $!;
        print {$fh} $response->{content} // q{mock data};
        close $fh;
    }
    return $response;
}

sub calls        { return $_[0]->{calls} }
sub mirror_calls { return $_[0]->{mirror_calls} }

1;
