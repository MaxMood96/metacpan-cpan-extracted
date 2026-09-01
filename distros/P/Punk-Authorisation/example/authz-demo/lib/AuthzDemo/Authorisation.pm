package
	AuthzDemo::Authorisation;

use strict;
use warnings;
use Punk::Plugin::Authorisation;    # installs `rule`

rule 'doc.read' => sub {
    my ($c, $doc) = @_;
    return 1 if $doc->{public};
    return 1 if $doc->{owner_id} == ($c->auth_id // 0);
    return 1 if $c->granted('doc.edit', $doc->{id});
    return $c->not_yours;
};

rule 'doc.edit' => sub {
    my ($c, $doc) = @_;
    return 1 if $doc->{owner_id} == ($c->auth_id // 0);
    return 1 if $c->granted('doc.edit', $doc->{id});
    return $c->not_yours;
};

rule 'doc.publish' => sub {
    my ($c, $doc) = @_;
    return $c->not_yours unless $doc->{owner_id} == ($c->auth_id // 0);
    return $c->forbidden unless $c->rank_at_least('editor');
    return 1;
};

rule 'doc.delete' => sub {
    my ($c, $doc) = @_;
    return 1 if $c->rank_at_least('admin');
    return $doc->{owner_id} == ($c->auth_id // 0) ? $c->forbidden
                                                  : $c->not_yours;
};

rule 'doc.share' => sub {
    my ($c, $doc) = @_;
    return 1 if $doc->{owner_id} == ($c->auth_id // 0);
    return $c->not_yours;
};

1;
