# Copyright (c) 2024-2025 Löwenfelsen UG (haftungsbeschränkt)
# Copyright (c) 2024-2025 Philipp Schafft

# licensed under Artistic License 2.0 (see LICENSE file)

# ABSTRACT: Work with Tag databases

package Data::TagDB::WellKnown;

use v5.10;
use strict;
use warnings;

use Carp;

use parent 'Data::TagDB::WeakBaseObject';

our $VERSION = v0.10;

my %wk_ise = (
    # Hints as taken from tagdb-cgi-import;
    also_shares_identifier      => 'ddd60c5c-2934-404f-8f2d-fcb4da88b633',
    tagname                     => 'bfae7574-3dae-425d-89b1-9c087c140c23',
    uuid                        => '8be115d2-dc2f-4a98-91e1-a6e3075cbc31',
    uri                         => 'a8d1637d-af19-49e9-9ef8-6bc1fbcf6439',
    oid                         => 'd08dc905-bbf6-4183-b219-67723c3c8374',
    wikidata_identifier         => 'ce7aae1e-a210-4214-926a-0ebca56d77e3',
    small_identifier            => 'f87a38cb-fd13-4e15-866c-e49901adbec5',
    
    # Used for additional features of source format:
    important                   => 'e6135f02-28c1-4973-986c-ab7a6421c0a0',
    no_direct                   => '05648b38-e73c-485c-b536-286ce0918193',
    has_type                    => '7f265548-81dc-4280-9550-1bd0aa4bf748',
    owned_by                    => '0ad7f760-8ee7-4367-97f2-ada06864325e',
    implies                     => 'e48cd5c6-83d7-411e-9640-cb370f3502fc',
    flagged_as                  => 'a1c478b5-0a85-4b5b-96da-d250db14a67c',
    using_namespace             => '3c9f40b4-2b98-44ce-b4dc-97649eb528ae',
    for_type                    => 'bc2d2e7c-8aa4-420e-ac07-59c422034de9',


    # Other stuff:
    default_context             => '6ba648c2-3657-47c2-8541-9b73c3a9b2b4',
    default_type                => '87c4892f-ae39-476e-8ed0-d9ed321dafe9',
    default_encoding            => '8440eabd-5d73-4679-8f06-abaa06cf04ac',
    specialises                 => '923b43ae-a50e-4db3-8655-ed931d0dd6d4',
    generalises                 => 'c8530d1b-d600-47e5-bc06-7b01416c79eb',
    unicode_string              => 'eacbf914-52cf-4192-a42c-8ecd27c85ee1',
    utf_8_string_encoding       => 'ec6cd46a-aef5-495d-830b-acb3347a34ec',
    string_ise_uuid_encoding    => 'b448c181-606e-460a-a8cd-8b60aeefe6bb',
    string_ise_oid_encoding     => '5af917c5-67fd-4019-be38-4093fde9b612',
    ascii_uri_encoding          => '61ae4438-e519-4af2-9286-afe8e03bf932',
    colour_value                => 'c64b5209-b975-4e59-9467-3c3b3f136b4e',
    hex_rgb_encoding            => '66d561ee-c06f-408f-a56c-a009439283bb',
    ascii_decimal_integer_encoding   => '84c0547d-4cce-4ece-8d47-57ca8b3a7763',
    tagpool_tag_icontext        => '922257e5-8fda-405c-aced-44a378acbdcf',
    tagpool_type_icontext       => '962af011-3e8e-4468-9b2e-9d4df93c0d9c',
    has_colour_value            => '4c771f95-9c12-4fc7-9cf6-1d5dee7024f9',
    displaycolour               => 'a7cfbcb0-45e2-46b9-8f60-646ab2c18b0b',
    also_shares_colour          => 'c6e83600-fd96-4b71-b216-21f0c4d73ca6',
    primary_colour              => 'd0421d68-8d37-4f78-b800-cae3e896bea5',
    tag_links                   => 'd926eb95-6984-415f-8892-233c13491931',
    tagpool_title               => '361fda18-50ce-4421-b378-881179b0318a',
    tagpool_description         => 'ca33b058-b4ce-4059-9f0b-61ca0fd39c35',
    tagpool_tagged_as           => '703cbb5d-eb4a-4718-9e60-adbef6f71869',
    subject_type                => 'e8c156be-4fe7-4b13-b4fa-e207213caef8',
    inverse_relation            => '1eae4688-f66c-4c77-bc9b-bb38be88240a',
    final_file_size             => '1cd4a6c6-0d7c-48d1-81e7-4e8d41fdb45d',
    final_file_hash             => '79385945-0963-44aa-880a-bca4a42e9002',
    final_file_encoding         => '448c50a8-c847-4bc7-856e-0db5fea8f23b',
    generator_request           => 'ab573786-73bc-4f5c-9b03-24ef8a70ae45',
    generated_by                => '8efbc13b-47e5-4d92-a960-bd9a2efa9ccb',
    namespace                   => 'd9bd807e-57cb-4736-9317-bf6bba5db48a',
    generator                   => '8a1cb2d6-df2f-46db-89c3-a75168adebf6',
    icon                        => 'caf11e36-d401-4521-8f10-f6b36125415c',
    fetch_file_uri              => '96674c6c-cf5e-40cd-af1e-63b86e741f4f',
    specific_taglist            => '03cadc6f-2609-4527-b296-2590d737e99a',
    also_list_contains_also     => '4c9656eb-c130-42b7-9348-a1fee3f42050',
    encoding_file_name_extension   => '3d737a5c-9389-4ae7-80ff-5f64c6b3b7f1',
    x11_colour_name             => '135032f7-cc60-46ee-8f64-1724c2a56fa2',
    also_has_role               => 'd2750351-aed7-4ade-aa80-c32436cc6030',
    also_has_comment            => '11d8962c-0a71-4d00-95ed-fa69182788a8',
    also_has_description        => '30710bdb-6418-42fb-96db-2278f3bfa17f',
    also_has_proto_title        => 'a845bfb7-130f-4f55-8a6d-ea3e5b1c2a09',
    also_has_title              => 'f7fd59e6-6727-4128-a0a7-cbc702dc09b8',
    also_has_subtitle           => 'df70343f-0c5f-4d76-93b6-4376f680f567',
    gamebook_has_title          => '1357f4c9-0419-4493-8d2c-97c6a40a9bc9',
    ascii_code_point            => 'f4b073ff-0b53-4034-b4e4-4affe5caf72c',
    unicode_code_point          => '5f167223-cc9c-4b2f-9928-9fe1b253b560',
    proto_file                  => '52a516d0-25d8-47c7-a6ba-80983e576c54',
    earth                       => '3c2c155f-a4a0-49f3-bdaf-7f61d25c6b8c',
    language_tag_identifier     => 'd0a4c6e2-ce2f-4d4c-b079-60065ac681f1', # sid=8
    text_fragment               => '6085f87e-4797-4bb2-b23d-85ff7edc1da0', # sid=19


    # Boolans:
    false                       => '6d34d4a1-8fbc-4e22-b3e0-d50f43d97cb1', # sid=45,sni=189
    true                        => 'eb50b3dc-28be-4cfc-a9ea-bd7cee73aed5', # sid=46,sni=190

    # Number related:
    unsigned_integer            => 'dea3782c-6bcb-4ce9-8a39-f8dab399d75d',
    has_prime_factor            => '7f55c943-06a4-42e4-9c02-f8d2d00479a0',
    zero                        => 'dd8e13d3-4b0f-5698-9afa-acf037584b20',
    one                         => 'bd27669b-201e-51ed-9eb8-774ba7fef7ad',
    two                         => '73415b5a-31fb-5b5a-bb82-8ea5eb3b12f7',
    three                       => 'be6d8e00-a6c1-5c44-8ffc-f7393e14aa23',
    four                        => '79422b2c-b6f6-547f-949f-0cba44fa69b7',
    hrair                       => '7cb67873-33bc-4a93-b53f-072ce96c6f1a',


    # Wikidata:
    wd_unicode_character        => '615351ce-3254-5684-a1ab-93f7c852e626', # P487
    wd_sRGB_colour_hex_triplet  => 'bcff702a-5d22-5e56-abaf-bda489b8438e', # P465


    # SIRTX:
    sirtx_logical               => '5e80c7b7-215e-4154-b310-a5387045c336', # sid=113,sni=10
    sirtx_function_number       => 'd73b6550-5309-46ad-acc9-865c9261065b',
    sirtx_function_name         => 'd690772e-de18-4714-aa4e-73fd35e8efc9',


    # Chat 0:
    chat_0_word_identifier      => '2c7e15ed-aa2f-4e2f-9a1d-64df0c85875a', # sid=112,sni=118
);

my %aliases = (
    taglist => 'specific_taglist',
);

my %wk_tagname = (
    # first some simple ones:
    (map {$_ => $_ =~ tr/_/-/r}
        # Taken from hints:
        qw(also_shares_identifier tagname uuid uri oid wikidata_identifier small_identifier),  # recommend
        qw(important no_direct has_type owned_by implies flagged_as using_namespace for_type), # friendly

        # related to generators:
        qw(generator_request generated_by namespace generator),


        # Others:
        qw(default_context),
        qw(also_has_role),
        qw(also_has_title),
        qw(tagpool_title tagpool_description tagpool_tag_icontext tagpool_type_icontext),
        qw(gamebook_has_title),
        qw(icon fetch_file_uri),
        qw(has_colour_value also_shares_colour primary_colour displaycolour),
        qw(proto_file),
    )
);

my %wk_sid = (
    # Entries marked as "unassigned" are unassigned as of 2024-05-12Z.
    also_shares_identifier      =>   1,
    uuid                        =>   2,
    tagname                     =>   3,
    has_type                    =>   4,
    uri                         =>   5,
    oid                         =>   6,
    #unassigned                      7
    language_tag_identifier     =>   8,
    wikidata_identifier         =>   9,
    specialises                 =>  10,
    unicode_string              =>  11,
    # integer                       12
    unsigned_integer            =>  13,
    #unassigned                     14
    #unassigned                     15
    default_context             =>  16,
    proto_file                  =>  17,
    final_file_size             =>  18,
    text_fragment               =>  19,
    also_list_contains_also     =>  20,
    # proto-message                 21
    # proto-entity                  22
    # proxy-type                    23
    flagged_as                  =>  24,
    # marked_as                     25
    # roaraudio-error-number        26
    small_identifier            =>  27,
    also_has_role               =>  28,
    #unassigned                     29
    #unassigned                     30
    #unassigned                     31
    final_file_encoding         =>  32,
    final_file_hash             =>  33,
    # ...
    false                       =>  45,
    true                        =>  46,
);

my %wk_default_type = (
    (map {$_ => 'unicode_string'}
        qw(also_has_title),
        qw(tagpool_title tagpool_description tagpool_tag_icontext tagpool_type_icontext),
        qw(gamebook_has_title),
    ),
    (map {$_ => 'uri'}
        qw(icon fetch_file_uri),
    ),
    (map {$_ => 'colour_value'}
        qw(has_colour_value also_shares_colour primary_colour displaycolour),
    ),
);

my %wk_default_encoding = (
    uuid                   => 'string_ise_uuid_encoding',
    oid                    => 'string_ise_oid_encoding',
    uri                    => 'ascii_uri_encoding',
    tagname                => 'utf_8_string_encoding',
    x11_colour_name        => 'utf_8_string_encoding',
    wikidata_identifier    => 'utf_8_string_encoding',
    small_identifier       => 'ascii_decimal_integer_encoding',
    unicode_string         => 'utf_8_string_encoding',
    colour_value           => 'hex_rgb_encoding',
);


# ---- Private helpers ----

sub DESTROY {} # So it's not autoloaded.

sub _call {
    my ($self, $name, $autocreate) = @_;

    if (defined $wk_ise{$name}) {
        return $self->{db}->_tag_by_ise_cached($wk_ise{$name}, $autocreate)
    } else {
        confess 'Unknown well known: '.$name;
    }
}

sub _list {
    my ($self) = @_;
    return keys %wk_ise;
}

sub _info {
    my ($self, $name) = @_;
    my %info;

    croak 'No such well known: '.$name unless defined $wk_ise{$name};

    $info{ise}              = $wk_ise{$name};
    $info{tagname}          = $wk_tagname{$name};
    $info{sid}              = $wk_sid{$name};
    $info{default_type}     = $wk_default_type{$name};
    $info{default_encoding} = $wk_default_encoding{$name};

    return \%info;
}

# ---- AUTOLOAD ----

sub AUTOLOAD {
    my ($self, @args) = @_;
    our $AUTOLOAD;
    my $name = $AUTOLOAD =~ s/^.*:://r;

    $name = $aliases{$name} // $name;

    $self->_call($name, @args);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Data::TagDB::WellKnown - Work with Tag databases

=head1 VERSION

version v0.10

=head1 SYNOPSIS

    use Data::TagDB;

    my $db = Data::TagDB->new(...);

    my Data::TagDB::WellKnown $wk = $db->wk;

    my Data::TagDB::Tag $tag = $wk->...;

This package provides access to well known tags.

See also L<Data::TagDB::Tutorial::WellKnown>.

=head1 AUTHOR

Löwenfelsen UG (haftungsbeschränkt) <support@loewenfelsen.net>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2024-2025 by Löwenfelsen UG (haftungsbeschränkt) <support@loewenfelsen.net>.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut
