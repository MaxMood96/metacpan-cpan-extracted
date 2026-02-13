use strict;
use warnings;
use Test::More;

use WWW::Bund::Response::JSON;
use WWW::Bund::Response::XML;
use WWW::Bund::Response::Raw;

# --- JSON Response ---

{
    my $resp = WWW::Bund::Response::JSON->new(
        content      => '{"name":"test","value":42}',
        content_type => 'application/json',
    );
    is_deeply($resp->data, { name => 'test', value => 42 }, 'JSON: parses to hash');
}

{
    my $resp = WWW::Bund::Response::JSON->new(
        content      => '[1,2,3]',
        content_type => 'application/json',
    );
    is_deeply($resp->data, [1, 2, 3], 'JSON: parses array');
}

{
    my $resp = WWW::Bund::Response::JSON->new(content => '');
    is($resp->data, undef, 'JSON: empty content returns undef');
}

# --- XML Response ---

{
    my $xml = '<root><name>test</name><value>42</value></root>';
    my $resp = WWW::Bund::Response::XML->new(
        content      => $xml,
        content_type => 'application/xml',
    );
    my $data = $resp->data;
    is(ref $data, 'HASH', 'XML: returns hash');
    is($data->{name}, 'test', 'XML: simple element text');
    is($data->{value}, '42', 'XML: another element text');
}

{
    my $xml = '<root><item>a</item><item>b</item><item>c</item></root>';
    my $resp = WWW::Bund::Response::XML->new(content => $xml);
    my $data = $resp->data;
    is_deeply($data->{item}, ['a', 'b', 'c'], 'XML: repeated elements become array');
}

{
    my $xml = '<root><el id="x1">hello</el></root>';
    my $resp = WWW::Bund::Response::XML->new(content => $xml);
    my $data = $resp->data;
    is(ref $data->{el}, 'HASH', 'XML: element with attr+text is hash');
    is($data->{el}{id}, 'x1', 'XML: attribute preserved');
    is($data->{el}{_text}, 'hello', 'XML: text in _text key');
}

{
    my $xml = '<root><parent><child>val</child></parent></root>';
    my $resp = WWW::Bund::Response::XML->new(content => $xml);
    my $data = $resp->data;
    is($data->{parent}{child}, 'val', 'XML: nested elements');
}

{
    my $resp = WWW::Bund::Response::XML->new(content => '');
    is($resp->data, undef, 'XML: empty content returns undef');
}

# --- Raw Response ---

{
    my $resp = WWW::Bund::Response::Raw->new(
        content      => 'plain text here',
        content_type => 'text/plain',
    );
    is($resp->data, 'plain text here', 'Raw: returns content as-is');
}

{
    my $resp = WWW::Bund::Response::Raw->new(content => '');
    is($resp->data, '', 'Raw: empty content returns empty string');
}

# --- Role attributes ---

{
    my $resp = WWW::Bund::Response::JSON->new(
        content      => '{}',
        content_type => 'application/json; charset=utf-8',
    );
    is($resp->content, '{}', 'content attribute accessible');
    is($resp->content_type, 'application/json; charset=utf-8', 'content_type attribute accessible');
}

done_testing;
