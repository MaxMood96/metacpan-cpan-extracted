use strict;
use warnings;
use utf8;
use Test::More;
use lib 't/lib';
use MIMERead;
BEGIN { do './t/sibling.pl' }

BEGIN {
    plan skip_all => 'Punk 0.29+ required for the plugin tests'
        unless eval { require Punk; Punk->VERSION('0.29'); 1 };
    plan skip_all => 'Template::Stencil 0.10+ required for template tests'
        unless eval { require Template::Stencil; Template::Stencil->VERSION('0.10'); 1 };
}

# templates: text and HTML from one name, the layout, escaping on the
# HTML side only, the render data, and the croak for a name that is not
# there.

my %probe;
{
    package T21;
    use Punk;

    plugin 'Mailer' => {
        transport => 'capture',
        from      => 'Ops <ops@example.com>',
        base      => 'https://t21.example',
        mail_dir  => 't/mail',
        layout    => 'layout',
    };

    get '/probe' => sub {
        my ($c) = @_;
        $probe{mail}     = sub { $c->mail(@_) };
        $probe{template} = sub { $c->mail_template(@_) };
        return $c->text('ok');
    };
}

require Punk::Test;
Punk::Test->new('T21')->get_ok('/probe')->status_is(200);
my $cap = Punk::Plugin::Mailer->engine_for('T21')->transport;

{
    my $st = Punk::Plugin::Mailer::state_for('T21');
    is_deeply([ sort keys %{ $st->{templates} } ], [ qw(layout plain token verify) ],
        'the directory was read at registration');
    is_deeply($st->{templates}{verify}, { txt => 1, html => 1 }, '  verify has both kinds');
    is_deeply($st->{templates}{plain}, { txt => 1 }, '  plain has text only');
}

# ---- text + html, through the layout --------------------------------------------
{
    my $r = $probe{mail}->(to => 'Ann <a@example.com>', subject => 'Please verify',
        template => 'verify', data => { name => 'Ann <b>', link => 'https://t21.example/v/1' });
    ok($r->accepted, 'sent') or diag $r->message;
    my $m = MIMERead::parse($cap->messages->[-1]{bytes});
    is($m->{type}, 'multipart/alternative', 'both kinds make an alternative');
    my ($text, $html) = map { $_->{body} } @{ $m->{parts} };
    like($text, qr/^== Please verify ==\r\n/, 'the text layout, with the subject');
    like($text, qr/Hello Ann <b>,/, 'the text part is not escaped');
    like($text, qr{visit https://t21\.example/v/1}, '  and has the link');
    like($text, qr/-- sent by https:\/\/t21\.example \(\)/, '  base in the data; locale empty without I18n');
    like($html, qr{<title>Please verify</title>}, 'the html layout');
    like($html, qr/Hello Ann &lt;b&gt;,/, 'the html part is escaped');
    like($html, qr{<a href="https://t21\.example/v/1">verify</a>}, '  and the body was inserted raw into the layout');
    like($html, qr{<footer>https://t21\.example</footer>}, '  with base in the layout data too');
}

# ---- a text-only template is a text-only message ---------------------------------
{
    $probe{mail}->(to => 'a@example.com', subject => 'p', template => 'plain', data => { word => 'here' });
    my $m = MIMERead::parse($cap->messages->[-1]{bytes});
    is($m->{type}, 'text/plain', 'text only');
    like($m->{body}, qr/Plain only: here/, '  rendered');
}

# ---- explicit text wins over the template's ------------------------------------------
{
    $probe{mail}->(to => 'a@example.com', subject => 'p', template => 'plain', text => "mine\n");
    my $m = MIMERead::parse($cap->messages->[-1]{bytes});
    like($m->{body}, qr/^== p ==|mine/, 'a given text is kept');
    unlike($m->{body}, qr/Plain only/, '  and the template text was not used');
}

# ---- mail_template ---------------------------------------------------------------------
{
    my $p = $probe{template}->('verify', { name => 'Zoë', link => 'L' });
    like($p->{text}, qr/Hello Zoë,/, 'mail_template text');
    like($p->{html}, qr/Hello Zoë,/, '  and html, with UTF-8 intact');
    $p = $probe{template}->('plain', { word => 'w' });
    is($p->{html}, undef, 'no html file means undef');

    # the whole way through: a rendered non-ASCII name must reach the wire
    # encoded once. Stencil returns UTF-8 bytes; read as latin-1 they would
    # be encoded again, and "ZoÃ«" is what the recipient would see.
    $probe{mail}->(to => 'a@example.com', subject => 'é', template => 'plain', data => { word => 'Zoë' });
    my $m = MIMERead::parse($cap->messages->[-1]{bytes});
    my $body = $m->{body};
    ok(utf8::decode($body), 'the body is valid UTF-8');
    like($body, qr/Plain only: Zoë/, '  and decodes to the name once, not twice');
    is($m->{headers}{subject}, '=?UTF-8?B?w6k=?=', 'the subject is encoded once too');
}

# ---- a name that is not there --------------------------------------------------------
{
    ok(!eval { $probe{mail}->(to => 'a@example.com', subject => 's', template => 'nope'); 1 },
        'an unknown template croaks');
    like($@, qr/no template 'nope' in mail_dir \(have: layout, plain, token, verify\)/,
        '  listing what exists');
    ok(!eval { $probe{mail}->(to => 'a@example.com', subject => 's', template => 'plain', data => 'x'); 1 },
        'data must be a hashref');
}

# ---- a layout that does not exist croaks at plugin time ---------------------------------
{
    my $err = do { local $@; eval q{ package T21b; use Punk; plugin 'Mailer' => { transport => 'capture', mail_dir => 't/mail', layout => 'nope' }; 1 }; $@ };
    like($err, qr/layout 'nope' has no nope\.txt\.tmpl/, 'a missing layout croaks at plugin time');
    $err = do { local $@; eval q{ package T21c; use Punk; plugin 'Mailer' => { transport => 'capture', mail_dir => 't/bin' }; 1 }; $@ };
    like($err, qr/holds no \*\.txt\.tmpl/, 'a directory with no templates croaks');
}

done_testing;
