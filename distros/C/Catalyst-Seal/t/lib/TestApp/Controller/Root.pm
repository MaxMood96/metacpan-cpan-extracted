package TestApp::Controller::Root;

use strict;
use warnings;
use base 'Catalyst::Controller';

__PACKAGE__->config(namespace => '');

sub hello :Path('/') :Args(0) {
    my ($self, $c) = @_;
    $c->res->content_type('text/plain');
    $c->res->body('hello');
}

sub book :Path('/books') :Args(1) {
    my ($self, $c, $id) = @_;
    $c->res->content_type('text/plain');
    $c->res->body("book $id");
}

sub query :Path('/query') :Args(0) {
    my ($self, $c) = @_;
    my $p = $c->req->query_parameters;
    $c->res->content_type('text/plain');
    $c->res->body(join ',', map { "$_=" . join('|', $p->get_all($_)) } sort keys %$p);
}

sub headers :Path('/headers') :Args(0) {
    my ($self, $c) = @_;
    $c->res->content_type('text/plain');
    $c->res->body(join ',', map { lc } sort $c->req->headers->header_field_names);
}

sub redirect :Path('/redirect') :Args(0) {
    my ($self, $c) = @_;
    $c->res->redirect('/', 302);
}

# A 3xx carrying Location whose body is a filehandle. This is the one input
# where collapsing the ContentLength / FixMissingBodyInRedirect /
# RemoveRedundantBody response callbacks into one changes the answer:
# response_cb strips Content-Length once per nesting level, so nested,
# FixMissingBodyInRedirect's filter removes it and ContentLength puts one back
# from -s; fused, ContentLength adds it and the single strip takes it away.
# It has to be a real file on disk. Plack::Util::is_real_fh is false for an
# in-memory scalar handle, so content_length returns undef and the interesting
# branch is never taken.
my $REAL_FILE;
BEGIN {
    require File::Temp;
    my ($fh, $name) = File::Temp::tempfile('sealtest-body-XXXXXX', TMPDIR => 1, UNLINK => 1);
    print {$fh} 'moved, with a real filehandle body';
    close $fh;
    $REAL_FILE = $name;
}

sub redirect_fh :Path('/redirect-fh') :Args(0) {
    my ($self, $c) = @_;
    open my $fh, '<', $REAL_FILE or die "$REAL_FILE: $!";
    $c->res->status(302);
    $c->res->header('Location' => '/');
    $c->res->body($fh);
}

# The sharper version: a *blessed* filehandle. FixMissingBodyInRedirect returns
# a chunk filter for this one, so its own response_cb strips Content-Length and
# ContentLength then puts one back from -s. A fused filter that strips once at
# the end instead loses it.
sub redirect_io :Path('/redirect-io') :Args(0) {
    my ($self, $c) = @_;
    require IO::File;
    my $fh = IO::File->new($REAL_FILE, 'r') or die "$REAL_FILE: $!";
    $c->res->status(302);
    $c->res->header('Location' => '/');
    $c->res->body($fh);
}

sub nobody :Path('/nobody') :Args(0) {
    my ($self, $c) = @_;
    $c->res->status(204);
}

sub boom :Path('/boom') :Args(0) {
    die "boom in the action\n";
}

sub httperr :Path('/httperr') :Args(0) {
    require SealTest::HttpError;
    SealTest::HttpError->throw;
}

sub wide :Path('/wide') :Args(0) {
    my ($self, $c) = @_;
    $c->res->content_type('text/plain; charset=UTF-8');
    $c->res->body("caf\x{e9} \x{2603}");
}

sub forwarded :Path('/forwarded') :Args(0) {
    my ($self, $c) = @_;
    $c->forward('hello');
    $c->res->body($c->res->body . ' forwarded');
}

sub notfound :Path :Args {
    my ($self, $c) = @_;
    $c->res->status(404);
    $c->res->content_type('text/plain');
    $c->res->body('not found');
}

# The one place the application asks for its own class data on a request, so a
# later phase that seals class data has something to be wrong about.
sub appname :Path('/appname') :Args(0) {
    my ($self, $c) = @_;
    $c->res->content_type('text/plain');
    $c->res->body($c->config->{name});
}

# The encoding matrix. Phase 6 memoises the decision finalize_encoding makes,
# and that decision is a pure function of the content type, the content
# encoding, the encodable-type regex and the application encoding. This route
# lets the parity table drive all four, and every body shape, from the query
# string.
sub enc :Path('/enc') :Args(0) {
    my ($self, $c) = @_;
    my $p = $c->req->query_parameters;

    if (defined $p->{encoding}) {
        if ($p->{encoding} eq 'clear') { $c->clear_encoding }
        else                           { $c->encoding($p->{encoding}) }
    }

    $c->res->content_type($p->{ct})              if defined $p->{ct};
    $c->res->content_encoding($p->{cenc})        if defined $p->{cenc};

    my $kind = defined $p->{kind} ? $p->{kind} : 'ascii';
    if    ($kind eq 'ascii') { $c->res->body('plain ascii') }
    elsif ($kind eq 'wide')  { $c->res->body("caf\x{e9} \x{2603}") }
    elsif ($kind eq 'bytes') { $c->res->body("caf\xc3\xa9") }
    # Wide, but every character maps to Latin-1, so an ISO-8859-1 encoding
    # succeeds rather than dying on the snowman.
    elsif ($kind eq 'latin') { $c->res->body("caf\x{e9}") }
    elsif ($kind eq 'array') { $c->res->body(['one', 'two']) }
    elsif ($kind eq 'empty') { $c->res->body('') }
    elsif ($kind eq 'undef') { }
    elsif ($kind eq 'fh')    {
        my $text = "from a filehandle";
        open my $fh, '<', \$text or die $!;
        $c->res->body($fh);
    }
}

# Root has its own begin and auto, which makes the Steps namespace two autos
# deep and gives the flattened chain an inherited step to get wrong.
sub begin :Private {
    my ($self, $c) = @_;
    push @{ $c->stash->{trace} ||= [] }, 'root-begin';
}

sub auto :Private {
    my ($self, $c) = @_;
    push @{ $c->stash->{trace} ||= [] }, 'root-auto';
    return 1;
}

sub end :Private {
    my ($self, $c) = @_;
    return if $c->res->body;
    return unless @{ $c->error };
    $c->res->status(500) if $c->res->status == 200;
    $c->res->content_type('text/plain');
    $c->res->body('error: ' . scalar @{ $c->error });
    $c->clear_errors;
}

1;
