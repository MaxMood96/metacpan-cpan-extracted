#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Encode qw(decode_utf8);
use IO::K8s;

my $k8s = IO::K8s->new;

# Helper to decode UTF-8 bytes for pattern matching
sub decode_utf8_checked {
    my ($str) = @_;
    return eval { decode_utf8($str, Encode::FB_CROAK) } // $str;
}

# Test UTF-8 in ConfigMap data
subtest 'ConfigMap with UTF-8 characters' => sub {
    my $cm = $k8s->new_object('ConfigMap', {
        metadata => { name => 'utf8-test', namespace => 'default' },
        data => {
            'german.txt' => 'Grüße aus München: ä ö ü ß',
            'french.txt' => 'Ça va bien!',
            'japanese.txt' => 'こんにちは',
            'emoji.txt' => '🚀⭐❤️🎉',
            'chinese.txt' => '你好世界',
            'special.txt' => '"quotes" and \'apostrophes\' and backslash \\',
        },
    });

    # Test to_json with UTF-8
    my $json = $k8s->object_to_json($cm);
    ok $json, 'to_json returns content';

    # Verify UTF-8 characters are preserved in JSON
    my $json_decoded = decode_utf8_checked($json);
    like $json_decoded, qr/Grüße/, 'German umlauts in JSON';
    like $json_decoded, qr/こんにちは/, 'Japanese in JSON';
    like $json_decoded, qr/🚀/, 'Emoji in JSON';

    # Round-trip: JSON -> Object
    my $decoded = $k8s->json_to_object($json);
    is $decoded->data->{'german.txt'}, 'Grüße aus München: ä ö ü ß', 'German survived round-trip';
    is $decoded->data->{'japanese.txt'}, 'こんにちは', 'Japanese survived round-trip';
    is $decoded->data->{'emoji.txt'}, '🚀⭐❤️🎉', 'Emoji survived round-trip';

    # Test to_yaml with UTF-8
    my $yaml = $cm->to_yaml;
    ok $yaml, 'to_yaml returns content';

    # YAML round-trip: YAML -> Object
    my $yaml_objs = $k8s->load_yaml($yaml);
    is scalar(@$yaml_objs), 1, 'YAML round-trip returned 1 object';
    my $yaml_decoded = $yaml_objs->[0];
    is $yaml_decoded->data->{'german.txt'}, 'Grüße aus München: ä ö ü ß', 'German survived YAML round-trip';
    is $yaml_decoded->data->{'japanese.txt'}, 'こんにちは', 'Japanese survived YAML round-trip';
};

# Test UTF-8 in Pod annotations and labels
subtest 'Pod with UTF-8 in metadata' => sub {
    my $pod = $k8s->new_object('Pod', {
        metadata => {
            name => 'utf8-pod',
            namespace => 'default',
            annotations => {
                'description' => 'Pod with German: Grüße, French: Ça va',
            },
            labels => {
                'app' => 'test-app',
                'environment' => 'développement',
            },
        },
        spec => {
            containers => [{
                name => 'main',
                image => 'nginx',
            }],
        },
    });

    my $json = $k8s->object_to_json($pod);
    my $json_decoded = decode_utf8_checked($json);
    like $json_decoded, qr/Grüße/, 'Annotation with German in JSON';
    like $json_decoded, qr/développement/, 'Label with French in JSON';

    my $decoded = $k8s->json_to_object($json);
    is $decoded->metadata->annotations->{'description'}, 'Pod with German: Grüße, French: Ça va', 'Annotation round-trip OK';
    is $decoded->metadata->labels->{'environment'}, 'développement', 'Label round-trip OK';
};

# Test Secret with UTF-8 data
subtest 'Secret with UTF-8 data' => sub {
    my $secret = $k8s->new_object('Secret', {
        metadata => { name => 'utf8-secret', namespace => 'default' },
        type => 'Opaque',
        data => {
            'password.txt' => 'töpsecret123',
        },
    });

    my $json = $k8s->object_to_json($secret);
    ok $json, 'Secret to_json returns content';

    my $decoded = $k8s->json_to_object($json);
    is $decoded->data->{'password.txt'}, 'töpsecret123', 'Secret data round-trip OK';
};

# Test that JSON output is valid UTF-8
subtest 'JSON output is valid UTF-8' => sub {
    my $cm = $k8s->new_object('ConfigMap', {
        metadata => { name => 'utf8-verify' },
        data => { 'test' => 'äöü' },
    });

    my $json = $k8s->object_to_json($cm);

    my $decoded = $k8s->json_to_object($json);
    is $decoded->data->{'test'}, 'äöü', 'UTF-8 round-trip successful';
};

# Test Container env vars with UTF-8
subtest 'Container with UTF-8 env vars' => sub {
    my $pod = $k8s->new_object('Pod', {
        metadata => { name => 'env-utf8' },
        spec => {
            containers => [{
                name => 'app',
                image => 'myapp:latest',
                env => [
                    { name => 'GREETING', value => 'Hällö Wörld!' },
                    { name => 'CHINESE', value => '你好' },
                ],
            }],
        },
    });

    my $json = $k8s->object_to_json($pod);
    my $json_decoded = decode_utf8_checked($json);
    like $json_decoded, qr/Hällö/, 'UTF-8 env value in JSON';
    like $json_decoded, qr/你好/, 'Chinese env value in JSON';

    my $decoded = $k8s->json_to_object($json);
    my $env = $decoded->spec->containers->[0]->env;
    is $env->[0]->value, 'Hällö Wörld!', 'German env var round-trip';
    is $env->[1]->value, '你好', 'Chinese env var round-trip';
};

done_testing;
