package Acme::ID::CompanyName;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2021-05-07'; # DATE
our $DIST = 'Acme-ID-CompanyName'; # DIST
our $VERSION = '0.007'; # VERSION

use 5.010001;
use strict;
#use warnings; # XXX actually want to just disable 'Possible attempts to put comments in qw()'

use Exporter 'import';
our @EXPORT_OK = qw(gen_generic_ind_company_names);

our %SPEC;

# you can comment to disable a word
our @Words = qw(
abad
abadi
adhi
adi
agung
aksa
aksara
akur
akurasi
akurat
alam
alami
aman
amanah
amanat
amerta
ampuh
andal
andalan
angkasa
anugerah
arta
artha
arunika
asa

bagus
bangsa
bangun
baru
baskara
baswara
batara
bentala
bentang
berdikari
berdiri
berjaya
berkat
berlian
bersama
bersatu
bersaudara
beruntung
besar
bestari
bijaksana
bina
binar
bintang
bisnis
buana
bukit
bulan
bumi

cahaya
cahya
cakra
cakrawala
candala
catur
cendrawasih
central
chandra
cipta
citra

dagang
dana
darma
dasa
dasar
data
delapan
delta
dharma
digital
dika
dirgantara
dunia
duta

eden
eka
elang
elegan
elegi
elektrik
elektro
elektronik
empat
enam
energi
era
esa
eterna
etos

fajar
forsa
fortuna

gading
galaksi
garuda
gelora
gemerlap
gemilang
gemintang
gempita
gilang
global
gloria
graha
griya
guna
gunung

halal
haluan
harapan
harmoni
harta
hasil
hasrat
hasta
hati
hoki
#hosana-christianish
hulu
human
humana
humania
hurip
hutama

indah
indonesia
indotama
industri
insan
inspirasi
internasional
inti
investa
investama

jasa
jatmika
jaya
jenggala
jingga
juara
jumantara
juwara
juwita

kala
kapital
karsa
karya
kasih
keluarga
kencana
khatulistiwa
kidung
kirana
kreasi
kreatif
krida
kurnia

laksana
langgeng
langit
lautan
layanan
legenda
lembayung
lentera
lestari
liberti
lima
lotus
luas
lumbung

mahkota
maju
makmur
maksindo
mandala
mandiri
mapan
marga
maritim
mas
media
megah
mekar
menara
menuju
milenia
milenial
mitra
multi
multimedia

nirmala
nirwana
normal
nuansa
nusa
nusantara

oasis
obor
online
optima
optimis
optimum
optimus
orisinal
otomatis

paripurna
pasifik
pelangi
perkasa
permata
pertama
perusahaan
pijar
pilar
pionir
polar
polarindo
pratama
prawira
prima
prioritas
properti
propertindo
prospek
pusaka
pusat
putera
putra

quadra
quadran
quanta
quantum

radian
raja
rajawali
ratu
raya
rekayasa
rembulan
rintis
roda
royal
ruang

santosa
sarana
sari
satu
sehat
sejahtera
sejati
selaras
sembilan
sempurna
sentosa
sentra
sentral
setia
simfoni
sinar
sintesa
sintesis
solusi
solusindo
sukses
sumber
surya

talenta
taktis
teduh
teknologi
tenteram
tentram
terang
terus
tiga
tren
tujuh
tunggal

ufuk
umum
untung
usaha
utama
utara

varia
variasi
vektor
ventura
venturindo
venus
versa
vidia
viktori
viktoria
visi
vista
vita
vito

wacana
wadah
waguna
wahana
wahyu
waringin
warna
widia
widya
wiguna
wira
wiratama
wiyata

xavier
xcel
xmas
xpres
xsis
xtra

#yahya-christianish
yasa
#yobel-christianish

zaitun
zaman
zeta
zeus
zona
);

my %Per_Letter_Words;
for my $letter ("a".."z") {
    for (@Words) {
        /(.).+/ or die;
        push @{ $Per_Letter_Words{$1} }, $_;
    }
}

our @Prefixes = qw(
adi
dana
dwi
eka
indo
inti
media
mega
mitra
multi
nara
oto
panca
prima
sapta
swa
tekno
tetra
trans
tri
);

our @Suffixes = qw(
indo
jaya
tama
);

$SPEC{gen_generic_ind_company_names} = {
    v => 1.1,
    summary => 'Generate nice-sounding, generic Indonesian company names',
    args => {
        type => {
            schema => 'str*',
            default => 'PT',
            summary => 'Just a string to be prepended before the name',
            cmdline_aliases => {t=>{}},
        },
        num_names => {
            schema => ['int*', min=>0],
            default => 1,
            cmdline_aliases => {n=>{}},
            pos => 0,
        },
        num_words => {
            schema => ['int*', min=>1],
            default => 3,
            cmdline_aliases => {w=>{}},
        },
        add_prefixes => {
            schema => ['bool*'],
            default => 1,
        },
        add_suffixes => {
            schema => ['bool*'],
            default => 1,
        },
        # XXX option to use some more specific words & suffixes/prefixes
        desired_initials => {
            schema => ['str*', min_len=>1, match=>qr/\A[A-Za-z]+\z/],
        },
    },
    result_naked => 1,
    examples => [
        {
            summary => 'Generate five random PT names',
            argv => [qw/5/],
            test => 0,
        },
        {
            summary => 'Generate three PT names with desired initials "ACME"',
            argv => [qw/-n3 --desired-initials ACME/],
            test => 0,
        },
    ],
};
sub gen_generic_ind_company_names {
    my %args = @_;

    my $type = $args{type} // 'PT';
    my $num_names = $args{num_names} // 1;
    my $num_words = $args{num_words} // 3;
    my $desired_initials = lc($args{desired_initials} // "");
    my $add_prefixes = $args{add_prefixes} // 1;
    my $add_suffixes = $args{add_suffixes} // 1;

    $num_words = length($desired_initials)
        if $num_words < length($desired_initials);

    my @res;
    my $name_tries = 0;
    for my $i (1..$num_names) {
        die "Can't produce that many unique company names"
            if ++$name_tries > 5*$num_names;

        my @words;
        my $word_tries = 0;
        my $has_added_prefix;
        my $has_added_suffix;
      WORD:
        for my $j (1..$num_words) {
            die "Can't produce a company name that satisfies requirements"
                if ++$word_tries > 1000;

            my $will_add_prefix =
                !$add_prefixes ? 0 :
                $has_added_prefix ? 0 :
                rand()*$num_words*6 > 1 ? 0 : 1;

            my $word;
            my $desired_initial = length($desired_initials) >= $j ?
                substr($desired_initials, $j-1, 1) : undef;

            if (!$will_add_prefix && $desired_initial) {
                die "There are no words that start with '$desired_initial'"
                    unless $Per_Letter_Words{$desired_initial};
                $word = $Per_Letter_Words{$desired_initial}->[
                    @{ $Per_Letter_Words{$desired_initial} } * rand()
                ];
            } else {
                $word = $Words[@Words * rand()];
            }
            next if $word =~ /^#/;

          ADD_PREFIX:
            {
                last unless $will_add_prefix;
                my $prefix = $Prefixes[@Prefixes * rand()];
                redo WORD if $desired_initial && substr($prefix, 0, 1) ne $desired_initial;

                # avoid prefixing e.g. 'indo-' to 'indonesia'
                last if $word =~ /^\Q$prefix\E/;

                # amalgamate letter
                if (substr($prefix, -1, 1) eq substr($word, 0, 1)) {
                    $word =~ s/^.//;
                }

                $word = "$prefix$word";
                $has_added_prefix++;
            }

          ADD_SUFFIX:
            {
                last unless $add_suffixes;
                last unless !$has_added_suffix && rand()*$num_words*3 < 1;
                my $suffix = $Suffixes[@Suffixes * rand()];

                # avoid suffixing e.g. '-tama' to 'pertama'
                last if $word =~ /\Q$suffix\E$/;

                # amalgamate letter
                if (substr($word, -1, 1) eq substr($suffix, 0, 1)) {
                    $word =~ s/.$//;
                }

                $word = "$word$suffix";
                $has_added_suffix++;
            }

            # avoid duplicate words
            redo if grep { $word eq $_ } @words;

            push @words, ucfirst $word;
        }
        my $name = join(" ", $type, @words);

        # avoid duplicate name
        redo if grep { $name eq $_ } @res;

        push @res, $name;

    }
    return \@res;
}

1;
# ABSTRACT: Generate nice-sounding, generic Indonesian company names

__END__

=pod

=encoding UTF-8

=head1 NAME

Acme::ID::CompanyName - Generate nice-sounding, generic Indonesian company names

=head1 VERSION

This document describes version 0.007 of Acme::ID::CompanyName (from Perl distribution Acme-ID-CompanyName), released on 2021-05-07.

=head1 DESCRIPTION

=head1 FUNCTIONS


=head2 gen_generic_ind_company_names

Usage:

 gen_generic_ind_company_names(%args) -> any

Generate nice-sounding, generic Indonesian company names.

Examples:

=over

=item * Generate five random PT names:

 gen_generic_ind_company_names( num_names => 5);

Result:

 [
   "PT Hulu Humania Harmoni",
   "PT Jaya Cipta Indoakurasi",
   "PT Baru Berjaya Legenda",
   "PT Normal Zona Gempita",
   "PT Multi Gelora Baswara",
 ]

=item * Generate three PT names with desired initials "ACME":

 gen_generic_ind_company_names( num_names => 3, desired_initials => "ACME");

Result:

 [
   "PT Aksara Catur Mekar Elektronik",
   "PT Anugerah Cendrawasih Mandala Esa",
   "PT Asaindo Cakra Mandala Elang",
 ]

=back

This function is not exported by default, but exportable.

Arguments ('*' denotes required arguments):

=over 4

=item * B<add_prefixes> => I<bool> (default: 1)

=item * B<add_suffixes> => I<bool> (default: 1)

=item * B<desired_initials> => I<str>

=item * B<num_names> => I<int> (default: 1)

=item * B<num_words> => I<int> (default: 3)

=item * B<type> => I<str> (default: "PT")

Just a string to be prepended before the name.


=back

Return value:  (any)

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Acme-ID-CompanyName>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Acme-ID-CompanyName>.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Acme-ID-CompanyName>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2021, 2017 by perlancar@cpan.org.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
