use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Mojolicious::Lite;
use Uniform::HTMX::Mojolicious;

get '/' => sub {
    my $c    = shift;
    my $htmx = Uniform::HTMX::Mojolicious->new($c);

    if ($htmx->is_htmx) {
        $htmx->res_trigger('mojoEvent', { status => 'ok' });
        $htmx->apply($c);
        return $c->render(text => '<strong>Updated via HTMX!</strong>');
    }

    $c->render(inline => <<'HTML');
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Uniform::HTMX::Mojolicious Test</title>
    <script src="https://unpkg.com/htmx.org@1.9.10"></script>
</head>
<body>
    <h1>Uniform::HTMX::Mojolicious Live Test</h1>
    <button hx-get="/" hx-target="#output">Click Me</button>
    <div id="output">Output area...</div>
</body>
</html>
HTML
};

app->start;
