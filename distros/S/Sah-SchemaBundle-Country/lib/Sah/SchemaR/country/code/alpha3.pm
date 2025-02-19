## no critic: TestingAndDebugging::RequireStrict
package Sah::SchemaR::country::code::alpha3;

our $DATE = '2024-06-26'; # DATE
our $VERSION = '0.010'; # VERSION

our $rschema = do{my$var={base=>"str",clsets_after_base=>[{description=>"\nAccept only current (not retired) codes. Only alpha-3 codes are accepted.\n\nCode will be converted to lowercase.\n\n",examples=>[{valid=>0,value=>""},{summary=>"Only alpha-3 codes are allowed",valid=>0,value=>"ID"},{valid=>1,validated_value=>"idn",value=>"IDN"},{valid=>0,value=>"xx"},{valid=>0,value=>"xxx"}],in=>["pri","cck","mkd","ken","abw","uzb","sle","mlt","irl","isl","fji","syc","dji","brn","jor","nzl","eth","nru","cri","hrv","cym","pcn","geo","alb","lbn","hmd","tza","nor","cmr","sgp","gtm","swz","mli","ssd","lby","ecu","plw","msr","slv","mex","mnp","mac","chn","bra","bgr","prt","btn","fin","sjm","sur","tur","aia","reu","vat","col","zaf","gib","mus","som","che","wsm","esh","jey","khm","afg","spm","pol","civ","wlf","bhr","npl","grd","kor","mar","tls","moz","kaz","ton","nfk","uga","iot","hnd","aus","ven","tkl","tjk","bvt","umi","blm","syr","yem","pyf","nga","gnq","mmr","fro","mys","isr","bel","tgo","sdn","mrt","usa","dom","tha","vnm","tcd","tca","flk","mtq","cog","caf","per","hti","kir","lca","swe","cub","blr","irn","pry","irq","are","aze","vut","vct","niu","bhs","gmb","eri","nic","ago","mng","cpv","ner","ata","mda","sxm","brb","kwt","deu","phl","mne","lso","ury","shn","arg","tun","blz","ggy","rus","zmb","srb","dma","prk","ncl","est","ala","ukr","gab","lux","stp","smr","gbr","guf","ind","mwi","chl","bfa","nld","lbr","slb","guy","lka","bwa","bmu","egy","fsm","gum","svn","pak","jam","bol","lao","cxr","bih","bes","maf","and","qat","atf","ltu","zwe","png","mco","com","kna","gnb","imn","tuv","myt","jpn","dza","pse","cyp","cod","bdi","cze","mhl","kgz","fra","sen","dnk","lva","glp","asm","can","sgs","esp","vir","tto","gha","ita","pan","tkm","lie","svk","nam","cok","grl","idn","rou","arm","mdv","omn","ben","mdg","atg","sau","hkg","grc","aut","hun","twn","gin","rwa","bgd","cuw","vgb"],match=>"\\A[a-z]{3}\\z",summary=>"Country code (alpha-3)","x.in.summaries"=>["Puerto Rico","Cocos (Keeling) Islands","North Macedonia","Kenya","Aruba","Uzbekistan","Sierra Leone","Malta","Ireland","Iceland","Fiji","Seychelles","Djibouti","Brunei Darussalam","Jordan","New Zealand","Ethiopia","Nauru","Costa Rica","Croatia","Cayman Islands","Pitcairn","Georgia","Albania","Lebanon","Heard Island and McDonald Islands","Tanzania, the United Republic of","Norway","Cameroon","Singapore","Guatemala","Eswatini","Mali","South Sudan","Libya","Ecuador","Palau","Montserrat","El Salvador","Mexico","Northern Mariana Islands","Macao","China","Brazil","Bulgaria","Portugal","Bhutan","Finland","Svalbard and Jan Mayen","Suriname","Turkiye","Anguilla","Reunion","Holy See","Colombia","South Africa","Gibraltar","Mauritius","Somalia","Switzerland","Samoa","Western Sahara","Jersey","Cambodia","Afghanistan","Saint Pierre and Miquelon","Poland","Cote d'Ivoire","Wallis and Futuna","Bahrain","Nepal","Grenada","Korea, The Republic of","Morocco","Timor-Leste","Mozambique","Kazakhstan","Tonga","Norfolk Island","Uganda","British Indian Ocean Territory","Honduras","Australia","Venezuela (Bolivarian Republic of)","Tokelau","Tajikistan","Bouvet Island","United States Minor Outlying Islands","Saint Barthelemy","Syrian Arab Republic","Yemen","French Polynesia","Nigeria","Equatorial Guinea","Myanmar","Faroe Islands","Malaysia","Israel","Belgium","Togo","Sudan","Mauritania","United States of America","Dominican Republic","Thailand","Viet Nam","Chad","Turks and Caicos Islands","Falkland Islands (The) [Malvinas]","Martinique","Congo","Central African Republic","Peru","Haiti","Kiribati","Saint Lucia","Sweden","Cuba","Belarus","Iran (Islamic Republic of)","Paraguay","Iraq","United Arab Emirates","Azerbaijan","Vanuatu","Saint Vincent and the Grenadines","Niue","Bahamas","Gambia","Eritrea","Nicaragua","Angola","Mongolia","Cabo Verde","Niger","Antarctica","Moldova, The Republic of","Sint Maarten (Dutch part)","Barbados","Kuwait","Germany","Philippines","Montenegro","Lesotho","Uruguay","Saint Helena, Ascension and Tristan da Cunha","Argentina","Tunisia","Belize","Guernsey","Russian Federation","Zambia","Serbia","Dominica","Korea, The Democratic People's Republic of","New Caledonia","Estonia","Aland Islands","Ukraine","Gabon","Luxembourg","Sao Tome and Principe","San Marino","United Kingdom of Great Britain and Northern Ireland","French Guiana","India","Malawi","Chile","Burkina Faso","Netherlands (Kingdom of the)","Liberia","Solomon Islands","Guyana","Sri Lanka","Botswana","Bermuda","Egypt","Micronesia (Federated States of)","Guam","Slovenia","Pakistan","Jamaica","Bolivia (Plurinational State of)","Lao People's Democratic Republic","Christmas Island","Bosnia and Herzegovina","Bonaire, Sint Eustatius and Saba","Saint Martin (French part)","Andorra","Qatar","French Southern Territories","Lithuania","Zimbabwe","Papua New Guinea","Monaco","Comoros","Saint Kitts and Nevis","Guinea-Bissau","Isle of Man","Tuvalu","Mayotte","Japan","Algeria","Palestine, State of","Cyprus","Congo (The Democratic Republic of the)","Burundi","Czechia","Marshall Islands","Kyrgyzstan","France","Senegal","Denmark","Latvia","Guadeloupe","American Samoa","Canada","South Georgia and the South Sandwich Islands","Spain","Virgin Islands (U.S.)","Trinidad and Tobago","Ghana","Italy","Panama","Turkmenistan","Liechtenstein","Slovakia","Namibia","Cook Islands","Greenland","Indonesia","Romania","Armenia","Maldives","Oman","Benin","Madagascar","Antigua and Barbuda","Saudi Arabia","Hong Kong","Greece","Austria","Hungary","Taiwan (Province of China)","Guinea","Rwanda","Bangladesh","Curacao","Virgin Islands (British)"],"x.perl.coerce_rules"=>["From_str::to_lower"]}],clsets_after_type=>['$var->{clsets_after_base}[0]'],"clsets_after_type.alt.merge.merged"=>['$var->{clsets_after_base}[0]'],resolve_path=>["str"],type=>"str",v=>2};$var->{clsets_after_type}[0]=$var->{clsets_after_base}[0];$var->{"clsets_after_type.alt.merge.merged"}[0]=$var->{clsets_after_base}[0];$var};

1;
# ABSTRACT: Country code (alpha-3)

__END__

=pod

=encoding UTF-8

=head1 NAME

Sah::SchemaR::country::code::alpha3 - Country code (alpha-3)

=head1 VERSION

This document describes version 0.010 of Sah::SchemaR::country::code::alpha3 (from Perl distribution Sah-SchemaBundle-Country), released on 2024-06-26.

=head1 DESCRIPTION

This module is automatically generated by Dist::Zilla::Plugin::Sah::SchemaBundle during distribution build.

A Sah::SchemaR::* module is useful if a client wants to quickly lookup the base type of a schema without having to do any extra resolving. With Sah::Schema::*, one might need to do several lookups if a schema is based on another schema, and so on. Compare for example L<Sah::Schema::poseven> vs L<Sah::SchemaR::poseven>, where in Sah::SchemaR::poseven one can immediately get that the base type is C<int>. Currently L<Perinci::Sub::Complete> uses Sah::SchemaR::* instead of Sah::Schema::* for reduced startup overhead when doing tab completion.

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Sah-SchemaBundle-Country>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Sah-SchemaBundle-Country>.

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

This software is copyright (c) 2024, 2023, 2020, 2019, 2018 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Sah-SchemaBundle-Country>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
