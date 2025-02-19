#!/usr/bin/env perl
use Full::Script qw(:v1);
use IO::Async::Loop;

use Web::Async::WebSocket::Server;

binmode STDERR, ':encoding(UTF-8)';

my $loop = IO::Async::Loop->new;
$loop->add(
    my $srv = Web::Async::WebSocket::Server->new(
        port => 9001,
        on_handshake_failure => async sub ($client, $stream, @) {
            my $txt = <<'HTML';
<!DOCTYPE html>
<html>
 <body>
  ws test
  <script type="module">
const ws = new WebSocket(`ws://${new URL(window.location.href).host}/api`);
ws.addEventListener('message', (msg) => {
    console.debug('Websocket message: ', msg);
});
ws.addEventListener('error', (msg) => {
    console.error('Websocket error received: ', msg);
});

ws.addEventListener('open', (evt) => {
    console.log(`Opened connection`);
    const data = { };
    setInterval(async () => {
        const len = 3 + parseInt(Math.random() * 100);
        let str = '';
        for(let i = 0; i < len; ++i) {
            str = str + String.fromCodePoint(32 + parseInt(Math.random() * 60502));
        }
        data[str] = Math.random();
        await ws.send(JSON.stringify(data));
    }, 300);
});
ws.addEventListener('closed', async (evt) => {
    console.log('Closed connection: ', evt);
});
  </script>
 </body>
</html>
HTML
            my $encoded = encode_utf8 $txt;
            my $length = length($encoded);
            await $stream->write("HTTP/1.1 200 OK\x0D\x0AConnection: close\x0D\x0AContent-Length: $length\x0D\x0AContent-Type: text/html\x0D\x0A\x0D\x0A" . $encoded . "\x0D\x0A");
            $stream->close;
        }
    )
);
$srv->closing_client->each(sub ($client, @) {
    $log->infof('Client: %s closing', '' . $client->{client});
});
$srv->disconnecting_client->each(sub ($client, @) {
    $log->infof('Client: %s disconnecting', '' . $client->{client});
});
$srv->incoming_client->each(sub ($client, @) {
    $log->infof('Client: %s', "$client");
    $client->incoming_frame->map(async sub ($frame, @) {
        $log->tracef('Frame %d with payload %d bytes', $frame->opcode, length $frame->payload);
        if($frame->opcode == 1) {
            await $client->write_frame(
                type    => 'text',
                payload => $frame->payload
            );
        }
    })->resolve->retain;
});

use Net::Async::WebSocket::Client;

$log->infof('Connect');
$loop->add(
    my $ws = Net::Async::WebSocket::Client->new(
        on_frame => sub {
            my ($ws, $frame) = @_;
            $log->infof('frame %s', $frame);
        },
    )
);
await $ws->connect(
    url => "ws://localhost:9001",
);
await $ws->send_text_frame(
    encode_json_utf8({
        id => 1,
        category => 'cs',
        method => 'test',
        data => {
            xyz => 'abc',
        },
        subscribe => 0
    })
);
$ws->close;

$loop->run;
