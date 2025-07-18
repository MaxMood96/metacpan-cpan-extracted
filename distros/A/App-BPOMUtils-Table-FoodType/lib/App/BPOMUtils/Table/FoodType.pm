package App::BPOMUtils::Table::FoodType;

use 5.010001;
use strict 'subs', 'vars';
use utf8;
use warnings;
use Log::ger;

use Exporter 'import';
use Perinci::Sub::Gen::AccessTable qw(gen_read_table_func);

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2025-05-22'; # DATE
our $DIST = 'App-BPOMUtils-Table-FoodType'; # DIST
our $VERSION = '0.021'; # VERSION

our @EXPORT_OK = qw(
                       bpom_list_food_types
               );

our %SPEC;

# BEGIN FRAGMENT id=meta-idn_bpom_jenis_pangan varname=meta_idn_bpom_jenis_pangan
# note: This fragment's content is generated by a script. Do not edit manually!
# src-file: /home/u1/repos/gudangdata/bin/../table/idn_bpom_jenis_pangan/meta.yaml
# src-revision: 7d9fb0684b5983e6d55c16bead9f904f783798e3 (Thu Oct 27 17:19:46 2022 +0700)
# generate-date: Fri Jan 20 09:03:11 2023 UTC
# generated-by: update-fragments-in-perl-module
our $meta_idn_bpom_jenis_pangan = {
  "fields" => {
    code => {
      filterable_regex => "Yes",
      pos => 0,
      schema => ["str*", { match => "^[0-9]+\$" }],
      sortable => "Yes",
      summary => "code",
    },
    summary => {
      filterable_regex => "Yes",
      pos => 1,
      schema => ["str*"],
      sortable => "Yes",
      summary => "Summary",
      unique => "No",
    },
  },
  "pk" => "code",
  "summary" => "Food types in BPOM processed food division",
  "summary.alt.lang.id_ID" => "Jenis pangan di BPOM pangan olahan",
};
# END FRAGMENT id=meta-idn_bpom_jenis_pangan

# BEGIN FRAGMENT id=data-idn_bpom_jenis_pangan varname=data_idn_bpom_jenis_pangan
# note: This fragment's content is generated by a script. Do not edit manually!
# src-file: /home/u1/repos/gudangdata/bin/../table/idn_bpom_jenis_pangan/data.csv
# src-revision: 7d9fb0684b5983e6d55c16bead9f904f783798e3 (Thu Oct 27 17:19:46 2022 +0700)
# generate-date: Fri Jan 20 09:03:11 2023 UTC
# generated-by: update-fragments-in-perl-module
our $data_idn_bpom_jenis_pangan = [
  ["001", "Susu Pasteurisasi"],
  ["002", "Susu UHT"],
  ["003", "Susu Steril"],
  ["004", "Susu Skim"],
  ["005", "Susu Lemak Nabati"],
  ["006", "Buttermilk"],
  ["007", "Dadih"],
  ["008", "Minuman Susu"],
  ["009", "Minuman dengan/ mengandung Susu"],
  ["010", "Minuman Susu Fermentasi"],
  ["011", "Minuman Yoghurt"],
  ["012", "Lassi"],
  ["013", "Susu Diasamkan"],
  ["014", "Susu Fermentasi"],
  ["015", "Yogurt"],
  ["016", "Susu yang Digumpalkan dengan Enzim Renin"],
  ["017", "Susu Evaporasi"],
  ["018", "Susu Kental Manis"],
  ["019", "Susu Skim Kental Manis"],
  ["020", "Krim Kental Manis"],
  ["021", "Krimer Kental Manis"],
  ["022", "Khoa"],
  ["023", "Krimer Minuman (Bukan Susu)"],
  ["024", "Krim"],
  ["025", "Whipped Cream"],
  ["026", "Krim yang digumpalkan"],
  ["027", "Krim Nabati (Krim Analog)"],
  ["028", "Susu Bubuk Berlemak (Full Cream)"],
  ["029", "Susu Skim Bubuk"],
  ["030", "Krim Bubuk"],
  ["031", "Susu dan Krim Bubuk Analog"],
  ["032", "Susu Bubuk Lemak/Minyak Nabati"],
  ["033", "Buttermilk Bubuk"],
  ["034", "Keju Analog"],
  ["035", "Keju Tanpa Pemeraman"],
  ["035", "Keju tanpa Pemeraman (Keju Mentah)"],
  ["036", "Keju Peram"],
  ["037", "Kulit Keju Peram"],
  ["038", "Keju Bubuk"],
  ["039", "Keju Whey"],
  ["040", "Keju Olahan"],
  ["041", "Es Krim"],
  ["042", "Es Susu / Es Mengandung Susu"],
  ["043", "Makanan Pencuci Mulut Berbahan Dasar Susu"],
  ["044", "Puding (Berbahan dasar susu atau bahan lainnya)"],
  ["045", "Whey"],
  ["046", "Whey Bubuk"],
  ["047", "Kolostrum"],
  ["048", "Bahan untuk Es Krim / Bahan untuk Es Susu"],
  ["049", "Bahan untuk Puding (Bubuk)"],
  ["050", "Susu Bubuk"],
  ["078", "Ghee"],
  ["079", "Virgin Oil"],
  ["080", "Cold Pressed Oils"],
  ["081", "Minyak Goreng (Frying Oil atau frying fat)"],
  ["082", "Minyak Masak atau Minyak Sayur (Cooking Oil)"],
  ["083", "Minyak Salad"],
  ["084", "Minyak serbuk"],
  ["085", "Vanaspati atau Minyak Samin (Vegetable Ghee)"],
  ["086", "Lemak Reroti (Shortening)"],
  ["087", "Pengganti Minyak mentega (Butter Oil Substitute)"],
  [
    "088",
    "Minyak Kelapa Sawit (Refined Bleached Deodorized Palm Oil/RBDPO)",
  ],
  [
    "089",
    "Minyak Olein Kelapa Sawit (Refined Bleached Deodorized Palm Olein)",
  ],
  [
    "090",
    "Minyak Stearin Kelapa Sawit (Refined Bleached Deodorized Palm stearin)",
  ],
  [
    "091",
    "Minyak Kelapa (Refined Bleached Deodorized Coconut Oil)",
  ],
  [
    "092",
    "Minyak Kacang Tanah (Refined Bleached Deodorized Peanut Oil/Refined Bleached Deodorized Groundnut Oil)",
  ],
  ["093", "Minyak Jagung (Refined Bleached Deodorized Corn Oil)"],
  [
    "094",
    "Minyak Kemiri (Refined Bleached Deodorized Candlenut/Limbang Oil)",
  ],
  [
    "095",
    "Minyak Kedelai (Refined Bleached Deodorized Soyabean Oil)",
  ],
  ["096", "Minyak Wijen (Sesame Oil)"],
  [
    "097",
    "Minyak Zaitun (Refined Bleached Deodorized Olive Oil)",
  ],
  ["098", "Minyak Safflower"],
  ["099", "Minyak Biji Bunga Matahari"],
  [
    100,
    "Minyak Dedak atau Minyak Bekatul atau Minyak Katul (Refined Bleached Deodorized Rice Brand Oil)",
  ],
  [
    101,
    "Minyak Biji Kapas (Refined Bleached Deodorized Cottonseed Oil)",
  ],
  [
    102,
    "Rapeseed oil (turnip rape oil/colza oil/ravison oil/sarson oil/toria oil)",
  ],
  [
    103,
    "Mustardseed Oil (Refined Bleached Deodorized Mustardseed Oil)",
  ],
  [104, "Lemak Hewani"],
  [105, "Minyak Ikan"],
  [106, "Mentega"],
  [107, "Margarin"],
  [
    108,
    "Campuran Margarin dan Mentega (Blends of Butter and Margarine)",
  ],
  [109, "Emulsi yang Mengandung Lemak Kurang Dari 80%"],
  [110, "Emulsi lemak dan makanan pencuci mulut berbasis lemak"],
  [111, "Es krim non dairy"],
  [112, "Minyak Nabati Lainnya"],
  [142, "Es selain es krim dan es susu"],
  [
    143,
    "Sediaan Cair atau Serbuk yang akan Dikonsumsi dalam Keadaan Beku",
  ],
  [174, "Manisan Buah"],
  [174, "Manisan Gula"],
  [175, "Buah Kering"],
  [176, "Asinan Buah"],
  [177, "Buah dalam ...... (medianya) kemasan"],
  [178, "Jem (Selai), Jeli dan Marmalad"],
  [179, "Sambal buah"],
  [180, "Bubur Buah, Puree Buah, Pasta Buah"],
  [181, "Saus Buah/Topping buah"],
  [181, "Saus Buah/Topping Buah"],
  [182, "Hasil olah kelapa"],
  [183, "Konsentrat Asam Jawa/Tamarin"],
  [184, "Buah Bubuk"],
  [185, "Makanan Pencuci Mulut"],
  [186, "Cincau"],
  [187, "Acar buah/ Produk Fermentasi Buah"],
  [188, "Lempok Buah"],
  [189, "Geplak"],
  [190, "Sayur beku"],
  [191, "Sayur Kering"],
  [192, "Rumput laut Kering"],
  [193, "Biji-Bjian / Kacang-Kacangan Kering"],
  [194, "Emping"],
  [195, "Sayur bubuk"],
  [196, "Sayur/ Jamur/Buah dalam Media Minyak"],
  [197, "Sayur Asin"],
  [198, "Acar Sayur / Produk Fermentasi Sayur"],
  [199, "Sayur dan Kacang dalam Kemasan"],
  [200, "Pasta sayur, bubur sayur, puree sayur, saus sayur"],
  [201, "Pasta Biji-bijian"],
  [202, "Produk sayur lain"],
  [202, "Produk Sayur Lain"],
  [203, "Olahan Buah Lainnya"],
  [233, "Kakao Bubuk"],
  [234, "Kakao Nib"],
  [235, "Massa Kakao dan Cairan Kental (Liquor) Cokelat"],
  [236, "Keik Kakao (Cococa Press Cake)"],
  [237, "Minuman Kakao/Cokelat"],
  [238, "Cokelat Instan"],
  [239, "Pasta coklat"],
  [240, "Cokelat"],
  [241, "Permen Cokelat/Permen Isi Cokelat"],
  [242, "Lemak kakao (Cocoa Butter)"],
  [243, "Produk Cokelat Analog/ Pengganti Cokelat"],
  [244, "Kembang Gula/permen Keras"],
  [245, "Kembang Gula/Permen Lunak"],
  [246, "Nougat, Marzipan"],
  [247, "Kembang Gula/Permen Karet"],
  [248, "Dekorasi, Topping (Non-Buah) dan Saus Manis"],
  [249, "Kakao Bubuk Lainnya"],
  [279, "Beras Diperkaya"],
  [281, "Tepung Beras (Beras, Beras Ketan)"],
  [282, "Tepung Jagung"],
  [283, "Tepung Kacang-Kacangan"],
  [284, "Tepung Kedelai"],
  [285, "Tepung Gandum / Pati Gandum"],
  [286, "Tepung Jewawut (Pearl Millet Flour)"],
  [287, "Tepung sorgum"],
  [288, "Tepung Terigu"],
  [289, "Tepung Gluten Terigu (Wheat Gluten Powder)"],
  [290, "Tepung Kulit Ari (Fine Bran)"],
  [291, "Tepung / Pati"],
  [293, "Dekstrin"],
  [294, "Tepung Gaplek"],
  [295, "Tepung Aren"],
  [296, "Pati Garut"],
  [297, "Pati Jagung atau Maizena"],
  [298, "Pati Sagu"],
  [299, "Tepung Hunkwee/Pati Kacang hijau"],
  [300, "Tapioka / Pati Singkong/Gari"],
  [301, "Pati Termodifikasi"],
  [304, "Nasi Jagung"],
  [305, "Sereal Siap Saji Termasuk Sereal Sarapan"],
  [306, "Tiwul"],
  [307, "Degermed Maize (Corn) Grits"],
  [308, "Mi Basah"],
  [309, "Kulit Pangsit"],
  [310, "Kuetiauw"],
  [311, "Pasta"],
  [312, "Sohun"],
  [313, "Bihun"],
  [314, "Mi Kering"],
  [315, "Mi instan"],
  [316, "Nasi Instan"],
  [
    317,
    "Makanan Pencuci Mulut Berbasis Serealia dan Pati (Misalnya Puding Nasi, Puding Tapioka)",
  ],
  [318, "Tepung Bumbu"],
  [319, "Kue berbahan dasar beras"],
  [320, "Minuman/Sari Kedelai"],
  [321, "Kembang Tahu"],
  [321, "KembangTahu"],
  [322, "Tahu"],
  [323, "Produk Kedelai Fermentasi"],
  [325, "Bubur Instan (Rasa Ayam, dll)"],
  [
    326,
    "Biji-Bijian dan Kacang-Kacangan (Utuh, Patahan, atau Serpihan)",
  ],
  [327, "Kerupuk Mentah"],
  [328, "Produk Protein Kedelai Lainnya"],
  [329, "Olahan dari Tepung/Pati"],
  [354, "Roti"],
  [355, "Krekers"],
  [356, "Biskuit"],
  [357, "Tepung Roti"],
  [358, "Roti Kukus"],
  [359, "Premiks untuk Bakeri /Untuk Stufing"],
  [360, "Keik (Cake)"],
  [361, "Wafer"],
  [362, "Kukis"],
  [363, "Kue (Contoh: bika ambon, cucur, cakue, dll)"],
  [
    395,
    "Daging Sapi Olahan / Daging Kerbau Olahan/Daging Rusa Olahan",
  ],
  [396, "Daging Babi Olahan"],
  [397, "Daging Ayam Olahan"],
  [
    398,
    "Produk Daging Campuran Olahan (terdiri dari 2 macam atau lebih)",
  ],
  [399, "Daging lain olahan"],
  [400, "Daging Analog"],
  [402, "Daging Kambing atau Daging Olahan"],
  [402, "Daging Kambing atau Domba Olahan"],
  [402, "Daging Kambing atau Domnba Olahan"],
  [432, "Ikan Olahan"],
  [435, "Udang Olahan"],
  [436, "Rajungan/Kepiting Olahan"],
  [437, "Produk olahan ikan lain"],
  [438, "Telur Ikan Olahan"],
  [439, "Ikan dalam kaleng"],
  [441, "Produk Ikan Olahan Lain dalam Kaleng"],
  [474, "Produk Telur Olahan"],
  [475, "Tepung telur"],
  [476, "Telur awetan"],
  [477, "Makanan Pencuci Mulut Berbahan Dasar Telur"],
  [478, "Ikan dan Olahan Analog"],
  [508, "Dekstrosa"],
  [509, "Fruktosa"],
  [510, "Tepung Gula atau Gula Halus"],
  [511, "Gula Merah"],
  [512, "Sirup Glukosa"],
  [513, "Glukosa"],
  [514, "Gula Kristal Putih atau Gula Pasir"],
  [515, "Laktosa"],
  [516, "Sirup Fruktosa (High Fructose Syrup/HFS)"],
  [517, "Tetes Tebu atau Molases"],
  [518, "Gula Invert"],
  [520, "Sirup lain"],
  [521, "Madu"],
  [522, "Sediaan Pemanis (Table Top)"],
  [524, "Gula Batu"],
  [553, "Garam"],
  [555, "Pengganti Garam"],
  [556, "Bumbu dan kondimen"],
  [556, "Bumbu dan Kondimen"],
  [557, "Cuka"],
  [558, "Arak masak (Angciu)"],
  [559, "Sup"],
  [560, "Sari Pati Ayam"],
  [561, "Kaldu"],
  [562, "Mayonais/Salad Dressing"],
  [563, "Sambal"],
  [564, "Saus Bumbu"],
  [565, "Saus Tomat"],
  [566, "Kecap selain kedelai"],
  [567, "Bubuk Untuk Saus dan Gravies"],
  [568, "Produk Oles Untuk Salad"],
  [569, "Ragi"],
  [570, "Pasta kedelai fermentasi"],
  [571, "Saus kedelai"],
  [572, "Kecap (Berbasis kedelai)"],
  [573, "Produk protein"],
  [574, "Mustard"],
  [596, "Ragi"],
  [604, "Formula bayi"],
  [605, "Formula Lanjutan"],
  [606, "Formula Pertumbuhan"],
  [610, "Makanan Diet Diabetes"],
  [
    613,
    "Makanan formula sebagai makanan diet kontrol berat badan",
  ],
  [615, "Pangan Ibu Hamil dan Pangan Ibu Menyusui"],
  [651, "Air mineral alami"],
  [652, "Air Minum dalam Kemasan (AMDK)"],
  [653, "Air Bermineral"],
  [654, "Air Soda"],
  [655, "Air minum Beroksigen"],
  [657, "Sari Buah"],
  [658, "Sari Sayur"],
  [659, "Sari buah dan sari sayuran"],
  [660, "Konsentrat Sari Buah"],
  [661, "Konsentrat Sari Sayur"],
  [662, "Konsentrat Sari Buah dan Sari Sayuran"],
  [663, "Nektar Buah/Sayur"],
  [664, "Konsentrat Nektar Buah/Sayur"],
  [665, "Minuman Berperisa Berkarbonat"],
  [666, "Minuman Berperisa tidak Berkarbonat"],
  [667, "Minuman Elektrolit Berkarbonat"],
  [668, "Minuman Elektrolit Tidak Berkarbonat"],
  [669, "Minuman Serbuk Berkarbonat"],
  [670, "Minuman Serbuk Tidak Berkarbonat"],
  [671, "Minuman Sari Buah"],
  [672, "Sirup Berperisa"],
  [673, "Sirup buah"],
  [674, "Sirup coklat, sirup karamel, sirup kopi"],
  [675, "Squash"],
  [
    677,
    "Minuman Botanikal/ Minuman lain-lain (asam jawa, nira, dll)",
  ],
  [678, "Minuman Nata De Coco / Jeli"],
  [679, "Teh Fermentasi"],
  [680, "Teh Olong atau Teh semi Fermentasi"],
  [681, "Teh tanpa Fermentasi"],
  [682, "Teh wangi"],
  [683, "Minuman Teh"],
  [684, "Teh instan"],
  [685, "Konsentrat teh"],
  [686, "Biji kopi"],
  [687, "Kopi"],
  [688, "Minuman Kopi (Siap Minum)"],
  [689, "Konsentrat kopi"],
  [690, "Minuman Botanikal"],
  [691, "Minuman sari kacang hijau"],
  [702, "Minuman Tradisional"],
  [703, "Minuman Konsentrat"],
  [704, "Sirup Teh"],
  [705, "Minuman Biji-Bijian dan Sereal"],
  [728, "Keripik"],
  [729, "Makanan ringan simulasi"],
  [730, "Makanan ringan lain"],
  [731, "Pilus"],
  [732, "Berondong"],
  [733, "Marning"],
  [734, "Jipang"],
  [735, "Kerupuk"],
  [736, "Rengginang / Ekivalen / Batiah"],
  [737, "Makanan ringan Ekstrudat"],
  [738, "Makanan ringan kacang"],
  [739, "Kemplang"],
  [740, "Getas"],
  [758, "Pangan Siap Saji (Terkemas)"],
  [758, "Pangan Siap Saji Terkemas"],
  [759, "Sup Sayuran"],
  [760, "Sup Jamur"],
  [761, "Pangsit Isi (Sayuran, Daging, dll)"],
  [762, "Jajanan Pasar"],
  [763, "Kebab/Roti Isi Daging/Tortilla Isi Daging"],
  [764, "Pasta Instan"],
  [765, "Kombinasi Pangan Olahan"],
  [766, "Olahan Gluten"],
  [767, "Kolak"],
  [789, "Bahan Tambahan Pangan"],
];
# END FRAGMENT id=data-idn_bpom_jenis_pangan

my $res = gen_read_table_func(
    name => 'bpom_list_food_types',
    summary => 'List food types in BPOM processed food division',
    table_data => $data_idn_bpom_jenis_pangan,
    table_spec => $meta_idn_bpom_jenis_pangan,
    description => <<'_',
_
    extra_props => {
        examples => [
        ],
    },
);
die "Can't generate function: $res->[0] - $res->[1]" unless $res->[0] == 200;

1;
# ABSTRACT: List food types in BPOM processed food division

__END__

=pod

=encoding UTF-8

=head1 NAME

App::BPOMUtils::Table::FoodType - List food types in BPOM processed food division

=head1 VERSION

This document describes version 0.021 of App::BPOMUtils::Table::FoodType (from Perl distribution App-BPOMUtils-Table-FoodType), released on 2025-05-22.

=head1 DESCRIPTION

This distribution contains the following CLIs:

=over

=item * L<bpom-daftar-jenis-pangan>

=item * L<bpom-daftar-jenis-pangan-rba-importir>

=item * L<bpom-daftar-jenis-pangan-rba-produsen>

=item * L<bpom-list-food-types>

=item * L<bpom-list-food-types-rba-importer>

=item * L<bpom-list-food-types-rba-producer>

=back

=head1 FUNCTIONS


=head2 bpom_list_food_types

Usage:

 bpom_list_food_types(%args) -> [$status_code, $reason, $payload, \%result_meta]

List food types in BPOM processed food division.

This function is not exported by default, but exportable.

Arguments ('*' denotes required arguments):

=over 4

=item * B<code> => I<str>

Only return records where the 'code' field equals specified value.

=item * B<code.contains> => I<str>

Only return records where the 'code' field contains specified text.

=item * B<code.in> => I<array[str]>

Only return records where the 'code' field is in the specified values.

=item * B<code.is> => I<str>

Only return records where the 'code' field equals specified value.

=item * B<code.isnt> => I<str>

Only return records where the 'code' field does not equal specified value.

=item * B<code.matches> => I<str>

Only return records where the 'code' field matches specified regular expression pattern.

=item * B<code.max> => I<str>

Only return records where the 'code' field is less than or equal to specified value.

=item * B<code.min> => I<str>

Only return records where the 'code' field is greater than or equal to specified value.

=item * B<code.not_contains> => I<str>

Only return records where the 'code' field does not contain specified text.

=item * B<code.not_in> => I<array[str]>

Only return records where the 'code' field is not in the specified values.

=item * B<code.not_matches> => I<str>

Only return records where the 'code' field does not match specified regular expression.

=item * B<code.xmax> => I<str>

Only return records where the 'code' field is less than specified value.

=item * B<code.xmin> => I<str>

Only return records where the 'code' field is greater than specified value.

=item * B<detail> => I<bool> (default: 0)

Return array of full records instead of just ID fields.

By default, only the key (ID) field is returned per result entry.

=item * B<exclude_fields> => I<array[str]>

Select fields to return.

=item * B<fields> => I<array[str]>

Select fields to return.

=item * B<queries> => I<array[str]>

Search.

This will search all searchable fields with one or more specified queries. Each
query can be in the form of C<-FOO> (dash prefix notation) to require that the
fields do not contain specified string, or C</FOO/> to use regular expression.
All queries must match if the C<query_boolean> option is set to C<and>; only one
query should match if the C<query_boolean> option is set to C<or>.

=item * B<query_boolean> => I<str> (default: "and")

Whether records must match all search queries ('and') or just one ('or').

If set to C<and>, all queries must match; if set to C<or>, only one query should
match. See the C<queries> option for more details on searching.

=item * B<random> => I<bool> (default: 0)

Return records in random order.

=item * B<result_limit> => I<int>

Only return a certain number of records.

=item * B<result_start> => I<int> (default: 1)

Only return starting from the n'th record.

=item * B<sort> => I<array[str]>

Order records according to certain field(s).

A list of field names separated by comma. Each field can be prefixed with '-' to
specify descending order instead of the default ascending.

=item * B<summary> => I<str>

Only return records where the 'summary' field equals specified value.

=item * B<summary.contains> => I<str>

Only return records where the 'summary' field contains specified text.

=item * B<summary.in> => I<array[str]>

Only return records where the 'summary' field is in the specified values.

=item * B<summary.is> => I<str>

Only return records where the 'summary' field equals specified value.

=item * B<summary.isnt> => I<str>

Only return records where the 'summary' field does not equal specified value.

=item * B<summary.matches> => I<str>

Only return records where the 'summary' field matches specified regular expression pattern.

=item * B<summary.max> => I<str>

Only return records where the 'summary' field is less than or equal to specified value.

=item * B<summary.min> => I<str>

Only return records where the 'summary' field is greater than or equal to specified value.

=item * B<summary.not_contains> => I<str>

Only return records where the 'summary' field does not contain specified text.

=item * B<summary.not_in> => I<array[str]>

Only return records where the 'summary' field is not in the specified values.

=item * B<summary.not_matches> => I<str>

Only return records where the 'summary' field does not match specified regular expression.

=item * B<summary.xmax> => I<str>

Only return records where the 'summary' field is less than specified value.

=item * B<summary.xmin> => I<str>

Only return records where the 'summary' field is greater than specified value.

=item * B<with_field_names> => I<bool>

Return field names in each record (as hashE<sol>associative array).

When enabled, function will return each record as hash/associative array
(field name => value pairs). Otherwise, function will return each record
as list/array (field value, field value, ...).


=back

Returns an enveloped result (an array).

First element ($status_code) is an integer containing HTTP-like status code
(200 means OK, 4xx caller error, 5xx function error). Second element
($reason) is a string containing error message, or something like "OK" if status is
200. Third element ($payload) is the actual result, but usually not present when enveloped result is an error response ($status_code is not 2xx). Fourth
element (%result_meta) is called result metadata and is optional, a hash
that contains extra information, much like how HTTP response headers provide additional metadata.

Return value:  (any)

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/App-BPOMUtils-Table-FoodType>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-App-BPOMUtils-Table-FoodType>.

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 CONTRIBUTING


To contribute, you can send patches by email/via RT, or send pull requests on
GitHub.

Most of the time, you don't need to build the distribution yourself. You can
simply modify the code, then test via:

 % prove -l

If you want to build the distribution (e.g. to try to install it locally on your
system), you can install L<Dist::Zilla>,
L<Dist::Zilla::PluginBundle::Author::PERLANCAR>,
L<Pod::Weaver::PluginBundle::Author::PERLANCAR>, and sometimes one or two other
Dist::Zilla- and/or Pod::Weaver plugins. Any additional steps required beyond
that are considered a bug and can be reported to me.

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2025 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=App-BPOMUtils-Table-FoodType>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
