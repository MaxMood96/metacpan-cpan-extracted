package Weather::NHC::TropicalCyclone::StormTable;

use strict;
use warnings;

our $NHC_ATCF_ARCHIVE_BASE_URL = q{https://ftp.nhc.noaa.gov/atcf/archive};

sub new {
    my $pkg  = shift;
    my $self = bless {}, $pkg;
    $self->_ingest_storm_table;
    return $self;
}

sub _ingest_storm_table {
    my $self = shift;
    my @storm_table = split /\n/, $self->_data;

    $self->{storm_table} = \@storm_table;

  RECORD_LOOP:
    foreach my $storm (@storm_table) {
        my $line       = __PACKAGE__->_parse_line($storm);
        my $name       = $line->[0];
        my $basin      = $line->[1];
        my $storm_num  = $line->[7];
        my $storm_year = $line->[8];
        my $storm_kind = $line->[9];

        # NOTE: adding storm lines by reference for the sake of memory efficiency

        # accessor by name (groups all same-named storms into an array ref) - normalized by upper case
        push @{ $self->{_by_name}->{$name} }, \$storm;

        # by basin (AL, EP, etc)
        push @{ $self->{_by_basin}->{$basin} }, \$storm;

        # by full storm designation (e.g., AL222020, etc)
        my $desig = __PACKAGE__->_get_storm_designation( $basin, $storm_year, $storm_num );
        push @{ $self->{_by_nhc_designation}->{$desig} }, \$storm;

        # by kind (HU, TP, etc)
        push @{ $self->{_by_kind}->{$storm_kind} }, \$storm;

        # all by year
        push @{ $self->{_by_year}->{$storm_year} }, \$storm;

        # all by year, basin
        push @{ $self->{_by_year_basin}->{$basin}->{$storm_year} }, \$storm;

        # accessor by year, storm number
        $self->{_direct_access}->{$storm_year}->{$basin}->{$storm_num} = \$storm;
    }
    return;
}

sub get_storm_numbers {
    my ( $self, $year, $basin ) = @_;
    return [ keys %{ $self->{_direct_access}->{$year}->{ uc $basin } } ];
}

sub get_latest_table {
    my $self = shift;
    require HTTP::Tiny;
    my $url      = qq{$NHC_ATCF_ARCHIVE_BASE_URL/storm.table};
    my $http     = HTTP::Tiny->new;
    my $response = $http->get($url);
    if ( not $response->{success} ) {
        die qq{Unable to retreive updated "storm.history" file.};
    }
    $self->_ingest_storm_table( $response->{content} );
    return;
}

sub _parse_line {
    my ( $self, $line ) = @_;
    my @line = split /, */, $line;
    @line = map { uc $_ } @line;
    $line[0] =~ s/ //g;    # get rid of leading white space - name
    $line[1] =~ s/ //g;    # get rid of leading white space - basin
    $line[9] =~ s/ //g;    # get rid of leading white space - storm kind
    return \@line;
}

sub storm_table {
    my $self = shift;
    return $self->{storm_table};
}

sub _get_storm_designation {
    my ( $self, $basin, $year, $storm_num ) = @_;
    my $desig = sprintf( "%s%02d%d", $basin, $storm_num, $year );
    return $desig;
}

sub get_history_archive_url {
    my ( $self, $year, $basin, $storm_num ) = @_;
    my $desig = $self->_get_storm_designation( $basin, $year, $storm_num );
    my $url   = sprintf( qq{%s/a%s.dat.gz}, $self->get_archive_url($year), $desig );
    return $url;
}

sub get_best_track_archive_url {
    my ( $self, $year, $basin, $storm_num ) = @_;
    my $desig = $self->_get_storm_designation( $basin, $year, $storm_num );
    my $url   = sprintf( qq{%s/b%s.dat.gz}, $self->get_archive_url($year), $desig );
    return $url;
}

sub get_fixes_archive_url {
    my ( $self, $year, $basin, $storm_num ) = @_;
    my $desig = $self->_get_storm_designation( $basin, $year, $storm_num );
    my $url   = sprintf( qq{%s/f%s.dat.gz}, $self->get_archive_url($year), $desig );
    return $url;
}

sub get_archive_url {
    my ( $self, $year ) = @_;
    my $url = sprintf( qq{%s/%d}, $NHC_ATCF_ARCHIVE_BASE_URL, $year );
    return $url;
}

sub get_by_year_basin {
    my ( $self, $year, $basin ) = @_;
    return $self->{_by_year_basin}->{$year}->{$basin};
}

# internal helper method for dereferencing scalars and returning them
# as an arrayref
sub _return_arrayref {
    my ( $self, $arrayref_of_scalarrefs ) = @_;

    # when queried, return array ref of deferenced strings so the called
    # doesn't have to mess with scalar references
    my @return_array = ();
    foreach my $scalarref (@$arrayref_of_scalarrefs) {
        push @return_array, $$scalarref;
    }
    return \@return_array;
}

# get all years
sub years {
    my $self = shift;
    return [ keys %{ $self->{_by_year} } ];
}

# get entries for a specific year (case insensitivie)
sub by_year {
    my ( $self, $year ) = @_;
    my $storms_arrayref = $self->{_by_year}->{ uc $year } // [];
    return $self->_return_arrayref($storms_arrayref);
}

# get all names
sub names {
    my $self = shift;
    return [ keys %{ $self->{_by_name} } ];
}

# get entries for a specific name (case insensitivie)
sub by_name {
    my ( $self, $name ) = @_;
    my $storms_arrayref = $self->{_by_name}->{ uc $name } // [];
    return $self->_return_arrayref($storms_arrayref);
}

# get all basins
sub basins {
    my $self = shift;
    return [ keys %{ $self->{_by_basin} } ];
}

sub by_basin {
    my ( $self, $basin ) = @_;
    my $storms_arrayref = $self->{_by_basin}->{ uc $basin } // [];
    return $self->_return_arrayref($storms_arrayref);
}

# get all nhc_designation_names
sub nhc_designations {
    my $self = shift;
    return [ keys %{ $self->{_by_nhc_designation} } ];
}

sub by_nhc_designation {
    my ( $self, $nhc_designation ) = @_;
    my $storms_arrayref = $self->{_by_nhc_designation}->{ uc $nhc_designation } // [];
    return $self->_return_arrayref($storms_arrayref);
}

# get all kind_names
sub storm_kinds {
    my $self = shift;
    return [ keys %{ $self->{_by_kind} } ];
}

sub by_storm_kind {
    my ( $self, $kind ) = @_;
    my $storms_arrayref = $self->{_by_kind}->{ uc $kind } // [];
    return $self->_return_arrayref($storms_arrayref);
}

sub _data {
    my $self = shift;

    return qq/UNNAMED, AL, L,  ,  ,  ,  , 01, 1851, HU, O, 1851062500, 1851062800, , , , , , ARCHIVE, , AL011851
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1851, HU, O, 1851070512, 1851070512, , , , , , ARCHIVE, , AL021851
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1851, TS, O, 1851071012, 1851071012, , , , , , ARCHIVE, , AL031851
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1851, HU, O, 1851081600, 1851082718, , , , , , ARCHIVE, , AL041851
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1851, TS, O, 1851091300, 1851091618, , , , , , ARCHIVE, , AL051851
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1851, TS, O, 1851101600, 1851101918, , , , , , ARCHIVE, , AL061851
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1852, HU, O, 1852081900, 1852083000, , , , , , ARCHIVE, , AL011852
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1852, HU, O, 1852090500, 1852090618, , , , , , ARCHIVE, , AL021852
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1852, HU, O, 1852090900, 1852091318, , , , , , ARCHIVE, , AL031852
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1852, HU, O, 1852092200, 1852093018, , , , , , ARCHIVE, , AL041852
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1852, HU, O, 1852100600, 1852101118, , , , , , ARCHIVE, , AL051852
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1853, TS, O, 1853080512, 1853080512, , , , , , ARCHIVE, , AL011853
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1853, TS, O, 1853081012, 1853081012, , , , , , ARCHIVE, , AL021853
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1853, HU, O, 1853083000, 1853091018, , , , , , ARCHIVE, , AL031853
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1853, HU, O, 1853090800, 1853091018, , , , , , ARCHIVE, , AL041853
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1853, TS, O, 1853092112, 1853092112, , , , , , ARCHIVE, , AL051853
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1853, HU, O, 1853092600, 1853100106, , , , , , ARCHIVE, , AL061853
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1853, TS, O, 1853092812, 1853092812, , , , , , ARCHIVE, , AL071853
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1853, HU, O, 1853101900, 1853102206, , , , , , ARCHIVE, , AL081853
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1854, HU, O, 1854062500, 1854062712, , , , , , ARCHIVE, , AL011854
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1854, TS, O, 1854082312, 1854082312, , , , , , ARCHIVE, , AL021854
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1854, HU, O, 1854090700, 1854091218, , , , , , ARCHIVE, , AL031854
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1854, HU, O, 1854091800, 1854092006, , , , , , ARCHIVE, , AL041854
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1854, TS, O, 1854102000, 1854102218, , , , , , ARCHIVE, , AL051854
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1855, HU, O, 1855080612, 1855080612, , , , , , ARCHIVE, , AL011855
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1855, HU, O, 1855081000, 1855081106, , , , , , ARCHIVE, , AL021855
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1855, HU, O, 1855081112, 1855081112, , , , , , ARCHIVE, , AL031855
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1855, TS, O, 1855082400, 1855082718, , , , , , ARCHIVE, , AL041855
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1855, HU, O, 1855091500, 1855091706, , , , , , ARCHIVE, , AL051855
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1856, HU, O, 1856080900, 1856081206, , , , , , ARCHIVE, , AL011856
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1856, HU, O, 1856081300, 1856081418, , , , , , ARCHIVE, , AL021856
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1856, TS, O, 1856081900, 1856082112, , , , , , ARCHIVE, , AL031856
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1856, TS, O, 1856082112, 1856082112, , , , , , ARCHIVE, , AL041856
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1856, HU, O, 1856082500, 1856090318, , , , , , ARCHIVE, , AL051856
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1856, HU, O, 1856091800, 1856092218, , , , , , ARCHIVE, , AL061856
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1857, TS, O, 1857063000, 1857070118, , , , , , ARCHIVE, , AL011857
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1857, HU, O, 1857090618, 1857091806, , , , , , ARCHIVE, , AL021857
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1857, HU, O, 1857092200, 1857092618, , , , , , ARCHIVE, , AL031857
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1857, HU, O, 1857092400, 1857093018, , , , , , ARCHIVE, , AL041857
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1858, HU, O, 1858061212, 1858061212, , , , , , ARCHIVE, , AL011858
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1858, HU, O, 1858080512, 1858080512, , , , , , ARCHIVE, , AL021858
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1858, HU, O, 1858091400, 1858091706, , , , , , ARCHIVE, , AL031858
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1858, HU, O, 1858091700, 1858092418, , , , , , ARCHIVE, , AL041858
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1858, HU, O, 1858092212, 1858092518, , , , , , ARCHIVE, , AL051858
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1858, HU, O, 1858102100, 1858102606, , , , , , ARCHIVE, , AL061858
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1859, HU, O, 1859070112, 1859070112, , , , , , ARCHIVE, , AL011859
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1859, HU, O, 1859081700, 1859081918, , , , , , ARCHIVE, , AL021859
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1859, HU, O, 1859090200, 1859090306, , , , , , ARCHIVE, , AL031859
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1859, HU, O, 1859091206, 1859091318, , , , , , ARCHIVE, , AL041859
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1859, HU, O, 1859091500, 1859091818, , , , , , ARCHIVE, , AL051859
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1859, HU, O, 1859100200, 1859100618, , , , , , ARCHIVE, , AL061859
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1859, TS, O, 1859101600, 1859101806, , , , , , ARCHIVE, , AL071859
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1859, HU, O, 1859102400, 1859102918, , , , , , ARCHIVE, , AL081859
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1860, HU, O, 1860080800, 1860081606, , , , , , ARCHIVE, , AL011860
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1860, HU, O, 1860082400, 1860082618, , , , , , ARCHIVE, , AL021860
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1860, HU, O, 1860091112, 1860091112, , , , , , ARCHIVE, , AL031860
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1860, HU, O, 1860091100, 1860091606, , , , , , ARCHIVE, , AL041860
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1860, TS, O, 1860091800, 1860092118, , , , , , ARCHIVE, , AL051860
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1860, HU, O, 1860093000, 1860100318, , , , , , ARCHIVE, , AL061860
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1860, HU, O, 1860102000, 1860102406, , , , , , ARCHIVE, , AL071860
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1861, HU, O, 1861070600, 1861071218, , , , , , ARCHIVE, , AL011861
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1861, HU, O, 1861081312, 1861081718, , , , , , ARCHIVE, , AL021861
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1861, HU, O, 1861082500, 1861083018, , , , , , ARCHIVE, , AL031861
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1861, HU, O, 1861091712, 1861091712, , , , , , ARCHIVE, , AL041861
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1861, HU, O, 1861092706, 1861092812, , , , , , ARCHIVE, , AL051861
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1861, TS, O, 1861100600, 1861100918, , , , , , ARCHIVE, , AL061861
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1861, TS, O, 1861100712, 1861100712, , , , , , ARCHIVE, , AL071861
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1861, HU, O, 1861110106, 1861110318, , , , , , ARCHIVE, , AL081861
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1862, TS, O, 1862061500, 1862061718, , , , , , ARCHIVE, , AL011862
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1862, HU, O, 1862081800, 1862082100, , , , , , ARCHIVE, , AL021862
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1862, HU, O, 1862091200, 1862092006, , , , , , ARCHIVE, , AL031862
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1862, TS, O, 1862100600, 1862100600, , , , , , ARCHIVE, , AL041862
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1862, HU, O, 1862101400, 1862101706, , , , , , ARCHIVE, , AL051862
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1862, TS, O, 1862112200, 1862112506, , , , , , ARCHIVE, , AL061862
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1863, HU, O, 1863080800, 1863080918, , , , , , ARCHIVE, , AL011863
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1863, HU, O, 1863081800, 1863081918, , , , , , ARCHIVE, , AL021863
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1863, HU, O, 1863081900, 1863082306, , , , , , ARCHIVE, , AL031863
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1863, HU, O, 1863082700, 1863082818, , , , , , ARCHIVE, , AL041863
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1863, HU, O, 1863090900, 1863091618, , , , , , ARCHIVE, , AL051863
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1863, TS, O, 1863091600, 1863091906, , , , , , ARCHIVE, , AL061863
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1863, TS, O, 1863091812, 1863091918, , , , , , ARCHIVE, , AL071863
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1863, TS, O, 1863092612, 1863092706, , , , , , ARCHIVE, , AL081863
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1863, TS, O, 1863092900, 1863100118, , , , , , ARCHIVE, , AL091863
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1864, HU, O, 1864071600, 1864071818, , , , , , ARCHIVE, , AL011864
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1864, TS, O, 1864072512, 1864072512, , , , , , ARCHIVE, , AL021864
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1864, HU, O, 1864082600, 1864090106, , , , , , ARCHIVE, , AL031864
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1864, TS, O, 1864090500, 1864090818, , , , , , ARCHIVE, , AL041864
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1864, HU, O, 1864102200, 1864102418, , , , , , ARCHIVE, , AL051864
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1865, TS, O, 1865053000, 1865053000, , , , , , ARCHIVE, , AL011865
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1865, TS, O, 1865063012, 1865063018, , , , , , ARCHIVE, , AL021865
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1865, TS, O, 1865082000, 1865082418, , , , , , ARCHIVE, , AL031865
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1865, HU, O, 1865090600, 1865091418, , , , , , ARCHIVE, , AL041865
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1865, TS, O, 1865090700, 1865090700, , , , , , ARCHIVE, , AL051865
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1865, HU, O, 1865092812, 1865092812, , , , , , ARCHIVE, , AL061865
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1865, HU, O, 1865101800, 1865102518, , , , , , ARCHIVE, , AL071865
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1866, HU, O, 1866071112, 1866071600, , , , , , ARCHIVE, , AL011866
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1866, HU, O, 1866081300, 1866081806, , , , , , ARCHIVE, , AL021866
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1866, HU, O, 1866090400, 1866090706, , , , , , ARCHIVE, , AL031866
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1866, HU, O, 1866091812, 1866091812, , , , , , ARCHIVE, , AL041866
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1866, HU, O, 1866092200, 1866092418, , , , , , ARCHIVE, , AL051866
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1866, HU, O, 1866092400, 1866100518, , , , , , ARCHIVE, , AL061866
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1866, TS, O, 1866102906, 1866103018, , , , , , ARCHIVE, , AL071866
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1867, HU, O, 1867062112, 1867062318, , , , , , ARCHIVE, , AL011867
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1867, HU, O, 1867072800, 1867080318, , , , , , ARCHIVE, , AL021867
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1867, HU, O, 1867080212, 1867080212, , , , , , ARCHIVE, , AL031867
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1867, HU, O, 1867083100, 1867090318, , , , , , ARCHIVE, , AL041867
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1867, TS, O, 1867090812, 1867090812, , , , , , ARCHIVE, , AL051867
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1867, HU, O, 1867092900, 1867100106, , , , , , ARCHIVE, , AL061867
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1867, HU, O, 1867100200, 1867100918, , , , , , ARCHIVE, , AL071867
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1867, TS, O, 1867100912, 1867100912, , , , , , ARCHIVE, , AL081867
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1867, HU, O, 1867102700, 1867103100, , , , , , ARCHIVE, , AL091867
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1868, HU, O, 1868090300, 1868090706, , , , , , ARCHIVE, , AL011868
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1868, TS, O, 1868100100, 1868100718, , , , , , ARCHIVE, , AL021868
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1868, HU, O, 1868100500, 1868100718, , , , , , ARCHIVE, , AL031868
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1868, HU, O, 1868101500, 1868101718, , , , , , ARCHIVE, , AL041868
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1869, HU, O, 1869081200, 1869081218, , , , , , ARCHIVE, , AL011869
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1869, HU, O, 1869081600, 1869081718, , , , , , ARCHIVE, , AL021869
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1869, HU, O, 1869082700, 1869082718, , , , , , ARCHIVE, , AL031869
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1869, TS, O, 1869090100, 1869090218, , , , , , ARCHIVE, , AL041869
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1869, HU, O, 1869090400, 1869090600, , , , , , ARCHIVE, , AL051869
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1869, HU, O, 1869090700, 1869090906, , , , , , ARCHIVE, , AL061869
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1869, HU, O, 1869091100, 1869091818, , , , , , ARCHIVE, , AL071869
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1869, TS, O, 1869091412, 1869091412, , , , , , ARCHIVE, , AL081869
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1869, TS, O, 1869100112, 1869100112, , , , , , ARCHIVE, , AL091869
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1869, HU, O, 1869100400, 1869100512, , , , , , ARCHIVE, , AL101869
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1870, HU, O, 1870073018, 1870073018, , , , , , ARCHIVE, , AL011870
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1870, HU, O, 1870083000, 1870090418, , , , , , ARCHIVE, , AL021870
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1870, TS, O, 1870090100, 1870090418, , , , , , ARCHIVE, , AL031870
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1870, HU, O, 1870090900, 1870091318, , , , , , ARCHIVE, , AL041870
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1870, HU, O, 1870091700, 1870092018, , , , , , ARCHIVE, , AL051870
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1870, HU, O, 1870100500, 1870101418, , , , , , ARCHIVE, , AL061870
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1870, HU, O, 1870100712, 1870100712, , , , , , ARCHIVE, , AL071870
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1870, HU, O, 1870101000, 1870101106, , , , , , ARCHIVE, , AL081870
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1870, HU, O, 1870101900, 1870102218, , , , , , ARCHIVE, , AL091870
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1870, HU, O, 1870102312, 1870102312, , , , , , ARCHIVE, , AL101870
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1870, HU, O, 1870103000, 1870110318, , , , , , ARCHIVE, , AL111870
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1871, TS, O, 1871060100, 1871060518, , , , , , ARCHIVE, , AL011871
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1871, TS, O, 1871060800, 1871061018, , , , , , ARCHIVE, , AL021871
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1871, HU, O, 1871081400, 1871082318, , , , , , ARCHIVE, , AL031871
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1871, HU, O, 1871081700, 1871083018, , , , , , ARCHIVE, , AL041871
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1871, HU, O, 1871083000, 1871090218, , , , , , ARCHIVE, , AL051871
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1871, HU, O, 1871090500, 1871090818, , , , , , ARCHIVE, , AL061871
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1871, HU, O, 1871093000, 1871100718, , , , , , ARCHIVE, , AL071871
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1871, HU, O, 1871101000, 1871101306, , , , , , ARCHIVE, , AL081871
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1872, TS, O, 1872070900, 1872071318, , , , , , ARCHIVE, , AL011872
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1872, HU, O, 1872082000, 1872090218, , , , , , ARCHIVE, , AL021872
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1872, HU, O, 1872090900, 1872092018, , , , , , ARCHIVE, , AL031872
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1872, HU, O, 1872093000, 1872100618, , , , , , ARCHIVE, , AL041872
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1872, HU, O, 1872102200, 1872102806, , , , , , ARCHIVE, , AL051872
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1873, TS, O, 1873060106, 1873060218, , , , , , ARCHIVE, , AL011873
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1873, HU, O, 1873081300, 1873082818, , , , , , ARCHIVE, , AL021873
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1873, HU, O, 1873091800, 1873092018, , , , , , ARCHIVE, , AL031873
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1873, TS, O, 1873092200, 1873092418, , , , , , ARCHIVE, , AL041873
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1873, HU, O, 1873092600, 1873101006, , , , , , ARCHIVE, , AL051873
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1874, TS, O, 1874070200, 1874070506, , , , , , ARCHIVE, , AL011874
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1874, HU, O, 1874080300, 1874080718, , , , , , ARCHIVE, , AL021874
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1874, HU, O, 1874082900, 1874090806, , , , , , ARCHIVE, , AL031874
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1874, TS, O, 1874090200, 1874090718, , , , , , ARCHIVE, , AL041874
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1874, TS, O, 1874090800, 1874091118, , , , , , ARCHIVE, , AL051874
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1874, HU, O, 1874092500, 1874100106, , , , , , ARCHIVE, , AL061874
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1874, HU, O, 1874103100, 1874110418, , , , , , ARCHIVE, , AL071874
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1875, HU, O, 1875081600, 1875081918, , , , , , ARCHIVE, , AL011875
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1875, HU, O, 1875090100, 1875091018, , , , , , ARCHIVE, , AL021875
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1875, HU, O, 1875090800, 1875091818, , , , , , ARCHIVE, , AL031875
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1875, TS, O, 1875092400, 1875092800, , , , , , ARCHIVE, , AL041875
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1875, HU, O, 1875100700, 1875101018, , , , , , ARCHIVE, , AL051875
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1875, HU, O, 1875101200, 1875101618, , , , , , ARCHIVE, , AL061875
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1876, HU, O, 1876090900, 1876091118, , , , , , ARCHIVE, , AL011876
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1876, HU, O, 1876091200, 1876091918, , , , , , ARCHIVE, , AL021876
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1876, TS, O, 1876091600, 1876091818, , , , , , ARCHIVE, , AL031876
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1876, HU, O, 1876092900, 1876100506, , , , , , ARCHIVE, , AL041876
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1876, HU, O, 1876101200, 1876102318, , , , , , ARCHIVE, , AL051876
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1877, TS, O, 1877080100, 1877080506, , , , , , ARCHIVE, , AL011877
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1877, HU, O, 1877091400, 1877092118, , , , , , ARCHIVE, , AL021877
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1877, HU, O, 1877091600, 1877092218, , , , , , ARCHIVE, , AL031877
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1877, HU, O, 1877092100, 1877100518, , , , , , ARCHIVE, , AL041877
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1877, TS, O, 1877092400, 1877092918, , , , , , ARCHIVE, , AL051877
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1877, TS, O, 1877101300, 1877101818, , , , , , ARCHIVE, , AL061877
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1877, TS, O, 1877102400, 1877102806, , , , , , ARCHIVE, , AL071877
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1877, TS, O, 1877112800, 1877113018, , , , , , ARCHIVE, , AL081877
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1878, TS, O, 1878070100, 1878070318, , , , , , ARCHIVE, , AL011878
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1878, HU, O, 1878080800, 1878081900, , , , , , ARCHIVE, , AL021878
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1878, HU, O, 1878081900, 1878082118, , , , , , ARCHIVE, , AL031878
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1878, HU, O, 1878082500, 1878083018, , , , , , ARCHIVE, , AL041878
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1878, HU, O, 1878090100, 1878091318, , , , , , ARCHIVE, , AL051878
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1878, HU, O, 1878091200, 1878091818, , , , , , ARCHIVE, , AL061878
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1878, HU, O, 1878092400, 1878100818, , , , , , ARCHIVE, , AL071878
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1878, HU, O, 1878100900, 1878101518, , , , , , ARCHIVE, , AL081878
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1878, HU, O, 1878100900, 1878101618, , , , , , ARCHIVE, , AL091878
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1878, HU, O, 1878101300, 1878101918, , , , , , ARCHIVE, , AL101878
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1878, HU, O, 1878101800, 1878102518, , , , , , ARCHIVE, , AL111878
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1878, TS, O, 1878112500, 1878120218, , , , , , ARCHIVE, , AL121878
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1879, HU, O, 1879080900, 1879081218, , , , , , ARCHIVE, , AL011879
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1879, HU, O, 1879081300, 1879082018, , , , , , ARCHIVE, , AL021879
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1879, HU, O, 1879081900, 1879082418, , , , , , ARCHIVE, , AL031879
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1879, HU, O, 1879082900, 1879090218, , , , , , ARCHIVE, , AL041879
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1879, TS, O, 1879100300, 1879100718, , , , , , ARCHIVE, , AL051879
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1879, TS, O, 1879100900, 1879101618, , , , , , ARCHIVE, , AL061879
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1879, HU, O, 1879102400, 1879102918, , , , , , ARCHIVE, , AL071879
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1879, HU, O, 1879111800, 1879112118, , , , , , ARCHIVE, , AL081879
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1880, TS, O, 1880062100, 1880062506, , , , , , ARCHIVE, , AL011880
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1880, HU, O, 1880080400, 1880081418, , , , , , ARCHIVE, , AL021880
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1880, HU, O, 1880081500, 1880082018, , , , , , ARCHIVE, , AL031880
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1880, HU, O, 1880082400, 1880090118, , , , , , ARCHIVE, , AL041880
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1880, HU, O, 1880082600, 1880090418, , , , , , ARCHIVE, , AL051880
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1880, HU, O, 1880090600, 1880091118, , , , , , ARCHIVE, , AL061880
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1880, HU, O, 1880090800, 1880091018, , , , , , ARCHIVE, , AL071880
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1880, HU, O, 1880092700, 1880100418, , , , , , ARCHIVE, , AL081880
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1880, HU, O, 1880100500, 1880101018, , , , , , ARCHIVE, , AL091880
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1880, HU, O, 1880101000, 1880101618, , , , , , ARCHIVE, , AL101880
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1880, TS, O, 1880102012, 1880102418, , , , , , ARCHIVE, , AL111880
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1881, TS, O, 1881080100, 1881080406, , , , , , ARCHIVE, , AL011881
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1881, TS, O, 1881081112, 1881081418, , , , , , ARCHIVE, , AL021881
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1881, HU, O, 1881081100, 1881081818, , , , , , ARCHIVE, , AL031881
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1881, HU, O, 1881081600, 1881082118, , , , , , ARCHIVE, , AL041881
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1881, HU, O, 1881082100, 1881082918, , , , , , ARCHIVE, , AL051881
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1881, HU, O, 1881090700, 1881091118, , , , , , ARCHIVE, , AL061881
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1881, TS, O, 1881091800, 1881092418, , , , , , ARCHIVE, , AL071881
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1882, HU, O, 1882082406, 1882082506, , , , , , ARCHIVE, , AL011882
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1882, HU, O, 1882090200, 1882091306, , , , , , ARCHIVE, , AL021882
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1882, TS, O, 1882091400, 1882091600, , , , , , ARCHIVE, , AL031882
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1882, TS, O, 1882092100, 1882092406, , , , , , ARCHIVE, , AL041882
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1882, HU, O, 1882092400, 1882092818, , , , , , ARCHIVE, , AL051882
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1882, HU, O, 1882100500, 1882101518, , , , , , ARCHIVE, , AL061882
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1883, HU, O, 1883081800, 1883082818, , , , , , ARCHIVE, , AL011883
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1883, HU, O, 1883082400, 1883090218, , , , , , ARCHIVE, , AL021883
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1883, HU, O, 1883090400, 1883091306, , , , , , ARCHIVE, , AL031883
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1883, TS, O, 1883102200, 1883102818, , , , , , ARCHIVE, , AL041883
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1884, HU, O, 1884090100, 1884090618, , , , , , ARCHIVE, , AL011884
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1884, HU, O, 1884090300, 1884091618, , , , , , ARCHIVE, , AL021884
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1884, HU, O, 1884091000, 1884092018, , , , , , ARCHIVE, , AL031884
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1884, HU, O, 1884100700, 1884101718, , , , , , ARCHIVE, , AL041884
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1885, HU, O, 1885080700, 1885081518, , , , , , ARCHIVE, , AL011885
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1885, HU, O, 1885082100, 1885082818, , , , , , ARCHIVE, , AL021885
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1885, TS, O, 1885082900, 1885083118, , , , , , ARCHIVE, , AL031885
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1885, HU, O, 1885091700, 1885092318, , , , , , ARCHIVE, , AL041885
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1885, HU, O, 1885091800, 1885092118, , , , , , ARCHIVE, , AL051885
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1885, HU, O, 1885092400, 1885100218, , , , , , ARCHIVE, , AL061885
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1885, HU, O, 1885092600, 1885092918, , , , , , ARCHIVE, , AL071885
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1885, TS, O, 1885101012, 1885101406, , , , , , ARCHIVE, , AL081885
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1886, HU, O, 1886061306, 1886061518, , , , , , ARCHIVE, , AL011886
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1886, HU, O, 1886061700, 1886062418, , , , , , ARCHIVE, , AL021886
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1886, HU, O, 1886062712, 1886070218, , , , , , ARCHIVE, , AL031886
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1886, HU, O, 1886071406, 1886072418, , , , , , ARCHIVE, , AL041886
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1886, HU, O, 1886081206, 1886082118, , , , , , ARCHIVE, , AL051886
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1886, HU, O, 1886081500, 1886082718, , , , , , ARCHIVE, , AL061886
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1886, HU, O, 1886082012, 1886082518, , , , , , ARCHIVE, , AL071886
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1886, HU, O, 1886091600, 1886092418, , , , , , ARCHIVE, , AL081886
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1886, HU, O, 1886092200, 1886093018, , , , , , ARCHIVE, , AL091886
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1886, HU, O, 1886100800, 1886101318, , , , , , ARCHIVE, , AL101886
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1886, TS, O, 1886101000, 1886101518, , , , , , ARCHIVE, , AL111886
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1886, TS, O, 1886102118, 1886102618, , , , , , ARCHIVE, , AL121886
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1887, TS, O, 1887051500, 1887052006, , , , , , ARCHIVE, , AL011887
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1887, TS, O, 1887051700, 1887052118, , , , , , ARCHIVE, , AL021887
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1887, TS, O, 1887061112, 1887061418, , , , , , ARCHIVE, , AL031887
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1887, HU, O, 1887072000, 1887072818, , , , , , ARCHIVE, , AL041887
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1887, TS, O, 1887073006, 1887080800, , , , , , ARCHIVE, , AL051887
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1887, HU, O, 1887081412, 1887082318, , , , , , ARCHIVE, , AL061887
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1887, HU, O, 1887081806, 1887082718, , , , , , ARCHIVE, , AL071887
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1887, HU, O, 1887090100, 1887090612, , , , , , ARCHIVE, , AL081887
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1887, HU, O, 1887091112, 1887092218, , , , , , ARCHIVE, , AL091887
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1887, HU, O, 1887091418, 1887091818, , , , , , ARCHIVE, , AL101887
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1887, TS, O, 1887100612, 1887100900, , , , , , ARCHIVE, , AL111887
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1887, TS, O, 1887100800, 1887100918, , , , , , ARCHIVE, , AL121887
   UNNAMED, AL, L,  ,  ,  ,  , 13, 1887, HU, O, 1887100906, 1887102200, , , , , , ARCHIVE, , AL131887
   UNNAMED, AL, L,  ,  ,  ,  , 14, 1887, HU, O, 1887101006, 1887101218, , , , , , ARCHIVE, , AL141887
   UNNAMED, AL, L,  ,  ,  ,  , 15, 1887, HU, O, 1887101512, 1887101918, , , , , , ARCHIVE, , AL151887
   UNNAMED, AL, L,  ,  ,  ,  , 16, 1887, TS, O, 1887102912, 1887110618, , , , , , ARCHIVE, , AL161887
   UNNAMED, AL, L,  ,  ,  ,  , 17, 1887, HU, O, 1887112712, 1887120418, , , , , , ARCHIVE, , AL171887
   UNNAMED, AL, L,  ,  ,  ,  , 18, 1887, HU, O, 1887120412, 1887121018, , , , , , ARCHIVE, , AL181887
   UNNAMED, AL, L,  ,  ,  ,  , 19, 1887, TS, O, 1887120706, 1887121218, , , , , , ARCHIVE, , AL191887
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1888, HU, O, 1888061600, 1888061818, , , , , , ARCHIVE, , AL011888
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1888, TS, O, 1888070412, 1888070612, , , , , , ARCHIVE, , AL021888
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1888, HU, O, 1888081412, 1888082418, , , , , , ARCHIVE, , AL031888
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1888, HU, O, 1888083100, 1888090806, , , , , , ARCHIVE, , AL041888
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1888, TS, O, 1888090606, 1888091300, , , , , , ARCHIVE, , AL051888
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1888, HU, O, 1888092312, 1888092712, , , , , , ARCHIVE, , AL061888
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1888, HU, O, 1888100812, 1888101218, , , , , , ARCHIVE, , AL071888
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1888, TS, O, 1888110106, 1888110818, , , , , , ARCHIVE, , AL081888
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1888, HU, O, 1888111700, 1888120218, , , , , , ARCHIVE, , AL091888
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1889, HU, O, 1889051606, 1889052200, , , , , , ARCHIVE, , AL011889
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1889, HU, O, 1889061500, 1889062018, , , , , , ARCHIVE, , AL021889
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1889, HU, O, 1889081906, 1889082818, , , , , , ARCHIVE, , AL031889
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1889, HU, O, 1889090100, 1889091218, , , , , , ARCHIVE, , AL041889
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1889, HU, O, 1889090200, 1889091118, , , , , , ARCHIVE, , AL051889
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1889, HU, O, 1889091200, 1889092612, , , , , , ARCHIVE, , AL061889
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1889, TS, O, 1889091206, 1889091918, , , , , , ARCHIVE, , AL071889
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1889, TS, O, 1889092912, 1889100612, , , , , , ARCHIVE, , AL081889
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1889, TS, O, 1889100506, 1889101106, , , , , , ARCHIVE, , AL091889
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1890, TS, O, 1890052712, 1890052918, , , , , , ARCHIVE, , AL011890
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1890, TS, O, 1890081812, 1890082806, , , , , , ARCHIVE, , AL021890
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1890, HU, O, 1890082612, 1890090312, , , , , , ARCHIVE, , AL031890
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1890, HU, O, 1890103100, 1890110106, , , , , , ARCHIVE, , AL041890
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1891, HU, O, 1891070306, 1891070806, , , , , , ARCHIVE, , AL011891
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1891, HU, O, 1891081706, 1891082918, , , , , , ARCHIVE, , AL021891
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1891, HU, O, 1891081812, 1891082518, , , , , , ARCHIVE, , AL031891
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1891, HU, O, 1891090206, 1891091012, , , , , , ARCHIVE, , AL041891
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1891, HU, O, 1891091600, 1891092618, , , , , , ARCHIVE, , AL051891
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1891, HU, O, 1891092906, 1891100818, , , , , , ARCHIVE, , AL061891
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1891, TS, O, 1891100412, 1891101006, , , , , , ARCHIVE, , AL071891
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1891, TS, O, 1891100712, 1891101600, , , , , , ARCHIVE, , AL081891
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1891, HU, O, 1891101212, 1891102018, , , , , , ARCHIVE, , AL091891
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1891, TS, O, 1891110300, 1891110600, , , , , , ARCHIVE, , AL101891
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1892, TS, O, 1892060900, 1892061618, , , , , , ARCHIVE, , AL011892
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1892, HU, O, 1892081500, 1892082418, , , , , , ARCHIVE, , AL021892
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1892, HU, O, 1892090306, 1892091712, , , , , , ARCHIVE, , AL031892
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1892, TS, O, 1892090818, 1892091712, , , , , , ARCHIVE, , AL041892
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1892, HU, O, 1892091200, 1892092318, , , , , , ARCHIVE, , AL051892
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1892, TS, O, 1892092506, 1892092718, , , , , , ARCHIVE, , AL061892
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1892, HU, O, 1892100500, 1892101600, , , , , , ARCHIVE, , AL071892
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1892, HU, O, 1892101300, 1892102006, , , , , , ARCHIVE, , AL081892
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1892, TS, O, 1892102100, 1892102906, , , , , , ARCHIVE, , AL091892
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1893, HU, O, 1893061206, 1893062018, , , , , , ARCHIVE, , AL011893
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1893, HU, O, 1893070412, 1893070718, , , , , , ARCHIVE, , AL021893
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1893, HU, O, 1893081312, 1893082518, , , , , , ARCHIVE, , AL031893
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1893, HU, O, 1893081506, 1893082618, , , , , , ARCHIVE, , AL041893
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1893, HU, O, 1893081512, 1893081906, , , , , , ARCHIVE, , AL051893
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1893, HU, O, 1893081512, 1893090218, , , , , , ARCHIVE, , AL061893
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1893, HU, O, 1893082006, 1893082918, , , , , , ARCHIVE, , AL071893
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1893, HU, O, 1893090406, 1893090918, , , , , , ARCHIVE, , AL081893
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1893, HU, O, 1893092506, 1893101518, , , , , , ARCHIVE, , AL091893
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1893, HU, O, 1893092712, 1893100512, , , , , , ARCHIVE, , AL101893
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1893, TS, O, 1893102012, 1893102318, , , , , , ARCHIVE, , AL111893
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1893, TS, O, 1893110500, 1893111218, , , , , , ARCHIVE, , AL121893
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1894, TS, O, 1894060600, 1894060918, , , , , , ARCHIVE, , AL011894
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1894, TS, O, 1894080506, 1894080918, , , , , , ARCHIVE, , AL021894
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1894, HU, O, 1894083000, 1894090918, , , , , , ARCHIVE, , AL031894
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1894, HU, O, 1894091800, 1894100106, , , , , , ARCHIVE, , AL041894
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1894, HU, O, 1894100100, 1894101212, , , , , , ARCHIVE, , AL051894
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1894, HU, O, 1894101100, 1894102018, , , , , , ARCHIVE, , AL061894
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1894, HU, O, 1894102106, 1894103112, , , , , , ARCHIVE, , AL071894
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1895, TS, O, 1895081406, 1895081718, , , , , , ARCHIVE, , AL011895
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1895, HU, O, 1895082200, 1895083018, , , , , , ARCHIVE, , AL021895
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1895, TS, O, 1895092800, 1895100712, , , , , , ARCHIVE, , AL031895
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1895, TS, O, 1895100200, 1895100712, , , , , , ARCHIVE, , AL041895
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1895, HU, O, 1895101200, 1895102612, , , , , , ARCHIVE, , AL051895
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1895, TS, O, 1895101306, 1895101700, , , , , , ARCHIVE, , AL061895
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1896, HU, O, 1896070412, 1896071212, , , , , , ARCHIVE, , AL011896
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1896, HU, O, 1896083006, 1896091118, , , , , , ARCHIVE, , AL021896
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1896, HU, O, 1896091800, 1896092812, , , , , , ARCHIVE, , AL031896
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1896, HU, O, 1896092206, 1896093012, , , , , , ARCHIVE, , AL041896
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1896, HU, O, 1896100700, 1896101612, , , , , , ARCHIVE, , AL051896
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1896, HU, O, 1896102606, 1896110918, , , , , , ARCHIVE, , AL061896
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1896, TS, O, 1896112700, 1896112918, , , , , , ARCHIVE, , AL071896
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1897, HU, O, 1897083106, 1897091018, , , , , , ARCHIVE, , AL011897
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1897, HU, O, 1897091006, 1897091318, , , , , , ARCHIVE, , AL021897
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1897, TS, O, 1897092012, 1897092512, , , , , , ARCHIVE, , AL031897
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1897, TS, O, 1897092500, 1897092918, , , , , , ARCHIVE, , AL041897
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1897, HU, O, 1897100918, 1897102218, , , , , , ARCHIVE, , AL051897
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1897, TS, O, 1897102306, 1897103118, , , , , , ARCHIVE, , AL061897
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1898, HU, O, 1898080200, 1898080318, , , , , , ARCHIVE, , AL011898
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1898, HU, O, 1898083006, 1898090118, , , , , , ARCHIVE, , AL021898
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1898, HU, O, 1898090306, 1898090600, , , , , , ARCHIVE, , AL031898
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1898, HU, O, 1898090512, 1898092012, , , , , , ARCHIVE, , AL041898
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1898, TS, O, 1898091206, 1898092212, , , , , , ARCHIVE, , AL051898
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1898, TS, O, 1898092012, 1898092818, , , , , , ARCHIVE, , AL061898
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1898, HU, O, 1898092500, 1898100618, , , , , , ARCHIVE, , AL071898
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1898, TS, O, 1898092518, 1898092818, , , , , , ARCHIVE, , AL081898
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1898, TS, O, 1898100206, 1898101418, , , , , , ARCHIVE, , AL091898
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1898, TS, O, 1898102100, 1898102318, , , , , , ARCHIVE, , AL101898
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1898, TS, O, 1898102706, 1898110418, , , , , , ARCHIVE, , AL111898
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1899, TS, O, 1899062612, 1899062718, , , , , , ARCHIVE, , AL011899
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1899, HU, O, 1899072812, 1899080218, , , , , , ARCHIVE, , AL021899
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1899, HU, O, 1899080300, 1899090418, , , , , , ARCHIVE, , AL031899
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1899, HU, O, 1899082906, 1899090818, , , , , , ARCHIVE, , AL041899
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1899, HU, O, 1899090300, 1899091518, , , , , , ARCHIVE, , AL051899
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1899, TS, O, 1899100206, 1899100806, , , , , , ARCHIVE, , AL061899
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1899, TS, O, 1899101012, 1899101412, , , , , , ARCHIVE, , AL071899
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1899, TS, O, 1899101512, 1899101818, , , , , , ARCHIVE, , AL081899   
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1899, HU, O, 1899102600, 1899110418, , , , , , ARCHIVE, , AL091899   
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1899, TS, O, 1899110700, 1899111018, , , , , , ARCHIVE, , AL101899
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1900, HU, O, 1900082700, 1900091518, , , , , , ARCHIVE, , AL011900
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1900, HU, O, 1900090700, 1900091906, , , , , , ARCHIVE, , AL021900
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1900, HU, O, 1900090812, 1900092318, , , , , , ARCHIVE, , AL031900
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1900, TS, O, 1900091100, 1900091518, , , , , , ARCHIVE, , AL041900
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1900, TS, O, 1900100406, 1900101412, , , , , , ARCHIVE, , AL051900
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1900, TS, O, 1900101006, 1900101518, , , , , , ARCHIVE, , AL061900
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1900, TS, O, 1900102400, 1900102918, , , , , , ARCHIVE, , AL071900
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1901, TS, O, 1901061100, 1901061518, , , , , , ARCHIVE, , AL011901
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1901, TS, O, 1901070112, 1901071018, , , , , , ARCHIVE, , AL021901
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1901, HU, O, 1901070400, 1901071318, , , , , , ARCHIVE, , AL031901
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1901, HU, O, 1901080200, 1901081818, , , , , , ARCHIVE, , AL041901
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1901, TS, O, 1901081812, 1901082218, , , , , , ARCHIVE, , AL051901
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1901, HU, O, 1901082512, 1901083018, , , , , , ARCHIVE, , AL061901
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1901, HU, O, 1901082906, 1901091118, , , , , , ARCHIVE, , AL071901
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1901, HU, O, 1901090906, 1901091918, , , , , , ARCHIVE, , AL081901
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1901, TS, O, 1901091200, 1901091718, , , , , , ARCHIVE, , AL091901
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1901, TS, O, 1901092100, 1901100212, , , , , , ARCHIVE, , AL101901
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1901, TS, O, 1901100500, 1901101412, , , , , , ARCHIVE, , AL111901
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1901, TS, O, 1901101500, 1901101818, , , , , , ARCHIVE, , AL121901
   UNNAMED, AL, L,  ,  ,  ,  , 13, 1901, HU, O, 1901103012, 1901110618, , , , , , ARCHIVE, , AL131901
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1902, TS, O, 1902061212, 1902061718, , , , , , ARCHIVE, , AL011902
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1902, HU, O, 1902062100, 1902062918, , , , , , ARCHIVE, , AL021902
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1902, HU, O, 1902091606, 1902092518, , , , , , ARCHIVE, , AL031902
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1902, HU, O, 1902100300, 1902101312, , , , , , ARCHIVE, , AL041902
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1902, TS, O, 1902110100, 1902110618, , , , , , ARCHIVE, , AL051902
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1903, HU, O, 1903072100, 1903072618, , , , , , ARCHIVE, , AL011903
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1903, HU, O, 1903080606, 1903081618, , , , , , ARCHIVE, , AL021903
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1903, HU, O, 1903090906, 1903091618, , , , , , ARCHIVE, , AL031903
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1903, HU, O, 1903091200, 1903091718, , , , , , ARCHIVE, , AL041903
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1903, TS, O, 1903091900, 1903092618, , , , , , ARCHIVE, , AL051903
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1903, HU, O, 1903092606, 1903093018, , , , , , ARCHIVE, , AL061903
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1903, HU, O, 1903100100, 1903101018, , , , , , ARCHIVE, , AL071903
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1903, TS, O, 1903100500, 1903101018, , , , , , ARCHIVE, , AL081903
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1903, TS, O, 1903102106, 1903102718, , , , , , ARCHIVE, , AL091903
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1903, HU, O, 1903111706, 1903112518, , , , , , ARCHIVE, , AL101903
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1904, HU, O, 1904061012, 1904061418, , , , , , ARCHIVE, , AL011904
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1904, HU, O, 1904090800, 1904091518, , , , , , ARCHIVE, , AL021904
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1904, HU, O, 1904092800, 1904100418, , , , , , ARCHIVE, , AL031904
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1904, HU, O, 1904101206, 1904102118, , , , , , ARCHIVE, , AL041904
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1904, TS, O, 1904101906, 1904102518, , , , , , ARCHIVE, , AL051904
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1904, TS, O, 1904103112, 1904110618, , , , , , ARCHIVE, , AL061904
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1905, TS, O, 1905090612, 1905090818, , , , , , ARCHIVE, , AL011905
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1905, TS, O, 1905091112, 1905091618, , , , , , ARCHIVE, , AL021905
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1905, TS, O, 1905092406, 1905093018, , , , , , ARCHIVE, , AL031905
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1905, HU, O, 1905100106, 1905101318, , , , , , ARCHIVE, , AL041905
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1905, TS, O, 1905100506, 1905101118, , , , , , ARCHIVE, , AL051905
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1906, TS, O, 1906060812, 1906061418, , , , , , ARCHIVE, , AL011906
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1906, HU, O, 1906061406, 1906062318, , , , , , ARCHIVE, , AL021906
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1906, TS, O, 1906082206, 1906082518, , , , , , ARCHIVE, , AL031906
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1906, HU, O, 1906082512, 1906091218, , , , , , ARCHIVE, , AL041906
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1906, HU, O, 1906090312, 1906091818, , , , , , ARCHIVE, , AL051906
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1906, HU, O, 1906091912, 1906093006, , , , , , ARCHIVE, , AL061906
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1906, TS, O, 1906092200, 1906100218, , , , , , ARCHIVE, , AL071906
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1906, HU, O, 1906100806, 1906102318, , , , , , ARCHIVE, , AL081906
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1906, TS, O, 1906101406, 1906101718, , , , , , ARCHIVE, , AL091906
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1906, TS, O, 1906101506, 1906102018, , , , , , ARCHIVE, , AL101906
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1906, HU, O, 1906110500, 1906111006, , , , , , ARCHIVE, , AL111906
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1907, TS, O, 1907062412, 1907063018, , , , , , ARCHIVE, , AL011907
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1907, TS, O, 1907091812, 1907092318, , , , , , ARCHIVE, , AL021907
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1907, TS, O, 1907092706, 1907093000, , , , , , ARCHIVE, , AL031907
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1907, TS, O, 1907101706, 1907102000, , , , , , ARCHIVE, , AL041907
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1907, TS, O, 1907110600, 1907111218, , , , , , ARCHIVE, , AL051907
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1908, HU, O, 1908030612, 1908030918, , , , , , ARCHIVE, , AL011908
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1908, HU, O, 1908052412, 1908053118, , , , , , ARCHIVE, , AL021908
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1908, HU, O, 1908072412, 1908080318, , , , , , ARCHIVE, , AL031908
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1908, TS, O, 1908072900, 1908080318, , , , , , ARCHIVE, , AL041908
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1908, TS, O, 1908083012, 1908090218, , , , , , ARCHIVE, , AL051908
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1908, HU, O, 1908090712, 1908091918, , , , , , ARCHIVE, , AL061908
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1908, TS, O, 1908091612, 1908091818, , , , , , ARCHIVE, , AL071908
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1908, HU, O, 1908092112, 1908100718, , , , , , ARCHIVE, , AL081908
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1908, HU, O, 1908101412, 1908101906, , , , , , ARCHIVE, , AL091908
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1908, TS, O, 1908101912, 1908102318, , , , , , ARCHIVE, , AL101908
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1909, TS, O, 1909061500, 1909061918, , , , , , ARCHIVE, , AL011909
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1909, HU, O, 1909062512, 1909063012, , , , , , ARCHIVE, , AL021909
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1909, TS, O, 1909062612, 1909070418, , , , , , ARCHIVE, , AL031909
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1909, HU, O, 1909071312, 1909072212, , , , , , ARCHIVE, , AL041909
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1909, TS, O, 1909080600, 1909081018, , , , , , ARCHIVE, , AL051909
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1909, HU, O, 1909082006, 1909082812, , , , , , ARCHIVE, , AL061909
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1909, TS, O, 1909082200, 1909082506, , , , , , ARCHIVE, , AL071909
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1909, TS, O, 1909082800, 1909083118, , , , , , ARCHIVE, , AL081909
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1909, HU, O, 1909091312, 1909092200, , , , , , ARCHIVE, , AL091909
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1909, TS, O, 1909092400, 1909092900, , , , , , ARCHIVE, , AL101909
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1909, HU, O, 1909100612, 1909101318, , , , , , ARCHIVE, , AL111909
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1909, HU, O, 1909110812, 1909111418, , , , , , ARCHIVE, , AL121909
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1910, TS, O, 1910082306, 1910082918, , , , , , ARCHIVE, , AL011910
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1910, TS, O, 1910082612, 1910083118, , , , , , ARCHIVE, , AL021910
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1910, HU, O, 1910090506, 1910091518, , , , , , ARCHIVE, , AL031910
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1910, HU, O, 1910092406, 1910092918, , , , , , ARCHIVE, , AL041910
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1910, HU, O, 1910100906, 1910102318, , , , , , ARCHIVE, , AL051910
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1911, TS, O, 1911080412, 1911081200, , , , , , ARCHIVE, , AL011911
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1911, HU, O, 1911080812, 1911081412, , , , , , ARCHIVE, , AL021911
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1911, HU, O, 1911082306, 1911083112, , , , , , ARCHIVE, , AL031911
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1911, HU, O, 1911090312, 1911091218, , , , , , ARCHIVE, , AL041911
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1911, TS, O, 1911091512, 1911092018, , , , , , ARCHIVE, , AL051911
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1911, TS, O, 1911102600, 1911110100, , , , , , ARCHIVE, , AL061911
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1912, TS, O, 1912060712, 1912061712, , , , , , ARCHIVE, , AL011912
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1912, TS, O, 1912071212, 1912071712, , , , , , ARCHIVE, , AL021912
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1912, TS, O, 1912090200, 1912090618, , , , , , ARCHIVE, , AL031912
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1912, HU, O, 1912091012, 1912091506, , , , , , ARCHIVE, , AL041912
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1912, HU, O, 1912100312, 1912101018, , , , , , ARCHIVE, , AL051912
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1912, HU, O, 1912101112, 1912101800, , , , , , ARCHIVE, , AL061912
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1912, HU, O, 1912111106, 1912112118, , , , , , ARCHIVE, , AL071912
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1913, HU, O, 1913062106, 1913062900, , , , , , ARCHIVE, , AL011913
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1913, TS, O, 1913081412, 1913081618, , , , , , ARCHIVE, , AL021913
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1913, TS, O, 1913082612, 1913091218, , , , , , ARCHIVE, , AL031913
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1913, HU, O, 1913083012, 1913090412, , , , , , ARCHIVE, , AL041913
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1913, HU, O, 1913100212, 1913101100, , , , , , ARCHIVE, , AL051913
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1913, HU, O, 1913102800, 1913103006, , , , , , ARCHIVE, , AL061913
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1914, TS, O, 1914091500, 1914091906, , , , , , ARCHIVE, , AL011914
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1915, HU, O, 1915073106, 1915080512, , , , , , ARCHIVE, , AL011915
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1915, HU, O, 1915080512, 1915082318, , , , , , ARCHIVE, , AL021915
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1915, HU, O, 1915082712, 1915091100, , , , , , ARCHIVE, , AL031915
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1915, HU, O, 1915083112, 1915090618, , , , , , ARCHIVE, , AL041915
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1915, TS, O, 1915091912, 1915092306, , , , , , ARCHIVE, , AL051915
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1915, HU, O, 1915092112, 1915100118, , , , , , ARCHIVE, , AL061915
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1916, TS, O, 1916051312, 1916051800, , , , , , ARCHIVE, , AL011916
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1916, HU, O, 1916062812, 1916071018, , , , , , ARCHIVE, , AL021916
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1916, HU, O, 1916071006, 1916072218, , , , , , ARCHIVE, , AL031916
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1916, HU, O, 1916071106, 1916071518, , , , , , ARCHIVE, , AL041916
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1916, TS, O, 1916080412, 1916080618, , , , , , ARCHIVE, , AL051916
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1916, HU, O, 1916081206, 1916082000, , , , , , ARCHIVE, , AL061916
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1916, HU, O, 1916082106, 1916082606, , , , , , ARCHIVE, , AL071916
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1916, HU, O, 1916082706, 1916090212, , , , , , ARCHIVE, , AL081916
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1916, TS, O, 1916090412, 1916090700, , , , , , ARCHIVE, , AL091916
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1916, HU, O, 1916091312, 1916092200, , , , , , ARCHIVE, , AL101916
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1916, HU, O, 1916091712, 1916092500, , , , , , ARCHIVE, , AL111916
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1916, TS, O, 1916100206, 1916100500, , , , , , ARCHIVE, , AL121916
   UNNAMED, AL, L,  ,  ,  ,  , 13, 1916, HU, O, 1916100606, 1916101500, , , , , , ARCHIVE, , AL131916
   UNNAMED, AL, L,  ,  ,  ,  , 14, 1916, HU, O, 1916100906, 1916101912, , , , , , ARCHIVE, , AL141916
   UNNAMED, AL, L,  ,  ,  ,  , 15, 1916, TS, O, 1916111100, 1916111606, , , , , , ARCHIVE, , AL151916
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1917, TS, O, 1917070612, 1917071412, , , , , , ARCHIVE, , AL011917
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1917, TS, O, 1917080600, 1917081118, , , , , , ARCHIVE, , AL021917
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1917, HU, O, 1917083006, 1917090718, , , , , , ARCHIVE, , AL031917
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1917, HU, O, 1917092000, 1917093006, , , , , , ARCHIVE, , AL041917
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1918, HU, O, 1918080100, 1918080718, , , , , , ARCHIVE, , AL011918
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1918, HU, O, 1918082206, 1918082612, , , , , , ARCHIVE, , AL021918
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1918, HU, O, 1918082306, 1918082612, , , , , , ARCHIVE, , AL031918
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1918, TS, O, 1918083112, 1918090600, , , , , , ARCHIVE, , AL041918
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1918, HU, O, 1918090200, 1918090812, , , , , , ARCHIVE, , AL051918
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1918, TS, O, 1918090900, 1918091412, , , , , , ARCHIVE, , AL061918
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1919, TS, O, 1919070206, 1919070518, , , , , , ARCHIVE, , AL011919
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1919, HU, O, 1919090212, 1919091612, , , , , , ARCHIVE, , AL021919
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1919, HU, O, 1919090200, 1919090500, , , , , , ARCHIVE, , AL031919
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1919, TS, O, 1919092900, 1919100200, , , , , , ARCHIVE, , AL041919
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1919, TS, O, 1919111000, 1919111518, , , , , , ARCHIVE, , AL051919
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1920, HU, O, 1920090700, 1920091606, , , , , , ARCHIVE, , AL011920
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1920, HU, O, 1920091606, 1920092306, , , , , , ARCHIVE, , AL021920
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1920, HU, O, 1920091906, 1920092400, , , , , , ARCHIVE, , AL031920
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1920, TS, O, 1920092312, 1920092718, , , , , , ARCHIVE, , AL041920
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1920, HU, O, 1920092506, 1920093018, , , , , , ARCHIVE, , AL051920
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1921, HU, O, 1921061600, 1921062612, , , , , , ARCHIVE, , AL011921
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1921, HU, O, 1921090412, 1921090806, , , , , , ARCHIVE, , AL021921
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1921, HU, O, 1921090600, 1921091718, , , , , , ARCHIVE, , AL031921
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1921, HU, O, 1921090800, 1921091418, , , , , , ARCHIVE, , AL041921
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1921, TS, O, 1921101512, 1921102406, , , , , , ARCHIVE, , AL051921
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1921, HU, O, 1921102000, 1921103006, , , , , , ARCHIVE, , AL061921
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1921, TS, O, 1921111900, 1921112518, , , , , , ARCHIVE, , AL071921
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1922, TS, O, 1922061212, 1922061618, , , , , , ARCHIVE, , AL011922
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1922, HU, O, 1922091300, 1922092806, , , , , , ARCHIVE, , AL021922
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1922, HU, O, 1922091800, 1922092500, , , , , , ARCHIVE, , AL031922
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1922, HU, O, 1922101100, 1922102206, , , , , , ARCHIVE, , AL041922
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1922, TS, O, 1922101200, 1922101718, , , , , , ARCHIVE, , AL051922
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1923, TS, O, 1923062212, 1923062900, , , , , , ARCHIVE, , AL011923
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1923, HU, O, 1923090100, 1923091012, , , , , , ARCHIVE, , AL021923
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1923, TS, O, 1923090700, 1923091100, , , , , , ARCHIVE, , AL031923
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1923, HU, O, 1923091000, 1923091500, , , , , , ARCHIVE, , AL041923
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1923, HU, O, 1923092418, 1923100418, , , , , , ARCHIVE, , AL051923
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1923, HU, O, 1923101206, 1923101712, , , , , , ARCHIVE, , AL061923
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1923, TS, O, 1923101500, 1923101918, , , , , , ARCHIVE, , AL071923
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1923, TS, O, 1923101612, 1923102118, , , , , , ARCHIVE, , AL081923
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1923, TS, O, 1923102406, 1923102700, , , , , , ARCHIVE, , AL091923
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1924, TS, O, 1924061800, 1924062106, , , , , , ARCHIVE, , AL011924
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1924, TS, O, 1924072806, 1924073018, , , , , , ARCHIVE, , AL021924
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1924, HU, O, 1924081606, 1924082812, , , , , , ARCHIVE, , AL031924
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1924, HU, O, 1924082600, 1924090618, , , , , , ARCHIVE, , AL041924
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1924, HU, O, 1924091300, 1924091918, , , , , , ARCHIVE, , AL051924
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1924, TS, O, 1924092000, 1924092218, , , , , , ARCHIVE, , AL061924
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1924, TS, O, 1924092400, 1924100518, , , , , , ARCHIVE, , AL071924
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1924, TS, O, 1924092700, 1924100100, , , , , , ARCHIVE, , AL081924
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1924, TS, O, 1924101112, 1924101506, , , , , , ARCHIVE, , AL091924
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1924, HU, O, 1924101400, 1924102312, , , , , , ARCHIVE, , AL101924
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1924, HU, O, 1924110512, 1924111418, , , , , , ARCHIVE, , AL111924
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1925, HU, O, 1925081800, 1925082106, , , , , , ARCHIVE, , AL011925
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1925, TS, O, 1925082512, 1925082800, , , , , , ARCHIVE, , AL021925
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1925, TS, O, 1925090600, 1925090718, , , , , , ARCHIVE, , AL031925
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1925, TS, O, 1925112700, 1925120512, , , , , , ARCHIVE, , AL041925
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1926, HU, O, 1926072206, 1926080212, , , , , , ARCHIVE, , AL011926
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1926, HU, O, 1926072912, 1926080818, , , , , , ARCHIVE, , AL021926
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1926, HU, O, 1926082012, 1926082718, , , , , , ARCHIVE, , AL031926
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1926, HU, O, 1926090100, 1926092412, , , , , , ARCHIVE, , AL041926
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1926, HU, O, 1926091006, 1926091418, , , , , , ARCHIVE, , AL051926
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1926, TS, O, 1926091100, 1926091712, , , , , , ARCHIVE, , AL061926
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1926, HU, O, 1926091112, 1926092212, , , , , , ARCHIVE, , AL071926
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1926, HU, O, 1926092112, 1926100118, , , , , , ARCHIVE, , AL081926
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1926, TS, O, 1926100300, 1926100512, , , , , , ARCHIVE, , AL091926
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1926, HU, O, 1926101406, 1926102806, , , , , , ARCHIVE, , AL101926
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1926, TS, O, 1926111206, 1926111612, , , , , , ARCHIVE, , AL111926
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1927, HU, O, 1927081812, 1927082912, , , , , , ARCHIVE, , AL011927
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1927, HU, O, 1927090206, 1927091118, , , , , , ARCHIVE, , AL021927
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1927, HU, O, 1927092212, 1927092906, , , , , , ARCHIVE, , AL031927
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1927, HU, O, 1927092300, 1927100118, , , , , , ARCHIVE, , AL041927
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1927, TS, O, 1927093012, 1927100406, , , , , , ARCHIVE, , AL051927
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1927, TS, O, 1927101600, 1927101906, , , , , , ARCHIVE, , AL061927
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1927, TS, O, 1927103012, 1927110406, , , , , , ARCHIVE, , AL071927
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1927, TS, O, 1927111900, 1927112118, , , , , , ARCHIVE, , AL081927
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1928, HU, O, 1928080300, 1928081318, , , , , , ARCHIVE, , AL011928
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1928, HU, O, 1928080712, 1928081706, , , , , , ARCHIVE, , AL021928
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1928, TS, O, 1928090118, 1928090818, , , , , , ARCHIVE, , AL031928
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1928, HU, O, 1928090600, 1928092100, , , , , , ARCHIVE, , AL041928
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1928, TS, O, 1928090812, 1928091306, , , , , , ARCHIVE, , AL051928
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1928, HU, O, 1928101000, 1928101506, , , , , , ARCHIVE, , AL061928
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1929, HU, O, 1929062700, 1929063006, , , , , , ARCHIVE, , AL011929
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1929, HU, O, 1929091900, 1929100500, , , , , , ARCHIVE, , AL021929
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1929, TS, O, 1929092500, 1929092918, , , , , , ARCHIVE, , AL031929
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1929, TS, O, 1929101500, 1929102006, , , , , , ARCHIVE, , AL041929
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1929, HU, O, 1929101912, 1929102300, , , , , , ARCHIVE, , AL051929
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1930, HU, O, 1930082118, 1930090300, , , , , , ARCHIVE, , AL011930
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1930, HU, O, 1930082900, 1930091718, , , , , , ARCHIVE, , AL021930
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1930, TS, O, 1930101812, 1930102106, , , , , , ARCHIVE, , AL031930
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1931, TS, O, 1931062412, 1931062818, , , , , , ARCHIVE, , AL011931
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1931, TS, O, 1931071106, 1931071706, , , , , , ARCHIVE, , AL021931
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1931, TS, O, 1931081018, 1931081900, , , , , , ARCHIVE, , AL031931
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1931, TS, O, 1931081606, 1931082106, , , , , , ARCHIVE, , AL041931
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1931, TS, O, 1931090100, 1931090400, , , , , , ARCHIVE, , AL051931
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1931, HU, O, 1931090618, 1931091312, , , , , , ARCHIVE, , AL061931
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1931, HU, O, 1931090818, 1931091618, , , , , , ARCHIVE, , AL071931
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1931, HU, O, 1931092306, 1931092906, , , , , , ARCHIVE, , AL081931
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1931, TS, O, 1931101312, 1931101612, , , , , , ARCHIVE, , AL091931
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1931, TS, O, 1931101812, 1931102218, , , , , , ARCHIVE, , AL101931
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1931, TS, O, 1931110112, 1931110518, , , , , , ARCHIVE, , AL111931
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1931, TS, O, 1931111112, 1931111618, , , , , , ARCHIVE, , AL121931
   UNNAMED, AL, L,  ,  ,  ,  , 13, 1931, TS, O, 1931112206, 1931112518, , , , , , ARCHIVE, , AL131931
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1932, TS, O, 1932050512, 1932051100, , , , , , ARCHIVE, , AL011932
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1932, HU, O, 1932081200, 1932081518, , , , , , ARCHIVE, , AL021932
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1932, HU, O, 1932082618, 1932090406, , , , , , ARCHIVE, , AL031932
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1932, HU, O, 1932083018, 1932091718, , , , , , ARCHIVE, , AL041932
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1932, TS, O, 1932090400, 1932090718, , , , , , ARCHIVE, , AL051932
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1932, TS, O, 1932090906, 1932091806, , , , , , ARCHIVE, , AL061932
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1932, TS, O, 1932091600, 1932092618, , , , , , ARCHIVE, , AL071932
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1932, TS, O, 1932091800, 1932092118, , , , , , ARCHIVE, , AL081932
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1932, HU, O, 1932092506, 1932100218, , , , , , ARCHIVE, , AL091932
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1932, TS, O, 1932092800, 1932093006, , , , , , ARCHIVE, , AL101932
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1932, HU, O, 1932100700, 1932101812, , , , , , ARCHIVE, , AL111932
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1932, TS, O, 1932100800, 1932101206, , , , , , ARCHIVE, , AL121932
   UNNAMED, AL, L,  ,  ,  ,  , 13, 1932, TS, O, 1932101800, 1932102100, , , , , , ARCHIVE, , AL131932
   UNNAMED, AL, L,  ,  ,  ,  , 14, 1932, HU, O, 1932103006, 1932111418, , , , , , ARCHIVE, , AL141932
   UNNAMED, AL, L,  ,  ,  ,  , 15, 1932, HU, O, 1932110306, 1932111018, , , , , , ARCHIVE, , AL151932
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1933, TS, O, 1933051412, 1933051918, , , , , , ARCHIVE, , AL011933
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1933, HU, O, 1933062412, 1933070712, , , , , , ARCHIVE, , AL021933
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1933, TS, O, 1933071400, 1933072706, , , , , , ARCHIVE, , AL031933
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1933, TS, O, 1933072412, 1933072700, , , , , , ARCHIVE, , AL041933
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1933, HU, O, 1933072412, 1933080518, , , , , , ARCHIVE, , AL051933
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1933, HU, O, 1933081312, 1933082812, , , , , , ARCHIVE, , AL061933
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1933, TS, O, 1933081400, 1933082112, , , , , , ARCHIVE, , AL071933
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1933, HU, O, 1933082206, 1933090518, , , , , , ARCHIVE, , AL081933
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1933, TS, O, 1933082312, 1933083118, , , , , , ARCHIVE, , AL091933
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1933, TS, O, 1933082618, 1933083000, , , , , , ARCHIVE, , AL101933
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1933, HU, O, 1933083106, 1933090718, , , , , , ARCHIVE, , AL111933
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1933, HU, O, 1933090800, 1933092218, , , , , , ARCHIVE, , AL121933
   UNNAMED, AL, L,  ,  ,  ,  , 13, 1933, HU, O, 1933091012, 1933091600, , , , , , ARCHIVE, , AL131933
   UNNAMED, AL, L,  ,  ,  ,  , 14, 1933, HU, O, 1933091606, 1933092512, , , , , , ARCHIVE, , AL141933
   UNNAMED, AL, L,  ,  ,  ,  , 15, 1933, HU, O, 1933092412, 1933092812, , , , , , ARCHIVE, , AL151933
   UNNAMED, AL, L,  ,  ,  ,  , 16, 1933, TS, O, 1933100100, 1933100418, , , , , , ARCHIVE, , AL161933
   UNNAMED, AL, L,  ,  ,  ,  , 17, 1933, HU, O, 1933100106, 1933100906, , , , , , ARCHIVE, , AL171933
   UNNAMED, AL, L,  ,  ,  ,  , 18, 1933, HU, O, 1933102506, 1933110718, , , , , , ARCHIVE, , AL181933
   UNNAMED, AL, L,  ,  ,  ,  , 19, 1933, TS, O, 1933102600, 1933103018, , , , , , ARCHIVE, , AL191933
   UNNAMED, AL, L,  ,  ,  ,  , 20, 1933, TS, O, 1933111512, 1933111706, , , , , , ARCHIVE, , AL201933
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1934, HU, O, 1934060412, 1934062118, , , , , , ARCHIVE, , AL011934
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1934, HU, O, 1934071200, 1934071700, , , , , , ARCHIVE, , AL021934
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1934, HU, O, 1934072206, 1934072618, , , , , , ARCHIVE, , AL031934
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1934, TS, O, 1934082018, 1934082306, , , , , , ARCHIVE, , AL041934
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1934, HU, O, 1934082606, 1934090118, , , , , , ARCHIVE, , AL051934
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1934, TS, O, 1934090100, 1934090406, , , , , , ARCHIVE, , AL061934
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1934, HU, O, 1934090506, 1934091012, , , , , , ARCHIVE, , AL071934
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1934, TS, O, 1934091612, 1934092312, , , , , , ARCHIVE, , AL081934
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1934, TS, O, 1934091800, 1934092506, , , , , , ARCHIVE, , AL091934
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1934, HU, O, 1934100112, 1934100406, , , , , , ARCHIVE, , AL101934
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1934, TS, O, 1934100112, 1934100618, , , , , , ARCHIVE, , AL111934
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1934, TS, O, 1934101918, 1934102318, , , , , , ARCHIVE, , AL121934
   UNNAMED, AL, L,  ,  ,  ,  , 13, 1934, HU, O, 1934112006, 1934113012, , , , , , ARCHIVE, , AL131934
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1935, TS, O, 1935051500, 1935051900, , , , , , ARCHIVE, , AL011935
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1935, HU, O, 1935081606, 1935082618, , , , , , ARCHIVE, , AL021935
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1935, HU, O, 1935082906, 1935091012, , , , , , ARCHIVE, , AL031935
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1935, TS, O, 1935083000, 1935090212, , , , , , ARCHIVE, , AL041935
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1935, HU, O, 1935092306, 1935100218, , , , , , ARCHIVE, , AL051935
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1935, HU, O, 1935101812, 1935102706, , , , , , ARCHIVE, , AL061935
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1935, HU, O, 1935103006, 1935110818, , , , , , ARCHIVE, , AL071935
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1935, TS, O, 1935110300, 1935111400, , , , , , ARCHIVE, , AL081935
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1936, TS, O, 1936061200, 1936061706, , , , , , ARCHIVE, , AL011936
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1936, TS, O, 1936061906, 1936062206, , , , , , ARCHIVE, , AL021936
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1936, HU, O, 1936062618, 1936062806, , , , , , ARCHIVE, , AL031936
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1936, TS, O, 1936072606, 1936072806, , , , , , ARCHIVE, , AL041936
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1936, HU, O, 1936072706, 1936080112, , , , , , ARCHIVE, , AL051936
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1936, TS, O, 1936080406, 1936081118, , , , , , ARCHIVE, , AL061936
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1936, TS, O, 1936080718, 1936081218, , , , , , ARCHIVE, , AL071936
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1936, HU, O, 1936081506, 1936082000, , , , , , ARCHIVE, , AL081936
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1936, TS, O, 1936082006, 1936082306, , , , , , ARCHIVE, , AL091936
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1936, HU, O, 1936082518, 1936090618, , , , , , ARCHIVE, , AL101936
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1936, HU, O, 1936082800, 1936083100, , , , , , ARCHIVE, , AL111936
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1936, TS, O, 1936090706, 1936090806, , , , , , ARCHIVE, , AL121936
   UNNAMED, AL, L,  ,  ,  ,  , 13, 1936, HU, O, 1936090806, 1936092518, , , , , , ARCHIVE, , AL131936
   UNNAMED, AL, L,  ,  ,  ,  , 14, 1936, TS, O, 1936090912, 1936091418, , , , , , ARCHIVE, , AL141936
   UNNAMED, AL, L,  ,  ,  ,  , 15, 1936, HU, O, 1936091818, 1936092512, , , , , , ARCHIVE, , AL151936
   UNNAMED, AL, L,  ,  ,  ,  , 16, 1936, TS, O, 1936100918, 1936101118, , , , , , ARCHIVE, , AL161936
   UNNAMED, AL, L,  ,  ,  ,  , 17, 1936, HU, O, 1936120212, 1936121600, , , , , , ARCHIVE, , AL171936
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1937, TS, O, 1937072900, 1937080218, , , , , , ARCHIVE, , AL011937
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1937, TS, O, 1937080218, 1937080912, , , , , , ARCHIVE, , AL021937
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1937, TS, O, 1937082412, 1937090218, , , , , , ARCHIVE, , AL031937
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1937, HU, O, 1937090900, 1937091418, , , , , , ARCHIVE, , AL041937
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1937, TS, O, 1937091006, 1937091206, , , , , , ARCHIVE, , AL051937
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1937, HU, O, 1937091306, 1937092018, , , , , , ARCHIVE, , AL061937
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1937, TS, O, 1937091612, 1937092118, , , , , , ARCHIVE, , AL071937
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1937, HU, O, 1937092006, 1937092812, , , , , , ARCHIVE, , AL081937
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1937, TS, O, 1937092606, 1937100300, , , , , , ARCHIVE, , AL091937
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1937, TS, O, 1937100200, 1937100406, , , , , , ARCHIVE, , AL101937
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1937, HU, O, 1937101812, 1937102100, , , , , , ARCHIVE, , AL111937
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1938, HU, O, 1938010112, 1938010618, , , , , , ARCHIVE, , AL011938
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1938, TS, O, 1938080806, 1938080918, , , , , , ARCHIVE, , AL021938
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1938, HU, O, 1938081000, 1938081512, , , , , , ARCHIVE, , AL031938
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1938, HU, O, 1938082306, 1938082900, , , , , , ARCHIVE, , AL041938
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1938, TS, O, 1938090912, 1938091400, , , , , , ARCHIVE, , AL051938
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1938, HU, O, 1938090912, 1938092300, , , , , , ARCHIVE, , AL061938
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1938, TS, O, 1938101018, 1938101718, , , , , , ARCHIVE, , AL071938
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1938, TS, O, 1938101612, 1938102100, , , , , , ARCHIVE, , AL081938
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1938, TS, O, 1938110706, 1938111018, , , , , , ARCHIVE, , AL091938
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1939, TS, O, 1939061206, 1939061818, , , , , , ARCHIVE, , AL011939
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1939, HU, O, 1939080718, 1939081918, , , , , , ARCHIVE, , AL021939
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1939, TS, O, 1939081500, 1939082018, , , , , , ARCHIVE, , AL031939
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1939, TS, O, 1939092300, 1939092706, , , , , , ARCHIVE, , AL041939
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1939, HU, O, 1939101112, 1939101818, , , , , , ARCHIVE, , AL051939
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1939, HU, O, 1939102812, 1939110700, , , , , , ARCHIVE, , AL061939
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1940, TS, O, 1940051912, 1940052706, , , , , , ARCHIVE, , AL011940
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1940, HU, O, 1940080312, 1940081018, , , , , , ARCHIVE, , AL021940
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1940, HU, O, 1940080518, 1940081418, , , , , , ARCHIVE, , AL031940
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1940, HU, O, 1940082612, 1940090318, , , , , , ARCHIVE, , AL041940
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1940, HU, O, 1940090718, 1940091918, , , , , , ARCHIVE, , AL051940
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1940, TS, O, 1940091812, 1940092506, , , , , , ARCHIVE, , AL061940
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1940, HU, O, 1940092200, 1940092812, , , , , , ARCHIVE, , AL071940
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1940, HU, O, 1940102000, 1940102412, , , , , , ARCHIVE, , AL081940
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1940, TS, O, 1940102418, 1940102918, , , , , , ARCHIVE, , AL091940
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1941, TS, O, 1941091100, 1941091606, , , , , , ARCHIVE, , AL011941
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1941, HU, O, 1941091712, 1941092700, , , , , , ARCHIVE, , AL021941
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1941, HU, O, 1941091800, 1941092518, , , , , , ARCHIVE, , AL031941
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1941, HU, O, 1941092318, 1941093018, , , , , , ARCHIVE, , AL041941
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1941, HU, O, 1941100318, 1941101318, , , , , , ARCHIVE, , AL051941
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1941, TS, O, 1941101506, 1941102206, , , , , , ARCHIVE, , AL061941
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1942, TS, O, 1942080300, 1942080518, , , , , , ARCHIVE, , AL011942
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1942, HU, O, 1942081712, 1942082312, , , , , , ARCHIVE, , AL021942
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1942, HU, O, 1942082312, 1942090112, , , , , , ARCHIVE, , AL031942
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1942, HU, O, 1942082506, 1942090318, , , , , , ARCHIVE, , AL041942
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1942, TS, O, 1942091518, 1942092312, , , , , , ARCHIVE, , AL051942
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1942, TS, O, 1942091812, 1942092500, , , , , , ARCHIVE, , AL061942
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1942, TS, O, 1942092706, 1942093006, , , , , , ARCHIVE, , AL071942
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1942, TS, O, 1942093012, 1942100518, , , , , , ARCHIVE, , AL081942
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1942, TS, O, 1942101006, 1942101300, , , , , , ARCHIVE, , AL091942
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1942, TS, O, 1942101312, 1942101818, , , , , , ARCHIVE, , AL101942
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1942, HU, O, 1942110500, 1942111118, , , , , , ARCHIVE, , AL111942   
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1943, HU, O, 1943072518, 1943073000, , , , , , ARCHIVE, , AL011943
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1943, TS, O, 1943081312, 1943081918, , , , , , ARCHIVE, , AL021943
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1943, HU, O, 1943081906, 1943082712, , , , , , ARCHIVE, , AL031943
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1943, HU, O, 1943090106, 1943091000, , , , , , ARCHIVE, , AL041943
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1943, TS, O, 1943091300, 1943091706, , , , , , ARCHIVE, , AL051943
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1943, HU, O, 1943091518, 1943092012, , , , , , ARCHIVE, , AL061943
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1943, TS, O, 1943092806, 1943100200, , , , , , ARCHIVE, , AL071943
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1943, TS, O, 1943100106, 1943100318, , , , , , ARCHIVE, , AL081943
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1943, HU, O, 1943101106, 1943101706, , , , , , ARCHIVE, , AL091943
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1943, TS, O, 1943102012, 1943102618, , , , , , ARCHIVE, , AL101943
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1944, HU, O, 1944071306, 1944072000, , , , , , ARCHIVE, , AL011944
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1944, TS, O, 1944072406, 1944072718, , , , , , ARCHIVE, , AL021944
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1944, HU, O, 1944073012, 1944080406, , , , , , ARCHIVE, , AL031944
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1944, HU, O, 1944081618, 1944082412, , , , , , ARCHIVE, , AL041944
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1944, TS, O, 1944081812, 1944082306, , , , , , ARCHIVE, , AL051944
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1944, TS, O, 1944090900, 1944091112, , , , , , ARCHIVE, , AL061944
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1944, HU, O, 1944090906, 1944091612, , , , , , ARCHIVE, , AL071944
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1944, HU, O, 1944091906, 1944092212, , , , , , ARCHIVE, , AL081944
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1944, HU, O, 1944092112, 1944092812, , , , , , ARCHIVE, , AL091944
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1944, TS, O, 1944093000, 1944100300, , , , , , ARCHIVE, , AL101944
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1944, TS, O, 1944093006, 1944100306, , , , , , ARCHIVE, , AL111944
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1944, HU, O, 1944101100, 1944101518, , , , , , ARCHIVE, , AL121944
   UNNAMED, AL, L,  ,  ,  ,  , 13, 1944, HU, O, 1944101212, 1944102412, , , , , , ARCHIVE, , AL131944
   UNNAMED, AL, L,  ,  ,  ,  , 14, 1944, TS, O, 1944110100, 1944110318, , , , , , ARCHIVE, , AL141944
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1945, HU, O, 1945062012, 1945070412, , , , , , ARCHIVE, , AL011945
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1945, TS, O, 1945071906, 1945072206, , , , , , ARCHIVE, , AL021945
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1945, TS, O, 1945080200, 1945080418, , , , , , ARCHIVE, , AL031945
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1945, TS, O, 1945081718, 1945082106, , , , , , ARCHIVE, , AL041945
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1945, HU, O, 1945082400, 1945082918, , , , , , ARCHIVE, , AL051945
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1945, TS, O, 1945082906, 1945090118, , , , , , ARCHIVE, , AL061945
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1945, TS, O, 1945090318, 1945090618, , , , , , ARCHIVE, , AL071945
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1945, TS, O, 1945090912, 1945091218, , , , , , ARCHIVE, , AL081945
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1945, HU, O, 1945091200, 1945092018, , , , , , ARCHIVE, , AL091945
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1945, HU, O, 1945100206, 1945100712, , , , , , ARCHIVE, , AL101945
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1945, HU, O, 1945101012, 1945101618, , , , , , ARCHIVE, , AL111945
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1946, TS, O, 1946061312, 1946061618, , , , , , ARCHIVE, , AL011946
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1946, HU, O, 1946070506, 1946071018, , , , , , ARCHIVE, , AL021946
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1946, TS, O, 1946082500, 1946082600, , , , , , ARCHIVE, , AL031946
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1946, HU, O, 1946091200, 1946091718, , , , , , ARCHIVE, , AL041946
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1946, TS, O, 1946100112, 1946100606, , , , , , ARCHIVE, , AL051946
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1946, HU, O, 1946100518, 1946101418, , , , , , ARCHIVE, , AL061946
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1946, TS, O, 1946103118, 1946110306, , , , , , ARCHIVE, , AL071946
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1947, TS, O, 1947073106, 1947080212, , , , , , ARCHIVE, , AL011947
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1947, HU, O, 1947080906, 1947081606, , , , , , ARCHIVE, , AL021947
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1947, HU, O, 1947081818, 1947082718, , , , , , ARCHIVE, , AL031947
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1947, HU, O, 1947090406, 1947092112, , , , , , ARCHIVE, , AL041947
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1947, TS, O, 1947090700, 1947090900, , , , , , ARCHIVE, , AL051947
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1947, TS, O, 1947092006, 1947092600, , , , , , ARCHIVE, , AL061947
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1947, TS, O, 1947100518, 1947100906, , , , , , ARCHIVE, , AL071947
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1947, TS, O, 1947100800, 1947101100, , , , , , ARCHIVE, , AL081947
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1947, HU, O, 1947100818, 1947101618, , , , , , ARCHIVE, , AL091947
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1947, HU, O, 1947101700, 1947102206, , , , , , ARCHIVE, , AL101947
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1948, TS, O, 1948052206, 1948052900, , , , , , ARCHIVE, , AL011948
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1948, TS, O, 1948070718, 1948071118, , , , , , ARCHIVE, , AL021948
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1948, HU, O, 1948082600, 1948090518, , , , , , ARCHIVE, , AL031948
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1948, TS, O, 1948083018, 1948090118, , , , , , ARCHIVE, , AL041948
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1948, HU, O, 1948090118, 1948090618, , , , , , ARCHIVE, , AL051948
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1948, HU, O, 1948090406, 1948091712, , , , , , ARCHIVE, , AL061948
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1948, TS, O, 1948091712, 1948091018, , , , , , ARCHIVE, , AL071948
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1948, HU, O, 1948091806, 1948092600, , , , , , ARCHIVE, , AL081948
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1948, HU, O, 1948100312, 1948101612, , , , , , ARCHIVE, , AL091948
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1948, HU, O, 1948110818, 1948111106, , , , , , ARCHIVE, , AL101948
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1949, HU, O, 1949082100, 1949083000, , , , , , ARCHIVE, , AL011949
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1949, HU, O, 1949082306, 1949090118, , , , , , ARCHIVE, , AL021949
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1949, TS, O, 1949083018, 1949090300, , , , , , ARCHIVE, , AL031949
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1949, HU, O, 1949090300, 1949091112, , , , , , ARCHIVE, , AL041949
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1949, TS, O, 1949090306, 1949090518, , , , , , ARCHIVE, , AL051949
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1949, TS, O, 1949090506, 1949091618, , , , , , ARCHIVE, , AL061949
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1949, TS, O, 1949091118, 1949091418, , , , , , ARCHIVE, , AL071949
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1949, TS, O, 1949091306, 1949091700, , , , , , ARCHIVE, , AL081949
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1949, HU, O, 1949092012, 1949092618, , , , , , ARCHIVE, , AL091949
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1949, HU, O, 1949092012, 1949092218, , , , , , ARCHIVE, , AL101949
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1949, HU, O, 1949092706, 1949100700, , , , , , ARCHIVE, , AL111949
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1949, TS, O, 1949100218, 1949100718, , , , , , ARCHIVE, , AL121949
   UNNAMED, AL, L,  ,  ,  ,  , 13, 1949, HU, O, 1949101306, 1949102118, , , , , , ARCHIVE, , AL131949
   UNNAMED, AL, L,  ,  ,  ,  , 14, 1949, TS, O, 1949101306, 1949101706, , , , , , ARCHIVE, , AL141949
   UNNAMED, AL, L,  ,  ,  ,  , 15, 1949, TS, O, 1949110112, 1949110600, , , , , , ARCHIVE, , AL151949
   UNNAMED, AL, L,  ,  ,  ,  , 16, 1949, TS, O, 1949110306, 1949110500, , , , , , ARCHIVE, , AL161949
   UNNAMED, EP, E,  ,  ,  ,  , 01, 1949, TS, O, 1949061100, 1949061212, , , , , , ARCHIVE, , EP011949
   UNNAMED, EP, E,  ,  ,  ,  , 02, 1949, TS, O, 1949061712, 1949062312, , , , , , ARCHIVE, , EP021949
   UNNAMED, EP, E,  ,  ,  ,  , 03, 1949, TS, O, 1949090312, 1949090912, , , , , , ARCHIVE, , EP031949
   UNNAMED, EP, E,  ,  ,  ,  , 04, 1949, HU, O, 1949090912, 1949091112, , , , , , ARCHIVE, , EP041949
   UNNAMED, EP, E,  ,  ,  ,  , 05, 1949, TS, O, 1949091712, 1949091912, , , , , , ARCHIVE, , EP051949
   UNNAMED, EP, E,  ,  ,  ,  , 06, 1949, HU, O, 1949092900, 1949093012, , , , , , ARCHIVE, , EP061949
      ABLE, AL, L,  ,  ,  ,  , 01, 1950, HU, O, 1950081200, 1950082406, , , , , , ARCHIVE, , AL011950
     BAKER, AL, L,  ,  ,  ,  , 02, 1950, HU, O, 1950081812, 1950090118, , , , , , ARCHIVE, , AL021950
   CHARLIE, AL, L,  ,  ,  ,  , 03, 1950, HU, O, 1950082112, 1950090512, , , , , , ARCHIVE, , AL031950
       DOG, AL, L,  ,  ,  ,  , 04, 1950, HU, O, 1950083018, 1950091800, , , , , , ARCHIVE, , AL041950
      EASY, AL, L,  ,  ,  ,  , 05, 1950, HU, O, 1950090106, 1950090918, , , , , , ARCHIVE, , AL051950
       FOX, AL, L,  ,  ,  ,  , 06, 1950, HU, O, 1950090806, 1950091706, , , , , , ARCHIVE, , AL061950
    GEORGE, AL, L,  ,  ,  ,  , 07, 1950, HU, O, 1950092706, 1950100712, , , , , , ARCHIVE, , AL071950
       HOW, AL, L,  ,  ,  ,  , 08, 1950, TS, O, 1950100106, 1950100418, , , , , , ARCHIVE, , AL081950
      ITEM, AL, L,  ,  ,  ,  , 09, 1950, HU, O, 1950100806, 1950101118, , , , , , ARCHIVE, , AL091950
       JIG, AL, L,  ,  ,  ,  , 10, 1950, HU, O, 1950101112, 1950101800, , , , , , ARCHIVE, , AL101950
      KING, AL, L,  ,  ,  ,  , 11, 1950, HU, O, 1950101306, 1950102006, , , , , , ARCHIVE, , AL111950
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1950, TS, O, 1950101706, 1950102418, , , , , , ARCHIVE, , AL121950
      LOVE, AL, L,  ,  ,  ,  , 13, 1950, HU, O, 1950101800, 1950102218, , , , , , ARCHIVE, , AL131950
      MIKE, AL, L,  ,  ,  ,  , 14, 1950, TS, O, 1950102512, 1950102818, , , , , , ARCHIVE, , AL141950
   UNNAMED, AL, L,  ,  ,  ,  , 15, 1950, TS, O, 1950102712, 1950102918, , , , , , ARCHIVE, , AL151950
   UNNAMED, AL, L,  ,  ,  ,  , 16, 1950, TS, O, 1950111000, 1950111206, , , , , , ARCHIVE, , AL161950
  ABLE_NEW, AL, L, , , , , 80, 1950, TS, O, 1950081200, 9999999999, , , , , , METWATCH, , AL801950
      HIKI, CP, C,  ,  ,  ,  , 01, 1950, HU, O, 1950081200, 1950082112, , , , , , ARCHIVE, , CP011950
   UNNAMED, EP, E,  ,  ,  ,  , 01, 1950, HU, O, 1950061412, 1950061912, , , , , , ARCHIVE, , EP011950
   UNNAMED, EP, E,  ,  ,  ,  , 02, 1950, HU, O, 1950070312, 1950070612, , , , , , ARCHIVE, , EP021950
   UNNAMED, EP, E,  ,  ,  ,  , 03, 1950, HU, O, 1950070912, 1950071212, , , , , , ARCHIVE, , EP031950
   UNNAMED, EP, E,  ,  ,  ,  , 04, 1950, TS, O, 1950081212, 1950081312, , , , , , ARCHIVE, , EP041950
   UNNAMED, EP, E, C,  ,  ,  , 05, 1950, HU, O, 1950082612, 1950083012, , , , , , ARCHIVE, , EP051950
   UNNAMED, EP, E,  ,  ,  ,  , 06, 1950, HU, O, 1950100112, 1950100312, , , , , , ARCHIVE, , EP061950
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1951, TS, O, 1951010212, 1951011212, , , , , , ARCHIVE, , AL011951
      ABLE, AL, L,  ,  ,  ,  , 02, 1951, HU, O, 1951051500, 1951052418, , , , , , ARCHIVE, , AL021951
     BAKER, AL, L,  ,  ,  ,  , 03, 1951, TS, O, 1951080206, 1951080518, , , , , , ARCHIVE, , AL031951
   CHARLIE, AL, L,  ,  ,  ,  , 04, 1951, HU, O, 1951081200, 1951082318, , , , , , ARCHIVE, , AL041951
       DOG, AL, L,  ,  ,  ,  , 05, 1951, HU, O, 1951082706, 1951090512, , , , , , ARCHIVE, , AL051951
      EASY, AL, L,  ,  ,  ,  , 06, 1951, HU, O, 1951090106, 1951091418, , , , , , ARCHIVE, , AL061951
       FOX, AL, L,  ,  ,  ,  , 07, 1951, HU, O, 1951090218, 1951091106, , , , , , ARCHIVE, , AL071951
    GEORGE, AL, L,  ,  ,  ,  , 08, 1951, TS, O, 1951091918, 1951092200, , , , , , ARCHIVE, , AL081951
       HOW, AL, L,  ,  ,  ,  , 09, 1951, HU, O, 1951092900, 1951101118, , , , , , ARCHIVE, , AL091951
      ITEM, AL, L,  ,  ,  ,  , 10, 1951, TS, O, 1951101206, 1951101718, , , , , , ARCHIVE, , AL101951
       JIG, AL, L,  ,  ,  ,  , 11, 1951, HU, O, 1951101506, 1951102000, , , , , , ARCHIVE, , AL111951
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1951, HU, O, 1951120312, 1951121206, , , , , , ARCHIVE, , AL121951
   UNNAMED, EP, E,  ,  ,  ,  , 01, 1951, TS, O, 1951051712, 1951052100, , , , , , ARCHIVE, , EP011951
   UNNAMED, EP, E,  ,  ,  ,  , 02, 1951, HU, O, 1951060100, 1951060200, , , , , , ARCHIVE, , EP021951
   UNNAMED, EP, E,  ,  ,  ,  , 03, 1951, TS, O, 1951062612, 1951062712, , , , , , ARCHIVE, , EP031951
   UNNAMED, EP, E,  ,  ,  ,  , 04, 1951, TS, O, 1951070512, 1951070612, , , , , , ARCHIVE, , EP041951
   UNNAMED, EP, E,  ,  ,  ,  , 05, 1951, TS, O, 1951080312, 1951081012, , , , , , ARCHIVE, , EP051951
   UNNAMED, EP, E,  ,  ,  ,  , 06, 1951, TS, O, 1951082412, 1951082912, , , , , , ARCHIVE, , EP061951
   UNNAMED, EP, E,  ,  ,  ,  , 07, 1951, TS, O, 1951091112, 1951091512, , , , , , ARCHIVE, , EP071951
   UNNAMED, EP, E,  ,  ,  ,  , 08, 1951, HU, O, 1951092312, 1951092812, , , , , , ARCHIVE, , EP081951
   UNNAMED, EP, E,  ,  ,  ,  , 09, 1951, TS, O, 1951112712, 1951113012, , , , , , ARCHIVE, , EP091951
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1952, TS, O, 1952020206, 1952020506, , , , , , ARCHIVE, , AL011952
      ABLE, AL, L,  ,  ,  ,  , 02, 1952, HU, O, 1952081806, 1952090306, , , , , , ARCHIVE, , AL021952
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1952, TS, O, 1952082718, 1952082818, , , , , , ARCHIVE, , AL031952
     BAKER, AL, L,  ,  ,  ,  , 04, 1952, HU, O, 1952083106, 1952091000, , , , , , ARCHIVE, , AL041952
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1952, TS, O, 1952090800, 1952091412, , , , , , ARCHIVE, , AL051952
   CHARLIE, AL, L,  ,  ,  ,  , 06, 1952, HU, O, 1952092400, 1952100100, , , , , , ARCHIVE, , AL061952
       DOG, AL, L,  ,  ,  ,  , 07, 1952, TS, O, 1952092412, 1952093018, , , , , , ARCHIVE, , AL071952
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1952, TS, O, 1952092512, 1952093012, , , , , , ARCHIVE, , AL081952
      EASY, AL, L,  ,  ,  ,  , 09, 1952, HU, O, 1952100612, 1952101112, , , , , , ARCHIVE, , AL091952
       FOX, AL, L,  ,  ,  ,  , 10, 1952, HU, O, 1952102012, 1952102812, , , , , , ARCHIVE, , AL101952
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1952, HU, O, 1952112418, 1952113018, , , , , , ARCHIVE, , AL111952
   UNNAMED, EP, E,  ,  ,  ,  , 01, 1952, TS, O, 1952052912, 1952053112, , , , , , ARCHIVE, , EP011952
   UNNAMED, EP, E,  ,  ,  ,  , 02, 1952, TS, O, 1952061212, 1952061612, , , , , , ARCHIVE, , EP021952
   UNNAMED, EP, E,  ,  ,  ,  , 03, 1952, TS, O, 1952071900, 1952072100, , , , , , ARCHIVE, , EP031952
   UNNAMED, EP, E,  ,  ,  ,  , 04, 1952, HU, O, 1952072400, 1952072700, , , , , , ARCHIVE, , EP041952
   UNNAMED, EP, E,  ,  ,  ,  , 05, 1952, HU, O, 1952091512, 1952092212, , , , , , ARCHIVE, , EP051952
   UNNAMED, EP, E,  ,  ,  ,  , 06, 1952, TS, O, 1952092612, 1952092812, , , , , , ARCHIVE, , EP061952
   UNNAMED, EP, E,  ,  ,  ,  , 07, 1952, HU, O, 1952101312, 1952101512, , , , , , ARCHIVE, , EP071952
     ALICE, AL, L,  ,  ,  ,  , 01, 1953, TS, O, 1953052518, 1953060706, , , , , , ARCHIVE, , AL011953
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1953, TS, O, 1953071118, 1953071600, , , , , , ARCHIVE, , AL021953
   BARBARA, AL, L,  ,  ,  ,  , 03, 1953, HU, O, 1953081106, 1953081618, , , , , , ARCHIVE, , AL031953
     CAROL, AL, L,  ,  ,  ,  , 04, 1953, HU, O, 1953082806, 1953090912, , , , , , ARCHIVE, , AL041953
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1953, TS, O, 1953082918, 1953090118, , , , , , ARCHIVE, , AL051953
     DOLLY, AL, L,  ,  ,  ,  , 06, 1953, HU, O, 1953090806, 1953091612, , , , , , ARCHIVE, , AL061953
      EDNA, AL, L,  ,  ,  ,  , 07, 1953, HU, O, 1953091500, 1953092118, , , , , , ARCHIVE, , AL071953
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1953, TS, O, 1953091518, 1953092100, , , , , , ARCHIVE, , AL081953
  FLORENCE, AL, L,  ,  ,  ,  , 09, 1953, HU, O, 1953092312, 1953092718, , , , , , ARCHIVE, , AL091953
      GAIL, AL, L,  ,  ,  ,  , 10, 1953, HU, O, 1953100206, 1953101206, , , , , , ARCHIVE, , AL101953
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1953, TS, O, 1953100318, 1953100806, , , , , , ARCHIVE, , AL111953
     HAZEL, AL, L,  ,  ,  ,  , 12, 1953, HU, O, 1953100706, 1953101612, , , , , , ARCHIVE, , AL121953
   UNNAMED, AL, L,  ,  ,  ,  , 13, 1953, TS, O, 1953112306, 1953112618, , , , , , ARCHIVE, , AL131953
   UNNAMED, AL, L,  ,  ,  ,  , 14, 1953, TS, O, 1953120718, 1953120918, , , , , , ARCHIVE, , AL141953
   UNNAMED, EP, E,  ,  ,  ,  , 01, 1953, TS, O, 1953082500, 1953082700, , , , , , ARCHIVE, , EP011953
   UNNAMED, EP, E,  ,  ,  ,  , 02, 1953, TS, O, 1953090912, 1953091012, , , , , , ARCHIVE, , EP021953
   UNNAMED, EP, E,  ,  ,  ,  , 03, 1953, HU, O, 1953091400, 1953091700, , , , , , ARCHIVE, , EP031953
   UNNAMED, EP, E,  ,  ,  ,  , 04, 1953, HU, O, 1953100200, 1953100800, , , , , , ARCHIVE, , EP041953
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1954, TS, O, 1954052812, 1954053118, , , , , , ARCHIVE, , AL011954
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1954, TS, O, 1954061800, 1954062500, , , , , , ARCHIVE, , AL021954
     ALICE, AL, L,  ,  ,  ,  , 03, 1954, HU, O, 1954062412, 1954062706, , , , , , ARCHIVE, , AL031954
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1954, TS, O, 1954071012, 1954071400, , , , , , ARCHIVE, , AL041954
   BARBARA, AL, L,  ,  ,  ,  , 05, 1954, TS, O, 1954072712, 1954073012, , , , , , ARCHIVE, , AL051954
     CAROL, AL, L,  ,  ,  ,  , 06, 1954, HU, O, 1954082512, 1954090106, , , , , , ARCHIVE, , AL061954
     DOLLY, AL, L,  ,  ,  ,  , 07, 1954, HU, O, 1954083112, 1954090418, , , , , , ARCHIVE, , AL071954
      EDNA, AL, L,  ,  ,  ,  , 08, 1954, HU, O, 1954090500, 1954091406, , , , , , ARCHIVE, , AL081954
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1954, TS, O, 1954090606, 1954090800, , , , , , ARCHIVE, , AL091954
  FLORENCE, AL, L,  ,  ,  ,  , 10, 1954, TS, O, 1954091012, 1954091218, , , , , , ARCHIVE, , AL101954
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1954, TS, O, 1954091512, 1954091800, , , , , , ARCHIVE, , AL111954
     GILDA, AL, L,  ,  ,  ,  , 12, 1954, TS, O, 1954092418, 1954093006, , , , , , ARCHIVE, , AL121954
   UNNAMED, AL, L,  ,  ,  ,  , 13, 1954, HU, O, 1954092506, 1954100700, , , , , , ARCHIVE, , AL131954
     HAZEL, AL, L,  ,  ,  ,  , 14, 1954, HU, O, 1954100506, 1954101806, , , , , , ARCHIVE, , AL141954
   UNNAMED, AL, L,  ,  ,  ,  , 15, 1954, TS, O, 1954111618, 1954112118, , , , , , ARCHIVE, , AL151954
     ALICE, AL, L,  ,  ,  ,  , 16, 1954, HU, O, 1954123006, 1955010600, , , , , , ARCHIVE, , AL161954
   UNNAMED, EP, E,  ,  ,  ,  , 01, 1954, TS, O, 1954061800, 1954062212, , , , , , ARCHIVE, , EP011954
   UNNAMED, EP, E,  ,  ,  ,  , 02, 1954, TS, O, 1954071000, 1954071600, , , , , , ARCHIVE, , EP021954
   UNNAMED, EP, E,  ,  ,  ,  , 03, 1954, HU, O, 1954071200, 1954071712, , , , , , ARCHIVE, , EP031954
   UNNAMED, EP, E,  ,  ,  ,  , 04, 1954, HU, O, 1954072500, 1954080112, , , , , , ARCHIVE, , EP041954
   UNNAMED, EP, E, C,  ,  ,  , 05, 1954, TS, O, 1954090200, 1954090900, , , , , , ARCHIVE, , EP051954
   UNNAMED, EP, E,  ,  ,  ,  , 06, 1954, TS, O, 1954090500, 1954090812, , , , , , ARCHIVE, , EP061954
   UNNAMED, EP, E,  ,  ,  ,  , 07, 1954, TS, O, 1954091512, 1954092112, , , , , , ARCHIVE, , EP071954
   UNNAMED, EP, E,  ,  ,  ,  , 08, 1954, TS, O, 1954092100, 1954092712, , , , , , ARCHIVE, , EP081954
   UNNAMED, EP, E,  ,  ,  ,  , 09, 1954, HU, O, 1954092700, 1954100100, , , , , , ARCHIVE, , EP091954
   UNNAMED, EP, E,  ,  ,  ,  , 10, 1954, TS, O, 1954101206, 1954101412, , , , , , ARCHIVE, , EP101954
   UNNAMED, EP, E,  ,  ,  ,  , 11, 1954, HU, O, 1954102612, 1954110112, , , , , , ARCHIVE, , EP111954
    BRENDA, AL, L,  ,  ,  ,  , 01, 1955, TS, O, 1955073106, 1955080306, , , , , , ARCHIVE, , AL011955
    CONNIE, AL, L,  ,  ,  ,  , 02, 1955, HU, O, 1955080306, 1955081500, , , , , , ARCHIVE, , AL021955
     DIANE, AL, L,  ,  ,  ,  , 03, 1955, HU, O, 1955080706, 1955082318, , , , , , ARCHIVE, , AL031955
     EDITH, AL, L,  ,  ,  ,  , 04, 1955, HU, O, 1955082112, 1955090506, , , , , , ARCHIVE, , AL041955
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1955, TS, O, 1955082518, 1955082818, , , , , , ARCHIVE, , AL051955
     FLORA, AL, L,  ,  ,  ,  , 06, 1955, HU, O, 1955090206, 1955090918, , , , , , ARCHIVE, , AL061955
    GLADYS, AL, L,  ,  ,  ,  , 07, 1955, HU, O, 1955090318, 1955090618, , , , , , ARCHIVE, , AL071955
      IONE, AL, L,  ,  ,  ,  , 08, 1955, HU, O, 1955091006, 1955092700, , , , , , ARCHIVE, , AL081955
     HILDA, AL, L,  ,  ,  ,  , 09, 1955, HU, O, 1955091200, 1955092006, , , , , , ARCHIVE, , AL091955
     JANET, AL, L,  ,  ,  ,  , 10, 1955, HU, O, 1955092112, 1955093012, , , , , , ARCHIVE, , AL101955
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1955, TS, O, 1955092312, 1955092818, , , , , , ARCHIVE, , AL111955
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1955, TS, O, 1955101006, 1955101412, , , , , , ARCHIVE, , AL121955
     KATIE, AL, L,  ,  ,  ,  , 13, 1955, HU, O, 1955101418, 1955101906, , , , , , ARCHIVE, , AL131955
   UNNAMED, EP, E,  ,  ,  ,  , 01, 1955, HU, O, 1955060600, 1955060812, , , , , , ARCHIVE, , EP011955
   UNNAMED, EP, E,  ,  ,  ,  , 02, 1955, TS, O, 1955060800, 1955061100, , , , , , ARCHIVE, , EP021955
   UNNAMED, EP, E,  ,  ,  ,  , 03, 1955, TS, O, 1955070612, 1955070900, , , , , , ARCHIVE, , EP031955
   UNNAMED, EP, E,  ,  ,  ,  , 04, 1955, TS, O, 1955090100, 1955090500, , , , , , ARCHIVE, , EP041955
   UNNAMED, EP, E,  ,  ,  ,  , 05, 1955, TS, O, 1955100100, 1955100400, , , , , , ARCHIVE, , EP051955
   UNNAMED, EP, E,  ,  ,  ,  , 06, 1955, HU, O, 1955101518, 1955101618, , , , , , ARCHIVE, , EP061955
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1956, TS, O, 1956061200, 1956061506, , , , , , ARCHIVE, , AL011956
      ANNA, AL, L,  ,  ,  ,  , 02, 1956, HU, O, 1956072518, 1956072712, , , , , , ARCHIVE, , AL021956
     BETSY, AL, L,  ,  ,  ,  , 03, 1956, HU, O, 1956080906, 1956082112, , , , , , ARCHIVE, , AL031956
     CARLA, AL, L,  ,  ,  ,  , 04, 1956, TS, O, 1956090700, 1956091606, , , , , , ARCHIVE, , AL041956
      DORA, AL, L,  ,  ,  ,  , 05, 1956, TS, O, 1956091006, 1956091300, , , , , , ARCHIVE, , AL051956
     ETHEL, AL, L,  ,  ,  ,  , 06, 1956, TS, O, 1956091118, 1956091406, , , , , , ARCHIVE, , AL061956
    FLOSSY, AL, L,  ,  ,  ,  , 07, 1956, HU, O, 1956092018, 1956100306, , , , , , ARCHIVE, , AL071956
     GRETA, AL, L,  ,  ,  ,  , 08, 1956, HU, O, 1956103100, 1956110706, , , , , , ARCHIVE, , AL081956
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1956, TS, O, 1956060706, 1956061012, , , , , , ARCHIVE, , AL091956
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1956, TS, O, 1956100906, 1956101200, , , , , , ARCHIVE, , AL101956
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1956, TS, O, 1956101412, 1956101900, , , , , , ARCHIVE, , AL111956
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1956, TS, O, 1956111900, 1956112112, , , , , , ARCHIVE, , AL121956
   UNNAMED, EP, E,  ,  ,  ,  , 01, 1956, HU, O, 1956051812, 1956051912, , , , , , ARCHIVE, , EP011956
   UNNAMED, EP, E,  ,  ,  ,  , 02, 1956, TS, O, 1956053000, 1956060312, , , , , , ARCHIVE, , EP021956
   UNNAMED, EP, E,  ,  ,  ,  , 03, 1956, HU, O, 1956060906, 1956061018, , , , , , ARCHIVE, , EP031956
   UNNAMED, EP, E,  ,  ,  ,  , 04, 1956, HU, O, 1956061212, 1956061400, , , , , , ARCHIVE, , EP041956
   UNNAMED, EP, E,  ,  ,  ,  , 05, 1956, HU, O, 1956070900, 1956071200, , , , , , ARCHIVE, , EP051956
   UNNAMED, EP, E,  ,  ,  ,  , 06, 1956, TS, O, 1956071412, 1956071612, , , , , , ARCHIVE, , EP061956
   UNNAMED, EP, E,  ,  ,  ,  , 07, 1956, TS, O, 1956082212, 1956082512, , , , , , ARCHIVE, , EP071956
   UNNAMED, EP, E,  ,  ,  ,  , 08, 1956, TS, O, 1956090300, 1956090318, , , , , , ARCHIVE, , EP081956
   UNNAMED, EP, E,  ,  ,  ,  , 09, 1956, HU, O, 1956090400, 1956090612, , , , , , ARCHIVE, , EP091956
   UNNAMED, EP, E,  ,  ,  ,  , 10, 1956, TS, O, 1956091212, 1956091700, , , , , , ARCHIVE, , EP101956
   UNNAMED, EP, E,  ,  ,  ,  , 11, 1956, TS, O, 1956101612, 1956101800, , , , , , ARCHIVE, , EP111956
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1957, TS, O, 1957060806, 1957061518, , , , , , ARCHIVE, , AL011957
    AUDREY, AL, L,  ,  ,  ,  , 02, 1957, HU, O, 1957062412, 1957062900, , , , , , ARCHIVE, , AL021957
    BERTHA, AL, L,  ,  ,  ,  , 03, 1957, TS, O, 1957080800, 1957081106, , , , , , ARCHIVE, , AL031957
    CARRIE, AL, L,  ,  ,  ,  , 04, 1957, HU, O, 1957090206, 1957092518, , , , , , ARCHIVE, , AL041957
    DEBBIE, AL, L,  ,  ,  ,  , 05, 1957, TS, O, 1957090706, 1957090906, , , , , , ARCHIVE, , AL051957
    ESTHER, AL, L,  ,  ,  ,  , 06, 1957, TS, O, 1957091600, 1957091912, , , , , , ARCHIVE, , AL061957
    FRIEDA, AL, L,  ,  ,  ,  , 07, 1957, HU, O, 1957092012, 1957092712, , , , , , ARCHIVE, , AL071957
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1957, TS, O, 1957102300, 1957102718, , , , , , ARCHIVE, , AL081957
     DELLA, CP, C, W,  ,  ,  , 01, 1957, HU, O, 1957090100, 1957091218, , , , , , ARCHIVE, , CP011957
   UNNAMED, CP, C,  ,  ,  ,  , 02, 1957, TS, O, 1957092500, 1957092800, , , , , , ARCHIVE, , CP021957
      NINA, CP, C,  ,  ,  ,  , 03, 1957, HU, O, 1957112900, 1957120612, , , , , , ARCHIVE, , CP031957
     KANOA, EP, E, C,  ,  ,  , 01, 1957, HU, O, 1957071500, 1957072600, , , , , , ARCHIVE, , EP011957
   UNNAMED, EP, E, C,  ,  ,  , 02, 1957, HU, O, 1957080600, 1957081600, , , , , , ARCHIVE, , EP021957
   UNNAMED, EP, E,  ,  ,  ,  , 03, 1957, HU, O, 1957080900, 1957081512, , , , , , ARCHIVE, , EP031957
   UNNAMED, EP, E, C,  ,  ,  , 04, 1957, TS, O, 1957090900, 1957091106, , , , , , ARCHIVE, , EP041957
   UNNAMED, EP, E,  ,  ,  ,  , 05, 1957, HU, O, 1957091700, 1957091818, , , , , , ARCHIVE, , EP051957
   UNNAMED, EP, E,  ,  ,  ,  , 06, 1957, TS, O, 1957092012, 1957092300, , , , , , ARCHIVE, , EP061957
   UNNAMED, EP, E,  ,  ,  ,  , 07, 1957, TS, O, 1957092618, 1957092712, , , , , , ARCHIVE, , EP071957
   UNNAMED, EP, E,  ,  ,  ,  , 08, 1957, HU, O, 1957100112, 1957100612, , , , , , ARCHIVE, , EP081957
   UNNAMED, EP, E,  ,  ,  ,  , 09, 1957, HU, O, 1957101712, 1957102000, , , , , , ARCHIVE, , EP091957
   UNNAMED, EP, E,  ,  ,  ,  , 10, 1957, HU, O, 1957102010, 1957102212, , , , , , ARCHIVE, , EP101957
      ALMA, AL, L,  ,  ,  ,  , 01, 1958, TS, O, 1958061406, 1958061606, , , , , , ARCHIVE, , AL011958
     BECKY, AL, L,  ,  ,  ,  , 02, 1958, TS, O, 1958080812, 1958081712, , , , , , ARCHIVE, , AL021958
      CLEO, AL, L,  ,  ,  ,  , 03, 1958, HU, O, 1958081106, 1958082218, , , , , , ARCHIVE, , AL031958
     DAISY, AL, L,  ,  ,  ,  , 04, 1958, HU, O, 1958082318, 1958083100, , , , , , ARCHIVE, , AL041958
      ELLA, AL, L,  ,  ,  ,  , 05, 1958, HU, O, 1958083006, 1958090700, , , , , , ARCHIVE, , AL051958
      FIFI, AL, L,  ,  ,  ,  , 06, 1958, HU, O, 1958090412, 1958091118, , , , , , ARCHIVE, , AL061958
     GERDA, AL, L,  ,  ,  ,  , 07, 1958, TS, O, 1958091406, 1958092200, , , , , , ARCHIVE, , AL071958
    HELENE, AL, L,  ,  ,  ,  , 08, 1958, HU, O, 1958092106, 1958100406, , , , , , ARCHIVE, , AL081958
      ILSA, AL, L,  ,  ,  ,  , 09, 1958, HU, O, 1958092406, 1958093006, , , , , , ARCHIVE, , AL091958
    JANICE, AL, L,  ,  ,  ,  , 10, 1958, HU, O, 1958100412, 1958101300, , , , , , ARCHIVE, , AL101958
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1958, TS, O, 1958052500, 1958052906, , , , , , ARCHIVE, , AL111958
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1958, TS, O, 1958101518, 1958101818, , , , , , ARCHIVE, , AL121958
   UNNAMED, CP, C,  ,  ,  ,  , 01, 1958, TS, O, 1958080700, 1958080900, , , , , , ARCHIVE, , CP011958
   UNNAMED, EP, E,  ,  ,  ,  , 01, 1958, HU, O, 1958060600, 1958061600, , , , , , ARCHIVE, , EP011958
   UNNAMED, EP, E,  ,  ,  ,  , 02, 1958, TS, O, 1958061300, 1958061500, , , , , , ARCHIVE, , EP021958
   UNNAMED, EP, E,  ,  ,  ,  , 03, 1958, HU, O, 1958071900, 1958072112, , , , , , ARCHIVE, , EP031958
   UNNAMED, EP, E,  ,  ,  ,  , 04, 1958, HU, O, 1958072112, 1958072512, , , , , , ARCHIVE, , EP041958
   UNNAMED, EP, E,  ,  ,  ,  , 05, 1958, TS, O, 1958072612, 1958073000, , , , , , ARCHIVE, , EP051958
   UNNAMED, EP, E,  ,  ,  ,  , 06, 1958, TS, O, 1958073112, 1958080112, , , , , , ARCHIVE, , EP061958
   UNNAMED, EP, E,  ,  ,  ,  , 07, 1958, TS, O, 1958081300, 1958081412, , , , , , ARCHIVE, , EP071958
   UNNAMED, EP, E,  ,  ,  ,  , 08, 1958, HU, O, 1958090612, 1958091300, , , , , , ARCHIVE, , EP081958
   UNNAMED, EP, E,  ,  ,  ,  , 09, 1958, TS, O, 1958091100, 1958091212, , , , , , ARCHIVE, , EP091958
   UNNAMED, EP, E,  ,  ,  ,  , 10, 1958, HU, O, 1958093000, 1958100612, , , , , , ARCHIVE, , EP101958
   UNNAMED, EP, E,  ,  ,  ,  , 11, 1958, TS, O, 1958101411, 1958101700, , , , , , ARCHIVE, , EP111958
   UNNAMED, EP, E,  ,  ,  ,  , 12, 1958, TS, O, 1958102900, 1958103006, , , , , , ARCHIVE, , EP121958
    ARLENE, AL, L,  ,  ,  ,  , 01, 1959, TS, O, 1959052806, 1959060218, , , , , , ARCHIVE, , AL011959
    BEULAH, AL, L,  ,  ,  ,  , 02, 1959, TS, O, 1959061518, 1959061906, , , , , , ARCHIVE, , AL021959
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1959, HU, O, 1959061800, 1959062212, , , , , , ARCHIVE, , AL031959
     CINDY, AL, L,  ,  ,  ,  , 04, 1959, HU, O, 1959070412, 1959071218, , , , , , ARCHIVE, , AL041959
     DEBRA, AL, L,  ,  ,  ,  , 05, 1959, HU, O, 1959072218, 1959072718, , , , , , ARCHIVE, , AL051959
     EDITH, AL, L,  ,  ,  ,  , 06, 1959, TS, O, 1959081800, 1959081900, , , , , , ARCHIVE, , AL061959
     FLORA, AL, L,  ,  ,  ,  , 07, 1959, HU, O, 1959090906, 1959091300, , , , , , ARCHIVE, , AL071959
    GRACIE, AL, L,  ,  ,  ,  , 08, 1959, HU, O, 1959092012, 1959100212, , , , , , ARCHIVE, , AL081959
    HANNAH, AL, L,  ,  ,  ,  , 09, 1959, HU, O, 1959092712, 1959100818, , , , , , ARCHIVE, , AL091959
     IRENE, AL, L,  ,  ,  ,  , 10, 1959, TS, O, 1959100618, 1959100912, , , , , , ARCHIVE, , AL101959
    JUDITH, AL, L,  ,  ,  ,  , 11, 1959, HU, O, 1959101406, 1959102206, , , , , , ARCHIVE, , AL111959
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1959, TS, O, 1959080200, 1959080618, , , , , , ARCHIVE, , AL121959
   UNNAMED, AL, L,  ,  ,  ,  , 13, 1959, TS, O, 1959082806, 1959090412, , , , , , ARCHIVE, , AL131959
   UNNAMED, AL, L,  ,  ,  ,  , 14, 1959, TS, O, 1959090900, 1959091400, , , , , , ARCHIVE, , AL141959
       DOT, CP, C,  ,  ,  ,  , 01, 1959, HU, O, 1959080118, 1959080806, , , , , , ARCHIVE, , CP011959
     PATSY, CP, C, W, C, W,  , 02, 1959, HU, O, 1959090606, 1959091012, , , , , , ARCHIVE, , CP021959
     WANDA, CP, C,  ,  ,  ,  , 03, 1959, TS, O, 1959092600, 1959092712, , , , , , ARCHIVE, , CP031959
   UNNAMED, EP, E,  ,  ,  ,  , 01, 1959, TS, O, 1959061000, 1959061212, , , , , , ARCHIVE, , EP011959
   UNNAMED, EP, E,  ,  ,  ,  , 02, 1959, TS, O, 1959062600, 1959062800, , , , , , ARCHIVE, , EP021959
   UNNAMED, EP, E,  ,  ,  ,  , 03, 1959, TS, O, 1959071600, 1959072200, , , , , , ARCHIVE, , EP031959
   UNNAMED, EP, E,  ,  ,  ,  , 04, 1959, TS, O, 1959072200, 1959072512, , , , , , ARCHIVE, , EP041959
   UNNAMED, EP, E,  ,  ,  ,  , 05, 1959, TS, O, 1959072900, 1959073000, , , , , , ARCHIVE, , EP051959
   UNNAMED, EP, E,  ,  ,  ,  , 06, 1959, TS, O, 1959080412, 1959080600, , , , , , ARCHIVE, , EP061959
   UNNAMED, EP, E,  ,  ,  ,  , 07, 1959, TS, O, 1959081918, 1959082112, , , , , , ARCHIVE, , EP071959
   UNNAMED, EP, E,  ,  ,  ,  , 08, 1959, TS, O, 1959082700, 1959082900, , , , , , ARCHIVE, , EP081959
   UNNAMED, EP, E,  ,  ,  ,  , 09, 1959, HU, O, 1959090400, 1959091112, , , , , , ARCHIVE, , EP091959
   UNNAMED, EP, E,  ,  ,  ,  , 10, 1959, HU, O, 1959092110, 1959092600, , , , , , ARCHIVE, , EP101959
   UNNAMED, EP, E,  ,  ,  ,  , 11, 1959, TS, O, 1959101900, 1959102100, , , , , , ARCHIVE, , EP111959
   UNNAMED, EP, E,  ,  ,  ,  , 12, 1959, HU, O, 1959102300, 1959102912, , , , , , ARCHIVE, , EP121959
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1960, TS, O, 1960062206, 1960062812, , , , , , ARCHIVE, , AL011960
      ABBY, AL, L,  ,  ,  ,  , 02, 1960, HU, O, 1960070912, 1960071712, , , , , , ARCHIVE, , AL021960
    BRENDA, AL, L,  ,  ,  ,  , 03, 1960, TS, O, 1960072718, 1960080718, , , , , , ARCHIVE, , AL031960
      CLEO, AL, L,  ,  ,  ,  , 04, 1960, HU, O, 1960081718, 1960082100, , , , , , ARCHIVE, , AL041960
     DONNA, AL, L,  ,  ,  ,  , 05, 1960, HU, O, 1960082918, 1960091412, , , , , , ARCHIVE, , AL051960
     ETHEL, AL, L,  ,  ,  ,  , 06, 1960, HU, O, 1960091218, 1960091718, , , , , , ARCHIVE, , AL061960
  FLORENCE, AL, L,  ,  ,  ,  , 07, 1960, TS, O, 1960091706, 1960092618, , , , , , ARCHIVE, , AL071960
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1960, TS, O, 1960090100, 1960090300, , , , , , ARCHIVE, , AL081960
   ANNETTE, EP, E,  ,  ,  ,  , 01, 1960, TS, O, 1960060900, 1960061212, , , , , , ARCHIVE, , EP011960
     BONNY, EP, E,  ,  ,  ,  , 02, 1960, TS, O, 1960062200, 1960062600, , , , , , ARCHIVE, , EP021960
   CELESTE, EP, E,  ,  ,  ,  , 03, 1960, HU, O, 1960072000, 1960072218, , , , , , ARCHIVE, , EP031960
     DIANA, EP, E,  ,  ,  ,  , 04, 1960, HU, O, 1960081700, 1960082012, , , , , , ARCHIVE, , EP041960
   ESTELLE, EP, E,  ,  ,  ,  , 05, 1960, HU, O, 1960082900, 1960090912, , , , , , ARCHIVE, , EP051960
  FERNANDA, EP, E,  ,  ,  ,  , 06, 1960, HU, O, 1960090300, 1960090812, , , , , , ARCHIVE, , EP061960
  HYACINTH, EP, E,  ,  ,  ,  , 07, 1960, HU, O, 1960102112, 1960102312, , , , , , ARCHIVE, , EP071960
      ANNA, AL, L,  ,  ,  ,  , 01, 1961, HU, O, 1961071718, 1961072500, , , , , , ARCHIVE, , AL011961
     BETSY, AL, L,  ,  ,  ,  , 02, 1961, HU, O, 1961090206, 1961091612, , , , , , ARCHIVE, , AL021961
     CARLA, AL, L,  ,  ,  ,  , 03, 1961, HU, O, 1961090312, 1961091800, , , , , , ARCHIVE, , AL031961
    DEBBIE, AL, L,  ,  ,  ,  , 04, 1961, HU, O, 1961090512, 1961091818, , , , , , ARCHIVE, , AL041961
    ESTHER, AL, L,  ,  ,  ,  , 05, 1961, HU, O, 1961091012, 1961092706, , , , , , ARCHIVE, , AL051961
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1961, TS, O, 1961091212, 1961091512, , , , , , ARCHIVE, , AL061961
   FRANCES, AL, L,  ,  ,  ,  , 07, 1961, HU, O, 1961093006, 1961101006, , , , , , ARCHIVE, , AL071961
     GERDA, AL, L,  ,  ,  ,  , 08, 1961, TS, O, 1961101700, 1961102212, , , , , , ARCHIVE, , AL081961
    HATTIE, AL, L,  ,  ,  ,  , 09, 1961, HU, O, 1961102600, 1961110106, , , , , , ARCHIVE, , AL091961
     JENNY, AL, L,  ,  ,  ,  , 10, 1961, HU, O, 1961110200, 1961111106, , , , , , ARCHIVE, , AL101961
      INGA, AL, L,  ,  ,  ,  , 11, 1961, TS, O, 1961110400, 1961110812, , , , , , ARCHIVE, , AL111961
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1961, TS, O, 1961111718, 1961112106, , , , , , ARCHIVE, , AL121961
       IVA, EP, E,  ,  ,  ,  , 01, 1961, HU, O, 1961060912, 1961061200, , , , , , ARCHIVE, , EP011961
    JOANNE, EP, E,  ,  ,  ,  , 02, 1961, TS, O, 1961071012, 1961071212, , , , , , ARCHIVE, , EP021961
  KATHLEEN, EP, E,  ,  ,  ,  , 03, 1961, TS, O, 1961071412, 1961071600, , , , , , ARCHIVE, , EP031961
      LIZA, EP, E,  ,  ,  ,  , 04, 1961, TS, O, 1961071500, 1961071912, , , , , , ARCHIVE, , EP041961
     NAOMI, EP, E,  ,  ,  ,  , 05, 1961, TS, O, 1961080400, 1961080512, , , , , , ARCHIVE, , EP051961
      ORLA, EP, E,  ,  ,  ,  , 06, 1961, TS, O, 1961090612, 1961091100, , , , , , ARCHIVE, , EP061961
   PAULINE, EP, E, C,  ,  ,  , 07, 1961, TS, O, 1961100300, 1961100400, , , , , , ARCHIVE, , EP071961
   REBECCA, EP, E,  ,  ,  ,  , 08, 1961, TS, O, 1961100312, 1961100412, , , , , , ARCHIVE, , EP081961
      TARA, EP, E,  ,  ,  ,  , 10, 1961, HU, O, 1961111000, 1961111212, , , , , , ARCHIVE, , EP101961
      ALMA, AL, L,  ,  ,  ,  , 01, 1962, HU, O, 1962082612, 1962090206, , , , , , ARCHIVE, , AL011962
     BECKY, AL, L,  ,  ,  ,  , 02, 1962, TS, O, 1962082706, 1962090100, , , , , , ARCHIVE, , AL021962
     CELIA, AL, L,  ,  ,  ,  , 03, 1962, TS, O, 1962091200, 1962092112, , , , , , ARCHIVE, , AL031962
     DAISY, AL, L,  ,  ,  ,  , 04, 1962, HU, O, 1962092906, 1962100906, , , , , , ARCHIVE, , AL041962
      ELLA, AL, L,  ,  ,  ,  , 05, 1962, HU, O, 1962101406, 1962102506, , , , , , ARCHIVE, , AL051962
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1962, TS, O, 1962062900, 1962070606, , , , , , ARCHIVE, , AL061962
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1962, HU, O, 1962112612, 1962120606, , , , , , ARCHIVE, , AL071962
   VALERIE, EP, E,  ,  ,  ,  , 01, 1962, HU, O, 1962062400, 1962062600, , , , , , ARCHIVE, , EP011962
     WILLA, EP, E,  ,  ,  ,  , 02, 1962, TS, O, 1962070800, 1962071012, , , , , , ARCHIVE, , EP021962
       AVA, EP, E,  ,  ,  ,  , 03, 1962, TS, O, 1962081612, 1962082000, , , , , , ARCHIVE, , EP031962
   UNNAMED, EP, E,  ,  ,  ,  , 04, 1962, TS, O, 1962082012, 1962082200, , , , , , ARCHIVE, , EP041962
         C, EP, E, C,  ,  ,  , 05, 1962, TS, O, 1962082900, 1962090200, , , , , , ARCHIVE, , EP051962
   BERNICE, EP, E,  ,  ,  ,  , 06, 1962, TS, O, 1962090200, 1962090612, , , , , , ARCHIVE, , EP061962
   CLAUDIA, EP, E,  ,  ,  ,  , 07, 1962, TS, O, 1962092000, 1962092412, , , , , , ARCHIVE, , EP071962
   UNNAMED, EP, E,  ,  ,  ,  , 08, 1962, TS, O, 1962092600, 1962093012, , , , , , ARCHIVE, , EP081962
    DOREEN, EP, E,  ,  ,  ,  , 09, 1962, HU, O, 1962100100, 1962100500, , , , , , ARCHIVE, , EP091962
    ARLENE, AL, L,  ,  ,  ,  , 01, 1963, HU, O, 1963073118, 1963081400, , , , , , ARCHIVE, , AL011963
    BEULAH, AL, L,  ,  ,  ,  , 02, 1963, HU, O, 1963082000, 1963090818, , , , , , ARCHIVE, , AL021963
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1963, HU, O, 1963090912, 1963091412, , , , , , ARCHIVE, , AL031963
     CINDY, AL, L,  ,  ,  ,  , 04, 1963, TS, O, 1963091612, 1963092000, , , , , , ARCHIVE, , AL041963
     DEBRA, AL, L,  ,  ,  ,  , 05, 1963, HU, O, 1963091906, 1963092418, , , , , , ARCHIVE, , AL051963
     EDITH, AL, L,  ,  ,  ,  , 06, 1963, HU, O, 1963092312, 1963092918, , , , , , ARCHIVE, , AL061963
     FLORA, AL, L,  ,  ,  ,  , 07, 1963, HU, O, 1963092812, 1963101718, , , , , , ARCHIVE, , AL071963
     GINNY, AL, L,  ,  ,  ,  , 08, 1963, HU, O, 1963101718, 1963103006, , , , , , ARCHIVE, , AL081963
    HELENA, AL, L,  ,  ,  ,  , 09, 1963, TS, O, 1963102506, 1963103012, , , , , , ARCHIVE, , AL091963
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1963, TS, O, 1963060112, 1963060412, , , , , , ARCHIVE, , AL101963
   UNNAMED, CP, C,  ,  ,  ,  , 01, 1963, TS, O, 1963080200, 1963080812, , , , , , ARCHIVE, , CP011963
     EMILY, EP, E,  ,  ,  ,  , 01, 1963, HU, O, 1963062900, 1963063012, , , , , , ARCHIVE, , EP011963
  FLORENCE, EP, E,  ,  ,  ,  , 02, 1963, HU, O, 1963071412, 1963071712, , , , , , ARCHIVE, , EP021963
    GLENDA, EP, E,  ,  ,  ,  , 03, 1963, HU, O, 1963071912, 1963072112, , , , , , ARCHIVE, , EP031963
   JEN-KAT, EP, E,  ,  ,  ,  , 04, 1963, TS, O, 1963090900, 1963091812, , , , , , ARCHIVE, , EP041963
      IRAH, EP, E, C,  ,  ,  , 05, 1963, TS, O, 1963091200, 1963092100, , , , , , ARCHIVE, , EP051963
   LILLIAN, EP, E,  ,  ,  ,  , 06, 1963, TS, O, 1963092412, 1963092900, , , , , , ARCHIVE, , EP061963
      MONA, EP, E,  ,  ,  ,  , 07, 1963, HU, O, 1963101712, 1963101900, , , , , , ARCHIVE, , EP071963
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1964, TS, O, 1964060312, 1964061118, , , , , , ARCHIVE, , AL011964
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1964, HU, O, 1964072806, 1964080912, , , , , , ARCHIVE, , AL021964
      ABBY, AL, L,  ,  ,  ,  , 03, 1964, TS, O, 1964080518, 1964080818, , , , , , ARCHIVE, , AL031964
    BRENDA, AL, L,  ,  ,  ,  , 04, 1964, TS, O, 1964080806, 1964081012, , , , , , ARCHIVE, , AL041964
      CLEO, AL, L,  ,  ,  ,  , 05, 1964, HU, O, 1964082018, 1964091100, , , , , , ARCHIVE, , AL051964
      DORA, AL, L,  ,  ,  ,  , 06, 1964, HU, O, 1964082812, 1964091600, , , , , , ARCHIVE, , AL061964
     ETHEL, AL, L,  ,  ,  ,  , 07, 1964, HU, O, 1964090406, 1964091712, , , , , , ARCHIVE, , AL071964
  FLORENCE, AL, L,  ,  ,  ,  , 08, 1964, TS, O, 1964090506, 1964091006, , , , , , ARCHIVE, , AL081964
    GLADYS, AL, L,  ,  ,  ,  , 09, 1964, HU, O, 1964091306, 1964092500, , , , , , ARCHIVE, , AL091964
     HILDA, AL, L,  ,  ,  ,  , 10, 1964, HU, O, 1964092812, 1964100712, , , , , , ARCHIVE, , AL101964
    ISBELL, AL, L,  ,  ,  ,  , 11, 1964, HU, O, 1964100906, 1964101618, , , , , , ARCHIVE, , AL111964
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1964, TS, O, 1964110500, 1964111000, , , , , , ARCHIVE, , AL121964
   UNNAMED, AL, L,  ,  ,  ,  , 13, 1964, TS, O, 1964072300, 1964072718, , , , , , ARCHIVE, , AL131964
   NATALIE, EP, E,  ,  ,  ,  , 01, 1964, TS, O, 1964070600, 1964070800, , , , , , ARCHIVE, , EP011964
    ODESSA, EP, E,  ,  ,  ,  , 02, 1964, HU, O, 1964071500, 1964071912, , , , , , ARCHIVE, , EP021964
  PRUDENCE, EP, E,  ,  ,  ,  , 03, 1964, TS, O, 1964072000, 1964072412, , , , , , ARCHIVE, , EP031964
    ROSLYN, EP, E,  ,  ,  ,  , 04, 1964, TS, O, 1964082100, 1964082212, , , , , , ARCHIVE, , EP041964
    TILLIE, EP, E,  ,  ,  ,  , 05, 1964, TS, O, 1964090700, 1964090900, , , , , , ARCHIVE, , EP051964
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1965, TS, O, 1965061318, 1965062018, , , , , , ARCHIVE, , AL011965
      ANNA, AL, L,  ,  ,  ,  , 02, 1965, HU, O, 1965082106, 1965082612, , , , , , ARCHIVE, , AL021965
     BETSY, AL, L,  ,  ,  ,  , 03, 1965, HU, O, 1965082700, 1965091300, , , , , , ARCHIVE, , AL031965
     CAROL, AL, L,  ,  ,  ,  , 04, 1965, HU, O, 1965091606, 1965100312, , , , , , ARCHIVE, , AL041965
    DEBBIE, AL, L,  ,  ,  ,  , 05, 1965, TS, O, 1965092412, 1965093000, , , , , , ARCHIVE, , AL051965
     ELENA, AL, L,  ,  ,  ,  , 06, 1965, HU, O, 1965101212, 1965102012, , , , , , ARCHIVE, , AL061965
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1965, TS, O, 1965090400, 1965091112, , , , , , ARCHIVE, , AL071965
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1965, TS, O, 1965092900, 1965100300, , , , , , ARCHIVE, , AL081965
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1965, TS, O, 1965101606, 1965101912, , , , , , ARCHIVE, , AL091965
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1965, TS, O, 1965112618, 1965120206, , , , , , ARCHIVE, , AL101965
  VICTORIA, EP, E,  ,  ,  ,  , 01, 1965, TS, O, 1965060400, 1965060712, , , , , , ARCHIVE, , EP011965
    WALLIE, EP, E,  ,  ,  ,  , 02, 1965, TS, O, 1965061700, 1965061812, , , , , , ARCHIVE, , EP021965
       AVA, EP, E,  ,  ,  ,  , 03, 1965, TS, O, 1965062900, 1965070500, , , , , , ARCHIVE, , EP031965
   BERNICE, EP, E,  ,  ,  ,  , 04, 1965, TS, O, 1965063012, 1965070800, , , , , , ARCHIVE, , EP041965
   CLAUDIA, EP, E,  ,  ,  ,  , 05, 1965, TS, O, 1965080712, 1965081112, , , , , , ARCHIVE, , EP051965
    DOREEN, EP, E, C,  ,  ,  , 06, 1965, TS, O, 1965082100, 1965083100, , , , , , ARCHIVE, , EP061965
     EMILY, EP, E,  ,  ,  ,  , 07, 1965, HU, O, 1965083000, 1965090612, , , , , , ARCHIVE, , EP071965
  FLORENCE, EP, E,  ,  ,  ,  , 08, 1965, TS, O, 1965090800, 1965091512, , , , , , ARCHIVE, , EP081965
    GLENDA, EP, E,  ,  ,  ,  , 09, 1965, TS, O, 1965091312, 1965092212, , , , , , ARCHIVE, , EP091965
     HAZEL, EP, E,  ,  ,  ,  , 10, 1965, TS, O, 1965092400, 1965092700, , , , , , ARCHIVE, , EP101965 
      ALMA, AL, L,  ,  ,  ,  , 01, 1966, HU, O, 1966060406, 1966061412, , , , , , ARCHIVE, , AL011966
     BECKY, AL, L,  ,  ,  ,  , 02, 1966, HU, O, 1966070118, 1966070318, , , , , , ARCHIVE, , AL021966
     CELIA, AL, L,  ,  ,  ,  , 03, 1966, HU, O, 1966071312, 1966072206, , , , , , ARCHIVE, , AL031966
   DOROTHY, AL, L,  ,  ,  ,  , 04, 1966, HU, O, 1966072218, 1966073118, , , , , , ARCHIVE, , AL041966
      ELLA, AL, L,  ,  ,  ,  , 05, 1966, TS, O, 1966072212, 1966072818, , , , , , ARCHIVE, , AL051966
     FAITH, AL, L,  ,  ,  ,  , 06, 1966, HU, O, 1966082100, 1966090700, , , , , , ARCHIVE, , AL061966
     GRETA, AL, L,  ,  ,  ,  , 07, 1966, TS, O, 1966090112, 1966090718, , , , , , ARCHIVE, , AL071966
    HALLIE, AL, L,  ,  ,  ,  , 08, 1966, TS, O, 1966092012, 1966092200, , , , , , ARCHIVE, , AL081966
      INEZ, AL, L,  ,  ,  ,  , 09, 1966, HU, O, 1966092112, 1966101112, , , , , , ARCHIVE, , AL091966
    JUDITH, AL, L,  ,  ,  ,  , 10, 1966, TS, O, 1966092700, 1966093012, , , , , , ARCHIVE, , AL101966
      LOIS, AL, L,  ,  ,  ,  , 11, 1966, HU, O, 1966110412, 1966111400, , , , , , ARCHIVE, , AL111966
     ADELE, EP, E,  ,  ,  ,  , 01, 1966, HU, O, 1966062000, 1966062412, , , , , , ARCHIVE, , EP011966
    BLANCA, EP, E, C,  ,  ,  , 02, 1966, HU, O, 1966080300, 1966081200, , , , , , ARCHIVE, , EP021966
    CONNIE, EP, E, C,  ,  ,  , 03, 1966, HU, O, 1966080800, 1966081712, , , , , , ARCHIVE, , EP031966
   DOLORES, EP, E,  ,  ,  ,  , 04, 1966, HU, O, 1966081612, 1966082518, , , , , , ARCHIVE, , EP041966
    EILEEN, EP, E,  ,  ,  ,  , 05, 1966, HU, O, 1966082300, 1966082900, , , , , , ARCHIVE, , EP051966
 FRANCESCA, EP, E,  ,  ,  ,  , 06, 1966, HU, O, 1966090600, 1966091612, , , , , , ARCHIVE, , EP061966
  GRETCHEN, EP, E,  ,  ,  ,  , 07, 1966, TS, O, 1966090800, 1966091112, , , , , , ARCHIVE, , EP071966
     HELGA, EP, E,  ,  ,  ,  , 08, 1966, HU, O, 1966090912, 1966091712, , , , , , ARCHIVE, , EP081966
      IONE, EP, E,  ,  ,  ,  , 09, 1966, TS, O, 1966091100, 1966091312, , , , , , ARCHIVE, , EP091966
     JOYCE, EP, E,  ,  ,  ,  , 10, 1966, TS, O, 1966091500, 1966092012, , , , , , ARCHIVE, , EP101966
   KIRSTEN, EP, E,  ,  ,  ,  , 11, 1966, TS, O, 1966092600, 1966092912, , , , , , ARCHIVE, , EP111966
  LORRAINE, EP, E,  ,  ,  ,  , 12, 1966, TS, O, 1966100400, 1966100512, , , , , , ARCHIVE, , EP121966
    MAGGIE, EP, E,  ,  ,  ,  , 13, 1966, TS, O, 1966101612, 1966101912, , , , , , ARCHIVE, , EP131966
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1967, TD, O, 1967061012, 1967061212, , , , , , ARCHIVE, , AL011967
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1967, TD, O, 1967061012, 1967061312, , , , , , ARCHIVE, , AL021967
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1967, TD, O, 1967061412, 1967061806, , , , , , ARCHIVE, , AL031967
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1967, TD, O, 1967061812, 1967062012, , , , , , ARCHIVE, , AL041967
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1967, TD, O, 1967070512, 1967070912, , , , , , ARCHIVE, , AL051967
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1967, TD, O, 1967072112, 1967072212, , , , , , ARCHIVE, , AL061967
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1967, TD, O, 1967080312, 1967080612, , , , , , ARCHIVE, , AL071967
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1967, TD, O, 1967081012, 1967081612, , , , , , ARCHIVE, , AL081967
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1967, TD, O, 1967081612, 1967081912, , , , , , ARCHIVE, , AL091967
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1967, TD, O, 1967082012, 1967082412, , , , , , ARCHIVE, , AL101967
    ARLENE, AL, L,  ,  ,  ,  , 11, 1967, HU, O, 1967082818, 1967090418, , , , , , ARCHIVE, , AL111967
     CHLOE, AL, L,  ,  ,  ,  , 12, 1967, HU, O, 1967090500, 1967092118, , , , , , ARCHIVE, , AL121967
    BEULAH, AL, L,  ,  ,  ,  , 13, 1967, HU, O, 1967090512, 1967092218, , , , , , ARCHIVE, , AL131967
     DORIA, AL, L,  ,  ,  ,  , 14, 1967, HU, O, 1967090800, 1967092112, , , , , , ARCHIVE, , AL141967
   UNNAMED, AL, L,  ,  ,  ,  , 15, 1967, TD, O, 1967091812, 1967092612, , , , , , ARCHIVE, , AL151967
   UNNAMED, AL, L,  ,  ,  ,  , 16, 1967, TD, O, 1967092212, 1967093012, , , , , , ARCHIVE, , AL161967
   UNNAMED, AL, L,  ,  ,  ,  , 17, 1967, TD, O, 1967092512, 1967092812, , , , , , ARCHIVE, , AL171967
     EDITH, AL, L,  ,  ,  ,  , 18, 1967, TS, O, 1967092612, 1967100112, , , , , , ARCHIVE, , AL181967
      FERN, AL, L,  ,  ,  ,  , 19, 1967, HU, O, 1967100118, 1967100418, , , , , , ARCHIVE, , AL191967
   UNNAMED, AL, L,  ,  ,  ,  , 20, 1967, TD, O, 1967100312, 1967100512, , , , , , ARCHIVE, , AL201967
    GINGER, AL, L,  ,  ,  ,  , 21, 1967, TS, O, 1967100512, 1967100818, , , , , , ARCHIVE, , AL211967
   UNNAMED, AL, L,  ,  ,  ,  , 22, 1967, TD, O, 1967100812, 1967100912, , , , , , ARCHIVE, , AL221967
   UNNAMED, AL, L,  ,  ,  ,  , 23, 1967, TD, O, 1967101212, 1967101412, , , , , , ARCHIVE, , AL231967
   UNNAMED, AL, L,  ,  ,  ,  , 24, 1967, TD, O, 1967101512, 1967101712, , , , , , ARCHIVE, , AL241967
     HEIDI, AL, L,  ,  ,  ,  , 25, 1967, HU, O, 1967101912, 1967110118, , , , , , ARCHIVE, , AL251967
   UNNAMED, AL, L,  ,  ,  ,  , 26, 1967, TD, O, 1967102612, 1967102912, , , , , , ARCHIVE, , AL261967
     SARAH, CP, C, W,  ,  ,  , 01, 1967, HU, O, 1967090900, 1967092200, , , , , , ARCHIVE, , CP011967
    AGATHA, EP, E,  ,  ,  ,  , 01, 1967, TS, O, 1967060712, 1967061012, , , , , , ARCHIVE, , EP011967
   BRIDGET, EP, E,  ,  ,  ,  , 02, 1967, TS, O, 1967061600, 1967061618, , , , , , ARCHIVE, , EP021967
  CARLOTTA, EP, E,  ,  ,  ,  , 03, 1967, HU, O, 1967062300, 1967062612, , , , , , ARCHIVE, , EP031967
    DENISE, EP, E, C,  ,  ,  , 04, 1967, TS, O, 1967070600, 1967071800, , , , , , ARCHIVE, , EP041967
   ELEANOR, EP, E, C,  ,  ,  , 05, 1967, TS, O, 1967071300, 1967072200, , , , , , ARCHIVE, , EP051967
  FRANCENE, EP, E,  ,  ,  ,  , 06, 1967, TS, O, 1967072400, 1967072712, , , , , , ARCHIVE, , EP061967
 GEORGETTE, EP, E,  ,  ,  ,  , 07, 1967, TS, O, 1967072500, 1967073000, , , , , , ARCHIVE, , EP071967
      ILSA, EP, E,  ,  ,  ,  , 08, 1967, TS, O, 1967081200, 1967081800, , , , , , ARCHIVE, , EP081967
     JEWEL, EP, E,  ,  ,  ,  , 09, 1967, HU, O, 1967081800, 1967082200, , , , , , ARCHIVE, , EP091967
   KATRINA, EP, E,  ,  ,  ,  , 10, 1967, HU, O, 1967083000, 1967090300, , , , , , ARCHIVE, , EP101967
      LILY, EP, E,  ,  ,  ,  , 11, 1967, HU, O, 1967090500, 1967091112, , , , , , ARCHIVE, , EP111967
    MONICA, EP, E,  ,  ,  ,  , 12, 1967, TS, O, 1967091306, 1967092012, , , , , , ARCHIVE, , EP121967
   NANETTE, EP, E,  ,  ,  ,  , 13, 1967, TS, O, 1967091312, 1967092112, , , , , , ARCHIVE, , EP131967
    OLIVIA, EP, E,  ,  ,  ,  , 14, 1967, HU, O, 1967100600, 1967101500, , , , , , ARCHIVE, , EP141967
 PRISCILLA, EP, E,  ,  ,  ,  , 15, 1967, HU, O, 1967101400, 1967102012, , , , , , ARCHIVE, , EP151967
    RAMONA, EP, E, C,  ,  ,  , 16, 1967, TS, O, 1967102100, 1967110312, , , , , , ARCHIVE, , EP161967
      ABBY, AL, L,  ,  ,  ,  , 01, 1968, HU, O, 1968060106, 1968061318, , , , , , ARCHIVE, , AL011968
    BRENDA, AL, L,  ,  ,  ,  , 02, 1968, HU, O, 1968061712, 1968062612, , , , , , ARCHIVE, , AL021968
     CANDY, AL, L,  ,  ,  ,  , 03, 1968, TS, O, 1968062218, 1968062606, , , , , , ARCHIVE, , AL031968
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1968, TD, O, 1968070400, 1968070500, , , , , , ARCHIVE, , AL041968
     DOLLY, AL, L,  ,  ,  ,  , 05, 1968, HU, O, 1968081000, 1968081700, , , , , , ARCHIVE, , AL051968
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1968, TD, O, 1968082600, 1968090100, , , , , , ARCHIVE, , AL061968
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1968, TD, O, 1968090700, 1968091012, , , , , , ARCHIVE, , AL071968
      EDNA, AL, L,  ,  ,  ,  , 08, 1968, TS, O, 1968091118, 1968091906, , , , , , ARCHIVE, , AL081968
   SUBTROP, AL, L,  ,  ,  ,  , 09, 1968, HU, O, 1968091412, 1968092318, , , , , , ARCHIVE, , AL091968
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1968, TD, O, 1968091700, 1968092112, , , , , , ARCHIVE, , AL101968
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1968, TD, O, 1968092300, 1968092512, , , , , , ARCHIVE, , AL111968
   FRANCES, AL, L,  ,  ,  ,  , 12, 1968, TS, O, 1968092312, 1968093018, , , , , , ARCHIVE, , AL121968
   UNNAMED, AL, L,  ,  ,  ,  , 13, 1968, TD, O, 1968092500, 1968092906, , , , , , ARCHIVE, , AL131968
    GLADYS, AL, L,  ,  ,  ,  , 14, 1968, HU, O, 1968101312, 1968102118, , , , , , ARCHIVE, , AL141968
   UNNAMED, AL, L,  ,  ,  ,  , 15, 1968, TD, O, 1968112412, 1968112512, , , , , , ARCHIVE, , AL151968
   ANNETTE, EP, E,  ,  ,  ,  , 01, 1968, TS, O, 1968062012, 1968062200, , , , , , ARCHIVE, , EP011968
     BONNY, EP, E,  ,  ,  ,  , 02, 1968, TS, O, 1968070400, 1968070912, , , , , , ARCHIVE, , EP021968
   CELESTE, EP, E,  ,  ,  ,  , 03, 1968, TS, O, 1968071500, 1968072112, , , , , , ARCHIVE, , EP031968
     DIANA, EP, E,  ,  ,  ,  , 04, 1968, TS, O, 1968072100, 1968072612, , , , , , ARCHIVE, , EP041968
   ESTELLE, EP, E,  ,  ,  ,  , 05, 1968, TS, O, 1968072312, 1968073112, , , , , , ARCHIVE, , EP051968
  FERNANDA, EP, E, C,  ,  ,  , 06, 1968, HU, O, 1968080500, 1968081500, , , , , , ARCHIVE, , EP061968
      GWEN, EP, E,  ,  ,  ,  , 07, 1968, TS, O, 1968080600, 1968080912, , , , , , ARCHIVE, , EP071968
  HYACINTH, EP, E,  ,  ,  ,  , 08, 1968, TS, O, 1968081700, 1968082112, , , , , , ARCHIVE, , EP081968
       IVA, EP, E,  ,  ,  ,  , 09, 1968, TS, O, 1968082100, 1968082600, , , , , , ARCHIVE, , EP091968
    JOANNE, EP, E,  ,  ,  ,  , 10, 1968, HU, O, 1968082100, 1968082800, , , , , , ARCHIVE, , EP101968
  KATHLEEN, EP, E, C,  ,  ,  , 11, 1968, TS, O, 1968082400, 1968090300, , , , , , ARCHIVE, , EP111968
      LIZA, EP, E,  ,  ,  ,  , 12, 1968, HU, O, 1968082800, 1968090600, , , , , , ARCHIVE, , EP121968
  MADELINE, EP, E,  ,  ,  ,  , 13, 1968, TS, O, 1968082900, 1968083012, , , , , , ARCHIVE, , EP131968
     NAOMI, EP, E,  ,  ,  ,  , 14, 1968, HU, O, 1968090900, 1968091312, , , , , , ARCHIVE, , EP141968
      ORLA, EP, E,  ,  ,  ,  , 15, 1968, TS, O, 1968092200, 1968093012, , , , , , ARCHIVE, , EP151968
   PAULINE, EP, E,  ,  ,  ,  , 16, 1968, HU, O, 1968092600, 1968100312, , , , , , ARCHIVE, , EP161968
   REBECCA, EP, E,  ,  ,  ,  , 17, 1968, HU, O, 1968100600, 1968101100, , , , , , ARCHIVE, , EP171968
    SIMONE, EP, E,  ,  ,  ,  , 18, 1968, TS, O, 1968101818, 1968101912, , , , , , ARCHIVE, , EP181968
      TARA, EP, E,  ,  ,  ,  , 19, 1968, TS, O, 1968102012, 1968102812, , , , , , ARCHIVE, , EP191968
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1969, TD, O, 1969052900, 1969060200, , , , , , ARCHIVE, , AL011969
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1969, TD, O, 1969052900, 1969053000, , , , , , ARCHIVE, , AL021969
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1969, TD, O, 1969060700, 1969060900, , , , , , ARCHIVE, , AL031969
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1969, TD, O, 1969061200, 1969061500, , , , , , ARCHIVE, , AL041969
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1969, TD, O, 1969072500, 1969072700, , , , , , ARCHIVE, , AL051969
      ANNA, AL, L,  ,  ,  ,  , 06, 1969, TS, O, 1969072506, 1969080512, , , , , , ARCHIVE, , AL061969
   BLANCHE, AL, L,  ,  ,  ,  , 07, 1969, HU, O, 1969081100, 1969081306, , , , , , ARCHIVE, , AL071969
    DEBBIE, AL, L,  ,  ,  ,  , 08, 1969, HU, O, 1969081412, 1969082512, , , , , , ARCHIVE, , AL081969
   CAMILLE, AL, L,  ,  ,  ,  , 09, 1969, HU, O, 1969081418, 1969082212, , , , , , ARCHIVE, , AL091969
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1969, TD, O, 1969082400, 1969082800, , , , , , ARCHIVE, , AL101969
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1969, TD, O, 1969082400, 1969082600, , , , , , ARCHIVE, , AL111969
       EVE, AL, L,  ,  ,  ,  , 12, 1969, TS, O, 1969082500, 1969082718, , , , , , ARCHIVE, , AL121969
 FRANCELIA, AL, L,  ,  ,  ,  , 13, 1969, HU, O, 1969082900, 1969090412, , , , , , ARCHIVE, , AL131969
   UNNAMED, AL, L,  ,  ,  ,  , 14, 1969, TD, O, 1969082900, 1969090100, , , , , , ARCHIVE, , AL141969
   UNNAMED, AL, L,  ,  ,  ,  , 15, 1969, TD, O, 1969090500, 1969091000, , , , , , ARCHIVE, , AL151969
     GERDA, AL, L,  ,  ,  ,  , 16, 1969, HU, O, 1969090600, 1969091012, , , , , , ARCHIVE, , AL161969
     HOLLY, AL, L,  ,  ,  ,  , 17, 1969, HU, O, 1969091412, 1969092100, , , , , , ARCHIVE, , AL171969
   UNNAMED, AL, L,  ,  ,  ,  , 18, 1969, TD, O, 1969091600, 1969092000, , , , , , ARCHIVE, , AL181969
   UNNAMED, AL, L,  ,  ,  ,  , 19, 1969, TD, O, 1969091900, 1969092018, , , , , , ARCHIVE, , AL191969
      INGA, AL, L,  ,  ,  ,  , 20, 1969, HU, O, 1969092012, 1969101500, , , , , , ARCHIVE, , AL201969
   UNNAMED, AL, L,  ,  ,  ,  , 21, 1969, HU, O, 1969092112, 1969092600, , , , , , ARCHIVE, , AL211969
   UNNAMED, AL, L,  ,  ,  ,  , 22, 1969, TS, O, 1969092412, 1969093000, , , , , , ARCHIVE, , AL221969
   SUBTROP, AL, L,  ,  ,  ,  , 23, 1969, SS, O, 1969092912, 1969100118, , , , , , ARCHIVE, , AL231969
     JENNY, AL, L,  ,  ,  ,  , 24, 1969, TS, O, 1969100112, 1969100618, , , , , , ARCHIVE, , AL241969
      KARA, AL, L,  ,  ,  ,  , 25, 1969, HU, O, 1969100712, 1969101906, , , , , , ARCHIVE, , AL251969
    LAURIE, AL, L,  ,  ,  ,  , 26, 1969, HU, O, 1969101700, 1969102706, , , , , , ARCHIVE, , AL261969
   UNNAMED, AL, L,  ,  ,  ,  , 27, 1969, TS, O, 1969102812, 1969103118, , , , , , ARCHIVE, , AL271969
   UNNAMED, AL, L,  ,  ,  ,  , 28, 1969, HU, O, 1969103012, 1969110700, , , , , , ARCHIVE, , AL281969
    MARTHA, AL, L,  ,  ,  ,  , 29, 1969, HU, O, 1969112112, 1969112512, , , , , , ARCHIVE, , AL291969
       AVA, EP, E,  ,  ,  ,  , 01, 1969, TS, O, 1969070118, 1969070812, , , , , , ARCHIVE, , EP011969
   BERNICE, EP, E,  ,  ,  ,  , 02, 1969, HU, O, 1969070900, 1969071700, , , , , , ARCHIVE, , EP021969
   CLAUDIA, EP, E,  ,  ,  ,  , 03, 1969, TS, O, 1969072200, 1969072312, , , , , , ARCHIVE, , EP031969
    DOREEN, EP, E,  ,  ,  ,  , 04, 1969, HU, O, 1969080400, 1969080912, , , , , , ARCHIVE, , EP041969
     EMILY, EP, E,  ,  ,  ,  , 05, 1969, TS, O, 1969082300, 1969082412, , , , , , ARCHIVE, , EP051969
  FLORENCE, EP, E,  ,  ,  ,  , 06, 1969, TS, O, 1969090200, 1969090712, , , , , , ARCHIVE, , EP061969
    GLENDA, EP, E,  ,  ,  ,  , 07, 1969, HU, O, 1969090800, 1969091200, , , , , , ARCHIVE, , EP071969
   HEATHER, EP, E,  ,  ,  ,  , 08, 1969, TS, O, 1969091900, 1969092512, , , , , , ARCHIVE, , EP081969
      IRAH, EP, E,  ,  ,  ,  , 09, 1969, TS, O, 1969093000, 1969100312, , , , , , ARCHIVE, , EP091969
  JENNIFER, EP, E,  ,  ,  ,  , 10, 1969, HU, O, 1969100900, 1969101212, , , , , , ARCHIVE, , EP101969
      ALMA, AL, L,  ,  ,  ,  , 01, 1970, HU, O, 1970051718, 1970052706, , , , , , ARCHIVE, , AL011970
     BECKY, AL, L,  ,  ,  ,  , 02, 1970, TS, O, 1970071900, 1970072312, , , , , , ARCHIVE, , AL021970
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1970, TD, O, 1970072712, 1970080118, , , , , , ARCHIVE, , AL031970
     CELIA, AL, L,  ,  ,  ,  , 04, 1970, HU, O, 1970073100, 1970080518, , , , , , ARCHIVE, , AL041970
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1970, TD, O, 1970080212, 1970080612, , , , , , ARCHIVE, , AL051970
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1970, TD, O, 1970080512, 1970080700, , , , , , ARCHIVE, , AL061970
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1970, TD, O, 1970081112, 1970081812, , , , , , ARCHIVE, , AL071970
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1970, TS, O, 1970081512, 1970081900, , , , , , ARCHIVE, , AL081970
   DOROTHY, AL, L,  ,  ,  ,  , 09, 1970, TS, O, 1970081712, 1970082312, , , , , , ARCHIVE, , AL091970
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1970, TD, O, 1970090312, 1970090906, , , , , , ARCHIVE, , AL101970
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1970, TD, O, 1970090512, 1970090718, , , , , , ARCHIVE, , AL111970
      ELLA, AL, L,  ,  ,  ,  , 12, 1970, HU, O, 1970090812, 1970091306, , , , , , ARCHIVE, , AL121970
    FELICE, AL, L,  ,  ,  ,  , 13, 1970, TS, O, 1970091200, 1970091712, , , , , , ARCHIVE, , AL131970
   UNNAMED, AL, L,  ,  ,  ,  , 14, 1970, TD, O, 1970092212, 1970092518, , , , , , ARCHIVE, , AL141970
   UNNAMED, AL, L,  ,  ,  ,  , 15, 1970, TD, O, 1970092312, 1970101112, , , , , , ARCHIVE, , AL151970
     GRETA, AL, L,  ,  ,  ,  , 16, 1970, TS, O, 1970092612, 1970100500, , , , , , ARCHIVE, , AL161970
   UNNAMED, AL, L,  ,  ,  ,  , 17, 1970, TD, O, 1970092912, 1970090112, , , , , , ARCHIVE, , AL171970
   UNNAMED, AL, L,  ,  ,  ,  , 18, 1970, HU, O, 1970101212, 1970101800, , , , , , ARCHIVE, , AL181970
   UNNAMED, AL, L,  ,  ,  ,  , 19, 1970, HU, O, 1970102012, 1970102812, , , , , , ARCHIVE, , AL191970
       DOT, CP, C,  ,  ,  ,  , 01, 1970, TS, O, 1970090100, 1970090406, , , , , , ARCHIVE, , CP011970
     ADELE, EP, E,  ,  ,  ,  , 01, 1970, HU, O, 1970053012, 1970060700, , , , , , ARCHIVE, , EP011970
    BLANCA, EP, E,  ,  ,  ,  , 02, 1970, TS, O, 1970061000, 1970061212, , , , , , ARCHIVE, , EP021970
    CONNIE, EP, E,  ,  ,  ,  , 03, 1970, TS, O, 1970061712, 1970062112, , , , , , ARCHIVE, , EP031970
    EILEEN, EP, E,  ,  ,  ,  , 04, 1970, TS, O, 1970062612, 1970063000, , , , , , ARCHIVE, , EP041970
 FRANCESCA, EP, E,  ,  ,  ,  , 05, 1970, HU, O, 1970070112, 1970071000, , , , , , ARCHIVE, , EP051970
  GRETCHEN, EP, E,  ,  ,  ,  , 06, 1970, TS, O, 1970071412, 1970072112, , , , , , ARCHIVE, , EP061970
     HELGA, EP, E,  ,  ,  ,  , 07, 1970, TS, O, 1970071612, 1970072000, , , , , , ARCHIVE, , EP071970
  IONE-ONE, EP, E,  ,  ,  ,  , 08, 1970, TS, O, 1970072212, 1970072612, , , , , , ARCHIVE, , EP081970
  IONE-TWO, EP, E,  ,  ,  ,  , 09, 1970, TS, O, 1970072400, 1970072500, , , , , , ARCHIVE, , EP091970
     JOYCE, EP, E,  ,  ,  ,  , 10, 1970, TS, O, 1970072912, 1970080412, , , , , , ARCHIVE, , EP101970
   KRISTEN, EP, E,  ,  ,  ,  , 11, 1970, TS, O, 1970080500, 1970080812, , , , , , ARCHIVE, , EP111970
  LORRAINE, EP, E, C,  ,  ,  , 12, 1970, HU, O, 1970081600, 1970082712, , , , , , ARCHIVE, , EP121970
    MAGGIE, EP, E, C,  ,  ,  , 13, 1970, TS, O, 1970082012, 1970082700, , , , , , ARCHIVE, , EP131970
     NORMA, EP, E,  ,  ,  ,  , 14, 1970, TS, O, 1970083100, 1970090600, , , , , , ARCHIVE, , EP141970
    ORLENE, EP, E,  ,  ,  ,  , 15, 1970, TS, O, 1970090700, 1970090900, , , , , , ARCHIVE, , EP151970
  PATRICIA, EP, E,  ,  ,  ,  , 16, 1970, HU, O, 1970100400, 1970101112, , , , , , ARCHIVE, , EP161970
   ROSALIE, EP, E,  ,  ,  ,  , 17, 1970, TS, O, 1970102100, 1970102312, , , , , , ARCHIVE, , EP171970
     SELMA, EP, E,  ,  ,  ,  , 18, 1970, TS, O, 1970110112, 1970110812, , , , , , ARCHIVE, , EP181970
    ARLENE, AL, L,  ,  ,  ,  , 01, 1971, TS, O, 1971070412, 1971070800, , , , , , ARCHIVE, , AL011971
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1971, TD, O, 1971070712, 1971070812, , , , , , ARCHIVE, , AL021971
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1971, TD, O, 1971071012, 1971071112, , , , , , ARCHIVE, , AL031971
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1971, HU, O, 1971080312, 1971080712, , , , , , ARCHIVE, , AL041971
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1971, TD, O, 1971080612, 1971080912, , , , , , ARCHIVE, , AL051971
      BETH, AL, L,  ,  ,  ,  , 06, 1971, HU, O, 1971081012, 1971081712, , , , , , ARCHIVE, , AL061971
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1971, TD, O, 1971081212, 1971081612, , , , , , ARCHIVE, , AL071971
     CHLOE, AL, L,  ,  ,  ,  , 08, 1971, TS, O, 1971081812, 1971082512, , , , , , ARCHIVE, , AL081971
     DORIA, AL, L,  ,  ,  ,  , 09, 1971, TS, O, 1971082012, 1971082906, , , , , , ARCHIVE, , AL091971
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1971, TD, O, 1971082812, 1971090112, , , , , , ARCHIVE, , AL101971
      FERN, AL, L,  ,  ,  ,  , 11, 1971, HU, O, 1971090312, 1971091300, , , , , , ARCHIVE, , AL111971
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1971, TD, O, 1971090312, 1971090818, , , , , , ARCHIVE, , AL121971
     EDITH, AL, L,  ,  ,  ,  , 13, 1971, HU, O, 1971090518, 1971091806, , , , , , ARCHIVE, , AL131971
    GINGER, AL, L,  ,  ,  ,  , 14, 1971, HU, O, 1971090600, 1971100506, , , , , , ARCHIVE, , AL141971
   UNNAMED, AL, L,  ,  ,  ,  , 15, 1971, TD, O, 1971090812, 1971091112, , , , , , ARCHIVE, , AL151971
   UNNAMED, AL, L,  ,  ,  ,  , 16, 1971, TD, O, 1971091012, 1971091412, , , , , , ARCHIVE, , AL161971
     HEIDI, AL, L,  ,  ,  ,  , 17, 1971, TS, O, 1971091100, 1971091500, , , , , , ARCHIVE, , AL171971
     IRENE, AL, L,  ,  ,  ,  , 18, 1971, HU, O, 1971091118, 1971092018, , , , , , ARCHIVE, , AL181971
    JANICE, AL, L,  ,  ,  ,  , 19, 1971, TS, O, 1971092106, 1971092418, , , , , , ARCHIVE, , AL191971
   UNNAMED, AL, L,  ,  ,  ,  , 20, 1971, TD, O, 1971100612, 1971101412, , , , , , ARCHIVE, , AL201971
    KRISTY, AL, L,  ,  ,  ,  , 21, 1971, TS, O, 1971101800, 1971102118, , , , , , ARCHIVE, , AL211971
     LAURA, AL, L,  ,  ,  ,  , 22, 1971, TS, O, 1971111212, 1971112200, , , , , , ARCHIVE, , AL221971
    AGATHA, EP, E,  ,  ,  ,  , 01, 1971, HU, O, 1971052112, 1971052512, , , , , , ARCHIVE, , EP011971
   BRIDGET, EP, E,  ,  ,  ,  , 02, 1971, HU, O, 1971061412, 1971062000, , , , , , ARCHIVE, , EP021971
  CARLOTTA, EP, E,  ,  ,  ,  , 03, 1971, HU, O, 1971070200, 1971070812, , , , , , ARCHIVE, , EP031971
    DENISE, EP, E, C,  ,  ,  , 04, 1971, HU, O, 1971070212, 1971071400, , , , , , ARCHIVE, , EP041971
   ELEANOR, EP, E,  ,  ,  ,  , 05, 1971, TS, O, 1971070700, 1971071112, , , , , , ARCHIVE, , EP051971
  FRANCENE, EP, E,  ,  ,  ,  , 06, 1971, HU, O, 1971071800, 1971072312, , , , , , ARCHIVE, , EP061971
 GEORGETTE, EP, E,  ,  ,  ,  , 07, 1971, TS, O, 1971072012, 1971072712, , , , , , ARCHIVE, , EP071971
    HILARY, EP, E, C,  ,  ,  , 08, 1971, HU, O, 1971072600, 1971080700, , , , , , ARCHIVE, , EP081971
      ILSA, EP, E,  ,  ,  ,  , 09, 1971, HU, O, 1971073100, 1971080818, , , , , , ARCHIVE, , EP091971
     JEWEL, EP, E,  ,  ,  ,  , 10, 1971, TS, O, 1971080612, 1971081112, , , , , , ARCHIVE, , EP101971
   KATRINA, EP, E,  ,  ,  ,  , 11, 1971, TS, O, 1971080812, 1971081300, , , , , , ARCHIVE, , EP111971
      LILY, EP, E,  ,  ,  ,  , 12, 1971, HU, O, 1971082800, 1971090112, , , , , , ARCHIVE, , EP121971
    MONICA, EP, E,  ,  ,  ,  , 13, 1971, HU, O, 1971082900, 1971090500, , , , , , ARCHIVE, , EP131971
   NANETTE, EP, E,  ,  ,  ,  , 14, 1971, HU, O, 1971090300, 1971090912, , , , , , ARCHIVE, , EP141971
    OLIVIA, EP, E,  ,  ,  ,  , 15, 1971, HU, O, 1971092000, 1971100100, , , , , , ARCHIVE, , EP151971
 PRISCILLA, EP, E,  ,  ,  ,  , 16, 1971, HU, O, 1971100612, 1971101300, , , , , , ARCHIVE, , EP161971
    RAMONA, EP, E,  ,  ,  ,  , 17, 1971, TS, O, 1971102800, 1971103112, , , , , , ARCHIVE, , EP171971
    SHARON, EP, E,  ,  ,  ,  , 18, 1971, TS, O, 1971112512, 1971112900, , , , , , ARCHIVE, , EP181971
     ALPHA, AL, L,  ,  ,  ,  , 01, 1972, SS, O, 1972052318, 1972052912, , , , , , ARCHIVE, , AL011972
     AGNES, AL, L,  ,  ,  ,  , 02, 1972, HU, O, 1972061412, 1972062300, , , , , , ARCHIVE, , AL021972
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1972, TD, O, 1972061900, 1972062018, , , , , , ARCHIVE, , AL031972
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1972, TD, O, 1972071012, 1972071218, , , , , , ARCHIVE, , AL041972
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1972, TD, O, 1972071612, 1972072018, , , , , , ARCHIVE, , AL051972
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1972, TD, O, 1972073112, 1972080312, , , , , , ARCHIVE, , AL061972
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1972, TD, O, 1972080512, 1972080718, , , , , , ARCHIVE, , AL071972
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1972, TD, O, 1972081212, 1972081512, , , , , , ARCHIVE, , AL081972
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1972, TD, O, 1972081612, 1972081812, , , , , , ARCHIVE, , AL091972
     BETTY, AL, L,  ,  ,  ,  , 10, 1972, HU, O, 1972082212, 1972090118, , , , , , ARCHIVE, , AL101972
    CARRIE, AL, L,  ,  ,  ,  , 11, 1972, TS, O, 1972082912, 1972090512, , , , , , ARCHIVE, , AL111972
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1972, TD, O, 1972090312, 1972090512, , , , , , ARCHIVE, , AL121972
      DAWN, AL, L,  ,  ,  ,  , 13, 1972, HU, O, 1972090500, 1972091412, , , , , , ARCHIVE, , AL131972
   CHARLIE, AL, L,  ,  ,  ,  , 14, 1972, SS, O, 1972091912, 1972092200, , , , , , ARCHIVE, , AL141972
   UNNAMED, AL, L,  ,  ,  ,  , 15, 1972, TD, O, 1972092012, 1972092412, , , , , , ARCHIVE, , AL151972
   UNNAMED, AL, L,  ,  ,  ,  , 16, 1972, TD, O, 1972100112, 1972100312, , , , , , ARCHIVE, , AL161972
   UNNAMED, AL, L,  ,  ,  ,  , 17, 1972, TD, O, 1972100512, 1972101512, , , , , , ARCHIVE, , AL171972
   UNNAMED, AL, L,  ,  ,  ,  , 18, 1972, TD, O, 1972101612, 1972102012, , , , , , ARCHIVE, , AL181972
     DELTA, AL, L,  ,  ,  ,  , 19, 1972, SS, O, 1972110118, 1972110718, , , , , , ARCHIVE, , AL191972
      JUNE, CP, C,  ,  ,  ,  , 01, 1972, TS, O, 1972092400, 1972092800, , , , , , ARCHIVE, , CP011972
      RUBY, CP, C, W,  ,  ,  , 02, 1972, HU, O, 1972111100, 1972112000, , , , , , ARCHIVE, , CP021972
   ANNETTE, EP, E,  ,  ,  ,  , 01, 1972, HU, O, 1972060100, 1972060812, , , , , , ARCHIVE, , EP011972
     BONNY, EP, E,  ,  ,  ,  , 02, 1972, TS, O, 1972072712, 1972073018, , , , , , ARCHIVE, , EP021972
   CELESTE, EP, E, C,  ,  ,  , 03, 1972, HU, O, 1972080600, 1972082200, , , , , , ARCHIVE, , EP031972
     DIANA, EP, E, C,  ,  ,  , 04, 1972, HU, O, 1972081100, 1972082000, , , , , , ARCHIVE, , EP041972
   ESTELLE, EP, E,  ,  ,  ,  , 05, 1972, HU, O, 1972081500, 1972082212, , , , , , ARCHIVE, , EP051972
  FERNANDA, EP, E, C,  ,  ,  , 06, 1972, HU, O, 1972082000, 1972090100, , , , , , ARCHIVE, , EP061972
      GWEN, EP, E,  ,  ,  ,  , 07, 1972, HU, O, 1972082200, 1972083100, , , , , , ARCHIVE, , EP071972
  HYACINTH, EP, E,  ,  ,  ,  , 08, 1972, HU, O, 1972082800, 1972090700, , , , , , ARCHIVE, , EP081972
       IVA, EP, E,  ,  ,  ,  , 09, 1972, TS, O, 1972091400, 1972092200, , , , , , ARCHIVE, , EP091972
    JOANNE, EP, E,  ,  ,  ,  , 10, 1972, HU, O, 1972093000, 1972100700, , , , , , ARCHIVE, , EP101972
  KATHLEEN, EP, E,  ,  ,  ,  , 11, 1972, TS, O, 1972101800, 1972101912, , , , , , ARCHIVE, , EP111972
      LIZA, EP, E,  ,  ,  ,  , 12, 1972, TS, O, 1972111312, 1972111512, , , , , , ARCHIVE, , EP121972
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1973, TD, O, 1973041812, 1973042112, , , , , , ARCHIVE, , AL011973
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1973, TD, O, 1973050212, 1973050512, , , , , , ARCHIVE, , AL021973
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1973, TD, O, 1973062412, 1973062612, , , , , , ARCHIVE, , AL031973
     ALICE, AL, L,  ,  ,  ,  , 04, 1973, HU, O, 1973070118, 1973070700, , , , , , ARCHIVE, , AL041973
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1973, TD, O, 1973071912, 1973072112, , , , , , ARCHIVE, , AL051973
      ALFA, AL, L,  ,  ,  ,  , 06, 1973, SS, O, 1973073012, 1973080200, , , , , , ARCHIVE, , AL061973
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1973, TD, O, 1973080912, 1973081112, , , , , , ARCHIVE, , AL071973
    BRENDA, AL, L,  ,  ,  ,  , 08, 1973, HU, O, 1973081806, 1973082200, , , , , , ARCHIVE, , AL081973
 CHRISTINE, AL, L,  ,  ,  ,  , 09, 1973, TS, O, 1973082512, 1973090418, , , , , , ARCHIVE, , AL091973
     DELIA, AL, L,  ,  ,  ,  , 10, 1973, TS, O, 1973090118, 1973090706, , , , , , ARCHIVE, , AL101973
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1973, TD, O, 1973090612, 1973091212, , , , , , ARCHIVE, , AL111973
     ELLEN, AL, L,  ,  ,  ,  , 12, 1973, HU, O, 1973091412, 1973092312, , , , , , ARCHIVE, , AL121973
   UNNAMED, AL, L,  ,  ,  ,  , 13, 1973, TD, O, 1973092412, 1973092612, , , , , , ARCHIVE, , AL131973
      FRAN, AL, L,  ,  ,  ,  , 14, 1973, HU, O, 1973100818, 1973101312, , , , , , ARCHIVE, , AL141973
   UNNAMED, AL, L,  ,  ,  ,  , 15, 1973, TD, O, 1973101012, 1973101212, , , , , , ARCHIVE, , AL151973
     GILDA, AL, L,  ,  ,  ,  , 16, 1973, TS, O, 1973101606, 1973103000, , , , , , ARCHIVE, , AL161973
   UNNAMED, AL, L,  ,  ,  ,  , 17, 1973, TD, O, 1973111712, 1973111818, , , , , , ARCHIVE, , AL171973
       AVA, EP, E,  ,  ,  ,  , 01, 1973, HU, O, 1973060200, 1973061212, , , , , , ARCHIVE, , EP011973
   BERNICE, EP, E,  ,  ,  ,  , 02, 1973, TS, O, 1973062200, 1973062312, , , , , , ARCHIVE, , EP021973
   CLAUDIA, EP, E,  ,  ,  ,  , 03, 1973, TS, O, 1973062600, 1973063000, , , , , , ARCHIVE, , EP031973
    DOREEN, EP, E, C,  ,  ,  , 04, 1973, HU, O, 1973071800, 1973080300, , , , , , ARCHIVE, , EP041973
     EMILY, EP, E,  ,  ,  ,  , 05, 1973, HU, O, 1973072112, 1973072812, , , , , , ARCHIVE, , EP051973
  FLORENCE, EP, E,  ,  ,  ,  , 06, 1973, HU, O, 1973072500, 1973073012, , , , , , ARCHIVE, , EP061973
    GLENDA, EP, E,  ,  ,  ,  , 07, 1973, TS, O, 1973073012, 1973080512, , , , , , ARCHIVE, , EP071973
   HEATHER, EP, E,  ,  ,  ,  , 08, 1973, TS, O, 1973083100, 1973090112, , , , , , ARCHIVE, , EP081973
      IRAH, EP, E,  ,  ,  ,  , 09, 1973, HU, O, 1973092200, 1973092700, , , , , , ARCHIVE, , EP091973
  JENNIFER, EP, E,  ,  ,  ,  , 10, 1973, TS, O, 1973092300, 1973092712, , , , , , ARCHIVE, , EP101973
 KATHERINE, EP, E, C,  ,  ,  , 11, 1973, HU, O, 1973092912, 1973100900, , , , , , ARCHIVE, , EP111973
   LILLIAN, EP, E,  ,  ,  ,  , 12, 1973, HU, O, 1973100500, 1973100912, , , , , , ARCHIVE, , EP121973
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1974, TD, O, 1974062212, 1974062612, , , , , , ARCHIVE, , AL011974
   SUBTROP, AL, L,  ,  ,  ,  , 02, 1974, SS, O, 1974062418, 1974062600, , , , , , ARCHIVE, , AL021974
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1974, TD, O, 1974063012, 1974070212, , , , , , ARCHIVE, , AL031974
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1974, TD, O, 1974071312, 1974071718, , , , , , ARCHIVE, , AL041974
   SUBTROP, AL, L,  ,  ,  ,  , 05, 1974, SS, O, 1974071600, 1974072012, , , , , , ARCHIVE, , AL051974
   SUBTROP, AL, L,  ,  ,  ,  , 06, 1974, SS, O, 1974081012, 1974081500, , , , , , ARCHIVE, , AL061974
      ALMA, AL, L,  ,  ,  ,  , 07, 1974, TS, O, 1974081212, 1974081512, , , , , , ARCHIVE, , AL071974
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1974, TD, O, 1974082412, 1974082612, , , , , , ARCHIVE, , AL081974
     BECKY, AL, L,  ,  ,  ,  , 09, 1974, HU, O, 1974082612, 1974090206, , , , , , ARCHIVE, , AL091974
    CARMEN, AL, L,  ,  ,  ,  , 10, 1974, HU, O, 1974082906, 1974091006, , , , , , ARCHIVE, , AL101974
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1974, TD, O, 1974090212, 1974091112, , , , , , ARCHIVE, , AL111974
     DOLLY, AL, L,  ,  ,  ,  , 12, 1974, TS, O, 1974090218, 1974090512, , , , , , ARCHIVE, , AL121974
    ELAINE, AL, L,  ,  ,  ,  , 13, 1974, TS, O, 1974090418, 1974091400, , , , , , ARCHIVE, , AL131974
      FIFI, AL, L,  ,  ,  ,  , 14, 1974, HU, O, 1974091412, 1974092212, , , , , , ARCHIVE, , AL141974
   UNNAMED, AL, L,  ,  ,  ,  , 15, 1974, TD, O, 1974091812, 1974092018, , , , , , ARCHIVE, , AL151974
   UNNAMED, AL, L,  ,  ,  ,  , 16, 1974, TD, O, 1974092312, 1974092712, , , , , , ARCHIVE, , AL161974
  GERTRUDE, AL, L,  ,  ,  ,  , 17, 1974, HU, O, 1974092712, 1974100400, , , , , , ARCHIVE, , AL171974
   SUBTROP, AL, L,  ,  ,  ,  , 18, 1974, SS, O, 1974100400, 1974100900, , , , , , ARCHIVE, , AL181974
   UNNAMED, AL, L,  ,  ,  ,  , 19, 1974, TD, O, 1974103012, 1974100212, , , , , , ARCHIVE, , AL191974
   UNNAMED, AL, L,  ,  ,  ,  , 20, 1974, TD, O, 1974111012, 1974111212, , , , , , ARCHIVE, , AL201974
     OLIVE, CP, C,  ,  ,  ,  , 01, 1974, TS, O, 1974082200, 1974082606, , , , , , ARCHIVE, , CP011974
    ALETTA, EP, E,  ,  ,  ,  , 01, 1974, TS, O, 1974052800, 1974053000, , , , , , ARCHIVE, , EP011974
    BLANCA, EP, E,  ,  ,  ,  , 02, 1974, TS, O, 1974060500, 1974060812, , , , , , ARCHIVE, , EP021974
    CONNIE, EP, E,  ,  ,  ,  , 03, 1974, HU, O, 1974060700, 1974062200, , , , , , ARCHIVE, , EP031974
   DOLORES, EP, E,  ,  ,  ,  , 04, 1974, HU, O, 1974061412, 1974061700, , , , , , ARCHIVE, , EP041974
    EILEEN, EP, E,  ,  ,  ,  , 05, 1974, TS, O, 1974070200, 1974070412, , , , , , ARCHIVE, , EP051974
 FRANCESCA, EP, E,  ,  ,  ,  , 06, 1974, HU, O, 1974071400, 1974071912, , , , , , ARCHIVE, , EP061974
  GRETCHEN, EP, E,  ,  ,  ,  , 07, 1974, HU, O, 1974071700, 1974072100, , , , , , ARCHIVE, , EP071974
     HELGA, EP, E,  ,  ,  ,  , 08, 1974, TS, O, 1974081000, 1974081312, , , , , , ARCHIVE, , EP081974
      IONE, EP, E, C,  ,  ,  , 09, 1974, HU, O, 1974082000, 1974083006, , , , , , ARCHIVE, , EP091974
     JOYCE, EP, E,  ,  ,  ,  , 10, 1974, HU, O, 1974082200, 1974082712, , , , , , ARCHIVE, , EP101974
   KIRSTEN, EP, E,  ,  ,  ,  , 11, 1974, HU, O, 1974082211, 1974082900, , , , , , ARCHIVE, , EP111974
  LORRAINE, EP, E,  ,  ,  ,  , 12, 1974, TS, O, 1974082300, 1974082800, , , , , , ARCHIVE, , EP121974
    MAGGIE, EP, E,  ,  ,  ,  , 13, 1974, HU, O, 1974082600, 1974090112, , , , , , ARCHIVE, , EP131974
     NORMA, EP, E,  ,  ,  ,  , 14, 1974, HU, O, 1974090918, 1974091018, , , , , , ARCHIVE, , EP141974
    ORLENE, EP, E,  ,  ,  ,  , 15, 1974, HU, O, 1974092100, 1974092412, , , , , , ARCHIVE, , EP151974
  PATRICIA, EP, E, C,  ,  ,  , 16, 1974, HU, O, 1974100612, 1974101700, , , , , , ARCHIVE, , EP161974
   ROSALIE, EP, E,  ,  ,  ,  , 17, 1974, TS, O, 1974102100, 1974102400, , , , , , ARCHIVE, , EP171974
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1975, TD, O, 1975062412, 1975062912, , , , , , ARCHIVE, , AL011975
       AMY, AL, L,  ,  ,  ,  , 02, 1975, TS, O, 1975062700, 1975070412, , , , , , ARCHIVE, , AL021975
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1975, TD, O, 1975070412, 1975070512, , , , , , ARCHIVE, , AL031975
   BLANCHE, AL, L,  ,  ,  ,  , 04, 1975, HU, O, 1975072400, 1975072818, , , , , , ARCHIVE, , AL041975
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1975, TD, O, 1975072506, 1975072618, , , , , , ARCHIVE, , AL051975
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1975, TD, O, 1975072812, 1975073012, , , , , , ARCHIVE, , AL061975
  CAROLINE, AL, L,  ,  ,  ,  , 07, 1975, HU, O, 1975082412, 1975090112, , , , , , ARCHIVE, , AL071975
     DORIS, AL, L,  ,  ,  ,  , 08, 1975, HU, O, 1975082812, 1975090412, , , , , , ARCHIVE, , AL081975
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1975, TD, O, 1975090312, 1975090906, , , , , , ARCHIVE, , AL091975
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1975, TD, O, 1975090312, 1975090612, , , , , , ARCHIVE, , AL101975
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1975, TD, O, 1975090612, 1975090718, , , , , , ARCHIVE, , AL111975
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1975, TD, O, 1975091112, 1975091418, , , , , , ARCHIVE, , AL121975
    ELOISE, AL, L,  ,  ,  ,  , 13, 1975, HU, O, 1975091306, 1975092418, , , , , , ARCHIVE, , AL131975
      FAYE, AL, L,  ,  ,  ,  , 14, 1975, HU, O, 1975091806, 1975092912, , , , , , ARCHIVE, , AL141975
    GLADYS, AL, L,  ,  ,  ,  , 15, 1975, HU, O, 1975092218, 1975100400, , , , , , ARCHIVE, , AL151975
   UNNAMED, AL, L,  ,  ,  ,  , 16, 1975, TD, O, 1975092512, 1975092912, , , , , , ARCHIVE, , AL161975
   UNNAMED, AL, L,  ,  ,  ,  , 17, 1975, TD, O, 1975100312, 1975100512, , , , , , ARCHIVE, , AL171975
   UNNAMED, AL, L,  ,  ,  ,  , 18, 1975, TD, O, 1975101412, 1975101712, , , , , , ARCHIVE, , AL181975
    HALLIE, AL, L,  ,  ,  ,  , 19, 1975, TS, O, 1975102418, 1975102800, , , , , , ARCHIVE, , AL191975
   UNNAMED, AL, L,  ,  ,  ,  , 20, 1975, TD, O, 1975102712, 1975102918, , , , , , ARCHIVE, , AL201975
   UNNAMED, AL, L,  ,  ,  ,  , 21, 1975, TD, O, 1975110812, 1975111218, , , , , , ARCHIVE, , AL211975
   UNNAMED, AL, L,  ,  ,  ,  , 22, 1975, TD, O, 1975112912, 1975110112, , , , , , ARCHIVE, , AL221975
   SUBTROP, AL, L,  ,  ,  ,  , 23, 1975, SS, O, 1975120912, 1975121312, , , , , , ARCHIVE, , AL231975
   UNNAMED, CP, C,  ,  ,  ,  , 01, 1975, HU, O, 1975083100, 1975090500, , , , , , ARCHIVE, , CP011975
    AGATHA, EP, E,  ,  ,  ,  , 01, 1975, HU, O, 1975060200, 1975060512, , , , , , ARCHIVE, , EP011975
   BRIDGET, EP, E,  ,  ,  ,  , 02, 1975, TS, O, 1975062800, 1975070312, , , , , , ARCHIVE, , EP021975
  CARLOTTA, EP, E,  ,  ,  ,  , 03, 1975, HU, O, 1975070212, 1975071100, , , , , , ARCHIVE, , EP031975
    DENISE, EP, E,  ,  ,  ,  , 04, 1975, HU, O, 1975070500, 1975071500, , , , , , ARCHIVE, , EP041975
   ELEANOR, EP, E,  ,  ,  ,  , 05, 1975, TS, O, 1975071012, 1975071212, , , , , , ARCHIVE, , EP051975
  FRANCENE, EP, E,  ,  ,  ,  , 06, 1975, TS, O, 1975072712, 1975073000, , , , , , ARCHIVE, , EP061975
 GEORGETTE, EP, E,  ,  ,  ,  , 07, 1975, TS, O, 1975081100, 1975081412, , , , , , ARCHIVE, , EP071975
    HILARY, EP, E,  ,  ,  ,  , 08, 1975, TS, O, 1975081300, 1975081712, , , , , , ARCHIVE, , EP081975
      ILSA, EP, E,  ,  ,  ,  , 09, 1975, HU, O, 1975081800, 1975082612, , , , , , ARCHIVE, , EP091975
     JEWEL, EP, E,  ,  ,  ,  , 10, 1975, HU, O, 1975082400, 1975083112, , , , , , ARCHIVE, , EP101975
   KATRINA, EP, E,  ,  ,  ,  , 11, 1975, HU, O, 1975082900, 1975090700, , , , , , ARCHIVE, , EP111975
      LILY, EP, E,  ,  ,  ,  , 12, 1975, HU, O, 1975091612, 1975092200, , , , , , ARCHIVE, , EP121975
    MONICA, EP, E,  ,  ,  ,  , 13, 1975, TS, O, 1975092812, 1975100200, , , , , , ARCHIVE, , EP131975
   NANETTE, EP, E,  ,  ,  ,  , 14, 1975, TS, O, 1975092812, 1975100400, , , , , , ARCHIVE, , EP141975
    OLIVIA, EP, E,  ,  ,  ,  , 15, 1975, HU, O, 1975102200, 1975102512, , , , , , ARCHIVE, , EP151975
 PRISCILLA, EP, E,  ,  ,  ,  , 16, 1975, TS, O, 1975110200, 1975110712, , , , , , ARCHIVE, , EP161975
   SUBTROP, AL, L,  ,  ,  ,  , 01, 1976, SS, O, 1976052112, 1976052518, , , , , , ARCHIVE, , AL011976
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1976, TD, O, 1976060706, 1976060912, , , , , , ARCHIVE, , AL021976
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1976, TD, O, 1976061112, 1976061218, , , , , , ARCHIVE, , AL031976
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1976, TD, O, 1976072012, 1976072212, , , , , , ARCHIVE, , AL041976
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1976, TD, O, 1976072312, 1976072418, , , , , , ARCHIVE, , AL051976
      ANNA, AL, L,  ,  ,  ,  , 06, 1976, TS, O, 1976072818, 1976080618, , , , , , ARCHIVE, , AL061976
     BELLE, AL, L,  ,  ,  ,  , 07, 1976, HU, O, 1976080606, 1976081012, , , , , , ARCHIVE, , AL071976
    DOTTIE, AL, L,  ,  ,  ,  , 08, 1976, TS, O, 1976081800, 1976082112, , , , , , ARCHIVE, , AL081976
   CANDICE, AL, L,  ,  ,  ,  , 09, 1976, HU, O, 1976081812, 1976082412, , , , , , ARCHIVE, , AL091976
      EMMY, AL, L,  ,  ,  ,  , 10, 1976, HU, O, 1976082012, 1976090418, , , , , , ARCHIVE, , AL101976
   FRANCES, AL, L,  ,  ,  ,  , 11, 1976, HU, O, 1976082712, 1976090712, , , , , , ARCHIVE, , AL111976
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1976, TD, O, 1976090412, 1976090612, , , , , , ARCHIVE, , AL121976
   UNNAMED, AL, L,  ,  ,  ,  , 13, 1976, TD, O, 1976090512, 1976090712, , , , , , ARCHIVE, , AL131976
   SUBTROP, AL, L,  ,  ,  ,  , 14, 1976, SS, O, 1976091312, 1976091700, , , , , , ARCHIVE, , AL141976
   UNNAMED, AL, L,  ,  ,  ,  , 15, 1976, TD, O, 1976092012, 1976092712, , , , , , ARCHIVE, , AL151976
   UNNAMED, AL, L,  ,  ,  ,  , 16, 1976, TD, O, 1976092212, 1976092418, , , , , , ARCHIVE, , AL161976
    GLORIA, AL, L,  ,  ,  ,  , 17, 1976, HU, O, 1976092612, 1976100500, , , , , , ARCHIVE, , AL171976
   UNNAMED, AL, L,  ,  ,  ,  , 18, 1976, TD, O, 1976092612, 1976092812, , , , , , ARCHIVE, , AL181976
   UNNAMED, AL, L,  ,  ,  ,  , 19, 1976, TD, O, 1976100312, 1976101212, , , , , , ARCHIVE, , AL191976
   UNNAMED, AL, L,  ,  ,  ,  , 20, 1976, TD, O, 1976101212, 1976101512, , , , , , ARCHIVE, , AL201976
     HOLLY, AL, L,  ,  ,  ,  , 21, 1976, HU, O, 1976102218, 1976102900, , , , , , ARCHIVE, , AL211976
      KATE, CP, C,  ,  ,  ,  , 01, 1976, HU, O, 1976092200, 1976100206, , , , , , ARCHIVE, , CP011976
   ANNETTE, EP, E,  ,  ,  ,  , 01, 1976, HU, O, 1976060300, 1976061406, , , , , , ARCHIVE, , EP011976
     BONNY, EP, E,  ,  ,  ,  , 02, 1976, HU, O, 1976062600, 1976062918, , , , , , ARCHIVE, , EP021976
   CELESTE, EP, E,  ,  ,  ,  , 03, 1976, TS, O, 1976071412, 1976071912, , , , , , ARCHIVE, , EP031976
     DIANA, EP, E, C,  ,  ,  , 04, 1976, HU, O, 1976071600, 1976072306, , , , , , ARCHIVE, , EP041976
   ESTELLE, EP, E,  ,  ,  ,  , 05, 1976, TS, O, 1976072700, 1976072900, , , , , , ARCHIVE, , EP051976
  FERNANDA, EP, E, C,  ,  ,  , 06, 1976, TS, O, 1976072800, 1976080200, , , , , , ARCHIVE, , EP061976
      GWEN, EP, E, C,  ,  ,  , 07, 1976, TS, O, 1976080500, 1976081806, , , , , , ARCHIVE, , EP071976
  HYACINTH, EP, E,  ,  ,  ,  , 08, 1976, HU, O, 1976080618, 1976081406, , , , , , ARCHIVE, , EP081976
       IVA, EP, E,  ,  ,  ,  , 09, 1976, HU, O, 1976082400, 1976090200, , , , , , ARCHIVE, , EP091976
    JOANNE, EP, E,  ,  ,  ,  , 10, 1976, TS, O, 1976082900, 1976090800, , , , , , ARCHIVE, , EP101976
  KATHLEEN, EP, E,  ,  ,  ,  , 11, 1976, HU, O, 1976090712, 1976091112, , , , , , ARCHIVE, , EP111976
      LIZA, EP, E,  ,  ,  ,  , 12, 1976, HU, O, 1976092518, 1976100200, , , , , , ARCHIVE, , EP121976
  MADELINE, EP, E,  ,  ,  ,  , 13, 1976, HU, O, 1976092900, 1976100818, , , , , , ARCHIVE, , EP131976
     NAOMI, EP, E,  ,  ,  ,  , 14, 1976, TS, O, 1976102512, 1976103012, , , , , , ARCHIVE, , EP141976
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1977, TD, O, 1977061312, 1977061418, , , , , , ARCHIVE, , AL011977
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1977, TD, O, 1977071806, 1977071912, , , , , , ARCHIVE, , AL021977
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1977, TD, O, 1977072512, 1977072612, , , , , , ARCHIVE, , AL031977
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1977, TD, O, 1977080112, 1977080412, , , , , , ARCHIVE, , AL041977
     ANITA, AL, L,  ,  ,  ,  , 05, 1977, HU, O, 1977082912, 1977090306, , , , , , ARCHIVE, , AL051977
      BABE, AL, L,  ,  ,  ,  , 06, 1977, HU, O, 1977090306, 1977090900, , , , , , ARCHIVE, , AL061977
     CLARA, AL, L,  ,  ,  ,  , 07, 1977, HU, O, 1977090512, 1977091200, , , , , , ARCHIVE, , AL071977
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1977, TD, O, 1977091712, 1977091912, , , , , , ARCHIVE, , AL081977
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1977, TD, O, 1977092212, 1977092312, , , , , , ARCHIVE, , AL091977
   DOROTHY, AL, L,  ,  ,  ,  , 10, 1977, HU, O, 1977092618, 1977093006, , , , , , ARCHIVE, , AL101977
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1977, TD, O, 1977100112, 1977100312, , , , , , ARCHIVE, , AL111977
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1977, TD, O, 1977100312, 1977100512, , , , , , ARCHIVE, , AL121977
    EVELYN, AL, L,  ,  ,  ,  , 13, 1977, HU, O, 1977101318, 1977101600, , , , , , ARCHIVE, , AL131977
    FRIEDA, AL, L,  ,  ,  ,  , 14, 1977, TS, O, 1977101618, 1977101900, , , , , , ARCHIVE, , AL141977
   UNNAMED, AL, L,  ,  ,  ,  , 15, 1977, TD, O, 1977102412, 1977102518, , , , , , ARCHIVE, , AL151977
       AVA, EP, E,  ,  ,  ,  , 01, 1977, TS, O, 1977052600, 1977053012, , , , , , ARCHIVE, , EP011977
   BERNICE, EP, E,  ,  ,  ,  , 02, 1977, TS, O, 1977062512, 1977062812, , , , , , ARCHIVE, , EP021977
   CLAUDIA, EP, E,  ,  ,  ,  , 03, 1977, HU, O, 1977070300, 1977070712, , , , , , ARCHIVE, , EP031977
    DOREEN, EP, E,  ,  ,  ,  , 04, 1977, HU, O, 1977081300, 1977081800, , , , , , ARCHIVE, , EP041977
     EMILY, EP, E,  ,  ,  ,  , 05, 1977, TS, O, 1977091300, 1977091412, , , , , , ARCHIVE, , EP051977
  FLORENCE, EP, E,  ,  ,  ,  , 06, 1977, HU, O, 1977092012, 1977092412, , , , , , ARCHIVE, , EP061977
    GLENDA, EP, E,  ,  ,  ,  , 07, 1977, TS, O, 1977092400, 1977092712, , , , , , ARCHIVE, , EP071977
   HEATHER, EP, E,  ,  ,  ,  , 08, 1977, HU, O, 1977100400, 1977100712, , , , , , ARCHIVE, , EP081977
   SUBTROP, AL, L,  ,  ,  ,  , 01, 1978, SS, O, 1978011812, 1978012300, , , , , , ARCHIVE, , AL011978
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1978, TD, O, 1978062112, 1978062218, , , , , , ARCHIVE, , AL021978
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1978, TD, O, 1978071012, 1978071212, , , , , , ARCHIVE, , AL031978
    AMELIA, AL, L,  ,  ,  ,  , 04, 1978, TS, O, 1978073018, 1978080100, , , , , , ARCHIVE, , AL041978
      BESS, AL, L,  ,  ,  ,  , 05, 1978, TS, O, 1978080512, 1978080812, , , , , , ARCHIVE, , AL051978
      CORA, AL, L,  ,  ,  ,  , 06, 1978, HU, O, 1978080712, 1978081200, , , , , , ARCHIVE, , AL061978
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1978, TD, O, 1978080712, 1978081118, , , , , , ARCHIVE, , AL071978
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1978, TD, O, 1978080912, 1978081018, , , , , , ARCHIVE, , AL081978
     DEBRA, AL, L,  ,  ,  ,  , 09, 1978, TS, O, 1978082612, 1978082918, , , , , , ARCHIVE, , AL091978
      ELLA, AL, L,  ,  ,  ,  , 10, 1978, HU, O, 1978083000, 1978090512, , , , , , ARCHIVE, , AL101978
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1978, TD, O, 1978083012, 1978080112, , , , , , ARCHIVE, , AL111978
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1978, TD, O, 1978090312, 1978091112, , , , , , ARCHIVE, , AL121978
   FLOSSIE, AL, L,  ,  ,  ,  , 13, 1978, HU, O, 1978090400, 1978091606, , , , , , ARCHIVE, , AL131978
   UNNAMED, AL, L,  ,  ,  ,  , 14, 1978, TD, O, 1978090812, 1978091018, , , , , , ARCHIVE, , AL141978
      HOPE, AL, L,  ,  ,  ,  , 15, 1978, TS, O, 1978091200, 1978092112, , , , , , ARCHIVE, , AL151978
     GRETA, AL, L,  ,  ,  ,  , 16, 1978, HU, O, 1978091318, 1978092000, , , , , , ARCHIVE, , AL161978
   UNNAMED, AL, L,  ,  ,  ,  , 17, 1978, TD, O, 1978091812, 1978092912, , , , , , ARCHIVE, , AL171978
   UNNAMED, AL, L,  ,  ,  ,  , 18, 1978, TD, O, 1978092112, 1978092312, , , , , , ARCHIVE, , AL181978
      IRMA, AL, L,  ,  ,  ,  , 19, 1978, TS, O, 1978100212, 1978100518, , , , , , ARCHIVE, , AL191978
    JULIET, AL, L,  ,  ,  ,  , 20, 1978, TS, O, 1978100718, 1978101112, , , , , , ARCHIVE, , AL201978
   UNNAMED, AL, L,  ,  ,  ,  , 21, 1978, TD, O, 1978101312, 1978101718, , , , , , ARCHIVE, , AL211978
   UNNAMED, AL, L,  ,  ,  ,  , 22, 1978, TD, O, 1978102612, 1978102912, , , , , , ARCHIVE, , AL221978
    KENDRA, AL, L,  ,  ,  ,  , 23, 1978, HU, O, 1978102818, 1978110312, , , , , , ARCHIVE, , AL231978
   UNNAMED, AL, L,  ,  ,  ,  , 24, 1978, TD, O, 1978110312, 1978110512, , , , , , ARCHIVE, , AL241978
     SUSAN, CP, C,  ,  ,  ,  , 01, 1978, HU, O, 1978101800, 1978102400, , , , , , ARCHIVE, , CP011978
    ALETTA, EP, E,  ,  ,  ,  , 01, 1978, HU, O, 1978053012, 1978060106, , , , , , ARCHIVE, , EP011978
       BUD, EP, E,  ,  ,  ,  , 02, 1978, TS, O, 1978061700, 1978062006, , , , , , ARCHIVE, , EP021978
  CARLOTTA, EP, E,  ,  ,  ,  , 03, 1978, HU, O, 1978061706, 1978062518, , , , , , ARCHIVE, , EP031978
    DANIEL, EP, E,  ,  ,  ,  , 04, 1978, HU, O, 1978062618, 1978070318, , , , , , ARCHIVE, , EP041978
    EMILIA, EP, E,  ,  ,  ,  , 05, 1978, TS, O, 1978070618, 1978071018, , , , , , ARCHIVE, , EP051978
      FICO, EP, E, C,  ,  ,  , 06, 1978, HU, O, 1978070900, 1978072818, , , , , , ARCHIVE, , EP061978
     GILMA, EP, E,  ,  ,  ,  , 07, 1978, HU, O, 1978071300, 1978072000, , , , , , ARCHIVE, , EP071978
    HECTOR, EP, E,  ,  ,  ,  , 08, 1978, HU, O, 1978072200, 1978072918, , , , , , ARCHIVE, , EP081978
       IVA, EP, E,  ,  ,  ,  , 09, 1978, HU, O, 1978081106, 1978081506, , , , , , ARCHIVE, , EP091978
      JOHN, EP, E, C,  ,  ,  , 10, 1978, HU, O, 1978081800, 1978083006, , , , , , ARCHIVE, , EP101978
    KRISTY, EP, E, C,  ,  ,  , 11, 1978, HU, O, 1978081818, 1978082800, , , , , , ARCHIVE, , EP111978
      LANE, EP, E, C,  ,  ,  , 12, 1978, TS, O, 1978081900, 1978082400, , , , , , ARCHIVE, , EP121978
    MIRIAM, EP, E, C,  ,  ,  , 13, 1978, HU, O, 1978082318, 1978090200, , , , , , ARCHIVE, , EP131978
    NORMAN, EP, E,  ,  ,  ,  , 14, 1978, HU, O, 1978083018, 1978090700, , , , , , ARCHIVE, , EP141978
    OLIVIA, EP, E,  ,  ,  ,  , 15, 1978, HU, O, 1978092000, 1978092300, , , , , , ARCHIVE, , EP151978
      PAUL, EP, E,  ,  ,  ,  , 16, 1978, TS, O, 1978092300, 1978092700, , , , , , ARCHIVE, , EP161978
      ROSA, EP, E,  ,  ,  ,  , 17, 1978, HU, O, 1978100218, 1978100718, , , , , , ARCHIVE, , EP171978
    SERGIO, EP, E,  ,  ,  ,  , 18, 1978, TS, O, 1978101818, 1978102112, , , , , , ARCHIVE, , EP181978
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1979, TD, O, 1979061112, 1979061618, , , , , , ARCHIVE, , AL011979
       ANA, AL, L,  ,  ,  ,  , 02, 1979, TS, O, 1979061912, 1979062400, , , , , , ARCHIVE, , AL021979
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1979, TD, O, 1979070812, 1979071312, , , , , , ARCHIVE, , AL031979
       BOB, AL, L,  ,  ,  ,  , 04, 1979, HU, O, 1979070912, 1979071612, , , , , , ARCHIVE, , AL041979
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1979, TD, O, 1979071012, 1979071318, , , , , , ARCHIVE, , AL051979
 CLAUDETTE, AL, L,  ,  ,  ,  , 06, 1979, TS, O, 1979071512, 1979072912, , , , , , ARCHIVE, , AL061979
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1979, TD, O, 1979072312, 1979072618, , , , , , ARCHIVE, , AL071979
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1979, TD, O, 1979073112, 1979080612, , , , , , ARCHIVE, , AL081979
     DAVID, AL, L,  ,  ,  ,  , 09, 1979, HU, O, 1979082512, 1979090800, , , , , , ARCHIVE, , AL091979
   UNNAMED, AL, L,  ,  ,  ,  , 10, 1979, TD, O, 1979082512, 1979082812, , , , , , ARCHIVE, , AL101979
  FREDERIC, AL, L,  ,  ,  ,  , 11, 1979, HU, O, 1979082906, 1979091500, , , , , , ARCHIVE, , AL111979
     ELENA, AL, L,  ,  ,  ,  , 12, 1979, TS, O, 1979083000, 1979090200, , , , , , ARCHIVE, , AL121979
   UNNAMED, AL, L,  ,  ,  ,  , 13, 1979, TD, O, 1979090112, 1979090612, , , , , , ARCHIVE, , AL131979
    GLORIA, AL, L,  ,  ,  ,  , 14, 1979, HU, O, 1979090412, 1979091506, , , , , , ARCHIVE, , AL141979
     HENRI, AL, L,  ,  ,  ,  , 15, 1979, HU, O, 1979091500, 1979092412, , , , , , ARCHIVE, , AL151979
   UNNAMED, AL, L,  ,  ,  ,  , 16, 1979, TD, O, 1979091612, 1979092112, , , , , , ARCHIVE, , AL161979
   UNNAMED, AL, L,  ,  ,  ,  , 17, 1979, TD, O, 1979101212, 1979102012, , , , , , ARCHIVE, , AL171979
   SUBTROP, AL, L,  ,  ,  ,  , 18, 1979, SS, O, 1979102312, 1979102512, , , , , , ARCHIVE, , AL181979
   UNNAMED, AL, L,  ,  ,  ,  , 19, 1979, TD, O, 1979102412, 1979102912, , , , , , ARCHIVE, , AL191979
   UNNAMED, AL, L,  ,  ,  ,  , 20, 1979, TD, O, 1979110712, 1979111000, , , , , , ARCHIVE, , AL201979
    ANDRES, EP, E,  ,  ,  ,  , 01, 1979, HU, O, 1979053118, 1979060418, , , , , , ARCHIVE, , EP011979
    BLANCA, EP, E,  ,  ,  ,  , 02, 1979, TS, O, 1979062106, 1979062512, , , , , , ARCHIVE, , EP021979
    CARLOS, EP, E,  ,  ,  ,  , 03, 1979, TS, O, 1979071418, 1979071606, , , , , , ARCHIVE, , EP031979
   DOLORES, EP, E,  ,  ,  ,  , 04, 1979, HU, O, 1979071706, 1979072318, , , , , , ARCHIVE, , EP041979
   ENRIQUE, EP, E,  ,  ,  ,  , 05, 1979, HU, O, 1979081718, 1979082418, , , , , , ARCHIVE, , EP051979
      FEFA, EP, E,  ,  ,  ,  , 06, 1979, HU, O, 1979082100, 1979082500, , , , , , ARCHIVE, , EP061979
 GUILLERMO, EP, E,  ,  ,  ,  , 07, 1979, HU, O, 1979090818, 1979091312, , , , , , ARCHIVE, , EP071979
     HILDA, EP, E,  ,  ,  ,  , 08, 1979, TS, O, 1979100400, 1979100618, , , , , , ARCHIVE, , EP081979
   IGNACIO, EP, E,  ,  ,  ,  , 09, 1979, HU, O, 1979102318, 1979103018, , , , , , ARCHIVE, , EP091979
    JIMENA, EP, E,  ,  ,  ,  , 10, 1979, TS, O, 1979111506, 1979111806, , , , , , ARCHIVE, , EP101979
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1980, TD, O, 1980071700, 1980072100, , , , , , ARCHIVE, , AL011980
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1980, TD, O, 1980071712, 1980072112, , , , , , ARCHIVE, , AL021980
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1980, TD, O, 1980072200, 1980072600, , , , , , ARCHIVE, , AL031980
     ALLEN, AL, L,  ,  ,  ,  , 04, 1980, HU, O, 1980073112, 1980081118, , , , , , ARCHIVE, , AL041980
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1980, TD, O, 1980081300, 1980081700, , , , , , ARCHIVE, , AL051980
    BONNIE, AL, L,  ,  ,  ,  , 06, 1980, HU, O, 1980081400, 1980081918, , , , , , ARCHIVE, , AL061980
   CHARLEY, AL, L,  ,  ,  ,  , 07, 1980, HU, O, 1980082012, 1980082518, , , , , , ARCHIVE, , AL071980
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1980, TD, O, 1980082500, 1980082900, , , , , , ARCHIVE, , AL081980
   GEORGES, AL, L,  ,  ,  ,  , 09, 1980, HU, O, 1980090100, 1980090818, , , , , , ARCHIVE, , AL091980
      EARL, AL, L,  ,  ,  ,  , 10, 1980, HU, O, 1980090412, 1980091100, , , , , , ARCHIVE, , AL101980
  DANIELLE, AL, L,  ,  ,  ,  , 11, 1980, TS, O, 1980090418, 1980090712, , , , , , ARCHIVE, , AL111980
   FRANCES, AL, L,  ,  ,  ,  , 12, 1980, HU, O, 1980090600, 1980092100, , , , , , ARCHIVE, , AL121980
   HERMINE, AL, L,  ,  ,  ,  , 13, 1980, TS, O, 1980092012, 1980092600, , , , , , ARCHIVE, , AL131980
      IVAN, AL, L,  ,  ,  ,  , 14, 1980, HU, O, 1980100100, 1980101200, , , , , , ARCHIVE, , AL141980
   UNNAMED, AL, L,  ,  ,  ,  , 15, 1980, TD, O, 1980101600, 1980101800, , , , , , ARCHIVE, , AL151980
    JEANNE, AL, L,  ,  ,  ,  , 16, 1980, HU, O, 1980110718, 1980111606, , , , , , ARCHIVE, , AL161980
   UNNAMED, AL, L,  ,  ,  ,  , 17, 1980, TD, O, 1980111212, 1980111812, , , , , , ARCHIVE, , AL171980
      KARL, AL, L,  ,  ,  ,  , 18, 1980, HU, O, 1980112500, 1980112800, , , , , , ARCHIVE, , AL181980
    AGATHA, EP, E,  ,  ,  ,  , 01, 1980, HU, O, 1980060900, 1980061518, , , , , , ARCHIVE, , EP011980
      BLAS, EP, E,  ,  ,  ,  , 02, 1980, TS, O, 1980061618, 1980061918, , , , , , ARCHIVE, , EP021980
     CELIA, EP, E,  ,  ,  ,  , 03, 1980, HU, O, 1980062506, 1980062918, , , , , , ARCHIVE, , EP031980
     DARBY, EP, E,  ,  ,  ,  , 04, 1980, TS, O, 1980070100, 1980070318, , , , , , ARCHIVE, , EP041980
   ESTELLE, EP, E,  ,  ,  ,  , 05, 1980, TS, O, 1980071200, 1980071300, , , , , , ARCHIVE, , EP051980
     FRANK, EP, E,  ,  ,  ,  , 06, 1980, TS, O, 1980071806, 1980072212, , , , , , ARCHIVE, , EP061980
 GEORGETTE, EP, E,  ,  ,  ,  , 07, 1980, HU, O, 1980072806, 1980073118, , , , , , ARCHIVE, , EP071980
    HOWARD, EP, E,  ,  ,  ,  , 08, 1980, HU, O, 1980073100, 1980080706, , , , , , ARCHIVE, , EP081980
      ISIS, EP, E,  ,  ,  ,  , 09, 1980, HU, O, 1980080518, 1980081112, , , , , , ARCHIVE, , EP091980
    JAVIER, EP, E,  ,  ,  ,  , 10, 1980, HU, O, 1980082218, 1980082900, , , , , , ARCHIVE, , EP101980
       KAY, EP, E, C,  ,  ,  , 11, 1980, HU, O, 1980091606, 1980093012, , , , , , ARCHIVE, , EP111980
    LESTER, EP, E,  ,  ,  ,  , 12, 1980, TS, O, 1980092118, 1980092500, , , , , , ARCHIVE, , EP121980
  MADELINE, EP, E,  ,  ,  ,  , 13, 1980, TS, O, 1980101100, 1980101206, , , , , , ARCHIVE, , EP131980
    NEWTON, EP, E,  ,  ,  ,  , 14, 1980, TS, O, 1980102806, 1980102912, , , , , , ARCHIVE, , EP141980
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1981, TD, O, 1981040612, 1981040712, , , , , , ARCHIVE, , AL011981
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1981, TD, O, 1981041912, 1981042118, , , , , , ARCHIVE, , AL021981
    ARLENE, AL, L,  ,  ,  ,  , 03, 1981, TS, O, 1981050618, 1981050906, , , , , , ARCHIVE, , AL031981
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1981, TD, O, 1981060306, 1981060518, , , , , , ARCHIVE, , AL041981
   UNNAMED, AL, L,  ,  ,  ,  , 05, 1981, TD, O, 1981061712, 1981061900, , , , , , ARCHIVE, , AL051981
      BRET, AL, L,  ,  ,  ,  , 06, 1981, TS, O, 1981062912, 1981070112, , , , , , ARCHIVE, , AL061981
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1981, TD, O, 1981070206, 1981070400, , , , , , ARCHIVE, , AL071981
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1981, TD, O, 1981072506, 1981072618, , , , , , ARCHIVE, , AL081981
     CINDY, AL, L,  ,  ,  ,  , 09, 1981, TS, O, 1981080218, 1981080512, , , , , , ARCHIVE, , AL091981
    DENNIS, AL, L,  ,  ,  ,  , 10, 1981, HU, O, 1981080706, 1981082200, , , , , , ARCHIVE, , AL101981
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1981, TD, O, 1981081706, 1981082118, , , , , , ARCHIVE, , AL111981
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1981, TD, O, 1981082618, 1981082912, , , , , , ARCHIVE, , AL121981
     EMILY, AL, L,  ,  ,  ,  , 13, 1981, HU, O, 1981083112, 1981091200, , , , , , ARCHIVE, , AL131981
     FLOYD, AL, L,  ,  ,  ,  , 14, 1981, HU, O, 1981090312, 1981091212, , , , , , ARCHIVE, , AL141981
      GERT, AL, L,  ,  ,  ,  , 15, 1981, HU, O, 1981090700, 1981091518, , , , , , ARCHIVE, , AL151981
    HARVEY, AL, L,  ,  ,  ,  , 16, 1981, HU, O, 1981091118, 1981092000, , , , , , ARCHIVE, , AL161981
   UNNAMED, AL, L,  ,  ,  ,  , 17, 1981, TD, O, 1981091200, 1981091412, , , , , , ARCHIVE, , AL171981
     IRENE, AL, L,  ,  ,  ,  , 18, 1981, HU, O, 1981092112, 1981100306, , , , , , ARCHIVE, , AL181981
   UNNAMED, AL, L,  ,  ,  ,  , 19, 1981, TD, O, 1981092600, 1981100418, , , , , , ARCHIVE, , AL191981
      JOSE, AL, L,  ,  ,  ,  , 20, 1981, TS, O, 1981102912, 1981110200, , , , , , ARCHIVE, , AL201981
   KATRINA, AL, L,  ,  ,  ,  , 21, 1981, HU, O, 1981110300, 1981110718, , , , , , ARCHIVE, , AL211981
   SUBTROP, AL, L,  ,  ,  ,  , 22, 1981, SS, O, 1981111212, 1981111706, , , , , , ARCHIVE, , AL221981
    ADRIAN, EP, E,  ,  ,  ,  , 01, 1981, TS, O, 1981053018, 1981060406, , , , , , ARCHIVE, , EP011981
   BEATRIZ, EP, E,  ,  ,  ,  , 02, 1981, HU, O, 1981062818, 1981070418, , , , , , ARCHIVE, , EP021981
    CALVIN, EP, E,  ,  ,  ,  , 03, 1981, TS, O, 1981070418, 1981070900, , , , , , ARCHIVE, , EP031981
      DORA, EP, E,  ,  ,  ,  , 04, 1981, HU, O, 1981071018, 1981071618, , , , , , ARCHIVE, , EP041981
    EUGENE, EP, E,  ,  ,  ,  , 05, 1981, TS, O, 1981071618, 1981072118, , , , , , ARCHIVE, , EP051981
  FERNANDA, EP, E,  ,  ,  ,  , 06, 1981, HU, O, 1981080612, 1981081300, , , , , , ARCHIVE, , EP061981
      GREG, EP, E, C,  ,  ,  , 07, 1981, HU, O, 1981081306, 1981082218, , , , , , ARCHIVE, , EP071981
    HILARY, EP, E,  ,  ,  ,  , 08, 1981, HU, O, 1981082118, 1981082818, , , , , , ARCHIVE, , EP081981
     IRWIN, EP, E,  ,  ,  ,  , 09, 1981, TS, O, 1981082718, 1981083106, , , , , , ARCHIVE, , EP091981
      JOVA, EP, E, C,  ,  ,  , 10, 1981, HU, O, 1981091412, 1981092100, , , , , , ARCHIVE, , EP101981
      KNUT, EP, E,  ,  ,  ,  , 11, 1981, TS, O, 1981091900, 1981092118, , , , , , ARCHIVE, , EP111981
     LIDIA, EP, E,  ,  ,  ,  , 12, 1981, TS, O, 1981100618, 1981100806, , , , , , ARCHIVE, , EP121981
       MAX, EP, E,  ,  ,  ,  , 13, 1981, TS, O, 1981100718, 1981101018, , , , , , ARCHIVE, , EP131981
     NORMA, EP, E,  ,  ,  ,  , 14, 1981, HU, O, 1981100818, 1981101212, , , , , , ARCHIVE, , EP141981
      OTIS, EP, E,  ,  ,  ,  , 15, 1981, HU, O, 1981102400, 1981103000, , , , , , ARCHIVE, , EP151981
   ALBERTO, AL, L,  ,  ,  ,  , 01, 1982, HU, O, 1982060212, 1982060612, , , , , , ARCHIVE, , AL011982
   SUBTROP, AL, L,  ,  ,  ,  , 02, 1982, SS, O, 1982061800, 1982062018, , , , , , ARCHIVE, , AL021982
     BERYL, AL, L,  ,  ,  ,  , 03, 1982, TS, O, 1982082812, 1982090612, , , , , , ARCHIVE, , AL031982
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1982, TD, O, 1982090600, 1982090912, , , , , , ARCHIVE, , AL041982
     CHRIS, AL, L,  ,  ,  ,  , 05, 1982, TS, O, 1982090900, 1982091218, , , , , , ARCHIVE, , AL051982
     DEBBY, AL, L,  ,  ,  ,  , 06, 1982, HU, O, 1982091312, 1982092018, , , , , , ARCHIVE, , AL061982
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1982, TD, O, 1982092400, 1982092712, , , , , , ARCHIVE, , AL071982
   ERNESTO, AL, L,  ,  ,  ,  , 08, 1982, TS, O, 1982093012, 1982100300, , , , , , ARCHIVE, , AL081982
     AKONI, CP, C,  ,  ,  ,  , 01, 1982, TS, O, 1982083006, 1982090212, , , , , , ARCHIVE, , CP011982
       EMA, CP, C,  ,  ,  ,  , 02, 1982, TS, O, 1982091518, 1982091900, , , , , , ARCHIVE, , CP021982
      HANA, CP, C,  ,  ,  ,  , 03, 1982, TS, O, 1982091518, 1982091900, , , , , , ARCHIVE, , CP031982
       IWA, CP, C,  ,  ,  ,  , 04, 1982, HU, O, 1982111912, 1982112500, , , , , , ARCHIVE, , CP041982
    ALETTA, EP, E,  ,  ,  ,  , 01, 1982, TS, O, 1982052000, 1982052912, , , , , , ARCHIVE, , EP011982
       BUD, EP, E,  ,  ,  ,  , 02, 1982, TS, O, 1982061512, 1982061712, , , , , , ARCHIVE, , EP021982
  CARLOTTA, EP, E,  ,  ,  ,  , 03, 1982, TS, O, 1982070112, 1982070600, , , , , , ARCHIVE, , EP031982
    DANIEL, EP, E, C,  ,  ,  , 04, 1982, HU, O, 1982070700, 1982072218, , , , , , ARCHIVE, , EP041982
    EMILIA, EP, E, C,  ,  ,  , 05, 1982, TS, O, 1982071212, 1982071518, , , , , , ARCHIVE, , EP051982
     FABIO, EP, E,  ,  ,  ,  , 06, 1982, HU, O, 1982071712, 1982072506, , , , , , ARCHIVE, , EP061982
     GILMA, EP, E, C,  ,  ,  , 07, 1982, HU, O, 1982072606, 1982080200, , , , , , ARCHIVE, , EP071982
    HECTOR, EP, E,  ,  ,  ,  , 08, 1982, HU, O, 1982072900, 1982080306, , , , , , ARCHIVE, , EP081982
       IVA, EP, E,  ,  ,  ,  , 09, 1982, TS, O, 1982080106, 1982080812, , , , , , ARCHIVE, , EP091982
      JOHN, EP, E, C,  ,  ,  , 10, 1982, HU, O, 1982080212, 1982081100, , , , , , ARCHIVE, , EP101982
    KRISTY, EP, E, C,  ,  ,  , 11, 1982, HU, O, 1982080818, 1982081700, , , , , , ARCHIVE, , EP111982
      LANE, EP, E,  ,  ,  ,  , 12, 1982, TS, O, 1982080818, 1982081500, , , , , , ARCHIVE, , EP121982
    MIRIAM, EP, E, C,  ,  ,  , 13, 1982, HU, O, 1982083000, 1982090618, , , , , , ARCHIVE, , EP131982
    NORMAN, EP, E,  ,  ,  ,  , 14, 1982, HU, O, 1982090918, 1982091812, , , , , , ARCHIVE, , EP141982
    OLIVIA, EP, E,  ,  ,  ,  , 15, 1982, HU, O, 1982091815, 1982092518, , , , , , ARCHIVE, , EP151982
      PAUL, EP, E,  ,  ,  ,  , 16, 1982, HU, O, 1982091818, 1982093006, , , , , , ARCHIVE, , EP161982
      ROSA, EP, E,  ,  ,  ,  , 17, 1982, TS, O, 1982093018, 1982100618, , , , , , ARCHIVE, , EP171982
    SERGIO, EP, E,  ,  ,  ,  , 18, 1982, HU, O, 1982101400, 1982102318, , , , , , ARCHIVE, , EP181982
      TARA, EP, E,  ,  ,  ,  , 19, 1982, TS, O, 1982101918, 1982102606, , , , , , ARCHIVE, , EP191982
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1983, TD, O, 1983072312, 1983072818, , , , , , ARCHIVE, , AL011983
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1983, TD, O, 1983072712, 1983070212, , , , , , ARCHIVE, , AL021983
    ALICIA, AL, L,  ,  ,  ,  , 03, 1983, HU, O, 1983081512, 1983082106, , , , , , ARCHIVE, , AL031983
     BARRY, AL, L,  ,  ,  ,  , 04, 1983, HU, O, 1983082318, 1983082912, , , , , , ARCHIVE, , AL041983
   CHANTAL, AL, L,  ,  ,  ,  , 05, 1983, HU, O, 1983091012, 1983091506, , , , , , ARCHIVE, , AL051983
      DEAN, AL, L,  ,  ,  ,  , 06, 1983, TS, O, 1983092618, 1983093018, , , , , , ARCHIVE, , AL061983
    ADOLPH, EP, E,  ,  ,  ,  , 01, 1983, HU, O, 1983052100, 1983052812, , , , , , ARCHIVE, , EP011983
   BARBARA, EP, E,  ,  ,  ,  , 02, 1983, HU, O, 1983060900, 1983061806, , , , , , ARCHIVE, , EP021983
     COSME, EP, E,  ,  ,  ,  , 03, 1983, TS, O, 1983070206, 1983070518, , , , , , ARCHIVE, , EP031983
   DALILIA, EP, E,  ,  ,  ,  , 04, 1983, TS, O, 1983070518, 1983071200, , , , , , ARCHIVE, , EP041983
     ERICK, EP, E,  ,  ,  ,  , 05, 1983, TS, O, 1983071206, 1983071618, , , , , , ARCHIVE, , EP051983
   FLOSSIE, EP, E,  ,  ,  ,  , 06, 1983, TS, O, 1983071700, 1983072112, , , , , , ARCHIVE, , EP061983
       GIL, EP, E, C,  ,  ,  , 07, 1983, HU, O, 1983072312, 1983080500, , , , , , ARCHIVE, , EP071983
 HENRIETTE, EP, E,  ,  ,  ,  , 08, 1983, HU, O, 1983072700, 1983080606, , , , , , ARCHIVE, , EP081983
    ISMAEL, EP, E,  ,  ,  ,  , 09, 1983, HU, O, 1983080818, 1983081412, , , , , , ARCHIVE, , EP091983
  JULIETTE, EP, E,  ,  ,  ,  , 10, 1983, TS, O, 1983082418, 1983090106, , , , , , ARCHIVE, , EP101983
      KIKO, EP, E,  ,  ,  ,  , 11, 1983, HU, O, 1983083106, 1983090900, , , , , , ARCHIVE, , EP111983
    LORENA, EP, E,  ,  ,  ,  , 12, 1983, HU, O, 1983090606, 1983091412, , , , , , ARCHIVE, , EP121983
    MANUEL, EP, E,  ,  ,  ,  , 13, 1983, HU, O, 1983091206, 1983092012, , , , , , ARCHIVE, , EP131983
     NARDA, EP, E, C,  ,  ,  , 14, 1983, TS, O, 1983092100, 1983100100, , , , , , ARCHIVE, , EP141983
    OCTAVE, EP, E,  ,  ,  ,  , 15, 1983, TS, O, 1983092718, 1983100212, , , , , , ARCHIVE, , EP151983
 PRISCILLA, EP, E,  ,  ,  ,  , 16, 1983, HU, O, 1983093018, 1983100700, , , , , , ARCHIVE, , EP161983
   RAYMOND, EP, E, C,  ,  ,  , 17, 1983, HU, O, 1983100806, 1983102018, , , , , , ARCHIVE, , EP171983
     SONIA, EP, E, C,  ,  ,  , 18, 1983, TS, O, 1983100918, 1983101418, , , , , , ARCHIVE, , EP181983
      TICO, EP, E,  ,  ,  ,  , 19, 1983, HU, O, 1983101112, 1983101918, , , , , , ARCHIVE, , EP191983
     VELMA, EP, E,  ,  ,  ,  , 20, 1983, TS, O, 1983110118, 1983110306, , , , , , ARCHIVE, , EP201983
    WINNIE, EP, E,  ,  ,  ,  , 21, 1983, HU, O, 1983120412, 1983120712, , , , , , ARCHIVE, , EP211983
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1984, TD, O, 1984061112, 1984061400, , , , , , ARCHIVE, , AL011984
   UNNAMED, AL, L,  ,  ,  ,  , 02, 1984, TD, O, 1984061812, 1984062006, , , , , , ARCHIVE, , AL021984
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1984, TD, O, 1984072406, 1984072618, , , , , , ARCHIVE, , AL031984
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1984, TD, O, 1984080612, 1984080818, , , , , , ARCHIVE, , AL041984
   SUBTROP, AL, L,  ,  ,  ,  , 05, 1984, SS, O, 1984081806, 1984082112, , , , , , ARCHIVE, , AL051984
    ARTHUR, AL, L,  ,  ,  ,  , 06, 1984, TS, O, 1984082818, 1984090518, , , , , , ARCHIVE, , AL061984
    BERTHA, AL, L,  ,  ,  ,  , 07, 1984, TS, O, 1984083012, 1984090418, , , , , , ARCHIVE, , AL071984
     CESAR, AL, L,  ,  ,  ,  , 08, 1984, TS, O, 1984083100, 1984090218, , , , , , ARCHIVE, , AL081984
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1984, TD, O, 1984090612, 1984090806, , , , , , ARCHIVE, , AL091984
     DIANA, AL, L,  ,  ,  ,  , 10, 1984, HU, O, 1984090812, 1984091606, , , , , , ARCHIVE, , AL101984
   EDOUARD, AL, L,  ,  ,  ,  , 11, 1984, TS, O, 1984091400, 1984091512, , , , , , ARCHIVE, , AL111984
      FRAN, AL, L,  ,  ,  ,  , 12, 1984, TS, O, 1984091512, 1984092012, , , , , , ARCHIVE, , AL121984
    GUSTAV, AL, L,  ,  ,  ,  , 13, 1984, TS, O, 1984091618, 1984091906, , , , , , ARCHIVE, , AL131984
  HORTENSE, AL, L,  ,  ,  ,  , 14, 1984, HU, O, 1984092300, 1984100218, , , , , , ARCHIVE, , AL141984
   ISIDORE, AL, L,  ,  ,  ,  , 15, 1984, TS, O, 1984092512, 1984100112, , , , , , ARCHIVE, , AL151984
 JOSEPHINE, AL, L,  ,  ,  ,  , 16, 1984, HU, O, 1984100706, 1984102100, , , , , , ARCHIVE, , AL161984
   UNNAMED, AL, L,  ,  ,  ,  , 17, 1984, TD, O, 1984102506, 1984102800, , , , , , ARCHIVE, , AL171984
     KLAUS, AL, L,  ,  ,  ,  , 18, 1984, HU, O, 1984110518, 1984111318, , , , , , ARCHIVE, , AL181984
   UNNAMED, AL, L,  ,  ,  ,  , 19, 1984, TD, O, 1984112312, 1984112806, , , , , , ARCHIVE, , AL191984
      LILI, AL, L,  ,  ,  ,  , 20, 1984, HU, O, 1984121212, 1984122412, , , , , , ARCHIVE, , AL201984
      KELI, CP, C,  ,  ,  ,  , 01, 1984, HU, O, 1984081618, 1984082200, , , , , , ARCHIVE, , CP011984
      MOKE, CP, C,  ,  ,  ,  , 02, 1984, TS, O, 1984090406, 1984090500, , , , , , ARCHIVE, , CP021984
      ALMA, EP, E,  ,  ,  ,  , 01, 1984, TS, O, 1984051718, 1984052118, , , , , , ARCHIVE, , EP011984
     BORIS, EP, E,  ,  ,  ,  , 02, 1984, HU, O, 1984052818, 1984061800, , , , , , ARCHIVE, , EP021984
  CRISTINA, EP, E,  ,  ,  ,  , 03, 1984, HU, O, 1984061706, 1984062600, , , , , , ARCHIVE, , EP031984
   DOUGLAS, EP, E, C,  ,  ,  , 04, 1984, HU, O, 1984062500, 1984070618, , , , , , ARCHIVE, , EP041984
     ELIDA, EP, E,  ,  ,  ,  , 05, 1984, HU, O, 1984062800, 1984070818, , , , , , ARCHIVE, , EP051984
    FAUSTO, EP, E,  ,  ,  ,  , 06, 1984, HU, O, 1984070312, 1984071000, , , , , , ARCHIVE, , EP061984
 GENEVIEVE, EP, E,  ,  ,  ,  , 07, 1984, HU, O, 1984070706, 1984071412, , , , , , ARCHIVE, , EP071984
    HERNAN, EP, E,  ,  ,  ,  , 08, 1984, TS, O, 1984072712, 1984080100, , , , , , ARCHIVE, , EP081984
    ISELLE, EP, E,  ,  ,  ,  , 09, 1984, HU, O, 1984080318, 1984081212, , , , , , ARCHIVE, , EP091984
     JULIO, EP, E,  ,  ,  ,  , 10, 1984, TS, O, 1984081500, 1984082012, , , , , , ARCHIVE, , EP101984
     KENNA, EP, E, C,  ,  ,  , 11, 1984, TS, O, 1984081618, 1984082118, , , , , , ARCHIVE, , EP111984
      LALA, EP, E, C,  ,  ,  , 12, 1984, TS, O, 1984082318, 1984090218, , , , , , ARCHIVE, , EP121984
    LOWELL, EP, E,  ,  ,  ,  , 13, 1984, HU, O, 1984082606, 1984083006, , , , , , ARCHIVE, , EP131984
     MARIE, EP, E,  ,  ,  ,  , 14, 1984, HU, O, 1984090512, 1984091100, , , , , , ARCHIVE, , EP141984
   NORBERT, EP, E,  ,  ,  ,  , 15, 1984, HU, O, 1984091418, 1984092606, , , , , , ARCHIVE, , EP151984
     ODILE, EP, E,  ,  ,  ,  , 16, 1984, HU, O, 1984091716, 1984092300, , , , , , ARCHIVE, , EP161984
      POLO, EP, E,  ,  ,  ,  , 17, 1984, HU, O, 1984092600, 1984100312, , , , , , ARCHIVE, , EP171984
    RACHEL, EP, E,  ,  ,  ,  , 18, 1984, TS, O, 1984100718, 1984101612, , , , , , ARCHIVE, , EP181984
     SIMON, EP, E,  ,  ,  ,  , 19, 1984, TS, O, 1984103100, 1984110800, , , , , , ARCHIVE, , EP191984
       ANA, AL, L,  ,  ,  ,  , 01, 1985, TS, O, 1985071518, 1985071912, , , , , , ARCHIVE, , AL011985
       BOB, AL, L,  ,  ,  ,  , 02, 1985, HU, O, 1985072106, 1985072600, , , , , , ARCHIVE, , AL021985
 CLAUDETTE, AL, L,  ,  ,  ,  , 03, 1985, HU, O, 1985080918, 1985081700, , , , , , ARCHIVE, , AL031985
     DANNY, AL, L,  ,  ,  ,  , 04, 1985, HU, O, 1985081200, 1985082018, , , , , , ARCHIVE, , AL041985
     ELENA, AL, L,  ,  ,  ,  , 05, 1985, HU, O, 1985082800, 1985090418, , , , , , ARCHIVE, , AL051985
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1985, TD, O, 1985090812, 1985091312, , , , , , ARCHIVE, , AL061985
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1985, TD, O, 1985091112, 1985091318, , , , , , ARCHIVE, , AL071985
    FABIAN, AL, L,  ,  ,  ,  , 08, 1985, TS, O, 1985091518, 1985091912, , , , , , ARCHIVE, , AL081985
    GLORIA, AL, L,  ,  ,  ,  , 09, 1985, HU, O, 1985091612, 1985100200, , , , , , ARCHIVE, , AL091985
     HENRI, AL, L,  ,  ,  ,  , 10, 1985, TS, O, 1985092118, 1985092500, , , , , , ARCHIVE, , AL101985
    ISABEL, AL, L,  ,  ,  ,  , 11, 1985, TS, O, 1985100700, 1985101512, , , , , , ARCHIVE, , AL111985
      JUAN, AL, L,  ,  ,  ,  , 12, 1985, HU, O, 1985102600, 1985110118, , , , , , ARCHIVE, , AL121985
      KATE, AL, L,  ,  ,  ,  , 13, 1985, HU, O, 1985111518, 1985112318, , , , , , ARCHIVE, , AL131985
   UNNAMED, AL, L,  ,  ,  ,  , 14, 1985, TD, O, 1985120712, 1985120918, , , , , , ARCHIVE, , AL141985
      NELE, CP, C,  ,  ,  ,  , 01, 1985, HU, O, 1985102318, 1985103006, , , , , , ARCHIVE, , CP011985
    ANDRES, EP, E,  ,  ,  ,  , 01, 1985, TS, O, 1985060518, 1985061206, , , , , , ARCHIVE, , EP011985
    BLANCA, EP, E,  ,  ,  ,  , 02, 1985, HU, O, 1985060618, 1985061618, , , , , , ARCHIVE, , EP021985
    CARLOS, EP, E,  ,  ,  ,  , 03, 1985, TS, O, 1985060718, 1985061018, , , , , , ARCHIVE, , EP031985
   DOLORES, EP, E,  ,  ,  ,  , 04, 1985, HU, O, 1985062606, 1985070518, , , , , , ARCHIVE, , EP041985
   ENRIQUE, EP, E, C,  ,  ,  , 05, 1985, TS, O, 1985062706, 1985070518, , , , , , ARCHIVE, , EP051985
      FEFA, EP, E,  ,  ,  ,  , 06, 1985, TS, O, 1985070212, 1985070618, , , , , , ARCHIVE, , EP061985
 GUILLERMO, EP, E,  ,  ,  ,  , 07, 1985, TS, O, 1985070718, 1985071200, , , , , , ARCHIVE, , EP071985
     HILDA, EP, E,  ,  ,  ,  , 08, 1985, TS, O, 1985071800, 1985072012, , , , , , ARCHIVE, , EP081985
   IGNACIO, EP, E, C,  ,  ,  , 09, 1985, HU, O, 1985072100, 1985072700, , , , , , ARCHIVE, , EP091985
    JIMENA, EP, E,  ,  ,  ,  , 10, 1985, HU, O, 1985072000, 1985072900, , , , , , ARCHIVE, , EP101985
     KEVIN, EP, E,  ,  ,  ,  , 11, 1985, TS, O, 1985072900, 1985080618, , , , , , ARCHIVE, , EP111985
     LINDA, EP, E, C,  ,  ,  , 12, 1985, TS, O, 1985072918, 1985080900, , , , , , ARCHIVE, , EP121985
     MARTY, EP, E,  ,  ,  ,  , 13, 1985, HU, O, 1985080618, 1985081318, , , , , , ARCHIVE, , EP131985
      NORA, EP, E,  ,  ,  ,  , 14, 1985, TS, O, 1985081918, 1985082312, , , , , , ARCHIVE, , EP141985
      OLAF, EP, E,  ,  ,  ,  , 15, 1985, HU, O, 1985082200, 1985083106, , , , , , ARCHIVE, , EP151985
   PAULINE, EP, E, C,  ,  ,  , 16, 1985, HU, O, 1985082718, 1985090918, , , , , , ARCHIVE, , EP161985
      RICK, EP, E, C,  ,  ,  , 17, 1985, HU, O, 1985090100, 1985091200, , , , , , ARCHIVE, , EP171985
    SANDRA, EP, E,  ,  ,  ,  , 18, 1985, HU, O, 1985090518, 1985091700, , , , , , ARCHIVE, , EP181985
     TERRY, EP, E,  ,  ,  ,  , 19, 1985, HU, O, 1985091518, 1985092418, , , , , , ARCHIVE, , EP191985
    VIVIAN, EP, E,  ,  ,  ,  , 20, 1985, TS, O, 1985091806, 1985092118, , , , , , ARCHIVE, , EP201985
     WALDO, EP, E,  ,  ,  ,  , 21, 1985, HU, O, 1985100700, 1985100912, , , , , , ARCHIVE, , EP211985
      XINA, EP, E,  ,  ,  ,  , 22, 1985, HU, O, 1985102506, 1985110506, , , , , , ARCHIVE, , EP221985
    ANDREW, AL, L,  ,  ,  ,  , 01, 1986, TS, O, 1986060500, 1986060818, , , , , , ARCHIVE, , AL011986
    BONNIE, AL, L,  ,  ,  ,  , 02, 1986, HU, O, 1986062318, 1986062812, , , , , , ARCHIVE, , AL021986
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1986, TD, O, 1986072312, 1986072812, , , , , , ARCHIVE, , AL031986
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1986, TD, O, 1986080406, 1986080518, , , , , , ARCHIVE, , AL041986
   CHARLEY, AL, L,  ,  ,  ,  , 05, 1986, HU, O, 1986081312, 1986083000, , , , , , ARCHIVE, , AL051986
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1986, TD, O, 1986083012, 1986090412, , , , , , ARCHIVE, , AL061986
   UNNAMED, AL, L,  ,  ,  ,  , 07, 1986, TD, O, 1986090112, 1986090412, , , , , , ARCHIVE, , AL071986
  DANIELLE, AL, L,  ,  ,  ,  , 08, 1986, TS, O, 1986090706, 1986091012, , , , , , ARCHIVE, , AL081986
      EARL, AL, L,  ,  ,  ,  , 09, 1986, HU, O, 1986091018, 1986092000, , , , , , ARCHIVE, , AL091986
   FRANCES, AL, L,  ,  ,  ,  , 10, 1986, HU, O, 1986111818, 1986112118, , , , , , ARCHIVE, , AL101986
    AGATHA, EP, E,  ,  ,  ,  , 01, 1986, HU, O, 1986052200, 1986052912, , , , , , ARCHIVE, , EP011986
      BLAS, EP, E,  ,  ,  ,  , 02, 1986, TS, O, 1986061712, 1986061900, , , , , , ARCHIVE, , EP021986
     CELIA, EP, E,  ,  ,  ,  , 03, 1986, HU, O, 1986062418, 1986063018, , , , , , ARCHIVE, , EP031986
     DARBY, EP, E,  ,  ,  ,  , 04, 1986, TS, O, 1986070318, 1986070718, , , , , , ARCHIVE, , EP041986
   ESTELLE, EP, E, C,  ,  ,  , 05, 1986, HU, O, 1986071612, 1986072606, , , , , , ARCHIVE, , EP051986
     FRANK, EP, E, C,  ,  ,  , 06, 1986, HU, O, 1986072418, 1986080300, , , , , , ARCHIVE, , EP061986
 GEORGETTE, EP, E,  ,  ,  ,  , 07, 1986, TS, O, 1986080300, 1986080418, , , , , , ARCHIVE, , EP071986
    HOWARD, EP, E,  ,  ,  ,  , 08, 1986, TS, O, 1986081612, 1986081812, , , , , , ARCHIVE, , EP081986
      ISIS, EP, E,  ,  ,  ,  , 09, 1986, TS, O, 1986081918, 1986082400, , , , , , ARCHIVE, , EP091986
    JAVIER, EP, E,  ,  ,  ,  , 10, 1986, HU, O, 1986082012, 1986083106, , , , , , ARCHIVE, , EP101986
       KAY, EP, E,  ,  ,  ,  , 11, 1986, TS, O, 1986082818, 1986090312, , , , , , ARCHIVE, , EP111986
    LESTER, EP, E, C,  ,  ,  , 12, 1986, TS, O, 1986091318, 1986091700, , , , , , ARCHIVE, , EP121986
  MADELINE, EP, E,  ,  ,  ,  , 13, 1986, TS, O, 1986091518, 1986092212, , , , , , ARCHIVE, , EP131986
    NEWTON, EP, E,  ,  ,  ,  , 14, 1986, Xb, O, 1986091812, 1986092318, , , , , , ARCHIVE, , EP141986
    ORLENE, EP, E, C,  ,  ,  , 15, 1986, HU, O, 1986092100, 1986092500, , , , , , ARCHIVE, , EP151986
     PAINE, EP, E,  ,  ,  ,  , 16, 1986, HU, O, 1986092800, 1986100218, , , , , , ARCHIVE, , EP161986
    ROSLYN, EP, E,  ,  ,  ,  , 17, 1986, HU, O, 1986101518, 1986102212, , , , , , ARCHIVE, , EP171986
   UNNAMED, AL, L,  ,  ,  ,  , 01, 1987, TD, O, 1987052412, 1987060100, , , , , , ARCHIVE, , AL011987
    ARLENE, AL, L,  ,  ,  ,  , 02, 1987, HU, O, 1987080800, 1987082800, , , , , , ARCHIVE, , AL021987
   UNNAMED, AL, L,  ,  ,  ,  , 03, 1987, TS, O, 1987080912, 1987081706, , , , , , ARCHIVE, , AL031987
   UNNAMED, AL, L,  ,  ,  ,  , 04, 1987, TD, O, 1987081300, 1987081512, , , , , , ARCHIVE, , AL041987
      BRET, AL, L,  ,  ,  ,  , 05, 1987, TS, O, 1987081800, 1987082406, , , , , , ARCHIVE, , AL051987
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1987, TD, O, 1987083012, 1987090218, , , , , , ARCHIVE, , AL061987
     CINDY, AL, L,  ,  ,  ,  , 07, 1987, TS, O, 1987090512, 1987091018, , , , , , ARCHIVE, , AL071987
   UNNAMED, AL, L,  ,  ,  ,  , 08, 1987, TD, O, 1987090600, 1987090818, , , , , , ARCHIVE, , AL081987
   UNNAMED, AL, L,  ,  ,  ,  , 09, 1987, TD, O, 1987090700, 1987090812, , , , , , ARCHIVE, , AL091987
    DENNIS, AL, L,  ,  ,  ,  , 10, 1987, TS, O, 1987090818, 1987092018, , , , , , ARCHIVE, , AL101987
   UNNAMED, AL, L,  ,  ,  ,  , 11, 1987, TD, O, 1987091312, 1987091712, , , , , , ARCHIVE, , AL111987
     EMILY, AL, L,  ,  ,  ,  , 12, 1987, HU, O, 1987092000, 1987092618, , , , , , ARCHIVE, , AL121987
     FLOYD, AL, L,  ,  ,  ,  , 13, 1987, HU, O, 1987100906, 1987101400, , , , , , ARCHIVE, , AL131987
   UNNAMED, AL, L,  ,  ,  ,  , 14, 1987, TD, O, 1987103118, 1987110418, , , , , , ARCHIVE, , AL141987
       OKA, CP, C,  ,  ,  ,  , 01, 1987, TS, O, 1987082600, 1987082918, , , , , , ARCHIVE, , CP011987
      PEKE, CP, C,  ,  ,  ,  , 02, 1987, HU, O, 1987092118, 1987092718, , , , , , ARCHIVE, , CP021987
    ADRIAN, EP, E,  ,  ,  ,  , 01, 1987, TS, O, 1987060718, 1987060912, , , , , , ARCHIVE, , EP011987
   BEATRIZ, EP, E,  ,  ,  ,  , 02, 1987, TS, O, 1987070312, 1987070700, , , , , , ARCHIVE, , EP021987
    CALVIN, EP, E,  ,  ,  ,  , 03, 1987, TS, O, 1987070518, 1987071006, , , , , , ARCHIVE, , EP031987
      DORA, EP, E,  ,  ,  ,  , 04, 1987, TS, O, 1987071500, 1987072000, , , , , , ARCHIVE, , EP041987
    EUGENE, EP, E,  ,  ,  ,  , 05, 1987, HU, O, 1987072200, 1987072612, , , , , , ARCHIVE, , EP051987
  FERNANDA, EP, E, C,  ,  ,  , 06, 1987, TS, O, 1987072406, 1987073112, , , , , , ARCHIVE, , EP061987
      GREG, EP, E,  ,  ,  ,  , 07, 1987, HU, O, 1987072800, 1987080318, , , , , , ARCHIVE, , EP071987
    HILARY, EP, E,  ,  ,  ,  , 08, 1987, HU, O, 1987073118, 1987080906, , , , , , ARCHIVE, , EP081987
     IRWIN, EP, E,  ,  ,  ,  , 09, 1987, TS, O, 1987080318, 1987080906, , , , , , ARCHIVE, , EP091987
      JOVA, EP, E, C,  ,  ,  , 10, 1987, HU, O, 1987081318, 1987082200, , , , , , ARCHIVE, , EP101987
      KNUT, EP, E,  ,  ,  ,  , 11, 1987, TS, O, 1987082818, 1987083018, , , , , , ARCHIVE, , EP111987
     LIDIA, EP, E,  ,  ,  ,  , 12, 1987, HU, O, 1987082912, 1987090312, , , , , , ARCHIVE, , EP121987
       MAX, EP, E,  ,  ,  ,  , 13, 1987, HU, O, 1987090912, 1987091612, , , , , , ARCHIVE, , EP131987
     NORMA, EP, E,  ,  ,  ,  , 14, 1987, HU, O, 1987091412, 1987092012, , , , , , ARCHIVE, , EP141987
      OTIS, EP, E,  ,  ,  ,  , 15, 1987, HU, O, 1987092000, 1987092618, , , , , , ARCHIVE, , EP151987
     PILAR, EP, E,  ,  ,  ,  , 16, 1987, TS, O, 1987093012, 1987100112, , , , , , ARCHIVE, , EP161987
     RAMON, EP, E,  ,  ,  ,  , 17, 1987, HU, O, 1987100518, 1987101206, , , , , , ARCHIVE, , EP171987
     SELMA, EP, E,  ,  ,  ,  , 18, 1987, TS, O, 1987102700, 1987103106, , , , , , ARCHIVE, , EP181987
   ALBERTO, AL, L,  ,  ,  ,  , 01, 1988, TS, O, 1988080518, 1988080818, , , , , , ARCHIVE, , AL011988
     BERYL, AL, L,  ,  ,  ,  , 02, 1988, TS, O, 1988080800, 1988081018, , , , , , ARCHIVE, , AL021988
     CHRIS, AL, L,  ,  ,  ,  , 03, 1988, TS, O, 1988082112, 1988083018, , , , , , ARCHIVE, , AL031988
     DEBBY, AL, L,  ,  ,  ,  , 04, 1988, HU, O, 1988083118, 1988090818, , , , , , ARCHIVE, , AL041988
   ERNESTO, AL, L,  ,  ,  ,  , 05, 1988, TS, O, 1988090300, 1988090500, , , , , , ARCHIVE, , AL051988
   UNNAMED, AL, L,  ,  ,  ,  , 06, 1988, TS, O, 1988090700, 1988091000, , , , , , ARCHIVE, , AL061988
  FLORENCE, AL, L,  ,  ,  ,  , 07, 1988, HU, O, 1988090706, 1988091112, , , , , , ARCHIVE, , AL071988
   GILBERT, AL, L,  ,  ,  ,  , 08, 1988, HU, O, 1988090818, 1988092000, , , , , , ARCHIVE, , AL081988
    HELENE, AL, L,  ,  ,  ,  , 09, 1988, HU, O, 1988091918, 1988093012, , , , , , ARCHIVE, , AL091988
     ISAAC, AL, L,  ,  ,  ,  , 10, 1988, TS, O, 1988092818, 1988100112, , , , , , ARCHIVE, , AL101988
      JOAN, AL, L,  ,  ,  ,  , 11, 1988, HU, O, 1988101018, 1988102306, , , , , , ARCHIVE, , AL111988
     KEITH, AL, L,  ,  ,  ,  , 12, 1988, TS, O, 1988111718, 1988112618, , , , , , ARCHIVE, , AL121988
   UNNAMED, AL, L,  ,  ,  ,  , 13, 1988, TD, O, 1988053112, 1988060212, , , , , , ARCHIVE, , AL131988
   UNNAMED, AL, L,  ,  ,  ,  , 14, 1988, TD, O, 1988081200, 1988081412, , , , , , ARCHIVE, , AL141988
   UNNAMED, AL, L,  ,  ,  ,  , 15, 1988, TD, O, 1988082012, 1988083112, , , , , , ARCHIVE, , AL151988
   UNNAMED, AL, L,  ,  ,  ,  , 16, 1988, TD, O, 1988082018, 1988082412, , , , , , ARCHIVE, , AL161988
   UNNAMED, AL, L,  ,  ,  ,  , 17, 1988, TD, O, 1988090400, 1988090406, , , , , , ARCHIVE, , AL171988
   UNNAMED, AL, L,  ,  ,  ,  , 18, 1988, TD, O, 1988092718, 1988092900, , , , , , ARCHIVE, , AL181988
   UNNAMED, AL, L,  ,  ,  ,  , 19, 1988, TD, O, 1988101918, 1988102118, , , , , , ARCHIVE, , AL191988
     ULEKI, CP, C, W,  ,  ,  , 01, 1988, HU, O, 1988082818, 1988091306, , , , , , ARCHIVE, , CP011988
      WILA, CP, C,  ,  ,  ,  , 02, 1988, TS, O, 1988092100, 1988092518, , , , , , ARCHIVE, , CP021988
    ALETTA, EP, E,  ,  ,  ,  , 01, 1988, TS, O, 1988061618, 1988062112, , , , , , ARCHIVE, , EP011988
       BUD, EP, E,  ,  ,  ,  , 02, 1988, TS, O, 1988062018, 1988062218, , , , , , ARCHIVE, , EP021988
  CARLOTTA, EP, E,  ,  ,  ,  , 03, 1988, HU, O, 1988070818, 1988071512, , , , , , ARCHIVE, , EP031988
    DANIEL, EP, E,  ,  ,  ,  , 04, 1988, TS, O, 1988071912, 1988072618, , , , , , ARCHIVE, , EP041988
    EMILIA, EP, E,  ,  ,  ,  , 05, 1988, TS, O, 1988072718, 1988080218, , , , , , ARCHIVE, , EP051988
     FABIO, EP, E, C,  ,  ,  , 06, 1988, HU, O, 1988072818, 1988080918, , , , , , ARCHIVE, , EP061988
     GILMA, EP, E, C,  ,  ,  , 07, 1988, TS, O, 1988072812, 1988080312, , , , , , ARCHIVE, , EP071988
    HECTOR, EP, E,  ,  ,  ,  , 08, 1988, HU, O, 1988073018, 1988080918, , , , , , ARCHIVE, , EP081988
       IVA, EP, E,  ,  ,  ,  , 09, 1988, HU, O, 1988080500, 1988081318, , , , , , ARCHIVE, , EP091988
      JOHN, EP, E,  ,  ,  ,  , 10, 1988, TS, O, 1988081618, 1988082106, , , , , , ARCHIVE, , EP101988
    KRISTY, EP, E,  ,  ,  ,  , 11, 1988, HU, O, 1988082900, 1988090612, , , , , , ARCHIVE, , EP111988
      LANE, EP, E,  ,  ,  ,  , 12, 1988, HU, O, 1988092106, 1988093012, , , , , , ARCHIVE, , EP121988
    MIRIAM, EP, E,  ,  ,  ,  , 13, 1988, TS, O, 1988102306, 1988110212, , , , , , ARCHIVE, , EP131988
   UNNAMED, EP, E,  ,  ,  ,  , 14, 1988, TD, O, 1988061512, 1988061818, , , , , , ARCHIVE, , EP141988
   UNNAMED, EP, E,  ,  ,  ,  , 15, 1988, TD, O, 1988070200, 1988070406, , , , , , ARCHIVE, , EP151988
   UNNAMED, EP, E,  ,  ,  ,  , 16, 1988, TD, O, 1988072818, 1988072918, , , , , , ARCHIVE, , EP161988
   UNNAMED, EP, E,  ,  ,  ,  , 17, 1988, TD, O, 1988081400, 1988081618, , , , , , ARCHIVE, , EP171988
   UNNAMED, EP, E,  ,  ,  ,  , 18, 1988, TD, O, 1988082700, 1988082900, , , , , , ARCHIVE, , EP181988
   UNNAMED, EP, E,  ,  ,  ,  , 19, 1988, TD, O, 1988091218, 1988091518, , , , , , ARCHIVE, , EP191988
   UNNAMED, EP, E,  ,  ,  ,  , 20, 1988, TD, O, 1988101106, 1988101218, , , , , , ARCHIVE, , EP201988
       ONE, AL, L,  ,  ,  ,  , 01, 1989, TD, O, 1989061518, 1989061706, , , , , , ARCHIVE, , AL011989
   ALLISON, AL, L,  ,  ,  ,  , 02, 1989, TS, O, 1989062418, 1989070112, , , , , , ARCHIVE, , AL021989
     BARRY, AL, L,  ,  ,  ,  , 03, 1989, TS, O, 1989070918, 1989071400, , , , , , ARCHIVE, , AL031989
   CHANTAL, AL, L,  ,  ,  ,  , 04, 1989, HU, O, 1989073012, 1989080300, , , , , , ARCHIVE, , AL041989
      DEAN, AL, L,  ,  ,  ,  , 05, 1989, HU, O, 1989073106, 1989080906, , , , , , ARCHIVE, , AL051989
       SIX, AL, L,  ,  ,  ,  , 06, 1989, TD, O, 1989080818, 1989081712, , , , , , ARCHIVE, , AL061989
      ERIN, AL, L,  ,  ,  ,  , 07, 1989, HU, O, 1989081800, 1989082700, , , , , , ARCHIVE, , AL071989
     FELIX, AL, L,  ,  ,  ,  , 08, 1989, HU, O, 1989082600, 1989091012, , , , , , ARCHIVE, , AL081989
      NINE, AL, L,  ,  ,  ,  , 09, 1989, TD, O, 1989082706, 1989081812, , , , , , ARCHIVE, , AL091989
 GABRIELLE, AL, L,  ,  ,  ,  , 10, 1989, HU, O, 1989083012, 1989091312, , , , , , ARCHIVE, , AL101989
      HUGO, AL, L,  ,  ,  ,  , 11, 1989, HU, O, 1989091012, 1989092512, , , , , , ARCHIVE, , AL111989
      IRIS, AL, L,  ,  ,  ,  , 12, 1989, TS, O, 1989091618, 1989092118, , , , , , ARCHIVE, , AL121989
  THIRTEEN, AL, L,  ,  ,  ,  , 13, 1989, TD, O, 1989100200, 1989100512, , , , , , ARCHIVE, , AL131989
     JERRY, AL, L,  ,  ,  ,  , 14, 1989, HU, O, 1989101212, 1989101618, , , , , , ARCHIVE, , AL141989
     KAREN, AL, L,  ,  ,  ,  , 15, 1989, TS, O, 1989112812, 1989120406, , , , , , ARCHIVE, , AL151989
    ADOLPH, EP, E,  ,  ,  ,  , 01, 1989, TS, O, 1989053118, 1989060518, , , , , , ARCHIVE, , EP011989
   BARBARA, EP, E,  ,  ,  ,  , 02, 1989, HU, O, 1989061518, 1989062100, , , , , , ARCHIVE, , EP021989
     COSME, EP, E,  ,  ,  ,  , 03, 1989, HU, O, 1989061800, 1989062312, , , , , , ARCHIVE, , EP031989
      FOUR, EP, E,  ,  ,  ,  , 04, 1989, TD, O, 1989070900, 1989071018, , , , , , ARCHIVE, , EP041989
      FIVE, EP, E,  ,  ,  ,  , 05, 1989, TD, O, 1989070900, 1989071318, , , , , , ARCHIVE, , EP051989
   DALILIA, EP, E,  ,  ,  ,  , 06, 1989, HU, O, 1989071112, 1989072118, , , , , , ARCHIVE, , EP061989
     SEVEN, EP, E,  ,  ,  ,  , 07, 1989, TD, O, 1989071500, 1989071806, , , , , , ARCHIVE, , EP071989
     ERICK, EP, E,  ,  ,  ,  , 08, 1989, TS, O, 1989071900, 1989072106, , , , , , ARCHIVE, , EP081989
   FLOSSIE, EP, E,  ,  ,  ,  , 09, 1989, TS, O, 1989072318, 1989072806, , , , , , ARCHIVE, , EP091989
       GIL, EP, E,  ,  ,  ,  , 10, 1989, HU, O, 1989073000, 1989080512, , , , , , ARCHIVE, , EP101989
 HENRIETTE, EP, E,  ,  ,  ,  , 11, 1989, TS, O, 1989081500, 1989081800, , , , , , ARCHIVE, , EP111989
    ISMAEL, EP, E,  ,  ,  ,  , 12, 1989, HU, O, 1989081412, 1989082512, , , , , , ARCHIVE, , EP121989
  JULIETTE, EP, E,  ,  ,  ,  , 13, 1989, TS, O, 1989082112, 1989082518, , , , , , ARCHIVE, , EP131989
      KIKO, EP, E,  ,  ,  ,  , 14, 1989, HU, O, 1989082512, 1989082918, , , , , , ARCHIVE, , EP141989
    LORENA, EP, E,  ,  ,  ,  , 15, 1989, HU, O, 1989082718, 1989090618, , , , , , ARCHIVE, , EP151989
    MANUEL, EP, E,  ,  ,  ,  , 16, 1989, TS, O, 1989082818, 1989083118, , , , , , ARCHIVE, , EP161989
     NARDA, EP, E,  ,  ,  ,  , 17, 1989, TS, O, 1989090300, 1989090800, , , , , , ARCHIVE, , EP171989
    OCTAVE, EP, E,  ,  ,  ,  , 18, 1989, HU, O, 1989090818, 1989091618, , , , , , ARCHIVE, , EP181989
 PRISCILLA, EP, E,  ,  ,  ,  , 19, 1989, TS, O, 1989092106, 1989092518, , , , , , ARCHIVE, , EP191989
    TWENTY, EP, E,  ,  ,  ,  , 20, 1989, TD, O, 1989092518, 1989092712, , , , , , ARCHIVE, , EP201989
   RAYMOND, EP, E,  ,  ,  ,  , 21, 1989, HU, O, 1989092500, 1989100518, , , , , , ARCHIVE, , EP211989
TWENTY-TWO, EP, E,  ,  ,  ,  , 22, 1989, TD, O, 1989100312, 1989100806, , , , , , ARCHIVE, , EP221989
TWENTY-THR, EP, E,  ,  ,  ,  , 23, 1989, TD, O, 1989101406, 1989101406, , , , , , ARCHIVE, , EP231989
TWENTY-FOU, EP, E,  ,  ,  ,  , 24, 1989, TD, O, 1989101600, 1989101912, , , , , , ARCHIVE, , EP241989
       ONE, AL, L,  ,  ,  ,  , 01, 1990, TD, O, 1990052418, 1990052606, , , , , , ARCHIVE, , AL011990
    ARTHUR, AL, L,  ,  ,  ,  , 02, 1990, TS, O, 1990072206, 1990072712, , , , , , ARCHIVE, , AL021990
    BERTHA, AL, L,  ,  ,  ,  , 03, 1990, HU, O, 1990072412, 1990080212, , , , , , ARCHIVE, , AL031990
     CESAR, AL, L,  ,  ,  ,  , 04, 1990, TS, O, 1990073100, 1990080712, , , , , , ARCHIVE, , AL041990
     DIANA, AL, L,  ,  ,  ,  , 05, 1990, HU, O, 1990080400, 1990080912, , , , , , ARCHIVE, , AL051990
   EDOUARD, AL, L,  ,  ,  ,  , 06, 1990, TS, O, 1990080218, 1990081312, , , , , , ARCHIVE, , AL061990
      FRAN, AL, L,  ,  ,  ,  , 07, 1990, TS, O, 1990081112, 1990081412, , , , , , ARCHIVE, , AL071990
    GUSTAV, AL, L,  ,  ,  ,  , 08, 1990, HU, O, 1990082406, 1990090306, , , , , , ARCHIVE, , AL081990
  HORTENSE, AL, L,  ,  ,  ,  , 09, 1990, TS, O, 1990082500, 1990083106, , , , , , ARCHIVE, , AL091990
   ISIDORE, AL, L,  ,  ,  ,  , 10, 1990, HU, O, 1990090400, 1990091712, , , , , , ARCHIVE, , AL101990
    ELEVEN, AL, L,  ,  ,  ,  , 11, 1990, TD, O, 1990091812, 1990092712, , , , , , ARCHIVE, , AL111990
 JOSEPHINE, AL, L,  ,  ,  ,  , 12, 1990, HU, O, 1990092106, 1990100612, , , , , , ARCHIVE, , AL121990
     KLAUS, AL, L,  ,  ,  ,  , 13, 1990, HU, O, 1990100312, 1990100912, , , , , , ARCHIVE, , AL131990
      LILI, AL, L,  ,  ,  ,  , 14, 1990, HU, O, 1990100606, 1990101512, , , , , , ARCHIVE, , AL141990
     MARCO, AL, L,  ,  ,  ,  , 15, 1990, TS, O, 1990100912, 1990101312, , , , , , ARCHIVE, , AL151990
      NANA, AL, L,  ,  ,  ,  , 16, 1990, HU, O, 1990101600, 1990102112, , , , , , ARCHIVE, , AL161990
       AKA, CP, C,  ,  ,  ,  , 01, 1990, TS, O, 1990080718, 1990081512, , , , , , ARCHIVE, , CP011990
      ALMA, EP, E,  ,  ,  ,  , 01, 1990, HU, O, 1990051218, 1990051812, , , , , , ARCHIVE, , EP011990
     BORIS, EP, E,  ,  ,  ,  , 02, 1990, HU, O, 1990060218, 1990060812, , , , , , ARCHIVE, , EP021990
  CRISTINA, EP, E,  ,  ,  ,  , 03, 1990, TS, O, 1990060812, 1990061606, , , , , , ARCHIVE, , EP031990
   DOUGLAS, EP, E,  ,  ,  ,  , 04, 1990, TS, O, 1990061900, 1990062318, , , , , , ARCHIVE, , EP041990
     ELIDA, EP, E,  ,  ,  ,  , 05, 1990, HU, O, 1990062606, 1990070212, , , , , , ARCHIVE, , EP051990
       SIX, EP, E,  ,  ,  ,  , 06, 1990, TD, O, 1990062918, 1990070318, , , , , , ARCHIVE, , EP061990
    FAUSTO, EP, E,  ,  ,  ,  , 07, 1990, HU, O, 1990070600, 1990071218, , , , , , ARCHIVE, , EP071990
 GENEVIEVE, EP, E,  ,  ,  ,  , 08, 1990, HU, O, 1990071000, 1990071812, , , , , , ARCHIVE, , EP081990
    HERNAN, EP, E,  ,  ,  ,  , 09, 1990, HU, O, 1990071912, 1990073100, , , , , , ARCHIVE, , EP091990
    ISELLE, EP, E,  ,  ,  ,  , 10, 1990, HU, O, 1990072012, 1990073012, , , , , , ARCHIVE, , EP101990
    ELEVEN, EP, E,  ,  ,  ,  , 11, 1990, TD, O, 1990072400, 1990072606, , , , , , ARCHIVE, , EP111990
    TWELVE, EP, E,  ,  ,  ,  , 12, 1990, TD, O, 1990081612, 1990081918, , , , , , ARCHIVE, , EP121990
     JULIO, EP, E,  ,  ,  ,  , 13, 1990, HU, O, 1990081700, 1990082418, , , , , , ARCHIVE, , EP131990
     KENNA, EP, E,  ,  ,  ,  , 14, 1990, HU, O, 1990082118, 1990083012, , , , , , ARCHIVE, , EP141990
    LOWELL, EP, E,  ,  ,  ,  , 15, 1990, HU, O, 1990082318, 1990090112, , , , , , ARCHIVE, , EP151990
     MARIE, EP, E,  ,  ,  ,  , 16, 1990, HU, O, 1990090712, 1990092100, , , , , , ARCHIVE, , EP161990
   NORBERT, EP, E,  ,  ,  ,  , 17, 1990, HU, O, 1990091000, 1990091912, , , , , , ARCHIVE, , EP171990
  EIGHTEEN, EP, E,  ,  ,  ,  , 18, 1990, TD, O, 1990090918, 1990091218, , , , , , ARCHIVE, , EP181990
     ODILE, EP, E,  ,  ,  ,  , 19, 1990, HU, O, 1990092312, 1990100200, , , , , , ARCHIVE, , EP191990
      POLO, EP, E,  ,  ,  ,  , 20, 1990, HU, O, 1990092818, 1990100118, , , , , , ARCHIVE, , EP201990
    RACHEL, EP, E,  ,  ,  ,  , 21, 1990, TS, O, 1990092700, 1990100300, , , , , , ARCHIVE, , EP211990
     SIMON, EP, E,  ,  ,  ,  , 22, 1990, TS, O, 1990100900, 1990101418, , , , , , ARCHIVE, , EP221990
     TRUDY, EP, E,  ,  ,  ,  , 23, 1990, HU, O, 1990101600, 1990110112, , , , , , ARCHIVE, , EP231990
     VANCE, EP, E,  ,  ,  ,  , 24, 1990, HU, O, 1990102118, 1990103118, , , , , , ARCHIVE, , EP241990
       ANA, AL, L,  ,  ,  ,  , 01, 1991, TS, O, 1991062912, 1991070512, , , , , , ARCHIVE, , AL011991
       TWO, AL, L,  ,  ,  ,  , 02, 1991, TD, O, 1991070518, 1991070700, , , , , , ARCHIVE, , AL021991
       BOB, AL, L,  ,  ,  ,  , 03, 1991, HU, O, 1991081600, 1991082900, , , , , , ARCHIVE, , AL031991
      FOUR, AL, L,  ,  ,  ,  , 04, 1991, TD, O, 1991082412, 1991082600, , , , , , ARCHIVE, , AL041991
      FIVE, AL, L,  ,  ,  ,  , 05, 1991, TD, O, 1991082812, 1991083112, , , , , , ARCHIVE, , AL051991
 CLAUDETTE, AL, L,  ,  ,  ,  , 06, 1991, HU, O, 1991090412, 1991091418, , , , , , ARCHIVE, , AL061991
     DANNY, AL, L,  ,  ,  ,  , 07, 1991, TS, O, 1991090700, 1991091112, , , , , , ARCHIVE, , AL071991
     ERIKA, AL, L,  ,  ,  ,  , 08, 1991, TS, O, 1991090818, 1991091218, , , , , , ARCHIVE, , AL081991
    FABIAN, AL, L,  ,  ,  ,  , 09, 1991, TS, O, 1991101500, 1991101700, , , , , , ARCHIVE, , AL091991
       TEN, AL, L,  ,  ,  ,  , 10, 1991, TD, O, 1991102412, 1991102512, , , , , , ARCHIVE, , AL101991
     GRACE, AL, L,  ,  ,  ,  , 11, 1991, HU, O, 1991102518, 1991102918, , , , , , ARCHIVE, , AL111991
   UNNAMED, AL, L,  ,  ,  ,  , 12, 1991, HU, O, 1991102818, 1991110218, , , , , , ARCHIVE, , AL121991
    ANDRES, EP, E,  ,  ,  ,  , 01, 1991, TS, O, 1991051606, 1991052000, , , , , , ARCHIVE, , EP011991
    BLANCA, EP, E,  ,  ,  ,  , 02, 1991, TS, O, 1991061418, 1991062200, , , , , , ARCHIVE, , EP021991
    CARLOS, EP, E,  ,  ,  ,  , 03, 1991, HU, O, 1991061612, 1991062712, , , , , , ARCHIVE, , EP031991
   DELORES, EP, E,  ,  ,  ,  , 04, 1991, HU, O, 1991062212, 1991062818, , , , , , ARCHIVE, , EP041991
      FIVE, EP, E,  ,  ,  ,  , 05, 1991, TD, O, 1991062812, 1991063000, , , , , , ARCHIVE, , EP051991
   ENRIQUE, EP, E,  ,  ,  ,  , 06, 1991, HU, O, 1991071512, 1991072118, , , , , , ARCHIVE, , EP061991
      FEFA, EP, E,  ,  ,  ,  , 07, 1991, HU, O, 1991072906, 1991080800, , , , , , ARCHIVE, , EP071991
 GUILLERMO, EP, E,  ,  ,  ,  , 08, 1991, HU, O, 1991080400, 1991081018, , , , , , ARCHIVE, , EP081991
     HILDA, EP, E,  ,  ,  ,  , 09, 1991, TS, O, 1991080800, 1991081406, , , , , , ARCHIVE, , EP091991
       TEN, EP, E,  ,  ,  ,  , 10, 1991, TD, O, 1991091212, 1991091400, , , , , , ARCHIVE, , EP101991
   IGNACIO, EP, E,  ,  ,  ,  , 11, 1991, TS, O, 1991091606, 1991091906, , , , , , ARCHIVE, , EP111991
    JIMENA, EP, E,  ,  ,  ,  , 12, 1991, HU, O, 1991092018, 1991100200, , , , , , ARCHIVE, , EP121991
     KEVIN, EP, E,  ,  ,  ,  , 13, 1991, HU, O, 1991092500, 1991101206, , , , , , ARCHIVE, , EP131991
     LINDA, EP, E,  ,  ,  ,  , 14, 1991, HU, O, 1991100312, 1991101318, , , , , , ARCHIVE, , EP141991
     MARTY, EP, E,  ,  ,  ,  , 15, 1991, HU, O, 1991100712, 1991101812, , , , , , ARCHIVE, , EP151991
      NORA, EP, E,  ,  ,  ,  , 16, 1991, HU, O, 1991110700, 1991111218, , , , , , ARCHIVE, , EP161991
   SUBTROP, AL, L,  ,  ,  ,  , 01, 1992, SS, O, 1992042112, 1992042418, , , , , , ARCHIVE, , AL011992
       ONE, AL, L,  ,  ,  ,  , 02, 1992, TD, O, 1992062512, 1992062612, , , , , , ARCHIVE, , AL021992
       TWO, AL, L,  ,  ,  ,  , 03, 1992, TD, O, 1992072418, 1992072612, , , , , , ARCHIVE, , AL031992
    ANDREW, AL, L,  ,  ,  ,  , 04, 1992, HU, O, 1992081618, 1992082806, , , , , , ARCHIVE, , AL041992
    BONNIE, AL, L,  ,  ,  ,  , 05, 1992, HU, O, 1992091718, 1992100218, , , , , , ARCHIVE, , AL051992
   CHARLEY, AL, L,  ,  ,  ,  , 06, 1992, HU, O, 1992092118, 1992092900, , , , , , ARCHIVE, , AL061992
  DANIELLE, AL, L,  ,  ,  ,  , 07, 1992, TS, O, 1992092212, 1992092612, , , , , , ARCHIVE, , AL071992
     SEVEN, AL, L,  ,  ,  ,  , 08, 1992, TD, O, 1992092512, 1992100112, , , , , , ARCHIVE, , AL081992
      EARL, AL, L,  ,  ,  ,  , 09, 1992, TS, O, 1992092618, 1992100318, , , , , , ARCHIVE, , AL091992
   FRANCES, AL, L,  ,  ,  ,  , 10, 1992, HU, O, 1992102212, 1992103000, , , , , , ARCHIVE, , AL101992
     EKEKA, CP, C,  ,  ,  ,  , 01, 1992, HU, O, 1992012618, 1992020900, , , , , , ARCHIVE, , CP011992
      HALI, CP, C,  ,  ,  ,  , 02, 1992, TS, O, 1992032806, 1992033018, , , , , , ARCHIVE, , CP021992
     THREE, CP, C,  ,  ,  ,  , 03, 1992, TD, O, 1992112200, 1992112300, , , , , , ARCHIVE, , CP031992
    AGATHA, EP, E,  ,  ,  ,  , 01, 1992, TS, O, 1992060112, 1992060518, , , , , , ARCHIVE, , EP011992
       TWO, EP, E,  ,  ,  ,  , 02, 1992, TD, O, 1992061618, 1992061812, , , , , , ARCHIVE, , EP021992
      BLAS, EP, E,  ,  ,  ,  , 03, 1992, TS, O, 1992062212, 1992062318, , , , , , ARCHIVE, , EP031992
     CELIA, EP, E,  ,  ,  ,  , 04, 1992, HU, O, 1992062212, 1992070418, , , , , , ARCHIVE, , EP041992
     DARBY, EP, E,  ,  ,  ,  , 05, 1992, HU, O, 1992070212, 1992071000, , , , , , ARCHIVE, , EP051992
   ESTELLE, EP, E,  ,  ,  ,  , 06, 1992, HU, O, 1992070900, 1992071706, , , , , , ARCHIVE, , EP061992
     FRANK, EP, E,  ,  ,  ,  , 07, 1992, HU, O, 1992071306, 1992072312, , , , , , ARCHIVE, , EP071992
 GEORGETTE, EP, E,  ,  ,  ,  , 08, 1992, HU, O, 1992071412, 1992072606, , , , , , ARCHIVE, , EP081992
    HOWARD, EP, E,  ,  ,  ,  , 09, 1992, TS, O, 1992072606, 1992073018, , , , , , ARCHIVE, , EP091992
      ISIS, EP, E,  ,  ,  ,  , 10, 1992, TS, O, 1992072800, 1992080200, , , , , , ARCHIVE, , EP101992
    JAVIER, EP, E,  ,  ,  ,  , 11, 1992, HU, O, 1992073018, 1992081200, , , , , , ARCHIVE, , EP111992
    TWELVE, EP, E,  ,  ,  ,  , 12, 1992, TD, O, 1992081000, 1992081300, , , , , , ARCHIVE, , EP121992
       KAY, EP, E,  ,  ,  ,  , 13, 1992, TS, O, 1992081806, 1992082218, , , , , , ARCHIVE, , EP131992
    LESTER, EP, E,  ,  ,  ,  , 14, 1992, HU, O, 1992082000, 1992082418, , , , , , ARCHIVE, , EP141992
  MADELINE, EP, E,  ,  ,  ,  , 15, 1992, TS, O, 1992082712, 1992083100, , , , , , ARCHIVE, , EP151992
    NEWTON, EP, E,  ,  ,  ,  , 16, 1992, TS, O, 1992082712, 1992083118, , , , , , ARCHIVE, , EP161992
    ORLENE, EP, E,  ,  ,  ,  , 17, 1992, HU, O, 1992090218, 1992091418, , , , , , ARCHIVE, , EP171992
     INIKI, EP, E,  ,  ,  ,  , 18, 1992, HU, O, 1992090518, 1992091318, , , , , , ARCHIVE, , EP181992
     PAINE, EP, E,  ,  ,  ,  , 19, 1992, HU, O, 1992091100, 1992091612, , , , , , ARCHIVE, , EP191992
    ROSLYN, EP, E,  ,  ,  ,  , 20, 1992, HU, O, 1992091312, 1992093018, , , , , , ARCHIVE, , EP201992
   SEYMORE, EP, E,  ,  ,  ,  , 21, 1992, HU, O, 1992091712, 1992092706, , , , , , ARCHIVE, , EP211992
      TINA, EP, E,  ,  ,  ,  , 22, 1992, HU, O, 1992091712, 1992101118, , , , , , ARCHIVE, , EP221992
    VIRGIL, EP, E,  ,  ,  ,  , 23, 1992, HU, O, 1992100106, 1992100518, , , , , , ARCHIVE, , EP231992
  WINIFRED, EP, E,  ,  ,  ,  , 24, 1992, HU, O, 1992100612, 1992101006, , , , , , ARCHIVE, , EP241992
    XAVIER, EP, E,  ,  ,  ,  , 25, 1992, TS, O, 1992101318, 1992101500, , , , , , ARCHIVE, , EP251992
   YOLANDA, EP, E,  ,  ,  ,  , 26, 1992, TS, O, 1992101518, 1992102212, , , , , , ARCHIVE, , EP261992
      ZEKE, EP, E,  ,  ,  ,  , 27, 1992, TS, O, 1992102512, 1992103018, , , , , , ARCHIVE, , EP271992
       ONE, AL, L,  ,  ,  ,  , 01, 1993, TD, O, 1993053112, 1993060300, , , , , , ARCHIVE, , AL011993
    ARLENE, AL, L,  ,  ,  ,  , 02, 1993, TS, O, 1993061800, 1993062106, , , , , , ARCHIVE, , AL021993
      BRET, AL, L,  ,  ,  ,  , 03, 1993, TS, O, 1993080412, 1993081112, , , , , , ARCHIVE, , AL031993
     CINDY, AL, L,  ,  ,  ,  , 04, 1993, TS, O, 1993081412, 1993081700, , , , , , ARCHIVE, , AL041993
     EMILY, AL, L,  ,  ,  ,  , 05, 1993, HU, O, 1993082218, 1993090612, , , , , , ARCHIVE, , AL051993
    DENNIS, AL, L,  ,  ,  ,  , 06, 1993, TS, O, 1993082312, 1993082812, , , , , , ARCHIVE, , AL061993
     FLOYD, AL, L,  ,  ,  ,  , 07, 1993, HU, O, 1993090712, 1993091300, , , , , , ARCHIVE, , AL071993
      GERT, AL, L,  ,  ,  ,  , 08, 1993, HU, O, 1993091418, 1993092118, , , , , , ARCHIVE, , AL081993
    HARVEY, AL, L,  ,  ,  ,  , 09, 1993, HU, O, 1993091818, 1993092118, , , , , , ARCHIVE, , AL091993
       TEN, AL, L,  ,  ,  ,  , 10, 1993, TD, O, 1993092918, 1993093018, , , , , , ARCHIVE, , AL101993
     KEONI, CP, C,  ,  ,  ,  , 01, 1993, HU, O, 1993080900, 1993082912, , , , , , ARCHIVE, , CP011993
    ADRIAN, EP, E,  ,  ,  ,  , 01, 1993, HU, O, 1993061106, 1993061912, , , , , , ARCHIVE, , EP011993
   BEATRIZ, EP, E,  ,  ,  ,  , 02, 1993, TS, O, 1993061806, 1993062000, , , , , , ARCHIVE, , EP021993
     THREE, EP, E,  ,  ,  ,  , 03, 1993, TD, O, 1993062700, 1993070200, , , , , , ARCHIVE, , EP031993
    CALVIN, EP, E,  ,  ,  ,  , 04, 1993, HU, O, 1993070412, 1993070900, , , , , , ARCHIVE, , EP041993
      DORA, EP, E,  ,  ,  ,  , 05, 1993, HU, O, 1993071412, 1993072018, , , , , , ARCHIVE, , EP051993
    EUGENE, EP, E,  ,  ,  ,  , 06, 1993, HU, O, 1993071518, 1993072500, , , , , , ARCHIVE, , EP061993
  FERNANDA, EP, E,  ,  ,  ,  , 07, 1993, HU, O, 1993080906, 1993081912, , , , , , ARCHIVE, , EP071993
      GREG, EP, E,  ,  ,  ,  , 08, 1993, HU, O, 1993081500, 1993082818, , , , , , ARCHIVE, , EP081993
    HILARY, EP, E,  ,  ,  ,  , 09, 1993, HU, O, 1993081706, 1993082706, , , , , , ARCHIVE, , EP091993
     IRWIN, EP, E,  ,  ,  ,  , 10, 1993, TS, O, 1993082106, 1993082212, , , , , , ARCHIVE, , EP101993
      JOVA, EP, E,  ,  ,  ,  , 11, 1993, HU, O, 1993082900, 1993090518, , , , , , ARCHIVE, , EP111993
   KENNETH, EP, E,  ,  ,  ,  , 12, 1993, HU, O, 1993090512, 1993091718, , , , , , ARCHIVE, , EP121993
     LIDIA, EP, E,  ,  ,  ,  , 13, 1993, HU, O, 1993090812, 1993091406, , , , , , ARCHIVE, , EP131993
  FOURTEEN, EP, E,  ,  ,  ,  , 14, 1993, TD, O, 1993092118, 1993092600, , , , , , ARCHIVE, , EP141993
       MAX, EP, E,  ,  ,  ,  , 15, 1993, TS, O, 1993093000, 1993100400, , , , , , ARCHIVE, , EP151993
     NORMA, EP, E,  ,  ,  ,  , 16, 1993, TS, O, 1993100218, 1993100612, , , , , , ARCHIVE, , EP161993
 SEVENTEEN, EP, E,  ,  ,  ,  , 17, 1993, TD, O, 1993101118, 1993101400, , , , , , ARCHIVE, , EP171993
   ALBERTO, AL, L,  ,  ,  ,  , 01, 1994, TS, O, 1994063006, 1994070718, , , , , , ARCHIVE, , AL011994
       TWO, AL, L,  ,  ,  ,  , 02, 1994, TD, O, 1994072006, 1994072106, , , , , , ARCHIVE, , AL021994
     BERYL, AL, L,  ,  ,  ,  , 03, 1994, TS, O, 1994081412, 1994081900, , , , , , ARCHIVE, , AL031994
     CHRIS, AL, L,  ,  ,  ,  , 04, 1994, HU, O, 1994081612, 1994082318, , , , , , ARCHIVE, , AL041994
      FIVE, AL, L,  ,  ,  ,  , 05, 1994, TD, O, 1994082912, 1994083112, , , , , , ARCHIVE, , AL051994
     DEBBY, AL, L,  ,  ,  ,  , 06, 1994, TS, O, 1994090912, 1994091100, , , , , , ARCHIVE, , AL061994
   ERNESTO, AL, L,  ,  ,  ,  , 07, 1994, TS, O, 1994092118, 1994092600, , , , , , ARCHIVE, , AL071994
     EIGHT, AL, L,  ,  ,  ,  , 08, 1994, TD, O, 1994092412, 1994092618, , , , , , ARCHIVE, , AL081994
      NINE, AL, L,  ,  ,  ,  , 09, 1994, TD, O, 1994092712, 1994092900, , , , , , ARCHIVE, , AL091994
       TEN, AL, L,  ,  ,  ,  , 10, 1994, TD, O, 1994092906, 1994093018, , , , , , ARCHIVE, , AL101994
  FLORENCE, AL, L,  ,  ,  ,  , 11, 1994, HU, O, 1994110200, 1994110818, , , , , , ARCHIVE, , AL111994
    GORDON, AL, L,  ,  ,  ,  , 12, 1994, HU, O, 1994110812, 1994112118, , , , , , ARCHIVE, , AL121994
       ONE, CP, C,  ,  ,  ,  , 01, 1994, TD, O, 1994080906, 1994081406, , , , , , ARCHIVE, , CP011994
      MELE, CP, C,  ,  ,  ,  , 02, 1994, TS, O, 1994090600, 1994090912, , , , , , ARCHIVE, , CP021994
      NONA, CP, C,  ,  ,  ,  , 03, 1994, TS, O, 1994102100, 1994102600, , , , , , ARCHIVE, , CP031994
    ALETTA, EP, E,  ,  ,  ,  , 01, 1994, TS, O, 1994061806, 1994062306, , , , , , ARCHIVE, , EP011994
       BUD, EP, E,  ,  ,  ,  , 02, 1994, TS, O, 1994062706, 1994062918, , , , , , ARCHIVE, , EP021994
  CARLOTTA, EP, E,  ,  ,  ,  , 03, 1994, HU, O, 1994062812, 1994070512, , , , , , ARCHIVE, , EP031994
    DANIEL, EP, E,  ,  ,  ,  , 04, 1994, TS, O, 1994070812, 1994071418, , , , , , ARCHIVE, , EP041994
    EMILIA, EP, E,  ,  ,  ,  , 05, 1994, HU, O, 1994071600, 1994072500, , , , , , ARCHIVE, , EP051994
     FABIO, EP, E,  ,  ,  ,  , 06, 1994, TS, O, 1994071900, 1994072400, , , , , , ARCHIVE, , EP061994
     GILMA, EP, E,  ,  ,  ,  , 07, 1994, HU, O, 1994072106, 1994073100, , , , , , ARCHIVE, , EP071994
        LI, EP, E,  ,  ,  ,  , 08, 1994, HU, O, 1994073118, 1994081800, , , , , , ARCHIVE, , EP081994
    HECTOR, EP, E,  ,  ,  ,  , 09, 1994, TS, O, 1994080700, 1994080918, , , , , , ARCHIVE, , EP091994
      JOHN, EP, E,  ,  ,  ,  , 10, 1994, HU, O, 1994081106, 1994091006, , , , , , ARCHIVE, , EP101994
    ILEANA, EP, E,  ,  ,  ,  , 11, 1994, HU, O, 1994081012, 1994081418, , , , , , ARCHIVE, , EP111994
    TWELVE, EP, E,  ,  ,  ,  , 12, 1994, TD, O, 1994081200, 1994081512, , , , , , ARCHIVE, , EP121994
    KRISTY, EP, E,  ,  ,  ,  , 13, 1994, HU, O, 1994082818, 1994090500, , , , , , ARCHIVE, , EP131994
      LANE, EP, E,  ,  ,  ,  , 14, 1994, HU, O, 1994090318, 1994091012, , , , , , ARCHIVE, , EP141994
    MIRIAM, EP, E,  ,  ,  ,  , 15, 1994, TS, O, 1994091518, 1994092112, , , , , , ARCHIVE, , EP151994
    NORMAN, EP, E,  ,  ,  ,  , 16, 1994, TS, O, 1994091906, 1994092200, , , , , , ARCHIVE, , EP161994
    OLIVIA, EP, E,  ,  ,  ,  , 17, 1994, HU, O, 1994092206, 1994092918, , , , , , ARCHIVE, , EP171994
      PAUL, EP, E,  ,  ,  ,  , 18, 1994, TS, O, 1994092412, 1994093000, , , , , , ARCHIVE, , EP181994
      ROSA, EP, E,  ,  ,  ,  , 19, 1994, HU, O, 1994100812, 1994101500, , , , , , ARCHIVE, , EP191994
   ALLISON, AL, L,  ,  ,  ,  , 01, 1995, HU, O, 1995060300, 1995061100, , , , , , ARCHIVE, , AL011995
     BARRY, AL, L,  ,  ,  ,  , 02, 1995, TS, O, 1995070506, 1995071006, , , , , , ARCHIVE, , AL021995
   CHANTAL, AL, L,  ,  ,  ,  , 03, 1995, TS, O, 1995071200, 1995072200, , , , , , ARCHIVE, , AL031995
      DEAN, AL, L,  ,  ,  ,  , 04, 1995, TS, O, 1995072818, 1995080218, , , , , , ARCHIVE, , AL041995
      ERIN, AL, L,  ,  ,  ,  , 05, 1995, HU, O, 1995073100, 1995080612, , , , , , ARCHIVE, , AL051995
       SIX, AL, L,  ,  ,  ,  , 06, 1995, TD, O, 1995080518, 1995080712, , , , , , ARCHIVE, , AL061995
     FELIX, AL, L,  ,  ,  ,  , 07, 1995, HU, O, 1995080800, 1995082500, , , , , , ARCHIVE, , AL071995
 GABRIELLE, AL, L,  ,  ,  ,  , 08, 1995, TS, O, 1995080918, 1995081200, , , , , , ARCHIVE, , AL081995
  HUMBERTO, AL, L,  ,  ,  ,  , 09, 1995, HU, O, 1995082200, 1995090100, , , , , , ARCHIVE, , AL091995
      IRIS, AL, L,  ,  ,  ,  , 10, 1995, HU, O, 1995082212, 1995090712, , , , , , ARCHIVE, , AL101995
     JERRY, AL, L,  ,  ,  ,  , 11, 1995, TS, O, 1995082218, 1995082800, , , , , , ARCHIVE, , AL111995
     KAREN, AL, L,  ,  ,  ,  , 12, 1995, TS, O, 1995082612, 1995090300, , , , , , ARCHIVE, , AL121995
      LUIS, AL, L,  ,  ,  ,  , 13, 1995, HU, O, 1995082818, 1995091218, , , , , , ARCHIVE, , AL131995
  FOURTEEN, AL, L,  ,  ,  ,  , 14, 1995, TD, O, 1995090912, 1995091312, , , , , , ARCHIVE, , AL141995
   MARILYN, AL, L,  ,  ,  ,  , 15, 1995, HU, O, 1995091218, 1995100118, , , , , , ARCHIVE, , AL151995
      NOEL, AL, L,  ,  ,  ,  , 16, 1995, HU, O, 1995092618, 1995100718, , , , , , ARCHIVE, , AL161995
      OPAL, AL, L,  ,  ,  ,  , 17, 1995, HU, O, 1995092718, 1995100618, , , , , , ARCHIVE, , AL171995
     PABLO, AL, L,  ,  ,  ,  , 18, 1995, TS, O, 1995100418, 1995100812, , , , , , ARCHIVE, , AL181995
   ROXANNE, AL, L,  ,  ,  ,  , 19, 1995, HU, O, 1995100718, 1995102100, , , , , , ARCHIVE, , AL191995
 SEBASTIEN, AL, L,  ,  ,  ,  , 20, 1995, TS, O, 1995102012, 1995102500, , , , , , ARCHIVE, , AL201995
     TANYA, AL, L,  ,  ,  ,  , 21, 1995, HU, O, 1995102700, 1995110300, , , , , , ARCHIVE, , AL211995
       ONE, EP, E,  ,  ,  ,  , 01, 1995, TD, O, 1995052106, 1995052300, , , , , , ARCHIVE, , EP011995
    ADOLPH, EP, E,  ,  ,  ,  , 02, 1995, HU, O, 1995061512, 1995062106, , , , , , ARCHIVE, , EP021995
   BARBARA, EP, E,  ,  ,  ,  , 03, 1995, HU, O, 1995070718, 1995071800, , , , , , ARCHIVE, , EP031995
     COSME, EP, E,  ,  ,  ,  , 04, 1995, HU, O, 1995071700, 1995072200, , , , , , ARCHIVE, , EP041995
    DALILA, EP, E,  ,  ,  ,  , 05, 1995, TS, O, 1995072412, 1995080206, , , , , , ARCHIVE, , EP051995
     ERICK, EP, E,  ,  ,  ,  , 06, 1995, TS, O, 1995080118, 1995080800, , , , , , ARCHIVE, , EP061995
   FLOSSIE, EP, E,  ,  ,  ,  , 07, 1995, HU, O, 1995080712, 1995081400, , , , , , ARCHIVE, , EP071995
       GIL, EP, E,  ,  ,  ,  , 08, 1995, TS, O, 1995082018, 1995082712, , , , , , ARCHIVE, , EP081995
 HENRIETTE, EP, E,  ,  ,  ,  , 09, 1995, HU, O, 1995090100, 1995090800, , , , , , ARCHIVE, , EP091995
    ISMAEL, EP, E,  ,  ,  ,  , 10, 1995, HU, O, 1995091218, 1995091518, , , , , , ARCHIVE, , EP101995
  JULIETTE, EP, E,  ,  ,  ,  , 11, 1995, HU, O, 1995091618, 1995092618, , , , , , ARCHIVE, , EP111995
    ARTHUR, AL, L,  ,  ,  ,  , 01, 1996, TS, O, 1996061718, 1996062300, , , , , , ARCHIVE, , AL011996
    BERTHA, AL, L,  ,  ,  ,  , 02, 1996, HU, O, 1996070500, 1996071706, , , , , , ARCHIVE, , AL021996
     CESAR, AL, L,  ,  ,  ,  , 03, 1996, HU, O, 1996072418, 1996072818, , , , , , ARCHIVE, , AL031996
     DOLLY, AL, L,  ,  ,  ,  , 04, 1996, HU, O, 1996081906, 1996082500, , , , , , ARCHIVE, , AL041996
   EDOUARD, AL, L,  ,  ,  ,  , 05, 1996, HU, O, 1996081918, 1996090618, , , , , , ARCHIVE, , AL051996
      FRAN, AL, L,  ,  ,  ,  , 06, 1996, HU, O, 1996082312, 1996091000, , , , , , ARCHIVE, , AL061996
    GUSTAV, AL, L,  ,  ,  ,  , 07, 1996, TS, O, 1996082600, 1996090200, , , , , , ARCHIVE, , AL071996
  HORTENSE, AL, L,  ,  ,  ,  , 08, 1996, HU, O, 1996090312, 1996091606, , , , , , ARCHIVE, , AL081996
   ISIDORE, AL, L,  ,  ,  ,  , 09, 1996, HU, O, 1996092412, 1996100212, , , , , , ARCHIVE, , AL091996
 JOSEPHINE, AL, L,  ,  ,  ,  , 10, 1996, TS, O, 1996100418, 1996101600, , , , , , ARCHIVE, , AL101996
      KYLE, AL, L,  ,  ,  ,  , 11, 1996, TS, O, 1996101112, 1996101218, , , , , , ARCHIVE, , AL111996
      LILI, AL, L,  ,  ,  ,  , 12, 1996, HU, O, 1996101412, 1996102900, , , , , , ARCHIVE, , AL121996
     MARCO, AL, L,  ,  ,  ,  , 13, 1996, HU, O, 1996111312, 1996112618, , , , , , ARCHIVE, , AL131996
       ONE, CP, C,  ,  ,  ,  , 01, 1996, TD, O, 1996091600, 1996092018, , , , , , ARCHIVE, , CP011996
   UNNAMED, EP, E,  ,  ,  ,  , 01, 1996, TS, O, 1996051306, 1996051618, , , , , , ARCHIVE, , EP011996
       TWO, EP, E,  ,  ,  ,  , 02, 1996, TD, O, 1996051512, 1996051900, , , , , , ARCHIVE, , EP021996
      ALMA, EP, E,  ,  ,  ,  , 03, 1996, HU, O, 1996062000, 1996062706, , , , , , ARCHIVE, , EP031996
     BORIS, EP, E,  ,  ,  ,  , 04, 1996, HU, O, 1996062700, 1996070112, , , , , , ARCHIVE, , EP041996
  CRISTINA, EP, E,  ,  ,  ,  , 05, 1996, TS, O, 1996070112, 1996070318, , , , , , ARCHIVE, , EP051996
       SIX, EP, E,  ,  ,  ,  , 06, 1996, TD, O, 1996070418, 1996070600, , , , , , ARCHIVE, , EP061996
   DOUGLAS, EP, E,  ,  ,  ,  , 07, 1996, HU, O, 1996072900, 1996080600, , , , , , ARCHIVE, , EP071996
     ELIDA, EP, E,  ,  ,  ,  , 08, 1996, TS, O, 1996083012, 1996090612, , , , , , ARCHIVE, , EP081996
    FAUSTO, EP, E,  ,  ,  ,  , 09, 1996, HU, O, 1996091000, 1996091418, , , , , , ARCHIVE, , EP091996
 GENEVIEVE, EP, E,  ,  ,  ,  , 10, 1996, TS, O, 1996092718, 1996100900, , , , , , ARCHIVE, , EP101996
    HERNAN, EP, E,  ,  ,  ,  , 11, 1996, HU, O, 1996093006, 1996100418, , , , , , ARCHIVE, , EP111996
    TWELVE, EP, E,  ,  ,  ,  , 12, 1996, TD, O, 1996110700, 1996111112, , , , , , ARCHIVE, , EP121996
   SUBTROP, AL, L,  ,  ,  ,  , 01, 1997, SS, O, 1997053118, 1997060218, , , , , , ARCHIVE, , AL011997
       ANA, AL, L,  ,  ,  ,  , 02, 1997, TS, O, 1997063012, 1997070500, , , , , , ARCHIVE, , AL021997
      BILL, AL, L,  ,  ,  ,  , 03, 1997, HU, O, 1997071106, 1997071306, , , , , , ARCHIVE, , AL031997
 CLAUDETTE, AL, L,  ,  ,  ,  , 04, 1997, TS, O, 1997071300, 1997071618, , , , , , ARCHIVE, , AL041997
     DANNY, AL, L,  ,  ,  ,  , 05, 1997, HU, O, 1997071612, 1997072712, , , , , , ARCHIVE, , AL051997
      FIVE, AL, L,  ,  ,  ,  , 06, 1997, TD, O, 1997071706, 1997071900, , , , , , ARCHIVE, , AL061997
     ERIKA, AL, L,  ,  ,  ,  , 07, 1997, HU, O, 1997090306, 1997091918, , , , , , ARCHIVE, , AL071997
    FABIAN, AL, L,  ,  ,  ,  , 08, 1997, TS, O, 1997100418, 1997100818, , , , , , ARCHIVE, , AL081997
     GRACE, AL, L,  ,  ,  ,  , 09, 1997, TS, O, 1997101412, 1997101712, , , , , , ARCHIVE, , AL091997
       ONE, CP, C,  ,  ,  ,  , 01, 1997, TD, O, 1997072612, 1997072718, , , , , , ARCHIVE, , CP011997
     OLIWA, CP, C,  ,  ,  ,  , 02, 1997, HU, O, 1997082806, 1997091706, , , , , , ARCHIVE, , CP021997
     THREE, CP, C,  ,  ,  ,  , 03, 1997, TD, O, 1997100512, 1997100718, , , , , , ARCHIVE, , CP031997
      FOUR, CP, C,  ,  ,  ,  , 04, 1997, TD, O, 1997103012, 1997110106, , , , , , ARCHIVE, , CP041997
      PAKA, CP, C,  ,  ,  ,  , 05, 1997, HU, O, 1997112818, 1997122212, , , , , , ARCHIVE, , CP051997
    ANDRES, EP, E,  ,  ,  ,  , 01, 1997, TS, O, 1997060100, 1997060700, , , , , , ARCHIVE, , EP011997
    BLANCA, EP, E,  ,  ,  ,  , 02, 1997, TS, O, 1997060918, 1997061206, , , , , , ARCHIVE, , EP021997
     THREE, EP, E,  ,  ,  ,  , 03, 1997, TD, O, 1997062118, 1997062400, , , , , , ARCHIVE, , EP031997
    CARLOS, EP, E,  ,  ,  ,  , 04, 1997, TS, O, 1997062506, 1997062800, , , , , , ARCHIVE, , EP041997
      FIVE, EP, E,  ,  ,  ,  , 05, 1997, TD, O, 1997062912, 1997070400, , , , , , ARCHIVE, , EP051997
   DOLORES, EP, E,  ,  ,  ,  , 06, 1997, HU, O, 1997070512, 1997071218, , , , , , ARCHIVE, , EP061997
   ENRIQUE, EP, E,  ,  ,  ,  , 07, 1997, HU, O, 1997071206, 1997071618, , , , , , ARCHIVE, , EP071997
   FELICIA, EP, E,  ,  ,  ,  , 08, 1997, HU, O, 1997071412, 1997072212, , , , , , ARCHIVE, , EP081997
 GUILLERMO, EP, E,  ,  ,  ,  , 09, 1997, HU, O, 1997073012, 1997082400, , , , , , ARCHIVE, , EP091997
     HILDA, EP, E,  ,  ,  ,  , 10, 1997, TS, O, 1997081000, 1997081500, , , , , , ARCHIVE, , EP101997
   IGNACIO, EP, E,  ,  ,  ,  , 11, 1997, TS, O, 1997081700, 1997082006, , , , , , ARCHIVE, , EP111997
    JIMENA, EP, E,  ,  ,  ,  , 12, 1997, HU, O, 1997082512, 1997083000, , , , , , ARCHIVE, , EP121997
     KEVIN, EP, E,  ,  ,  ,  , 13, 1997, TS, O, 1997090318, 1997090700, , , , , , ARCHIVE, , EP131997
     LINDA, EP, E,  ,  ,  ,  , 14, 1997, HU, O, 1997090912, 1997091718, , , , , , ARCHIVE, , EP141997
     MARTY, EP, E,  ,  ,  ,  , 15, 1997, TS, O, 1997091218, 1997091612, , , , , , ARCHIVE, , EP151997
      NORA, EP, E,  ,  ,  ,  , 16, 1997, HU, O, 1997091606, 1997092606, , , , , , ARCHIVE, , EP161997
      OLAF, EP, E,  ,  ,  ,  , 17, 1997, TS, O, 1997092612, 1997101218, , , , , , ARCHIVE, , EP171997
   PAULINE, EP, E,  ,  ,  ,  , 18, 1997, HU, O, 1997100512, 1997101006, , , , , , ARCHIVE, , EP181997
      RICK, EP, E,  ,  ,  ,  , 19, 1997, HU, O, 1997110700, 1997111018, , , , , , ARCHIVE, , EP191997
      ALEX, AL, L,  ,  ,  ,  , 01, 1998, TS, O, 1998072712, 1998080218, , , , , , ARCHIVE, , AL011998
    BONNIE, AL, L,  ,  ,  ,  , 02, 1998, HU, O, 1998081912, 1998083106, , , , , , ARCHIVE, , AL021998
   CHARLEY, AL, L,  ,  ,  ,  , 03, 1998, TS, O, 1998082106, 1998082400, , , , , , ARCHIVE, , AL031998
  DANIELLE, AL, L,  ,  ,  ,  , 04, 1998, HU, O, 1998082406, 1998090806, , , , , , ARCHIVE, , AL041998
      EARL, AL, L,  ,  ,  ,  , 05, 1998, HU, O, 1998083112, 1998090812, , , , , , ARCHIVE, , AL051998
   FRANCES, AL, L,  ,  ,  ,  , 06, 1998, TS, O, 1998090818, 1998091318, , , , , , ARCHIVE, , AL061998
   GEORGES, AL, L,  ,  ,  ,  , 07, 1998, HU, O, 1998091512, 1998100106, , , , , , ARCHIVE, , AL071998
   HERMINE, AL, L,  ,  ,  ,  , 08, 1998, TS, O, 1998091712, 1998092018, , , , , , ARCHIVE, , AL081998
      IVAN, AL, L,  ,  ,  ,  , 09, 1998, HU, O, 1998091900, 1998092718, , , , , , ARCHIVE, , AL091998
    JEANNE, AL, L,  ,  ,  ,  , 10, 1998, HU, O, 1998092106, 1998100412, , , , , , ARCHIVE, , AL101998
      KARL, AL, L,  ,  ,  ,  , 11, 1998, HU, O, 1998092312, 1998092918, , , , , , ARCHIVE, , AL111998
      LISA, AL, L,  ,  ,  ,  , 12, 1998, HU, O, 1998100500, 1998101000, , , , , , ARCHIVE, , AL121998
     MITCH, AL, L,  ,  ,  ,  , 13, 1998, HU, O, 1998102200, 1998110918, , , , , , ARCHIVE, , AL131998
    NICOLE, AL, L,  ,  ,  ,  , 14, 1998, HU, O, 1998112400, 1998120212, , , , , , ARCHIVE, , AL141998
       ONE, CP, C,  ,  ,  ,  , 01, 1998, TD, O, 1998081600, 1998081900, , , , , , ARCHIVE, , CP011998
    AGATHA, EP, E,  ,  ,  ,  , 01, 1998, TS, O, 1998061112, 1998061618, , , , , , ARCHIVE, , EP011998
       TWO, EP, E,  ,  ,  ,  , 02, 1998, TD, O, 1998061918, 1998062200, , , , , , ARCHIVE, , EP021998
      BLAS, EP, E,  ,  ,  ,  , 03, 1998, HU, O, 1998062200, 1998063018, , , , , , ARCHIVE, , EP031998
     CELIA, EP, E,  ,  ,  ,  , 04, 1998, TS, O, 1998071706, 1998072106, , , , , , ARCHIVE, , EP041998
     DARBY, EP, E,  ,  ,  ,  , 05, 1998, HU, O, 1998072300, 1998080100, , , , , , ARCHIVE, , EP051998
   ESTELLE, EP, E,  ,  ,  ,  , 06, 1998, HU, O, 1998072918, 1998080818, , , , , , ARCHIVE, , EP061998
     FRANK, EP, E,  ,  ,  ,  , 07, 1998, TS, O, 1998080612, 1998081000, , , , , , ARCHIVE, , EP071998
 GEORGETTE, EP, E,  ,  ,  ,  , 08, 1998, HU, O, 1998081100, 1998081706, , , , , , ARCHIVE, , EP081998
    HOWARD, EP, E,  ,  ,  ,  , 09, 1998, HU, O, 1998082006, 1998083000, , , , , , ARCHIVE, , EP091998
      ISIS, EP, E,  ,  ,  ,  , 10, 1998, HU, O, 1998090100, 1998090318, , , , , , ARCHIVE, , EP101998
    JAVIER, EP, E,  ,  ,  ,  , 11, 1998, TS, O, 1998090612, 1998091412, , , , , , ARCHIVE, , EP111998
    TWELVE, EP, E,  ,  ,  ,  , 12, 1998, TD, O, 1998100118, 1998100312, , , , , , ARCHIVE, , EP121998
       KAY, EP, E,  ,  ,  ,  , 13, 1998, HU, O, 1998101300, 1998101700, , , , , , ARCHIVE, , EP131998
    LESTER, EP, E,  ,  ,  ,  , 14, 1998, HU, O, 1998101500, 1998102612, , , , , , ARCHIVE, , EP141998
  MADELINE, EP, E,  ,  ,  ,  , 15, 1998, HU, O, 1998101600, 1998102000, , , , , , ARCHIVE, , EP151998
    ARLENE, AL, L,  ,  ,  ,  , 01, 1999, TS, O, 1999061118, 1999061800, , , , , , ARCHIVE, , AL011999
       TWO, AL, L,  ,  ,  ,  , 02, 1999, TD, O, 1999070218, 1999070306, , , , , , ARCHIVE, , AL021999
      BRET, AL, L,  ,  ,  ,  , 03, 1999, HU, O, 1999081818, 1999082500, , , , , , ARCHIVE, , AL031999
     CINDY, AL, L,  ,  ,  ,  , 04, 1999, HU, O, 1999081900, 1999083112, , , , , , ARCHIVE, , AL041999
    DENNIS, AL, L,  ,  ,  ,  , 05, 1999, HU, O, 1999082400, 1999090818, , , , , , ARCHIVE, , AL051999
     EMILY, AL, L,  ,  ,  ,  , 06, 1999, TS, O, 1999082406, 1999082812, , , , , , ARCHIVE, , AL061999
     SEVEN, AL, L,  ,  ,  ,  , 07, 1999, TD, O, 1999090518, 1999090712, , , , , , ARCHIVE, , AL071999
     FLOYD, AL, L,  ,  ,  ,  , 08, 1999, HU, O, 1999090718, 1999091912, , , , , , ARCHIVE, , AL081999
      GERT, AL, L,  ,  ,  ,  , 09, 1999, HU, O, 1999091112, 1999092312, , , , , , ARCHIVE, , AL091999
    HARVEY, AL, L,  ,  ,  ,  , 10, 1999, TS, O, 1999091906, 1999092200, , , , , , ARCHIVE, , AL101999
    ELEVEN, AL, L,  ,  ,  ,  , 11, 1999, TD, O, 1999100406, 1999100612, , , , , , ARCHIVE, , AL111999
    TWELVE, AL, L,  ,  ,  ,  , 12, 1999, TD, O, 1999100600, 1999100818, , , , , , ARCHIVE, , AL121999
     IRENE, AL, L,  ,  ,  ,  , 13, 1999, HU, O, 1999101212, 1999101918, , , , , , ARCHIVE, , AL131999
      JOSE, AL, L,  ,  ,  ,  , 14, 1999, HU, O, 1999101718, 1999102512, , , , , , ARCHIVE, , AL141999
   KATRINA, AL, L,  ,  ,  ,  , 15, 1999, TS, O, 1999102818, 1999110112, , , , , , ARCHIVE, , AL151999
     LENNY, AL, L,  ,  ,  ,  , 16, 1999, HU, O, 1999111318, 1999112306, , , , , , ARCHIVE, , AL161999
    ADRIAN, EP, E,  ,  ,  ,  , 01, 1999, HU, O, 1999061806, 1999062218, , , , , , ARCHIVE, , EP011999
   BEATRIZ, EP, E,  ,  ,  ,  , 02, 1999, HU, O, 1999070906, 1999071700, , , , , , ARCHIVE, , EP021999
     THREE, EP, E,  ,  ,  ,  , 03, 1999, TD, O, 1999071406, 1999071518, , , , , , ARCHIVE, , EP031999
      FOUR, EP, E,  ,  ,  ,  , 04, 1999, TD, O, 1999072300, 1999072500, , , , , , ARCHIVE, , EP041999
    CALVIN, EP, E,  ,  ,  ,  , 05, 1999, TS, O, 1999072506, 1999072706, , , , , , ARCHIVE, , EP051999
       SIX, EP, E,  ,  ,  ,  , 06, 1999, TD, O, 1999072618, 1999072800, , , , , , ARCHIVE, , EP061999
      DORA, EP, E,  ,  ,  ,  , 07, 1999, HU, O, 1999080600, 1999082318, , , , , , ARCHIVE, , EP071999
    EUGENE, EP, E,  ,  ,  ,  , 08, 1999, HU, O, 1999080606, 1999081518, , , , , , ARCHIVE, , EP081999
      NINE, EP, E,  ,  ,  ,  , 09, 1999, TD, O, 1999081312, 1999081506, , , , , , ARCHIVE, , EP091999
  FERNANDA, EP, E,  ,  ,  ,  , 10, 1999, TS, O, 1999081706, 1999082218, , , , , , ARCHIVE, , EP101999
    ELEVEN, EP, E,  ,  ,  ,  , 11, 1999, TD, O, 1999082318, 1999082412, , , , , , ARCHIVE, , EP111999
      GREG, EP, E,  ,  ,  ,  , 12, 1999, HU, O, 1999090512, 1999090918, , , , , , ARCHIVE, , EP121999
    HILARY, EP, E,  ,  ,  ,  , 13, 1999, HU, O, 1999091706, 1999092118, , , , , , ARCHIVE, , EP131999
     IRWIN, EP, E,  ,  ,  ,  , 14, 1999, TS, O, 1999100812, 1999101106, , , , , , ARCHIVE, , EP141999
       ONE, AL, L,  ,  ,  ,  , 01, 2000, TD, O, 2000060718, 2000060812, , , , , , ARCHIVE, , AL012000
       TWO, AL, L,  ,  ,  ,  , 02, 2000, TD, O, 2000062300, 2000062518, , , , , , ARCHIVE, , AL022000
   ALBERTO, AL, L,  ,  ,  ,  , 03, 2000, HU, O, 2000080318, 2000082506, , , , , , ARCHIVE, , AL032000
      FOUR, AL, L,  ,  ,  ,  , 04, 2000, TD, O, 2000080812, 2000081112, , , , , , ARCHIVE, , AL042000
     BERYL, AL, L,  ,  ,  ,  , 05, 2000, TS, O, 2000081318, 2000081518, , , , , , ARCHIVE, , AL052000
     CHRIS, AL, L,  ,  ,  ,  , 06, 2000, TS, O, 2000081712, 2000081912, , , , , , ARCHIVE, , AL062000
     DEBBY, AL, L,  ,  ,  ,  , 07, 2000, HU, O, 2000081918, 2000082412, , , , , , ARCHIVE, , AL072000
   ERNESTO, AL, L,  ,  ,  ,  , 08, 2000, TS, O, 2000090112, 2000090318, , , , , , ARCHIVE, , AL082000
      NINE, AL, L,  ,  ,  ,  , 09, 2000, TD, O, 2000090818, 2000090912, , , , , , ARCHIVE, , AL092000
  FLORENCE, AL, L,  ,  ,  ,  , 10, 2000, HU, O, 2000091018, 2000091718, , , , , , ARCHIVE, , AL102000
    GORDON, AL, L,  ,  ,  ,  , 11, 2000, HU, O, 2000091412, 2000092106, , , , , , ARCHIVE, , AL112000
    HELENE, AL, L,  ,  ,  ,  , 12, 2000, TS, O, 2000091512, 2000092518, , , , , , ARCHIVE, , AL122000
     ISAAC, AL, L,  ,  ,  ,  , 13, 2000, HU, O, 2000092112, 2000100406, , , , , , ARCHIVE, , AL132000
     JOYCE, AL, L,  ,  ,  ,  , 14, 2000, HU, O, 2000092512, 2000100206, , , , , , ARCHIVE, , AL142000
     KEITH, AL, L,  ,  ,  ,  , 15, 2000, HU, O, 2000092818, 2000100612, , , , , , ARCHIVE, , AL152000
    LESLIE, AL, L,  ,  ,  ,  , 16, 2000, TS, O, 2000100412, 2000101018, , , , , , ARCHIVE, , AL162000
   MICHAEL, AL, L,  ,  ,  ,  , 17, 2000, HU, O, 2000101512, 2000102018, , , , , , ARCHIVE, , AL172000
    NADINE, AL, L,  ,  ,  ,  , 18, 2000, TS, O, 2000101912, 2000102212, , , , , , ARCHIVE, , AL182000
   SUBTROP, AL, L,  ,  ,  ,  , 19, 2000, SS, O, 2000102500, 2000102912, , , , , , ARCHIVE, , AL192000
     UPANA, CP, C,  ,  ,  ,  , 01, 2000, TS, O, 2000072000, 2000072406, , , , , , ARCHIVE, , CP012000
      WENE, CP, C,  ,  ,  ,  , 02, 2000, TS, O, 2000081600, 2000081706, , , , , , ARCHIVE, , CP022000
    ALETTA, EP, E,  ,  ,  ,  , 01, 2000, HU, O, 2000052212, 2000052800, , , , , , ARCHIVE, , EP012000
       BUD, EP, E,  ,  ,  ,  , 02, 2000, TS, O, 2000061306, 2000061712, , , , , , ARCHIVE, , EP022000
  CARLOTTA, EP, E,  ,  ,  ,  , 03, 2000, HU, O, 2000061818, 2000062506, , , , , , ARCHIVE, , EP032000
      FOUR, EP, E,  ,  ,  ,  , 04, 2000, TD, O, 2000070612, 2000070712, , , , , , ARCHIVE, , EP042000
      FIVE, EP, E,  ,  ,  ,  , 05, 2000, TD, O, 2000072200, 2000072312, , , , , , ARCHIVE, , EP052000
    DANIEL, EP, E,  ,  ,  ,  , 06, 2000, HU, O, 2000072300, 2000080506, , , , , , ARCHIVE, , EP062000
    EMILIA, EP, E,  ,  ,  ,  , 07, 2000, TS, O, 2000072606, 2000073000, , , , , , ARCHIVE, , EP072000
     FABIO, EP, E,  ,  ,  ,  , 08, 2000, TS, O, 2000080312, 2000080800, , , , , , ARCHIVE, , EP082000
     GILMA, EP, E,  ,  ,  ,  , 09, 2000, HU, O, 2000080500, 2000081100, , , , , , ARCHIVE, , EP092000
    HECTOR, EP, E,  ,  ,  ,  , 10, 2000, HU, O, 2000081018, 2000081618, , , , , , ARCHIVE, , EP102000
    ILEANA, EP, E,  ,  ,  ,  , 11, 2000, TS, O, 2000081318, 2000081700, , , , , , ARCHIVE, , EP112000
      JOHN, EP, E,  ,  ,  ,  , 12, 2000, TS, O, 2000082806, 2000090112, , , , , , ARCHIVE, , EP122000
    KRISTY, EP, E,  ,  ,  ,  , 13, 2000, TS, O, 2000083100, 2000090300, , , , , , ARCHIVE, , EP132000
      LANE, EP, E,  ,  ,  ,  , 14, 2000, HU, O, 2000090500, 2000091400, , , , , , ARCHIVE, , EP142000
    MIRIAM, EP, E,  ,  ,  ,  , 15, 2000, TS, O, 2000091518, 2000091712, , , , , , ARCHIVE, , EP152000
    NORMAN, EP, E,  ,  ,  ,  , 16, 2000, TS, O, 2000092000, 2000092218, , , , , , ARCHIVE, , EP162000
    OLIVIA, EP, E,  ,  ,  ,  , 17, 2000, TS, O, 2000100212, 2000101006, , , , , , ARCHIVE, , EP172000
      PAUL, EP, E,  ,  ,  ,  , 18, 2000, TS, O, 2000102506, 2000102900, , , , , , ARCHIVE, , EP182000
      ROSA, EP, E,  ,  ,  ,  , 19, 2000, TS, O, 2000110318, 2000110812, , , , , , ARCHIVE, , EP192000
   ALLISON, AL, L,  ,  ,  ,  , 01, 2001, TS, O, 2001060512, 2001061900, , , , , , ARCHIVE, , AL012001
       TWO, AL, L,  ,  ,  ,  , 02, 2001, TD, O, 2001071118, 2001071218, , , , , , ARCHIVE, , AL022001
     BARRY, AL, L,  ,  ,  ,  , 03, 2001, TS, O, 2001080212, 2001080806, , , , , , ARCHIVE, , AL032001
   CHANTAL, AL, L,  ,  ,  ,  , 04, 2001, TS, O, 2001081418, 2001082212, , , , , , ARCHIVE, , AL042001
      DEAN, AL, L,  ,  ,  ,  , 05, 2001, TS, O, 2001082212, 2001082912, , , , , , ARCHIVE, , AL052001
      ERIN, AL, L,  ,  ,  ,  , 06, 2001, HU, O, 2001090118, 2001091700, , , , , , ARCHIVE, , AL062001
     FELIX, AL, L,  ,  ,  ,  , 07, 2001, HU, O, 2001090718, 2001091900, , , , , , ARCHIVE, , AL072001
 GABRIELLE, AL, L,  ,  ,  ,  , 08, 2001, HU, O, 2001091118, 2001092118, , , , , , ARCHIVE, , AL082001
      NINE, AL, L,  ,  ,  ,  , 09, 2001, TD, O, 2001091918, 2001092006, , , , , , ARCHIVE, , AL092001
  HUMBERTO, AL, L,  ,  ,  ,  , 10, 2001, HU, O, 2001092112, 2001092718, , , , , , ARCHIVE, , AL102001
      IRIS, AL, L,  ,  ,  ,  , 11, 2001, HU, O, 2001100412, 2001100912, , , , , , ARCHIVE, , AL112001
     JERRY, AL, L,  ,  ,  ,  , 12, 2001, TS, O, 2001100612, 2001100818, , , , , , ARCHIVE, , AL122001
     KAREN, AL, L,  ,  ,  ,  , 13, 2001, HU, O, 2001101106, 2001101518, , , , , , ARCHIVE, , AL132001
   LORENZO, AL, L,  ,  ,  ,  , 14, 2001, TS, O, 2001102712, 2001103106, , , , , , ARCHIVE, , AL142001
  MICHELLE, AL, L,  ,  ,  ,  , 15, 2001, HU, O, 2001102918, 2001110618, , , , , , ARCHIVE, , AL152001
      NOEL, AL, L,  ,  ,  ,  , 16, 2001, HU, O, 2001110400, 2001110618, , , , , , ARCHIVE, , AL162001
      OLGA, AL, L,  ,  ,  ,  , 17, 2001, HU, O, 2001112306, 2001120418, , , , , , ARCHIVE, , AL172001
       ONE, CP, C,  ,  ,  ,  , 01, 2001, TD, O, 2001091000, 2001091112, , , , , , ARCHIVE, , CP012001
       TWO, CP, C,  ,  ,  ,  , 02, 2001, TS, O, 2001092212, 2001092506, , , , , , ARCHIVE, , CP022001
    ADOLPH, EP, E,  ,  ,  ,  , 01, 2001, HU, O, 2001052518, 2001060118, , , , , , ARCHIVE, , EP012001
   BARBARA, EP, E,  ,  ,  ,  , 02, 2001, TS, O, 2001062000, 2001062606, , , , , , ARCHIVE, , EP022001
     COSME, EP, E,  ,  ,  ,  , 03, 2001, TS, O, 2001071306, 2001071506, , , , , , ARCHIVE, , EP032001
     ERICK, EP, E,  ,  ,  ,  , 04, 2001, TS, O, 2001072018, 2001072400, , , , , , ARCHIVE, , EP042001
    DALILA, EP, E,  ,  ,  ,  , 05, 2001, HU, O, 2001072100, 2001072812, , , , , , ARCHIVE, , EP052001
       SIX, EP, E,  ,  ,  ,  , 06, 2001, TD, O, 2001082212, 2001082400, , , , , , ARCHIVE, , EP062001
   FLOSSIE, EP, E,  ,  ,  ,  , 07, 2001, HU, O, 2001082606, 2001090200, , , , , , ARCHIVE, , EP072001
       GIL, EP, E,  ,  ,  ,  , 08, 2001, HU, O, 2001090406, 2001090918, , , , , , ARCHIVE, , EP082001
 HENRIETTE, EP, E,  ,  ,  ,  , 09, 2001, TS, O, 2001090412, 2001090812, , , , , , ARCHIVE, , EP092001
       IVO, EP, E,  ,  ,  ,  , 10, 2001, TS, O, 2001091012, 2001091500, , , , , , ARCHIVE, , EP102001
  JULIETTE, EP, E,  ,  ,  ,  , 11, 2001, HU, O, 2001092106, 2001100300, , , , , , ARCHIVE, , EP112001
      KIKO, EP, E,  ,  ,  ,  , 12, 2001, HU, O, 2001092118, 2001092518, , , , , , ARCHIVE, , EP122001
    LORENA, EP, E,  ,  ,  ,  , 13, 2001, TS, O, 2001100200, 2001100418, , , , , , ARCHIVE, , EP132001
  FOURTEEN, EP, E,  ,  ,  ,  , 14, 2001, TD, O, 2001100300, 2001100400, , , , , , ARCHIVE, , EP142001
    MANUEL, EP, E,  ,  ,  ,  , 15, 2001, TS, O, 2001101012, 2001101800, , , , , , ARCHIVE, , EP152001
     NARDA, EP, E,  ,  ,  ,  , 16, 2001, HU, O, 2001102012, 2001102506, , , , , , ARCHIVE, , EP162001
    OCTAVE, EP, E,  ,  ,  ,  , 17, 2001, HU, O, 2001103100, 2001110318, , , , , , ARCHIVE, , EP172001
    ARTHUR, AL, L,  ,  ,  ,  , 01, 2002, TS, O, 2002071418, 2002071912, , , , , , ARCHIVE, , AL012002
    BERTHA, AL, L,  ,  ,  ,  , 02, 2002, TS, O, 2002080418, 2002080912, , , , , , ARCHIVE, , AL022002
 CRISTOBAL, AL, L,  ,  ,  ,  , 03, 2002, TS, O, 2002080518, 2002080818, , , , , , ARCHIVE, , AL032002
     DOLLY, AL, L,  ,  ,  ,  , 04, 2002, TS, O, 2002082912, 2002090418, , , , , , ARCHIVE, , AL042002
   EDOUARD, AL, L,  ,  ,  ,  , 05, 2002, TS, O, 2002090118, 2002090612, , , , , , ARCHIVE, , AL052002
       FAY, AL, L, E,  ,  ,  , 06, 2002, TS, O, 2002090518, 2002091100, , , , , , ARCHIVE, , AL062002
     SEVEN, AL, L,  ,  ,  ,  , 07, 2002, TD, O, 2002090712, 2002090812, , , , , , ARCHIVE, , AL072002
    GUSTAV, AL, L,  ,  ,  ,  , 08, 2002, HU, O, 2002090812, 2002091500, , , , , , ARCHIVE, , AL082002
     HANNA, AL, L,  ,  ,  ,  , 09, 2002, TS, O, 2002091200, 2002091512, , , , , , ARCHIVE, , AL092002
   ISIDORE, AL, L,  ,  ,  ,  , 10, 2002, HU, O, 2002091418, 2002092718, , , , , , ARCHIVE, , AL102002
 JOSEPHINE, AL, L,  ,  ,  ,  , 11, 2002, TS, O, 2002091712, 2002091912, , , , , , ARCHIVE, , AL112002
      KYLE, AL, L,  ,  ,  ,  , 12, 2002, HU, O, 2002092018, 2002101212, , , , , , ARCHIVE, , AL122002
      LILI, AL, L,  ,  ,  ,  , 13, 2002, HU, O, 2002092118, 2002100412, , , , , , ARCHIVE, , AL132002
  FOURTEEN, AL, L,  ,  ,  ,  , 14, 2002, TD, O, 2002101412, 2002101618, , , , , , ARCHIVE, , AL142002
     ALIKA, CP, C, E,  ,  ,  , 01, 2002, TS, O, 2002082118, 2002082806, , , , , , ARCHIVE, , CP012002
       ELE, CP, C,  ,  ,  ,  , 02, 2002, HU, O, 2002082500, 2002083000, , , , , , ARCHIVE, , CP022002
      HUKO, CP, C,  ,  ,  ,  , 03, 2002, HU, O, 2002102318, 2002110306, , , , , , ARCHIVE, , CP032002
      ALMA, EP, E,  ,  ,  ,  , 01, 2002, HU, O, 2002052418, 2002060112, , , , , , ARCHIVE, , EP012002
     BORIS, EP, E,  ,  ,  ,  , 02, 2002, TS, O, 2002060812, 2002061200, , , , , , ARCHIVE, , EP022002
     THREE, EP, E,  ,  ,  ,  , 03, 2002, TD, O, 2002062712, 2002062906, , , , , , ARCHIVE, , EP032002
  CRISTINA, EP, E,  ,  ,  ,  , 04, 2002, TS, O, 2002070912, 2002071618, , , , , , ARCHIVE, , EP042002
   DOUGLAS, EP, E,  ,  ,  ,  , 05, 2002, HU, O, 2002072012, 2002072700, , , , , , ARCHIVE, , EP052002
     ELIDA, EP, E,  ,  ,  ,  , 06, 2002, HU, O, 2002072306, 2002073118, , , , , , ARCHIVE, , EP062002
     SEVEN, EP, E,  ,  ,  ,  , 07, 2002, TD, O, 2002080600, 2002080800, , , , , , ARCHIVE, , EP072002
    FAUSTO, EP, E, C,  ,  ,  , 08, 2002, HU, O, 2002082112, 2002090300, , , , , , ARCHIVE, , EP082002
 GENEVIEVE, EP, E,  ,  ,  ,  , 09, 2002, TS, O, 2002082600, 2002090106, , , , , , ARCHIVE, , EP092002
    HERNAN, EP, E,  ,  ,  ,  , 10, 2002, HU, O, 2002083006, 2002090618, , , , , , ARCHIVE, , EP102002
    ELEVEN, EP, E,  ,  ,  ,  , 11, 2002, TD, O, 2002090518, 2002091000, , , , , , ARCHIVE, , EP112002
    ISELLE, EP, E,  ,  ,  ,  , 12, 2002, TS, O, 2002091506, 2002092012, , , , , , ARCHIVE, , EP122002
     JULIO, EP, E,  ,  ,  ,  , 13, 2002, TS, O, 2002092500, 2002092612, , , , , , ARCHIVE, , EP132002
     KENNA, EP, E,  ,  ,  ,  , 14, 2002, HU, O, 2002102200, 2002102600, , , , , , ARCHIVE, , EP142002
    LOWELL, EP, E, C,  ,  ,  , 15, 2002, TS, O, 2002102218, 2002103100, , , , , , ARCHIVE, , EP152002
   SIXTEEN, EP, E,  ,  ,  ,  , 16, 2002, TD, O, 2002111400, 2002111606, , , , , , ARCHIVE, , EP162002
       ANA, AL, L,  ,  ,  ,  , 01, 2003, TS, O, 2003041800, 2003042712, , , , , , ARCHIVE, , AL012003
       TWO, AL, L,  ,  ,  ,  , 02, 2003, TD, O, 2003060912, 2003061300, , , , , , ARCHIVE, , AL022003
      BILL, AL, L,  ,  ,  ,  , 03, 2003, TS, O, 2003062806, 2003070300, , , , , , ARCHIVE, , AL032003
 CLAUDETTE, AL, L, E,  ,  ,  , 04, 2003, HU, O, 2003070700, 2003071712, , , , , , ARCHIVE, , AL042003
     DANNY, AL, L,  ,  ,  ,  , 05, 2003, HU, O, 2003071612, 2003072706, , , , , , ARCHIVE, , AL052003
       SIX, AL, L,  ,  ,  ,  , 06, 2003, TD, O, 2003071918, 2003072112, , , , , , ARCHIVE, , AL062003
     SEVEN, AL, L,  ,  ,  ,  , 07, 2003, TD, O, 2003072412, 2003072700, , , , , , ARCHIVE, , AL072003
     ERIKA, AL, L, E,  ,  ,  , 08, 2003, HU, O, 2003081418, 2003081700, , , , , , ARCHIVE, , AL082003
      NINE, AL, L,  ,  ,  ,  , 09, 2003, TD, O, 2003082118, 2003082212, , , , , , ARCHIVE, , AL092003
    FABIAN, AL, L,  ,  ,  ,  , 10, 2003, HU, O, 2003082718, 2003090918, , , , , , ARCHIVE, , AL102003
     GRACE, AL, L,  ,  ,  ,  , 11, 2003, TS, O, 2003083012, 2003090206, , , , , , ARCHIVE, , AL112003
     HENRI, AL, L,  ,  ,  ,  , 12, 2003, TS, O, 2003090318, 2003090818, , , , , , ARCHIVE, , AL122003
    ISABEL, AL, L,  ,  ,  ,  , 13, 2003, HU, O, 2003090600, 2003092000, , , , , , ARCHIVE, , AL132003
  FOURTEEN, AL, L,  ,  ,  ,  , 14, 2003, TD, O, 2003090806, 2003091012, , , , , , ARCHIVE, , AL142003
      JUAN, AL, L,  ,  ,  ,  , 15, 2003, HU, O, 2003092412, 2003092912, , , , , , ARCHIVE, , AL152003
      KATE, AL, L,  ,  ,  ,  , 16, 2003, HU, O, 2003092518, 2003101000, , , , , , ARCHIVE, , AL162003
     LARRY, AL, L, E,  ,  ,  , 17, 2003, TS, O, 2003092718, 2003100718, , , , , , ARCHIVE, , AL172003
     MINDY, AL, L,  ,  ,  ,  , 18, 2003, TS, O, 2003101018, 2003101400, , , , , , ARCHIVE, , AL182003
  NICHOLAS, AL, L,  ,  ,  ,  , 19, 2003, TS, O, 2003101018, 2003110118, , , , , , ARCHIVE, , AL192003
    ODETTE, AL, L,  ,  ,  ,  , 20, 2003, TS, O, 2003120412, 2003120918, , , , , , ARCHIVE, , AL202003
     PETER, AL, L,  ,  ,  ,  , 21, 2003, TS, O, 2003120718, 2003121106, , , , , , ARCHIVE, , AL212003
       ONE, CP, C, E,  ,  ,  , 01, 2003, TD, O, 2003081100, 2003081700, , , , , , ARCHIVE, , CP012003
    ANDRES, EP, E, C,  ,  ,  , 01, 2003, TS, O, 2003051918, 2003052612, , , , , , ARCHIVE, , EP012003
    BLANCA, EP, E,  ,  ,  ,  , 02, 2003, TS, O, 2003061700, 2003062418, , , , , , ARCHIVE, , EP022003
    CARLOS, EP, E, L,  ,  ,  , 03, 2003, TS, O, 2003062312, 2003062818, , , , , , ARCHIVE, , EP032003
   DOLORES, EP, E,  ,  ,  ,  , 04, 2003, TS, O, 2003070212, 2003070800, , , , , , ARCHIVE, , EP042003
   ENRIQUE, EP, E,  ,  ,  ,  , 05, 2003, TS, O, 2003071012, 2003071600, , , , , , ARCHIVE, , EP052003
   FELICIA, EP, E, C,  ,  ,  , 06, 2003, TS, O, 2003071718, 2003072412, , , , , , ARCHIVE, , EP062003
 GUILLERMO, EP, E, C,  ,  ,  , 07, 2003, TS, O, 2003080706, 2003081300, , , , , , ARCHIVE, , EP072003
     HILDA, EP, E,  ,  ,  ,  , 08, 2003, TS, O, 2003080906, 2003081312, , , , , , ARCHIVE, , EP082003
   IGNACIO, EP, E,  ,  ,  ,  , 09, 2003, HU, O, 2003082212, 2003082718, , , , , , ARCHIVE, , EP092003
    JIMENA, EP, E, C,  ,  ,  , 10, 2003, HU, O, 2003082618, 2003090300, , , , , , ARCHIVE, , EP102003
     KEVIN, EP, E,  ,  ,  ,  , 11, 2003, TS, O, 2003090312, 2003091006, , , , , , ARCHIVE, , EP112003
     LINDA, EP, E,  ,  ,  ,  , 12, 2003, HU, O, 2003091318, 2003091818, , , , , , ARCHIVE, , EP122003
     MARTY, EP, E,  ,  ,  ,  , 13, 2003, HU, O, 2003091818, 2003092600, , , , , , ARCHIVE, , EP132003
      NORA, EP, E,  ,  ,  ,  , 14, 2003, HU, O, 2003100118, 2003100906, , , , , , ARCHIVE, , EP142003
      OLAF, EP, E,  ,  ,  ,  , 15, 2003, HU, O, 2003100306, 2003100800, , , , , , ARCHIVE, , EP152003
  PATRICIA, EP, E,  ,  ,  ,  , 16, 2003, HU, O, 2003101912, 2003102700, , , , , , ARCHIVE, , EP162003
      ALEX, AL, L,  ,  ,  ,  , 01, 2004, HU, O, 2004073118, 2004080618, , , , , , ARCHIVE, , AL012004
    BONNIE, AL, L,  ,  ,  ,  , 02, 2004, TS, O, 2004080312, 2004081400, , , , , , ARCHIVE, , AL022004
   CHARLEY, AL, L,  ,  ,  ,  , 03, 2004, HU, O, 2004080912, 2004081512, , , , , , ARCHIVE, , AL032004
  DANIELLE, AL, L,  ,  ,  ,  , 04, 2004, HU, O, 2004081312, 2004082418, , , , , , ARCHIVE, , AL042004
      EARL, AL, L,  ,  ,  ,  , 05, 2004, TS, O, 2004081318, 2004081518, , , , , , ARCHIVE, , AL052004
   FRANCES, AL, L,  ,  ,  ,  , 06, 2004, HU, O, 2004082500, 2004091018, , , , , , ARCHIVE, , AL062004
    GASTON, AL, L,  ,  ,  ,  , 07, 2004, HU, O, 2004082712, 2004090300, , , , , , ARCHIVE, , AL072004
   HERMINE, AL, L,  ,  ,  ,  , 08, 2004, TS, O, 2004082718, 2004083112, , , , , , ARCHIVE, , AL082004
      IVAN, AL, L,  ,  ,  ,  , 09, 2004, HU, O, 2004090218, 2004092406, , , , , , ARCHIVE, , AL092004
       TEN, AL, L,  ,  ,  ,  , 10, 2004, TD, O, 2004090712, 2004091012, , , , , , ARCHIVE, , AL102004
    JEANNE, AL, L,  ,  ,  ,  , 11, 2004, HU, O, 2004091318, 2004092912, , , , , , ARCHIVE, , AL112004
      KARL, AL, L,  ,  ,  ,  , 12, 2004, HU, O, 2004091606, 2004092800, , , , , , ARCHIVE, , AL122004
      LISA, AL, L,  ,  ,  ,  , 13, 2004, HU, O, 2004091918, 2004100306, , , , , , ARCHIVE, , AL132004
   MATTHEW, AL, L,  ,  ,  ,  , 14, 2004, TS, O, 2004100812, 2004101106, , , , , , ARCHIVE, , AL142004
    NICOLE, AL, L,  ,  ,  ,  , 15, 2004, TS, O, 2004101000, 2004101118, , , , , , ARCHIVE, , AL152004
      OTTO, AL, L,  ,  ,  ,  , 16, 2004, TS, O, 2004112600, 2004120512, , , , , , ARCHIVE, , AL162004
       ONE, CP, C,  ,  ,  ,  , 01, 2004, TD, O, 2004070400, 2004070600, , , , , , ARCHIVE, , CP012004
    AGATHA, EP, E,  ,  ,  ,  , 01, 2004, TS, O, 2004052200, 2004052600, , , , , , ARCHIVE, , EP012004
       TWO, EP, E,  ,  ,  ,  , 02, 2004, TD, O, 2004070212, 2004070500, , , , , , ARCHIVE, , EP022004
      BLAS, EP, E,  ,  ,  ,  , 03, 2004, TS, O, 2004071212, 2004071906, , , , , , ARCHIVE, , EP032004
     CELIA, EP, E,  ,  ,  ,  , 04, 2004, HU, O, 2004071900, 2004072606, , , , , , ARCHIVE, , EP042004
     DARBY, EP, E, C,  ,  ,  , 05, 2004, HU, O, 2004072612, 2004080106, , , , , , ARCHIVE, , EP052004
       SIX, EP, E,  ,  ,  ,  , 06, 2004, TD, O, 2004080106, 2004080200, , , , , , ARCHIVE, , EP062004
   ESTELLE, EP, E, C,  ,  ,  , 07, 2004, TS, O, 2004081906, 2004082518, , , , , , ARCHIVE, , EP072004
     FRANK, EP, E,  ,  ,  ,  , 08, 2004, HU, O, 2004082306, 2004082712, , , , , , ARCHIVE, , EP082004
      NINE, EP, E,  ,  ,  ,  , 09, 2004, TD, O, 2004082318, 2004082806, , , , , , ARCHIVE, , EP092004
 GEORGETTE, EP, E, C,  ,  ,  , 10, 2004, TS, O, 2004082612, 2004090312, , , , , , ARCHIVE, , EP102004
    HOWARD, EP, E,  ,  ,  ,  , 11, 2004, HU, O, 2004083012, 2004091006, , , , , , ARCHIVE, , EP112004
      ISIS, EP, E, C,  ,  ,  , 12, 2004, HU, O, 2004090806, 2004092100, , , , , , ARCHIVE, , EP122004
    JAVIER, EP, E,  ,  ,  ,  , 13, 2004, HU, O, 2004091018, 2004092000, , , , , , ARCHIVE, , EP132004
       KAY, EP, E,  ,  ,  ,  , 14, 2004, TS, O, 2004100418, 2004100712, , , , , , ARCHIVE, , EP142004
    LESTER, EP, E,  ,  ,  ,  , 15, 2004, TS, O, 2004101118, 2004101312, , , , , , ARCHIVE, , EP152004
   SIXTEEN, EP, E,  ,  ,  ,  , 16, 2004, TD, O, 2004102500, 2004102612, , , , , , ARCHIVE, , EP162004
   UNNAMED, SL, S,  ,  ,  ,  , 01, 2004, HU, O, 2004032518, 2004032812, , , , , , ARCHIVE, , SL012004
    ARLENE, AL, L,  ,  ,  ,  , 01, 2005, TS, O, 2005060818, 2005061406, , , , , , ARCHIVE, , AL012005
      BRET, AL, L,  ,  ,  ,  , 02, 2005, TS, O, 2005062818, 2005063000, , , , , , ARCHIVE, , AL022005
     CINDY, AL, L,  ,  ,  ,  , 03, 2005, HU, O, 2005070318, 2005071106, , , , , , ARCHIVE, , AL032005
    DENNIS, AL, L,  ,  ,  ,  , 04, 2005, HU, O, 2005070418, 2005071806, , , , , , ARCHIVE, , AL042005
     EMILY, AL, L,  ,  ,  ,  , 05, 2005, HU, O, 2005071100, 2005072112, , , , , , ARCHIVE, , AL052005
  FRANKLIN, AL, L,  ,  ,  ,  , 06, 2005, TS, O, 2005072118, 2005073100, , , , , , ARCHIVE, , AL062005
      GERT, AL, L,  ,  ,  ,  , 07, 2005, TS, O, 2005072318, 2005072518, , , , , , ARCHIVE, , AL072005
    HARVEY, AL, L,  ,  ,  ,  , 08, 2005, TS, O, 2005080218, 2005081400, , , , , , ARCHIVE, , AL082005
     IRENE, AL, L,  ,  ,  ,  , 09, 2005, HU, O, 2005080418, 2005081812, , , , , , ARCHIVE, , AL092005
       TEN, AL, L,  ,  ,  ,  , 10, 2005, TD, O, 2005081312, 2005081812, , , , , , ARCHIVE, , AL102005
      JOSE, AL, L,  ,  ,  ,  , 11, 2005, TS, O, 2005082212, 2005082312, , , , , , ARCHIVE, , AL112005
   KATRINA, AL, L,  ,  ,  ,  , 12, 2005, HU, O, 2005082318, 2005083106, , , , , , ARCHIVE, , AL122005
       LEE, AL, L,  ,  ,  ,  , 13, 2005, TS, O, 2005082812, 2005090318, , , , , , ARCHIVE, , AL132005
     MARIA, AL, L,  ,  ,  ,  , 14, 2005, HU, O, 2005090112, 2005091400, , , , , , ARCHIVE, , AL142005
      NATE, AL, L,  ,  ,  ,  , 15, 2005, HU, O, 2005090518, 2005091218, , , , , , ARCHIVE, , AL152005
   OPHELIA, AL, L,  ,  ,  ,  , 16, 2005, HU, O, 2005090606, 2005092300, , , , , , ARCHIVE, , AL162005
  PHILIPPE, AL, L,  ,  ,  ,  , 17, 2005, HU, O, 2005091712, 2005092406, , , , , , ARCHIVE, , AL172005
      RITA, AL, L,  ,  ,  ,  , 18, 2005, HU, O, 2005091800, 2005092606, , , , , , ARCHIVE, , AL182005
  NINETEEN, AL, L,  ,  ,  ,  , 19, 2005, TD, O, 2005093012, 2005100212, , , , , , ARCHIVE, , AL192005
      STAN, AL, L,  ,  ,  ,  , 20, 2005, HU, S, 2005093018, 2005100506, , , , , , ARCHIVE, , AL202005
   UNNAMED, AL, L,  ,  ,  ,  , 21, 2005, SS, O, 2005100400, 2005100512, , , , , , ARCHIVE, , AL212005
     TAMMY, AL, L,  ,  ,  ,  , 22, 2005, TS, O, 2005100506, 2005100700, , , , , , ARCHIVE, , AL222005
TWENTY-TWO, AL, L,  ,  ,  ,  , 23, 2005, TD, S, 2005100612, 2005101118, , , , , , ARCHIVE, , AL232005
     VINCE, AL, L,  ,  ,  ,  , 24, 2005, HU, S, 2005100718, 2005101112, , , , , , ARCHIVE, , AL242005
     WILMA, AL, L,  ,  ,  ,  , 25, 2005, HU, O, 2005101518, 2005102618, , , , , , ARCHIVE, , AL252005
     ALPHA, AL, L,  ,  ,  ,  , 26, 2005, TS, O, 2005102212, 2005102418, , , , , , ARCHIVE, , AL262005
      BETA, AL, L,  ,  ,  ,  , 27, 2005, HU, O, 2005102618, 2005103100, , , , , , ARCHIVE, , AL272005
     GAMMA, AL, L,  ,  ,  ,  , 28, 2005, TS, O, 2005111400, 2005112200, , , , , , ARCHIVE, , AL282005
     DELTA, AL, L,  ,  ,  ,  , 29, 2005, TS, O, 2005111912, 2005112918, , , , , , ARCHIVE, , AL292005
   EPSILON, AL, L,  ,  ,  ,  , 30, 2005, HU, O, 2005112906, 2005120918, , , , , , ARCHIVE, , AL302005
      ZETA, AL, L,  ,  ,  ,  , 31, 2005, TS, O, 2005123000, 2006010718, , , , , , ARCHIVE, , AL312005
     ONE-C, CP, C,  ,  ,  ,  , 01, 2005, TD, O, 2005080218, 2005080500, , , , , , ARCHIVE, , CP012005
    ADRIAN, EP, E,  ,  ,  ,  , 01, 2005, HU, O, 2005051718, 2005052100, , , , , , ARCHIVE, , EP012005
   BEATRIZ, EP, E,  ,  ,  ,  , 02, 2005, TS, O, 2005062118, 2005062606, , , , , , ARCHIVE, , EP022005
    CALVIN, EP, E,  ,  ,  ,  , 03, 2005, TS, O, 2005062606, 2005070312, , , , , , ARCHIVE, , EP032005
      DORA, EP, E,  ,  ,  ,  , 04, 2005, TS, O, 2005070400, 2005070618, , , , , , ARCHIVE, , EP042005
    EUGENE, EP, E,  ,  ,  ,  , 05, 2005, TS, O, 2005071806, 2005072118, , , , , , ARCHIVE, , EP052005
  FERNANDA, EP, E, C,  ,  ,  , 06, 2005, HU, O, 2005080912, 2005081712, , , , , , ARCHIVE, , EP062005
      GREG, EP, E,  ,  ,  ,  , 07, 2005, TS, O, 2005081106, 2005081518, , , , , , ARCHIVE, , EP072005
    HILARY, EP, E,  ,  ,  ,  , 08, 2005, HU, O, 2005081918, 2005082800, , , , , , ARCHIVE, , EP082005
     IRWIN, EP, E,  ,  ,  ,  , 09, 2005, TS, O, 2005082512, 2005090218, , , , , , ARCHIVE, , EP092005
      JOVA, EP, E, C,  ,  ,  , 10, 2005, HU, O, 2005091200, 2005092500, , , , , , ARCHIVE, , EP102005
   KENNETH, EP, E,  ,  ,  ,  , 11, 2005, HU, O, 2005091418, 2005093018, , , , , , ARCHIVE, , EP112005
     LIDIA, EP, E,  ,  ,  ,  , 12, 2005, TS, O, 2005091712, 2005091900, , , , , , ARCHIVE, , EP122005
       MAX, EP, E,  ,  ,  ,  , 13, 2005, HU, O, 2005091712, 2005092212, , , , , , ARCHIVE, , EP132005
     NORMA, EP, E,  ,  ,  ,  , 14, 2005, TS, O, 2005092300, 2005100100, , , , , , ARCHIVE, , EP142005
      OTIS, EP, E,  ,  ,  ,  , 15, 2005, HU, O, 2005092800, 2005100512, , , , , , ARCHIVE, , EP152005
   SIXTEEN, EP, E,  ,  ,  ,  , 16, 2005, TD, O, 2005101500, 2005102106, , , , , , ARCHIVE, , EP162005
   ALBERTO, AL, L,  ,  ,  ,  , 01, 2006, TS, O, 2006061006, 2006061906, , , , , , ARCHIVE, , AL012006
    NONAME, AL, L,  ,  ,  ,  , 02, 2006, TS, O, 2006071612, 2006071912, , , , , , ARCHIVE, , AL022006
     BERYL, AL, L,  ,  ,  ,  , 03, 2006, TS, O, 2006071812, 2006072212, , , , , , ARCHIVE, , AL032006
     CHRIS, AL, L,  ,  ,  ,  , 04, 2006, TS, O, 2006080100, 2006080612, , , , , , ARCHIVE, , AL042006
     DEBBY, AL, L,  ,  ,  ,  , 05, 2006, TS, O, 2006082118, 2006082800, , , , , , ARCHIVE, , AL052006
   ERNESTO, AL, L,  ,  ,  ,  , 06, 2006, HU, O, 2006082418, 2006090406, , , , , , ARCHIVE, , AL062006
  FLORENCE, AL, L,  ,  ,  ,  , 07, 2006, HU, R, 2006090312, 2006091512, , , , , , ARCHIVE, , AL072006
    GORDON, AL, L,  ,  ,  ,  , 08, 2006, HU, O, 2006091018, 2006092418, , , , , , ARCHIVE, , AL082006
    HELENE, AL, L,  ,  ,  ,  , 09, 2006, HU, O, 2006091212, 2006092718, , , , , , ARCHIVE, , AL092006
     ISAAC, AL, L,  ,  ,  ,  , 10, 2006, HU, O, 2006092718, 2006100312, , , , , , ARCHIVE, , AL102006
      IOKE, CP, C, W,  ,  ,  , 01, 2006, HU, O, 2006081600, 2006082312, , , , , , ARCHIVE, , CP012006
       TWO, CP, C,  ,  ,  ,  , 02, 2006, TD, O, 2006091412, 2006092318, , , , , , ARCHIVE, , CP022006
     THREE, CP, C,  ,  ,  ,  , 03, 2006, TD, O, 2006092500, 2006092706, , , , , , ARCHIVE, , CP032006
      FOUR, CP, C,  ,  ,  ,  , 04, 2006, TD, O, 2006100718, 2006101618, , , , , , ARCHIVE, , CP042006
    ALETTA, EP, E,  ,  ,  ,  , 01, 2006, TS, O, 2006052706, 2006053100, , , , , , ARCHIVE, , EP012006
       TWO, EP, E,  ,  ,  ,  , 02, 2006, TD, O, 2006060312, 2006060500, , , , , , ARCHIVE, , EP022006
       BUD, EP, E,  ,  ,  ,  , 03, 2006, HU, O, 2006071100, 2006071712, , , , , , ARCHIVE, , EP032006
  CARLOTTA, EP, E,  ,  ,  ,  , 04, 2006, HU, O, 2006071200, 2006072000, , , , , , ARCHIVE, , EP042006
    DANIEL, EP, E,  ,  ,  ,  , 05, 2006, HU, O, 2006071618, 2006072812, , , , , , ARCHIVE, , EP052006
    EMILIA, EP, E,  ,  ,  ,  , 06, 2006, TS, O, 2006072112, 2006073112, , , , , , ARCHIVE, , EP062006
     FABIO, EP, E,  ,  ,  ,  , 07, 2006, TS, O, 2006073118, 2006080518, , , , , , ARCHIVE, , EP072006
     GILMA, EP, E,  ,  ,  ,  , 08, 2006, TS, O, 2006080100, 2006080500, , , , , , ARCHIVE, , EP082006
    HECTOR, EP, E,  ,  ,  ,  , 09, 2006, HU, O, 2006081518, 2006082406, , , , , , ARCHIVE, , EP092006
    ILEANA, EP, E,  ,  ,  ,  , 10, 2006, HU, O, 2006082112, 2006082906, , , , , , ARCHIVE, , EP102006
      JOHN, EP, E,  ,  ,  ,  , 11, 2006, HU, O, 2006082800, 2006090412, , , , , , ARCHIVE, , EP112006
    KRISTY, EP, E,  ,  ,  ,  , 12, 2006, HU, O, 2006083000, 2006090906, , , , , , ARCHIVE, , EP122006
      LANE, EP, E,  ,  ,  ,  , 13, 2006, HU, O, 2006091318, 2006091712, , , , , , ARCHIVE, , EP132006
    MIRIAM, EP, E,  ,  ,  ,  , 14, 2006, TS, O, 2006091600, 2006092106, , , , , , ARCHIVE, , EP142006
    NORMAN, EP, E,  ,  ,  ,  , 15, 2006, TS, O, 2006100900, 2006101518, , , , , , ARCHIVE, , EP152006
    OLIVIA, EP, E,  ,  ,  ,  , 16, 2006, TS, O, 2006100918, 2006101418, , , , , , ARCHIVE, , EP162006
      PAUL, EP, E,  ,  ,  ,  , 17, 2006, HU, O, 2006102106, 2006102606, , , , , , ARCHIVE, , EP172006
  EIGHTEEN, EP, E,  ,  ,  ,  , 18, 2006, TD, O, 2006102612, 2006102900, , , , , , ARCHIVE, , EP182006
      ROSA, EP, E,  ,  ,  ,  , 19, 2006, TS, O, 2006110806, 2006111018, , , , , , ARCHIVE, , EP192006
    TWENTY, EP, E,  ,  ,  ,  , 20, 2006, TD, O, 2006111100, 2006111112, , , , , , ARCHIVE, , EP202006
    SERGIO, EP, E,  ,  ,  ,  , 21, 2006, HU, O, 2006111318, 2006112018, , , , , , ARCHIVE, , EP212006
    ANDREA, AL, L,  ,  ,  ,  , 01, 2007, HU, O, 2007050612, 2007051400, , , , , , ARCHIVE, , AL012007
     BARRY, AL, L,  ,  ,  ,  , 02, 2007, TS, O, 2007053100, 2007060512, , , , , , ARCHIVE, , AL022007
   CHANTAL, AL, L,  ,  ,  ,  , 03, 2007, TS, O, 2007073100, 2007080512, , , , , , ARCHIVE, , AL032007
      DEAN, AL, L,  ,  ,  ,  , 04, 2007, HU, O, 2007081306, 2007082300, , , , , , ARCHIVE, , AL042007
      ERIN, AL, L,  ,  ,  ,  , 05, 2007, TS, O, 2007081500, 2007081918, , , , , , ARCHIVE, , AL052007
     FELIX, AL, L,  ,  ,  ,  , 06, 2007, HU, O, 2007083112, 2007090618, , , , , , ARCHIVE, , AL062007
 GABRIELLE, AL, L,  ,  ,  ,  , 07, 2007, TS, O, 2007090800, 2007091106, , , , , , ARCHIVE, , AL072007
    INGRID, AL, L,  ,  ,  ,  , 08, 2007, TS, O, 2007091206, 2007091812, , , , , , ARCHIVE, , AL082007
  HUMBERTO, AL, L,  ,  ,  ,  , 09, 2007, HU, O, 2007091206, 2007091412, , , , , , ARCHIVE, , AL092007
       TEN, AL, L,  ,  ,  ,  , 10, 2007, TD, O, 2007092112, 2007092206, , , , , , ARCHIVE, , AL102007
     JERRY, AL, L,  ,  ,  ,  , 11, 2007, TS, O, 2007092300, 2007092418, , , , , , ARCHIVE, , AL112007
     KAREN, AL, L,  ,  ,  ,  , 12, 2007, HU, O, 2007092500, 2007092912, , , , , , ARCHIVE, , AL122007
   LORENZO, AL, L,  ,  ,  ,  , 13, 2007, HU, O, 2007092518, 2007092818, , , , , , ARCHIVE, , AL132007
   MELISSA, AL, L,  ,  ,  ,  , 14, 2007, TS, O, 2007092806, 2007100518, , , , , , ARCHIVE, , AL142007
   FIFTEEN, AL, L,  ,  ,  ,  , 15, 2007, TS, O, 2007101112, 2007101718, , , , , , ARCHIVE, , AL152007
      NOEL, AL, L,  ,  ,  ,  , 16, 2007, HU, O, 2007102400, 2007110600, , , , , , ARCHIVE, , AL162007
      OLGA, AL, L,  ,  ,  ,  , 17, 2007, TS, O, 2007121012, 2007121606, , , , , , ARCHIVE, , AL172007
     ALVIN, EP, E,  ,  ,  ,  , 01, 2007, TS, O, 2007052700, 2007060612, , , , , , ARCHIVE, , EP012007
   BARBARA, EP, E,  ,  ,  ,  , 02, 2007, TS, O, 2007052918, 2007060218, , , , , , ARCHIVE, , EP022007
     THREE, EP, E,  ,  ,  ,  , 03, 2007, TD, O, 2007061112, 2007061500, , , , , , ARCHIVE, , EP032007
      FOUR, EP, E,  ,  ,  ,  , 04, 2007, TD, O, 2007070918, 2007071118, , , , , , ARCHIVE, , EP042007
      FIVE, EP, E,  ,  ,  ,  , 05, 2007, TD, O, 2007071412, 2007071600, , , , , , ARCHIVE, , EP052007
     COSME, EP, E, C,  ,  ,  , 06, 2007, HU, O, 2007071412, 2007072418, , , , , , ARCHIVE, , EP062007
    DALILA, EP, E,  ,  ,  ,  , 07, 2007, TS, O, 2007072200, 2007073006, , , , , , ARCHIVE, , EP072007
     ERICK, EP, E,  ,  ,  ,  , 08, 2007, TS, O, 2007073112, 2007080200, , , , , , ARCHIVE, , EP082007
   FLOSSIE, EP, E, C,  ,  ,  , 09, 2007, HU, O, 2007080818, 2007081612, , , , , , ARCHIVE, , EP092007
       GIL, EP, E,  ,  ,  ,  , 10, 2007, TS, O, 2007082912, 2007090300, , , , , , ARCHIVE, , EP102007
 HENRIETTE, EP, E,  ,  ,  ,  , 11, 2007, HU, O, 2007083006, 2007090606, , , , , , ARCHIVE, , EP112007
       IVO, EP, E,  ,  ,  ,  , 12, 2007, HU, O, 2007091806, 2007092500, , , , , , ARCHIVE, , EP122007
  THIRTEEN, EP, E,  ,  ,  ,  , 13, 2007, TD, O, 2007091906, 2007092500, , , , , , ARCHIVE, , EP132007
  JULIETTE, EP, E,  ,  ,  ,  , 14, 2007, TS, O, 2007092900, 2007100500, , , , , , ARCHIVE, , EP142007
      KIKO, EP, E,  ,  ,  ,  , 15, 2007, TS, O, 2007101500, 2007102706, , , , , , ARCHIVE, , EP152007
    ARTHUR, AL, L,  ,  ,  ,  , 01, 2008, TS, O, 2008053100, 2008060200, , , , , , ARCHIVE, , AL012008
    BERTHA, AL, L,  ,  ,  ,  , 02, 2008, TS, O, 2008063006, 2008072012, , , , , , ARCHIVE, , AL022008
 CRISTOBAL, AL, L,  ,  ,  ,  , 03, 2008, TS, O, 2008071900, 2008072306, , , , , , ARCHIVE, , AL032008
     DOLLY, AL, L, E,  ,  ,  , 04, 2008, HU, O, 2008072012, 2008072700, , , , , , ARCHIVE, , AL042008
   EDOUARD, AL, L,  ,  ,  ,  , 05, 2008, TS, O, 2008080312, 2008080618, , , , , , ARCHIVE, , AL052008
       FAY, AL, L,  ,  ,  ,  , 06, 2008, TS, O, 2008081512, 2008082806, , , , , , ARCHIVE, , AL062008
    GUSTAV, AL, L,  ,  ,  ,  , 07, 2008, HU, O, 2008082500, 2008090512, , , , , , ARCHIVE, , AL072008
     HANNA, AL, L,  ,  ,  ,  , 08, 2008, HU, O, 2008082800, 2008090812, , , , , , ARCHIVE, , AL082008
       IKE, AL, L,  ,  ,  ,  , 09, 2008, HU, O, 2008090106, 2008091512, , , , , , ARCHIVE, , AL092008
 JOSEPHINE, AL, L,  ,  ,  ,  , 10, 2008, TS, O, 2008090200, 2008091000, , , , , , ARCHIVE, , AL102008
      KYLE, AL, L,  ,  ,  ,  , 11, 2008, HU, O, 2008092500, 2008093012, , , , , , ARCHIVE, , AL112008
     LAURA, AL, L,  ,  ,  ,  , 12, 2008, HU, O, 2008092600, 2008100406, , , , , , ARCHIVE, , AL122008
     MARCO, AL, L,  ,  ,  ,  , 13, 2008, TS, O, 2008100600, 2008100718, , , , , , ARCHIVE, , AL132008
      NANA, AL, L,  ,  ,  ,  , 14, 2008, TS, O, 2008101206, 2008101512, , , , , , ARCHIVE, , AL142008
      OMAR, AL, L,  ,  ,  ,  , 15, 2008, HU, O, 2008101306, 2008102100, , , , , , ARCHIVE, , AL152008
   SIXTEEN, AL, L,  ,  ,  ,  , 16, 2008, TD, O, 2008101412, 2008101600, , , , , , ARCHIVE, , AL162008
    PALOMA, AL, L,  ,  ,  ,  , 17, 2008, HU, O, 2008110518, 2008111406, , , , , , ARCHIVE, , AL172008
      KIKA, CP, C, E, W,  ,  , 01, 2008, TS, O, 2008080412, 2008081606, , , , , , ARCHIVE, , CP012008
      ALMA, EP, E,  ,  ,  ,  , 01, 2008, TS, O, 2008052900, 2008053012, , , , , , ARCHIVE, , EP012008
     BORIS, EP, E,  ,  ,  ,  , 02, 2008, HU, O, 2008062706, 2008070606, , , , , , ARCHIVE, , EP022008
  CRISTINA, EP, E,  ,  ,  ,  , 03, 2008, TS, O, 2008062718, 2008070300, , , , , , ARCHIVE, , EP032008
   DOUGLAS, EP, E,  ,  ,  ,  , 04, 2008, TS, O, 2008070118, 2008070606, , , , , , ARCHIVE, , EP042008
      FIVE, EP, E,  ,  ,  ,  , 05, 2008, TD, O, 2008070118, 2008070706, , , , , , ARCHIVE, , EP052008
     ELIDA, EP, E, C,  ,  ,  , 06, 2008, TD, O, 2008071000, 2008072100, , , , , , ARCHIVE, , EP062008
    FAUSTO, EP, E,  ,  ,  ,  , 07, 2008, HU, O, 2008071606, 2008072406, , , , , , ARCHIVE, , EP072008
 GENEVIEVE, EP, E, C,  ,  ,  , 08, 2008, HU, O, 2008072112, 2008073106, , , , , , ARCHIVE, , EP082008
    HERNAN, EP, E, C,  ,  ,  , 09, 2008, HU, O, 2008080612, 2008081612, , , , , , ARCHIVE, , EP092008
    ISELLE, EP, E,  ,  ,  ,  , 10, 2008, TS, O, 2008081312, 2008082312, , , , , , ARCHIVE, , EP102008
     JULIO, EP, E,  ,  ,  ,  , 11, 2008, TS, O, 2008082312, 2008082706, , , , , , ARCHIVE, , EP112008
    KARINA, EP, E,  ,  ,  ,  , 12, 2008, TS, O, 2008090206, 2008090318, , , , , , ARCHIVE, , EP122008
    LOWELL, EP, E,  ,  ,  ,  , 13, 2008, TS, O, 2008090612, 2008091112, , , , , , ARCHIVE, , EP132008
     MARIE, EP, E,  ,  ,  ,  , 14, 2008, HU, O, 2008100106, 2008101912, , , , , , ARCHIVE, , EP142008
   NORBERT, EP, E,  ,  ,  ,  , 15, 2008, HU, O, 2008100400, 2008101212, , , , , , ARCHIVE, , EP152008
     ODILE, EP, E,  ,  ,  ,  , 16, 2008, TS, O, 2008100812, 2008101312, , , , , , ARCHIVE, , EP162008
 SEVENTEEN, EP, E,  ,  ,  ,  , 17, 2008, TD, O, 2008102306, 2008102718, , , , , , ARCHIVE, , EP172008
      POLO, EP, E,  ,  ,  ,  , 18, 2008, TS, O, 2008110212, 2008110500, , , , , , ARCHIVE, , EP182008
       ONE, AL, L,  ,  ,  ,  , 01, 2009, TD, O, 2009052618, 2009053006, , , , , , ARCHIVE, , AL012009
       ANA, AL, L,  ,  ,  ,  , 02, 2009, TS, O, 2009081000, 2009081612, , , , , , ARCHIVE, , AL022009
      BILL, AL, L,  ,  ,  ,  , 03, 2009, HU, O, 2009081506, 2009082600, , , , , , ARCHIVE, , AL032009
 CLAUDETTE, AL, L,  ,  ,  ,  , 04, 2009, TS, O, 2009081606, 2009081718, , , , , , ARCHIVE, , AL042009
     DANNY, AL, L,  ,  ,  ,  , 05, 2009, TS, O, 2009082609, 2009082900, , , , , , ARCHIVE, , AL052009
     ERIKA, AL, L,  ,  ,  ,  , 06, 2009, TS, O, 2009090118, 2009090406, , , , , , ARCHIVE, , AL062009
      FRED, AL, L,  ,  ,  ,  , 07, 2009, HU, O, 2009090718, 2009091912, , , , , , ARCHIVE, , AL072009
     EIGHT, AL, L,  ,  ,  ,  , 08, 2009, TD, O, 2009092506, 2009092618, , , , , , ARCHIVE, , AL082009
     GRACE, AL, L,  ,  ,  ,  , 09, 2009, TS, O, 2009092718, 2009100618, , , , , , ARCHIVE, , AL092009
     HENRI, AL, L,  ,  ,  ,  , 10, 2009, TS, O, 2009100600, 2009101112, , , , , , ARCHIVE, , AL102009
       IDA, AL, L,  ,  ,  ,  , 11, 2009, HU, O, 2009110406, 2009111106, , , , , , ARCHIVE, , AL112009
      MAKA, CP, C, W,  ,  ,  , 01, 2009, TS, O, 2009080818, 2009081806, , , , , , ARCHIVE, , CP012009
       TWO, CP, C, W,  ,  ,  , 02, 2009, TD, O, 2009082606, 2009090200, , , , , , ARCHIVE, , CP022009
      NEKI, CP, C,  ,  ,  ,  , 03, 2009, HU, O, 2009101818, 2009102700, , , , , , ARCHIVE, , CP032009
       ONE, EP, E,  ,  ,  ,  , 01, 2009, TD, O, 2009061718, 2009061912, , , , , , ARCHIVE, , EP012009
    ANDRES, EP, E,  ,  ,  ,  , 02, 2009, HU, O, 2009062112, 2009062412, , , , , , ARCHIVE, , EP022009
    BLANCA, EP, E,  ,  ,  ,  , 03, 2009, TS, O, 2009070606, 2009071206, , , , , , ARCHIVE, , EP032009
    CARLOS, EP, E,  ,  ,  ,  , 04, 2009, HU, O, 2009071006, 2009071618, , , , , , ARCHIVE, , EP042009
   DOLORES, EP, E,  ,  ,  ,  , 05, 2009, TS, O, 2009071400, 2009072000, , , , , , ARCHIVE, , EP052009
      LANA, EP, E, C,  ,  ,  , 06, 2009, TS, O, 2009073012, 2009080306, , , , , , ARCHIVE, , EP062009
   ENRIQUE, EP, E,  ,  ,  ,  , 07, 2009, TS, O, 2009080318, 2009080812, , , , , , ARCHIVE, , EP072009
   FELICIA, EP, E, C,  ,  ,  , 08, 2009, HU, O, 2009080318, 2009081118, , , , , , ARCHIVE, , EP082009
      NINE, EP, E,  ,  ,  ,  , 09, 2009, TD, O, 2009080900, 2009081500, , , , , , ARCHIVE, , EP092009
 GUILLERMO, EP, E, C,  ,  ,  , 10, 2009, HU, O, 2009081200, 2009082306, , , , , , ARCHIVE, , EP102009
     HILDA, EP, E, C,  ,  ,  , 11, 2009, TS, O, 2009082112, 2009083118, , , , , , ARCHIVE, , EP112009
   IGNACIO, EP, E,  ,  ,  ,  , 12, 2009, TS, O, 2009082418, 2009082818, , , , , , ARCHIVE, , EP122009
    JIMENA, EP, E,  ,  ,  ,  , 13, 2009, HU, O, 2009082800, 2009090512, , , , , , ARCHIVE, , EP132009
     KEVIN, EP, E,  ,  ,  ,  , 14, 2009, TS, O, 2009082718, 2009090606, , , , , , ARCHIVE, , EP142009
     LINDA, EP, E,  ,  ,  ,  , 15, 2009, HU, O, 2009090600, 2009091500, , , , , , ARCHIVE, , EP152009
     MARTY, EP, E,  ,  ,  ,  , 16, 2009, TS, O, 2009091512, 2009092218, , , , , , ARCHIVE, , EP162009
      NORA, EP, E,  ,  ,  ,  , 17, 2009, TS, O, 2009092200, 2009092912, , , , , , ARCHIVE, , EP172009
      OLAF, EP, E,  ,  ,  ,  , 18, 2009, TS, O, 2009100112, 2009100412, , , , , , ARCHIVE, , EP182009
  PATRICIA, EP, E,  ,  ,  ,  , 19, 2009, TS, O, 2009101118, 2009101512, , , , , , ARCHIVE, , EP192009
      RICK, EP, E,  ,  ,  ,  , 20, 2009, HU, O, 2009101518, 2009102120, , , , , , ARCHIVE, , EP202009
      ALEX, AL, L,  ,  ,  ,  , 01, 2010, HU, O, 2010062418, 2010070200, , , , , , ARCHIVE, , AL012010
       TWO, AL, L,  ,  ,  ,  , 02, 2010, TD, O, 2010070706, 2010071000, , , , , , ARCHIVE, , AL022010
    BONNIE, AL, L,  ,  ,  ,  , 03, 2010, TS, O, 2010072206, 2010072518, , , , , , ARCHIVE, , AL032010
     COLIN, AL, L,  ,  ,  ,  , 04, 2010, TS, O, 2010080212, 2010080806, , , , , , ARCHIVE, , AL042010
      FIVE, AL, L,  ,  ,  ,  , 05, 2010, TD, O, 2010081006, 2010081800, , , , , , ARCHIVE, , AL052010
  DANIELLE, AL, L,  ,  ,  ,  , 06, 2010, HU, O, 2010082112, 2010090300, , , , , , ARCHIVE, , AL062010
      EARL, AL, L,  ,  ,  ,  , 07, 2010, HU, O, 2010082400, 2010090600, , , , , , ARCHIVE, , AL072010
     FIONA, AL, L,  ,  ,  ,  , 08, 2010, TS, O, 2010083000, 2010090418, , , , , , ARCHIVE, , AL082010
    GASTON, AL, L,  ,  ,  ,  , 09, 2010, TS, O, 2010090100, 2010090806, , , , , , ARCHIVE, , AL092010
   HERMINE, AL, L,  ,  ,  ,  , 10, 2010, TS, O, 2010090418, 2010091000, , , , , , ARCHIVE, , AL102010
      IGOR, AL, L,  ,  ,  ,  , 11, 2010, HU, O, 2010090806, 2010092300, , , , , , ARCHIVE, , AL112010
     JULIA, AL, L,  ,  ,  ,  , 12, 2010, HU, O, 2010091206, 2010092418, , , , , , ARCHIVE, , AL122010
      KARL, AL, L,  ,  ,  ,  , 13, 2010, HU, O, 2010091318, 2010091806, , , , , , ARCHIVE, , AL132010
      LISA, AL, L,  ,  ,  ,  , 14, 2010, HU, O, 2010092000, 2010092900, , , , , , ARCHIVE, , AL142010
   MATTHEW, AL, L,  ,  ,  ,  , 15, 2010, TS, O, 2010092312, 2010092618, , , , , , ARCHIVE, , AL152010
    NICOLE, AL, L,  ,  ,  ,  , 16, 2010, TS, O, 2010092800, 2010093012, , , , , , ARCHIVE, , AL162010
      OTTO, AL, L,  ,  ,  ,  , 17, 2010, HU, O, 2010100606, 2010101718, , , , , , ARCHIVE, , AL172010
     PAULA, AL, L,  ,  ,  ,  , 18, 2010, HU, O, 2010101100, 2010101518, , , , , , ARCHIVE, , AL182010
   RICHARD, AL, L,  ,  ,  ,  , 19, 2010, HU, O, 2010101918, 2010102612, , , , , , ARCHIVE, , AL192010
     SHARY, AL, L,  ,  ,  ,  , 20, 2010, HU, O, 2010102818, 2010103018, , , , , , ARCHIVE, , AL202010
     TOMAS, AL, L,  ,  ,  ,  , 21, 2010, HU, O, 2010102906, 2010111018, , , , , , ARCHIVE, , AL212010
     OMEKA, CP, C, W,  ,  ,  , 01, 2010, TS, O, 2010121600, 2010122218, , , , , , ARCHIVE, , CP012010
    AGATHA, EP, E,  ,  ,  ,  , 01, 2010, TS, O, 2010052818, 2010053012, , , , , , ARCHIVE, , EP012010
       TWO, EP, E,  ,  ,  ,  , 02, 2010, TD, O, 2010061606, 2010061700, , , , , , ARCHIVE, , EP022010
      BLAS, EP, E,  ,  ,  ,  , 03, 2010, TS, O, 2010061506, 2010062300, , , , , , ARCHIVE, , EP032010
     CELIA, EP, E,  ,  ,  ,  , 04, 2010, HU, O, 2010061806, 2010063012, , , , , , ARCHIVE, , EP042010
     DARBY, EP, E,  ,  ,  ,  , 05, 2010, HU, O, 2010062012, 2010062918, , , , , , ARCHIVE, , EP052010
       SIX, EP, E,  ,  ,  ,  , 06, 2010, TD, O, 2010071400, 2010071806, , , , , , ARCHIVE, , EP062010
   ESTELLE, EP, E,  ,  ,  ,  , 07, 2010, TS, O, 2010080412, 2010081018, , , , , , ARCHIVE, , EP072010
     EIGHT, EP, E,  ,  ,  ,  , 08, 2010, TD, O, 2010082006, 2010082300, , , , , , ARCHIVE, , EP082010
     FRANK, EP, E,  ,  ,  ,  , 09, 2010, HU, O, 2010082118, 2010082900, , , , , , ARCHIVE, , EP092010
       TEN, EP, E,  ,  ,  ,  , 10, 2010, TD, O, 2010090300, 2010090506, , , , , , ARCHIVE, , EP102010
    ELEVEN, EP, E,  ,  ,  ,  , 11, 2010, TD, O, 2010090318, 2010090418, , , , , , ARCHIVE, , EP112010
 GEORGETTE, EP, E,  ,  ,  ,  , 12, 2010, TS, O, 2010092012, 2010092300, , , , , , ARCHIVE, , EP122010
   UNNAMED, SL, Q,  ,  ,  ,  , 50, 2010, TS, O, 2010030800, 2010031218, , , , , , ARCHIVE, , SL502010
    ARLENE, AL, L,  ,  ,  ,  , 01, 2011, TS, O, 2011062806, 2011070100, , , , , , ARCHIVE, , AL012011
      BRET, AL, L,  ,  ,  ,  , 02, 2011, TS, O, 2011071606, 2011072306, , , , , , ARCHIVE, , AL022011
     CINDY, AL, L,  ,  ,  ,  , 03, 2011, TS, O, 2011072006, 2011072306, , , , , , ARCHIVE, , AL032011
       DON, AL, L,  ,  ,  ,  , 04, 2011, TS, O, 2011072706, 2011073006, , , , , , ARCHIVE, , AL042011
     EMILY, AL, L,  ,  ,  ,  , 05, 2011, TS, O, 2011080200, 2011080718, , , , , , ARCHIVE, , AL052011
  FRANKLIN, AL, L,  ,  ,  ,  , 06, 2011, TS, O, 2011081212, 2011081600, , , , , , ARCHIVE, , AL062011
      GERT, AL, L,  ,  ,  ,  , 07, 2011, TS, O, 2011081306, 2011081718, , , , , , ARCHIVE, , AL072011
    HARVEY, AL, L,  ,  ,  ,  , 08, 2011, TS, O, 2011081900, 2011082212, , , , , , ARCHIVE, , AL082011
     IRENE, AL, L,  ,  ,  ,  , 09, 2011, HU, O, 2011082100, 2011083000, , , , , , ARCHIVE, , AL092011
       TEN, AL, L,  ,  ,  ,  , 10, 2011, TD, O, 2011082500, 2011082700, , , , , , ARCHIVE, , AL102011
      JOSE, AL, L,  ,  ,  ,  , 11, 2011, TS, O, 2011082612, 2011082912, , , , , , ARCHIVE, , AL112011
     KATIA, AL, L,  ,  ,  ,  , 12, 2011, HU, O, 2011082800, 2011091218, , , , , , ARCHIVE, , AL122011
       LEE, AL, L,  ,  ,  ,  , 13, 2011, TS, O, 2011090200, 2011090618, , , , , , ARCHIVE, , AL132011
     MARIA, AL, L,  ,  ,  ,  , 14, 2011, HU, O, 2011090618, 2011091618, , , , , , ARCHIVE, , AL142011
      NATE, AL, L,  ,  ,  ,  , 15, 2011, HU, O, 2011090618, 2011091200, , , , , , ARCHIVE, , AL152011
   OPHELIA, AL, L,  ,  ,  ,  , 16, 2011, HU, O, 2011092006, 2011100412, , , , , , ARCHIVE, , AL162011
  PHILIPPE, AL, L,  ,  ,  ,  , 17, 2011, HU, O, 2011092300, 2011100900, , , , , , ARCHIVE, , AL172011
      RINA, AL, L,  ,  ,  ,  , 18, 2011, HU, O, 2011102200, 2011102906, , , , , , ARCHIVE, , AL182011
      SEAN, AL, L,  ,  ,  ,  , 19, 2011, TS, O, 2011110600, 2011111218, , , , , , ARCHIVE, , AL192011
   UNNAMED, AL, L,  ,  ,  ,  , 20, 2011, TS, O, 2011083112, 2011090318, , , , , , ARCHIVE, , AL202011
    ADRIAN, EP, E,  ,  ,  ,  , 01, 2011, HU, O, 2011060700, 2011061406, , , , , , ARCHIVE, , EP012011
   BEATRIZ, EP, E,  ,  ,  ,  , 02, 2011, HU, O, 2011061818, 2011062200, , , , , , ARCHIVE, , EP022011
    CALVIN, EP, E,  ,  ,  ,  , 03, 2011, HU, O, 2011070700, 2011071400, , , , , , ARCHIVE, , EP032011
      DORA, EP, E,  ,  ,  ,  , 04, 2011, HU, O, 2011071800, 2011072600, , , , , , ARCHIVE, , EP042011
    EUGENE, EP, E,  ,  ,  ,  , 05, 2011, HU, O, 2011073012, 2011081000, , , , , , ARCHIVE, , EP052011
  FERNANDA, EP, E, C,  ,  ,  , 06, 2011, TS, O, 2011081412, 2011082112, , , , , , ARCHIVE, , EP062011
      GREG, EP, E,  ,  ,  ,  , 07, 2011, HU, O, 2011081618, 2011082300, , , , , , ARCHIVE, , EP072011
     EIGHT, EP, E,  ,  ,  ,  , 08, 2011, TD, O, 2011082906, 2011090100, , , , , , ARCHIVE, , EP082011
    HILARY, EP, E,  ,  ,  ,  , 09, 2011, HU, O, 2011092106, 2011100312, , , , , , ARCHIVE, , EP092011
      JOVA, EP, E,  ,  ,  ,  , 10, 2011, HU, O, 2011100512, 2011101218, , , , , , ARCHIVE, , EP102011
     IRWIN, EP, E,  ,  ,  ,  , 11, 2011, HU, O, 2011100418, 2011101812, , , , , , ARCHIVE, , EP112011
    TWELVE, EP, E,  ,  ,  ,  , 12, 2011, TD, O, 2011100618, 2011101300, , , , , , ARCHIVE, , EP122011
   KENNETH, EP, E,  ,  ,  ,  , 13, 2011, HU, O, 2011111812, 2011112600, , , , , , ARCHIVE, , EP132011
   UNNAMED, SL, Q,  ,  ,  ,  , 50, 2011, XX, O, 2011030918, 2011031618, , , , , , ARCHIVE, , SL502011
   ALBERTO, AL, L,  ,  ,  ,  , 01, 2012, TS, O, 2012051900, 2012052318, , , , , , ARCHIVE, , AL012012
     BERYL, AL, L,  ,  ,  ,  , 02, 2012, TS, O, 2012052512, 2012060200, , , , , , ARCHIVE, , AL022012
     CHRIS, AL, L,  ,  ,  ,  , 03, 2012, HU, O, 2012061700, 2012062412, , , , , , ARCHIVE, , AL032012
     DEBBY, AL, L,  ,  ,  ,  , 04, 2012, TS, O, 2012062312, 2012062712, , , , , , ARCHIVE, , AL042012
   ERNESTO, AL, L,  ,  ,  ,  , 05, 2012, HU, O, 2012080112, 2012081006, , , , , , ARCHIVE, , AL052012
  FLORENCE, AL, L,  ,  ,  ,  , 06, 2012, TS, O, 2012080306, 2012080806, , , , , , ARCHIVE, , AL062012
    HELENE, AL, L,  ,  ,  ,  , 07, 2012, TS, O, 2012080918, 2012081900, , , , , , ARCHIVE, , AL072012
    GORDON, AL, L,  ,  ,  ,  , 08, 2012, HU, O, 2012081512, 2012082112, , , , , , ARCHIVE, , AL082012
     ISAAC, AL, L,  ,  ,  ,  , 09, 2012, HU, O, 2012082012, 2012090106, , , , , , ARCHIVE, , AL092012
     JOYCE, AL, L,  ,  ,  ,  , 10, 2012, TS, O, 2012082118, 2012082412, , , , , , ARCHIVE, , AL102012
      KIRK, AL, L,  ,  ,  ,  , 11, 2012, HU, O, 2012082818, 2012090300, , , , , , ARCHIVE, , AL112012
    LESLIE, AL, L,  ,  ,  ,  , 12, 2012, HU, O, 2012082812, 2012091200, , , , , , ARCHIVE, , AL122012
   MICHAEL, AL, L,  ,  ,  ,  , 13, 2012, HU, O, 2012090200, 2012091206, , , , , , ARCHIVE, , AL132012
    NADINE, AL, L,  ,  ,  ,  , 14, 2012, HU, O, 2012091012, 2012100406, , , , , , ARCHIVE, , AL142012
     OSCAR, AL, L,  ,  ,  ,  , 15, 2012, TS, O, 2012100212, 2012100512, , , , , , ARCHIVE, , AL152012
     PATTY, AL, L,  ,  ,  ,  , 16, 2012, TS, O, 2012101018, 2012101306, , , , , , ARCHIVE, , AL162012
    RAFAEL, AL, L,  ,  ,  ,  , 17, 2012, HU, O, 2012101218, 2012102612, , , , , , ARCHIVE, , AL172012
     SANDY, AL, L,  ,  ,  ,  , 18, 2012, HU, O, 2012102118, 2012103112, , , , , , ARCHIVE, , AL182012
      TONY, AL, L,  ,  ,  ,  , 19, 2012, TS, O, 2012102118, 2012102612, , , , , , ARCHIVE, , AL192012
    ALETTA, EP, E,  ,  ,  ,  , 01, 2012, TS, O, 2012051318, 2012052000, , , , , , ARCHIVE, , EP012012
       BUD, EP, E,  ,  ,  ,  , 02, 2012, HU, O, 2012052012, 2012052612, , , , , , ARCHIVE, , EP022012
  CARLOTTA, EP, E,  ,  ,  ,  , 03, 2012, HU, O, 2012061318, 2012061706, , , , , , ARCHIVE, , EP032012
    DANIEL, EP, E, C,  ,  ,  , 04, 2012, HU, O, 2012070406, 2012071406, , , , , , ARCHIVE, , EP042012
    EMILIA, EP, E,  ,  ,  ,  , 05, 2012, HU, O, 2012070706, 2012071800, , , , , , ARCHIVE, , EP052012
     FABIO, EP, E,  ,  ,  ,  , 06, 2012, HU, O, 2012071012, 2012072006, , , , , , ARCHIVE, , EP062012
     GILMA, EP, E,  ,  ,  ,  , 07, 2012, HU, O, 2012080600, 2012081400, , , , , , ARCHIVE, , EP072012
    HECTOR, EP, E,  ,  ,  ,  , 08, 2012, TS, O, 2012081112, 2012082006, , , , , , ARCHIVE, , EP082012
    ILEANA, EP, E,  ,  ,  ,  , 09, 2012, HU, O, 2012082518, 2012090606, , , , , , ARCHIVE, , EP092012
      JOHN, EP, E,  ,  ,  ,  , 10, 2012, TS, O, 2012090212, 2012090706, , , , , , ARCHIVE, , EP102012
    KRISTY, EP, E,  ,  ,  ,  , 11, 2012, TS, O, 2012091118, 2012091918, , , , , , ARCHIVE, , EP112012
      LANE, EP, E,  ,  ,  ,  , 12, 2012, HU, O, 2012091512, 2012092006, , , , , , ARCHIVE, , EP122012
    MIRIAM, EP, E,  ,  ,  ,  , 13, 2012, HU, O, 2012092200, 2012100218, , , , , , ARCHIVE, , EP132012
    NORMAN, EP, E,  ,  ,  ,  , 14, 2012, TS, O, 2012092806, 2012093006, , , , , , ARCHIVE, , EP142012
    OLIVIA, EP, E,  ,  ,  ,  , 15, 2012, TS, O, 2012100612, 2012101012, , , , , , ARCHIVE, , EP152012
      PAUL, EP, E,  ,  ,  ,  , 16, 2012, HU, O, 2012101312, 2012101800, , , , , , ARCHIVE, , EP162012
      ROSA, EP, E,  ,  ,  ,  , 17, 2012, TS, O, 2012102918, 2012110506, , , , , , ARCHIVE, , EP172012
    ANDREA, AL, L,  ,  ,  ,  , 01, 2013, TS, O, 2013060518, 2013060818, , , , , , ARCHIVE, , AL012013
     BARRY, AL, L,  ,  ,  ,  , 02, 2013, TS, O, 2013061600, 2013062100, , , , , , ARCHIVE, , AL022013
   CHANTAL, AL, L,  ,  ,  ,  , 03, 2013, TS, O, 2013070712, 2013071012, , , , , , ARCHIVE, , AL032013
    DORIAN, AL, L,  ,  ,  ,  , 04, 2013, TS, O, 2013072218, 2013080406, , , , , , ARCHIVE, , AL042013
      ERIN, AL, L,  ,  ,  ,  , 05, 2013, TS, O, 2013081500, 2013081918, , , , , , ARCHIVE, , AL052013
   FERNAND, AL, L,  ,  ,  ,  , 06, 2013, TS, O, 2013082512, 2013082618, , , , , , ARCHIVE, , AL062013
 GABRIELLE, AL, L,  ,  ,  ,  , 07, 2013, TS, O, 2013090418, 2013091312, , , , , , ARCHIVE, , AL072013
     EIGHT, AL, L,  ,  ,  ,  , 08, 2013, TD, O, 2013090612, 2013090706, , , , , , ARCHIVE, , AL082013
  HUMBERTO, AL, L,  ,  ,  ,  , 09, 2013, HU, O, 2013090800, 2013091906, , , , , , ARCHIVE, , AL092013
    INGRID, AL, L,  ,  ,  ,  , 10, 2013, HU, O, 2013091206, 2013091706, , , , , , ARCHIVE, , AL102013
     JERRY, AL, L,  ,  ,  ,  , 11, 2013, TS, O, 2013092800, 2013100600, , , , , , ARCHIVE, , AL112013
     KAREN, AL, L,  ,  ,  ,  , 12, 2013, TS, O, 2013100306, 2013100606, , , , , , ARCHIVE, , AL122013
   LORENZO, AL, L,  ,  ,  ,  , 13, 2013, TS, O, 2013102106, 2013102606, , , , , , ARCHIVE, , AL132013
   MELISSA, AL, L,  ,  ,  ,  , 14, 2013, TS, O, 2013111700, 2013112306, , , , , , ARCHIVE, , AL142013
   UNNAMED, AL, L,  ,  ,  ,  , 15, 2013, SS, O, 2013120318, 2013120712, , , , , , ARCHIVE, , AL152013
      PEWA, CP, C, W,  ,  ,  , 01, 2013, HU, O, 2013081500, 2013082506, , , , , , ARCHIVE, , CP012013
     UNALA, CP, C,  ,  ,  ,  , 02, 2013, TS, O, 2013081206, 2013081906, , , , , , ARCHIVE, , CP022013
     THREE, CP, C, W,  ,  ,  , 03, 2013, TD, O, 2013080906, 2013082100, , , , , , ARCHIVE, , CP032013
     ALVIN, EP, E,  ,  ,  ,  , 01, 2013, TS, O, 2013051312, 2013051700, , , , , , ARCHIVE, , EP012013
   BARBARA, EP, E,  ,  ,  ,  , 02, 2013, HU, O, 2013052812, 2013053018, , , , , , ARCHIVE, , EP022013
     COSME, EP, E,  ,  ,  ,  , 03, 2013, HU, O, 2013062312, 2013063018, , , , , , ARCHIVE, , EP032013
    DALILA, EP, E,  ,  ,  ,  , 04, 2013, HU, O, 2013062818, 2013070818, , , , , , ARCHIVE, , EP042013
     ERICK, EP, E,  ,  ,  ,  , 05, 2013, HU, O, 2013070412, 2013070918, , , , , , ARCHIVE, , EP052013
   FLOSSIE, EP, E, C,  ,  ,  , 06, 2013, TS, O, 2013072500, 2013073012, , , , , , ARCHIVE, , EP062013
       GIL, EP, E, C,  ,  ,  , 07, 2013, HU, O, 2013073000, 2013080618, , , , , , ARCHIVE, , EP072013
 HENRIETTE, EP, E, C,  ,  ,  , 08, 2013, HU, O, 2013080200, 2013081200, , , , , , ARCHVIE, , EP082013
       IVO, EP, E,  ,  ,  ,  , 09, 2013, TS, O, 2013082006, 2013082718, , , , , , ARCHIVE, , EP092013
  JULIETTE, EP, E,  ,  ,  ,  , 10, 2013, TS, O, 2013082812, 2013083018, , , , , , ARCHIVE, , EP102013
      KIKO, EP, E,  ,  ,  ,  , 11, 2013, HU, O, 2013082918, 2013090406, , , , , , ARCHIVE, , EP112013
    LORENA, EP, E,  ,  ,  ,  , 12, 2013, TS, O, 2013090412, 2013090900, , , , , , ARCHIVE, , EP122013
    MANUEL, EP, E,  ,  ,  ,  , 13, 2013, HU, O, 2013091312, 2013091918, , , , , , ARCHIVE, , EP132013
     NARDA, EP, E,  ,  ,  ,  , 14, 2013, TS, O, 2013100618, 2013101212, , , , , , ARCHIVE, , EP142013
    OCTAVE, EP, E,  ,  ,  ,  , 15, 2013, TS, O, 2013101218, 2013101600, , , , , , ARCHIVE, , EP152013
 PRISCILLA, EP, E,  ,  ,  ,  , 16, 2013, TS, O, 2013101312, 2013101812, , , , , , ARCHIVE, , EP162013
   RAYMOND, EP, E,  ,  ,  ,  , 17, 2013, HU, O, 2013101918, 2013110100, , , , , , ARCHIVE, , EP172013
     SONIA, EP, E,  ,  ,  ,  , 18, 2013, TS, O, 2013110106, 2013110406, , , , , , ARCHIVE, , EP182013
    ARTHUR, AL, L,  ,  ,  ,  , 01, 2014, HU, O, 2014062818, 2014070918, , , , , , ARCHIVE, , AL012014
       TWO, AL, L,  ,  ,  ,  , 02, 2014, TD, O, 2014071912, 2014072312, , , , , , ARCHIVE, , AL022014
    BERTHA, AL, L,  ,  ,  ,  , 03, 2014, HU, O, 2014072906, 2014080912, , , , , , ARCHIVE, , AL032014
 CRISTOBAL, AL, L,  ,  ,  ,  , 04, 2014, HU, O, 2014082318, 2014090206, , , , , , ARCHIVE, , AL042014
     DOLLY, AL, L,  ,  ,  ,  , 05, 2014, TS, O, 2014090112, 2014090400, , , , , , ARCHIVE, , AL052014
   EDOUARD, AL, L,  ,  ,  ,  , 06, 2014, HU, O, 2014091018, 2014092206, , , , , , ARCHIVE, , AL062014
       FAY, AL, L,  ,  ,  ,  , 07, 2014, HU, O, 2014101000, 2014101300, , , , , , ARCHIVE, , AL072014
   GONZALO, AL, L,  ,  ,  ,  , 08, 2014, HU, O, 2014101118, 2014102006, , , , , , ARCHIVE, , AL082014
     HANNA, AL, L,  ,  ,  ,  , 09, 2014, TS, O, 2014102100, 2014102918, , , , , , ARCHIVE, , AL092014
      WALI, CP, C,  ,  ,  ,  , 01, 2014, TS, O, 2014071312, 2014071900, , , , , , ARCHIVE, , CP012014
       ANA, CP, C,  ,  ,  ,  , 02, 2014, HU, O, 2014101012, 2014102612, , , , , , ARCHIVE, , CP022014
    AMANDA, EP, E,  ,  ,  ,  , 01, 2014, HU, O, 2014052206, 2014052912, , , , , , ARCHIVE, , EP012014
     BORIS, EP, E,  ,  ,  ,  , 02, 2014, TS, O, 2014060112, 2014060418, , , , , , ARCHIVE, , EP022014
  CRISTINA, EP, E,  ,  ,  ,  , 03, 2014, HU, O, 2014060900, 2014061900, , , , , , ARCHIVE, , EP032014
   DOUGLAS, EP, E,  ,  ,  ,  , 04, 2014, TS, O, 2014062818, 2014070900, , , , , , ARCHIVE, , EP042014
     ELIDA, EP, E,  ,  ,  ,  , 05, 2014, TS, O, 2014063006, 2014070218, , , , , , ARCHIVE, , EP052014
    FAUSTO, EP, E,  ,  ,  ,  , 06, 2014, TS, O, 2014070606, 2014070906, , , , , , ARCHIVE, , EP062014
 GENEVIEVE, EP, E, C, W,  ,  , 07, 2014, ST, O, 2014072218, 2014081306, , , , , , ARCHIVE, , EP072014
    HERNAN, EP, E,  ,  ,  ,  , 08, 2014, HU, O, 2014072600, 2014073106, , , , , , ARCHIVE, , EP082014
    ISELLE, EP, E, C,  ,  ,  , 09, 2014, HU, O, 2014073012, 2014081012, , , , , , ARCHIVE, , EP092014
     JULIO, EP, E, C,  ,  ,  , 10, 2014, HU, O, 2014080200, 2014081806, , , , , , ARCHIVE, , EP102014
    KARINA, EP, E,  ,  ,  ,  , 11, 2014, HU, O, 2014081212, 2014082800, , , , , , ARCHIVE, , EP112014
    LOWELL, EP, E,  ,  ,  ,  , 12, 2014, HU, O, 2014081700, 2014082818, , , , , , ARCHIVE, , EP122014
     MARIE, EP, E,  ,  ,  ,  , 13, 2014, HU, O, 2014082200, 2014090206, , , , , , ARCHIVE, , EP132014
   NORBERT, EP, E,  ,  ,  ,  , 14, 2014, HU, O, 2014090212, 2014091100, , , , , , ARCHIVE, , EP142014
     ODILE, EP, E,  ,  ,  ,  , 15, 2014, HU, O, 2014090912, 2014091800, , , , , , ARCHIVE, , EP152014
   SIXTEEN, EP, E,  ,  ,  ,  , 16, 2014, TD, O, 2014091006, 2014091606, , , , , , ARCHIVE, , EP162014
      POLO, EP, E,  ,  ,  ,  , 17, 2014, HU, O, 2014091600, 2014092618, , , , , , ARCHIVE, , EP172014
    RACHEL, EP, E,  ,  ,  ,  , 18, 2014, HU, O, 2014092400, 2014100300, , , , , , ARCHIVE, , EP182014
     SIMON, EP, E,  ,  ,  ,  , 19, 2014, HU, O, 2014093012, 2014100900, , , , , , ARCHIVE, , EP192014
     TRUDY, EP, E,  ,  ,  ,  , 20, 2014, TS, O, 2014101706, 2014101900, , , , , , ARCHIVE, , EP202014
     VANCE, EP, E,  ,  ,  ,  , 21, 2014, HU, O, 2014102918, 2014110506, , , , , , ARCHIVE, , EP212014
       ANA, AL, L,  ,  ,  ,  , 01, 2015, TS, S, 2015050606, 2015051218, , , , , , ARCHIVE, , AL012015
      BILL, AL, L,  ,  ,  ,  , 02, 2015, TS, S, 2015061600, 2015062100, , , , , , ARCHIVE, , AL022015
 CLAUDETTE, AL, L,  ,  ,  ,  , 03, 2015, TS, S, 2015071200, 2015071512, , , , , , ARCHIVE, , AL032015
     DANNY, AL, L,  ,  ,  ,  , 04, 2015, HU, S, 2015081700, 2015082412, , , , , , ARCHIVE, , AL042015
     ERIKA, AL, L,  ,  ,  ,  , 05, 2015, TS, S, 2015082418, 2015082812, , , , , , ARCHIVE, , AL052015
      FRED, AL, L,  ,  ,  ,  , 06, 2015, HU, S, 2015083000, 2015090612, , , , , , ARCHIVE, , AL062015
     GRACE, AL, L,  ,  ,  ,  , 07, 2015, TS, S, 2015090506, 2015090906, , , , , , ARCHIVE, , AL072015
     HENRI, AL, L,  ,  ,  ,  , 08, 2015, TS, S, 2015090806, 2015091106, , , , , , ARCHIVE, , AL082015
      NINE, AL, L,  ,  ,  ,  , 09, 2015, TD, S, 2015091500, 2015091912, , , , , , ARCHIVE, , AL092015
       IDA, AL, L,  ,  ,  ,  , 10, 2015, TS, S, 2015091512, 2015092800, , , , , , ARCHIVE, , AL102015
   JOAQUIN, AL, L,  ,  ,  ,  , 11, 2015, HU, S, 2015092618, 2015101500, , , , , , ARCHIVE, , AL112015
      KATE, AL, L,  ,  ,  ,  , 12, 2015, HU, S, 2015110818, 2015111312, , , , , , ARCHIVE, , AL122015
    HALOLA, CP, C, W,  ,  ,  , 01, 2015, TY, S, 2015070618, 2015072612, , , , , , ARCHIVE, , CP012015
      IUNE, CP, C,  ,  ,  ,  , 02, 2015, TS, S, 2015070818, 2015071706, , , , , , ARCHIVE, , CP022015
      KILO, CP, C, W,  ,  ,  , 03, 2015, HU, S, 2015082200, 2015091112, , , , , , ARCHIVE, , CP032015
      LOKE, CP, C,  ,  ,  ,  , 04, 2015, HU, S, 2015081900, 2015082618, , , , , , ARCHIVE, , CP042015
     MALIA, CP, C,  ,  ,  ,  , 05, 2015, TS, S, 2015091706, 2015092300, , , , , , ARCHIVE, , CP052015
     NIALA, CP, C,  ,  ,  ,  , 06, 2015, TS, S, 2015092306, 2015093018, , , , , , ARCHIVE, , CP062015
       OHO, CP, C,  ,  ,  ,  , 07, 2015, HU, S, 2015100106, 2015101012, , , , , , ARCHIVE, , CP072015
     EIGHT, CP, C,  ,  ,  ,  , 08, 2015, TD, S, 2015100200, 2015100612, , , , , , ARCHIVE, , CP082015
      NINE, CP, C, W,  ,  ,  , 09, 2015, TD, S, 2015122718, 2016010112, , , , , , ARCHIVE, , CP092015
    ANDRES, EP, E,  ,  ,  ,  , 01, 2015, HU, S, 2015052806, 2015060700, , , , , , ARCHIVE, , EP012015
    BLANCA, EP, E,  ,  ,  ,  , 02, 2015, HU, S, 2015053112, 2015060906, , , , , , ARCHIVE, , EP022015
    CARLOS, EP, E,  ,  ,  ,  , 03, 2015, HU, S, 2015061012, 2015061800, , , , , , ARCHIVE, , EP032015
       ELA, EP, E, C,  ,  ,  , 04, 2015, TS, S, 2015070712, 2015071212, , , , , , ARCHIVE, , EP042015
   DOLORES, EP, E,  ,  ,  ,  , 05, 2015, HU, S, 2015071100, 2015072200, , , , , , ARCHIVE, , EP052015
   ENRIQUE, EP, E,  ,  ,  ,  , 06, 2015, TS, S, 2015071212, 2015072118, , , , , , ARCHIVE, , EP062015
   FELICIA, EP, E,  ,  ,  ,  , 07, 2015, TS, S, 2015072212, 2015072718, , , , , , ARCHIVE, , EP072015
     EIGHT, EP, E,  ,  ,  ,  , 08, 2015, TD, S, 2015072712, 2015073106, , , , , , ARCHIVE, , EP082015
 GUILLERMO, EP, E, C,  ,  ,  , 09, 2015, HU, S, 2015072712, 2015080818, , , , , , ARCHIVE, , EP092015
     HILDA, EP, E, C,  ,  ,  , 10, 2015, HU, S, 2015080600, 2015081418, , , , , , ARCHIVE, , EP102015
    ELEVEN, EP, E,  ,  ,  ,  , 11, 2015, TD, S, 2015081600, 2015082000, , , , , , ARCHIVE, , EP112015
   IGNACIO, EP, E, C,  ,  ,  , 12, 2015, HU, R, 2015082318, 2015090812, , , , , , ARCHIVE, , EP122015
    JIMENA, EP, E, C,  ,  ,  , 13, 2015, HU, S, 2015082512, 2015091000, , , , , , ARCHIVE, , EP132015
     KEVIN, EP, E,  ,  ,  ,  , 14, 2015, TS, S, 2015083118, 2015090606, , , , , , ARCHIVE, , EP142015
     LINDA, EP, E,  ,  ,  ,  , 15, 2015, HU, S, 2015090412, 2015091412, , , , , , ARCHIVE, , EP152015
   SIXTEEN, EP, E,  ,  ,  ,  , 16, 2015, TD, S, 2015092018, 2015092115, , , , , , ARCHIVE, , EP162015
     MARTY, EP, E,  ,  ,  ,  , 17, 2015, HU, S, 2015092612, 2015093018, , , , , , ARCHIVE, , EP172015
      NORA, EP, E, C,  ,  ,  , 18, 2015, TS, S, 2015100906, 2015101518, , , , , , ARCHIVE, , EP182015
      OLAF, EP, E, C,  ,  ,  , 19, 2015, HU, S, 2015101500, 2015102812, , , , , , ARCHIVE, , EP192015
  PATRICIA, EP, E,  ,  ,  ,  , 20, 2015, HU, S, 2015102006, 2015102412, , , , , , ARCHIVE, , EP202015
      RICK, EP, E,  ,  ,  ,  , 21, 2015, TS, S, 2015111806, 2015112606, , , , , , ARCHIVE, , EP212015
    SANDRA, EP, E,  ,  ,  ,  , 22, 2015, HU, R, 2015112312, 2015112912, , , , , , ARCHIVE, , EP222015
      ALEX, AL, L,  ,  ,  ,  , 01, 2016, HU, S, 2016010700, 2016011700, , , , , , ARCHIVE, , AL012016
    BONNIE, AL, L,  ,  ,  ,  , 02, 2016, TS, S, 2016052706, 2016060918, , , , , , ARCHIVE, , AL022016
     COLIN, AL, L,  ,  ,  ,  , 03, 2016, TS, S, 2016060512, 2016060818, , , , , , ARCHIVE, , AL032016
  DANIELLE, AL, L,  ,  ,  ,  , 04, 2016, TS, S, 2016061818, 2016062106, , , , , , ARCHIVE, , AL042016
      EARL, AL, L,  ,  ,  ,  , 05, 2016, HU, S, 2016080206, 2016080612, , , , , , ARCHIVE, , AL052016
     FIONA, AL, L,  ,  ,  ,  , 06, 2016, TS, S, 2016081618, 2016082406, , , , , , ARCHIVE, , AL062016
    GASTON, AL, L,  ,  ,  ,  , 07, 2016, HU, S, 2016082112, 2016090312, , , , , , ARCHIVE, , AL072016
     EIGHT, AL, L,  ,  ,  ,  , 08, 2016, TD, S, 2016082700, 2016090100, , , , , , ARCHIVE, , AL082016
   HERMINE, AL, L,  ,  ,  ,  , 09, 2016, HU, S, 2016082818, 2016090818, , , , , , ARCHIVE, , AL092016
       IAN, AL, L,  ,  ,  ,  , 10, 2016, TS, S, 2016091200, 2016091700, , , , , , ARCHIVE, , AL102016
     JULIA, AL, L,  ,  ,  ,  , 11, 2016, TS, S, 2016091306, 2016092106, , , , , , ARCHIVE, , AL112016
      KARL, AL, L,  ,  ,  ,  , 12, 2016, TS, S, 2016091218, 2016092600, , , , , , ARCHIVE, , AL122016
      LISA, AL, L,  ,  ,  ,  , 13, 2016, TS, S, 2016091606, 2016092612, , , , , , ARCHIVE, , AL132016
   MATTHEW, AL, L,  ,  ,  ,  , 14, 2016, HU, S, 2016092812, 2016101000, , , , , , ARCHIVE, , AL142016
    NICOLE, AL, L,  ,  ,  ,  , 15, 2016, HU, S, 2016100406, 2016101912, , , , , , ARCHIVE, , AL152016
      OTTO, AL, L, E,  ,  ,  , 16, 2016, HU, S, 2016111718, 2016112612, , , , , , ARCHIVE, , AL162016
      PALI, CP, C,  ,  ,  ,  , 01, 2016, HU, S, 2016010506, 2016011512, , , , , , ARCHIVE, , CP012016
       ONE, EP, E,  ,  ,  ,  , 01, 2016, TD, S, 2016060606, 2016060806, , , , , , ARCHIVE, , EP012016
    AGATHA, EP, E,  ,  ,  ,  , 02, 2016, TS, S, 2016070106, 2016070806, , , , , , ARCHIVE, , EP022016
      BLAS, EP, E,  ,  ,  ,  , 03, 2016, HU, S, 2016070218, 2016071118, , , , , , ARCHIVE, , EP032016
     CELIA, EP, E, C,  ,  ,  , 04, 2016, HU, S, 2016070600, 2016072112, , , , , , ARCHIVE, , EP042016
     DARBY, EP, E, C,  ,  ,  , 05, 2016, HU, S, 2016071112, 2016072612, , , , , , ARCHIVE, , EP052016
   ESTELLE, EP, E,  ,  ,  ,  , 06, 2016, TS, S, 2016071500, 2016072406, , , , , , ARCHIVE, , EP062016
     FRANK, EP, E,  ,  ,  ,  , 07, 2016, HU, S, 2016072106, 2016073018, , , , , , ARCHIVE, , EP072016
 GEORGETTE, EP, E,  ,  ,  ,  , 08, 2016, HU, S, 2016072100, 2016073000, , , , , , ARCHIVE, , EP082016
    HOWARD, EP, E,  ,  ,  ,  , 09, 2016, TS, S, 2016073112, 2016080712, , , , , , ARCHIVE, , EP092016
    IVETTE, EP, E, C,  ,  ,  , 10, 2016, TS, S, 2016080300, 2016081100, , , , , , ARCVIVE, , EP102016
    JAVIER, EP, E,  ,  ,  ,  , 11, 2016, TS, S, 2016080618, 2016081012, , , , , , ARCHIVE, , EP112016
       KAY, EP, E,  ,  , ,   , 12, 2016, TS, S, 2016081700, 2016082606, , , , , , ARCHIVE, , EP122016
    LESTER, EP, E, C,  ,  ,  , 13, 2016, HU, S, 2016082406, 2016090800, , , , , , ARCHIVE, , EP132016
  MADELINE, EP, E, C,  ,  ,  , 14, 2016, HU, S, 2016082618, 2016090318, , , , , , ARCHIVE, , EP142016
    NEWTON, EP, E,  ,  ,  ,  , 15, 2016, HU, S, 2016090406, 2016090806, , , , , , ARCHIVE, , EP152016
    ORLENE, EP, E,  ,  ,  ,  , 16, 2016, HU, S, 2016091012, 2016091706, , , , , , ARCHIVE, , EP162016
     PAINE, EP, E,  ,  ,  ,  , 17, 2016, HU, S, 2016091800, 2016092112, , , , , , ARCHIVE, , EP172016
    ROSLYN, EP, E,  ,  ,  ,  , 18, 2016, TS, S, 2016092512, 2016093018, , , , , , ARCHIVE, , EP182016
     ULIKA, EP, E, C,  ,  ,  , 19, 2016, HU, S, 2016092512, 2016100300, , , , , , ARCHIVE, , EP192016
   SEYMOUR, EP, E,  ,  ,  ,  , 20, 2016, HU, S, 2016102206, 2016103006, , , , , , ARCHIVE, , EP202016
      TINA, EP, E,  ,  ,  ,  , 21, 2016, TS, S, 2016111306, 2016111812, , , , , , ARCHIVE, , EP212016
      OTTO, EP, E, L,  ,  ,  , 22, 2016, HU, S, 2016111718, 2016112612, , , , , , ARCHIVE, , EP222016
    ARLENE, AL, L,  ,  ,  ,  , 01, 2017, TS, S, 2017041606, 2017042218, , , , , , ARCHIVE, , AL012017
      BRET, AL, L,  ,  ,  ,  , 02, 2017, TS, S, 2017061818, 2017062009, , , , , , ARCHIVE, , AL022017
     CINDY, AL, L,  ,  ,  ,  , 03, 2017, TS, S, 2017061918, 2017062406, , , , , , ARCHIVE, , AL032017
      FOUR, AL, L,  ,  ,  ,  , 04, 2017, TD, S, 2017070512, 2017070712, , , , , , ARCHIVE, , AL042017
       DON, AL, L,  ,  ,  ,  , 05, 2017, TS, S, 2017071700, 2017071812, , , , , , ARCHIVE, , AL052017
     EMILY, AL, L,  ,  ,  ,  , 06, 2017, TS, S, 2017073018, 2017080200, , , , , , ARCHIVE, , AL062017
  FRANKLIN, AL, L,  ,  ,  ,  , 07, 2017, HU, S, 2017080618, 2017081012, , , , , , ARCHIVE, , AL072017
      GERT, AL, L,  ,  ,  ,  , 08, 2017, HU, S, 2017081200, 2017081818, , , , , , ARCHIVE, , AL082017
    HARVEY, AL, L,  ,  ,  ,  , 09, 2017, HU, S, 2017081606, 2017090212, , , , , , ARCHIVE, , AL092017
       TEN, AL, L,  ,  ,  ,  , 10, 2017, DB, S, 2017082718, 2017082918, , , , , , ARCHIVE, , AL102017
      IRMA, AL, L,  ,  ,  ,  , 11, 2017, HU, S, 2017083000, 2017091313, , , , , , ARCHIVE, , AL112017
      JOSE, AL, L,  ,  ,  ,  , 12, 2017, HU, S, 2017090406, 2017092506, , , , , , ARCHIVE, , AL122017
     KATIA, AL, L,  ,  ,  ,  , 13, 2017, HU, S, 2017090512, 2017090912, , , , , , ARCHIVE, , AL132017
       LEE, AL, L,  ,  ,  ,  , 14, 2017, HU, S, 2017091418, 2017093006, , , , , , ARCHIVE, , AL142017
     MARIA, AL, L,  ,  ,  ,  , 15, 2017, HU, S, 2017091612, 2017100212, , , , , , ARCHIVE, , AL152017
      NATE, AL, L,  ,  ,  ,  , 16, 2017, HU, S, 2017100312, 2017101100, , , , , , ARCHIVE, , AL162017
   OPHELIA, AL, L,  ,  ,  ,  , 17, 2017, HU, S, 2017100612, 2017101718, , , , , , ARCHIVE, , AL172017
  PHILIPPE, AL, L,  ,  ,  ,  , 18, 2017, TS, S, 2017102718, 2017102900, , , , , , ARCHIVE, , AL182017
      RINA, AL, L,  ,  ,  ,  , 19, 2017, TS, S, 2017110412, 2017110912, , , , , , ARCHIVE, , AL192017
    ADRIAN, EP, E,  ,  ,  ,  , 01, 2017, TS, S, 2017050918, 2017051206, , , , , , ARCHIVE, , EP012017
   BEATRIZ, EP, E,  ,  ,  ,  , 02, 2017, TS, S, 2017053112, 2017060206, , , , , , ARCHIVE, , EP022017
    CALVIN, EP, E,  ,  ,  ,  , 03, 2017, TS, S, 2017061112, 2017061306, , , , , , ARCHIVE, , EP032017
      DORA, EP, E,  ,  ,  ,  , 04, 2017, HU, S, 2017062400, 2017070100, , , , , , ARCHIVE, , EP042017
    EUGENE, EP, E,  ,  ,  ,  , 05, 2017, HU, S, 2017070712, 2017071406, , , , , , ARCHIVE, , EP052017
  FERNANDA, EP, E, C,  ,  ,  , 06, 2017, HU, S, 2017071118, 2017072218, , , , , , ARCHIVE, , EP062017
      GREG, EP, E, C,  ,  ,  , 07, 2017, TS, S, 2017071712, 2017072606, , , , , , ARCHIVE, , EP072017
     EIGHT, EP, E,  ,  ,  ,  , 08, 2017, TD, S, 2017071618, 2017072100, , , , , , ARCHIVE, , EP082017
    HILARY, EP, E,  ,  ,  ,  , 09, 2017, HU, S, 2017072012, 2017080100, , , , , , ARCHIVE, , EP092017
     IRWIN, EP, E,  ,  ,  ,  , 10, 2017, HU, S, 2017072206, 2017080312, , , , , , ARCHIVE, , EP102017
    ELEVEN, EP, E,  ,  ,  ,  , 11, 2017, TD, S, 2017080400, 2017080800, , , , , , ARCHIVE, , EP112017
      JOVA, EP, E,  ,  ,  ,  , 12, 2017, TS, S, 2017081112, 2017081700, , , , , , ARCHIVE, , EP122017
   KENNETH, EP, E,  ,  ,  ,  , 13, 2017, HU, S, 2017081712, 2017082718, , , , , , ARCHIVE, , EP132017
     LIDIA, EP, E,  ,  ,  ,  , 14, 2017, TS, S, 2017082918, 2017090312, , , , , , ARCHIVE, , EP142017
      OTIS, EP, E,  ,  ,  ,  , 15, 2017, HU, S, 2017091106, 2017092100, , , , , , ARCHIVE, , EP152017
       MAX, EP, E,  ,  ,  ,  , 16, 2017, HU, S, 2017091312, 2017091506, , , , , , ARCHIVE, , EP162017
     NORMA, EP, E,  ,  ,  ,  , 17, 2017, HU, S, 2017091406, 2017092206, , , , , , ARCHIVE, , EP172017
     PILAR, EP, E,  ,  ,  ,  , 18, 2017, TS, S, 2017092200, 2017092512, , , , , , ARCHIVE, , EP182017
     RAMON, EP, E,  ,  ,  ,  , 19, 2017, TS, S, 2017100318, 2017100418, , , , , , ARCHIVE, , EP192017
     SELMA, EP, E,  ,  ,  ,  , 20, 2017, TS, S, 2017102618, 2017102812, , , , , , ARCHIVE, , EP202017
   ALBERTO, AL, L,  ,  ,  ,  , 01, 2018, TS, S, 2018052512, 2018053112, , , , , , ARCHIVE, , AL012018
     BERYL, AL, L,  ,  ,  ,  , 02, 2018, HU, S, 2018070412, 2018071706, , , , , , ARCHIVE, , AL022018
     CHRIS, AL, L,  ,  ,  ,  , 03, 2018, HU, S, 2018070506, 2018071712, , , , , , ARCHIVE, , AL032018
     DEBBY, AL, L,  ,  ,  ,  , 04, 2018, TS, S, 2018080218, 2018081012, , , , , , ARCHIVE, , AL042018
   ERNESTO, AL, L,  ,  ,  ,  , 05, 2018, TS, S, 2018081500, 2018081906, , , , , , ARCHIVE, , AL052018
  FLORENCE, AL, L,  ,  ,  ,  , 06, 2018, HU, S, 2018083006, 2018091812, , , , , , ARCHIVE, , AL062018
    GORDON, AL, L,  ,  ,  ,  , 07, 2018, TS, S, 2018090218, 2018090718, , , , , , ARCHIVE, , AL072018
    HELENE, AL, L,  ,  ,  ,  , 08, 2018, HU, S, 2018090712, 2018091718, , , , , , ARCHIVE, , AL082018
     ISAAC, AL, L,  ,  ,  ,  , 09, 2018, HU, S, 2018090712, 2018091500, , , , , , ARCHIVE, , AL092018
     JOYCE, AL, L,  ,  ,  ,  , 10, 2018, TS, S, 2018091200, 2018092112, , , , , , ARCHIVE, , AL102018
    ELEVEN, AL, L,  ,  ,  ,  , 11, 2018, TD, S, 2018092118, 2018092218, , , , , , ARCHIVE, , AL112018
      KIRK, AL, L,  ,  ,  ,  , 12, 2018, TS, S, 2018092206, 2018092818, , , , , , ARCHIVE, , AL122018
    LESLIE, AL, L,  ,  ,  ,  , 13, 2018, HU, S, 2018092200, 2018101400, , , , , , ARCHIVE, , AL132018
   MICHAEL, AL, L,  ,  ,  ,  , 14, 2018, HU, S, 2018100618, 2018101518, , , , , , ARCHIVE, , AL142018
    NADINE, AL, L,  ,  ,  ,  , 15, 2018, TS, S, 2018100812, 2018101218, , , , , , ARCHIVE, , AL152018
     OSCAR, AL, L,  ,  ,  ,  , 16, 2018, HU, O, 2018102618, 2018110412, , , , , , ARCHIVE, , AL162018
    WALAKA, CP, C,  ,  ,  ,  , 01, 2018, HS, S, 2018092606, 2018100712, , , , , , ARCHIVE, , CP012018
       ONE, EP, E,  ,  ,  ,  , 01, 2018, TD, S, 2018051012, 2018051313, , , , , , ARCHIVE, , EP012018
    ALETTA, EP, E,  ,  ,  ,  , 02, 2018, HU, S, 2018060600, 2018061600, , , , , , ARCHIVE, , EP022018
       BUD, EP, E,  ,  ,  ,  , 03, 2018, HU, S, 2018060918, 2018061600, , , , , , ARCHIVE, , EP032018
  CARLOTTA, EP, E,  ,  ,  ,  , 04, 2018, TS, S, 2018061418, 2018061900, , , , , , ARCHIVE, , EP042018
    DANIEL, EP, E,  ,  ,  ,  , 05, 2018, TS, S, 2018062300, 2018062806, , , , , , ARCHIVE, , EP052018
    EMILIA, EP, E,  ,  ,  ,  , 06, 2018, TS, S, 2018062706, 2018070400, , , , , , ARCHIVE, , EP062018
     FABIO, EP, E,  ,  ,  ,  , 07, 2018, HU, S, 2018063018, 2018070906, , , , , , ARCHIVE, , EP072018
     GILMA, EP, E,  ,  ,  ,  , 08, 2018, TS, S, 2018072612, 2018073118, , , , , , ARCHIVE, , EP082018
      NINE, EP, E,  ,  ,  ,  , 09, 2018, TD, S, 2018072618, 2018072718, , , , , , ARCHIVE, , EP092018
    HECTOR, EP, E, C, W,  ,  , 10, 2018, HU, S, 2018073112, 2018081700, , , , , , ARCHIVE, , EP102018
    ILEANA, EP, E,  ,  ,  ,  , 11, 2018, TS, S, 2018080418, 2018080706, , , , , , ARCHIVE, , EP112018
      JOHN, EP, E,  ,  ,  ,  , 12, 2018, HU, S, 2018080512, 2018081318, , , , , , ARCHIVE, , EP122018
    KRISTY, EP, E,  ,  ,  ,  , 13, 2018, TS, S, 2018080618, 2018081300, , , , , , ARCHIVE, , EP132018
      LANE, EP, E, C,  ,  ,  , 14, 2018, HU, S, 2018081312, 2018082906, , , , , , ARCHIVE, , EP142018
    MIRIAM, EP, E, C,  ,  ,  , 15, 2018, HU, S, 2018082512, 2018090300, , , , , , ARCHIVE, , EP152018
    NORMAN, EP, E, C,  ,  ,  , 16, 2018, HU, S, 2018082718, 2018091006, , , , , , ARCHIVE, , EP162018
    OLIVIA, EP, E, C,  ,  ,  , 17, 2018, HU, S, 2018090100, 2018091412, , , , , , ARCHIVE, , EP172018
      PAUL, EP, E,  ,  ,  ,  , 18, 2018, TS, S, 2018090712, 2018091418, , , , , , ARCHIVE, , EP182018
  NINETEEN, EP, E,  ,  ,  ,  , 19, 2018, TD, S, 2018091912, 2018092006, , , , , , ARCHIVE, , EP192018
      ROSA, EP, E,  ,  ,  ,  , 20, 2018, HU, S, 2018092506, 2018100212, , , , , , ARCHIVE, , EP202018
    SERGIO, EP, E,  ,  ,  ,  , 21, 2018, HU, S, 2018092912, 2018101218, , , , , , ARCHIVE, , EP212018
      TARA, EP, E,  ,  ,  ,  , 22, 2018, TS, S, 2018101412, 2018101618, , , , , , ARCHIVE, , EP222018
   VICENTE, EP, E,  ,  ,  ,  , 23, 2018, TS, S, 2018101900, 2018102313, , , , , , ARCHIVE, , EP232018
     WILLA, EP, E,  ,  ,  ,  , 24, 2018, HU, S, 2018101900, 2018102406, , , , , , ARCHIVE, , EP242018
    XAVIER, EP, E,  ,  ,  ,  , 25, 2018, TS, S, 2018110200, 2018110900, , , , , , ARCHIVE, , EP252018
    ANDREA, AL, L,  ,  ,  ,  , 01, 2019, SS, S, 2019052018, 2019052206, , , , , , ARCHIVE, , AL012019
     BARRY, AL, L,  ,  ,  ,  , 02, 2019, HU, S, 2019071012, 2019071606, , , , , , ARCHIVE, , AL022019
     THREE, AL, L,  ,  ,  ,  , 03, 2019, TD, S, 2019072212, 2019072312, , , , , , ARCHIVE, , AL032019
   CHANTAL, AL, L,  ,  ,  ,  , 04, 2019, TS, S, 2019082018, 2019082618, , , , , , ARCHIVE, , AL042019
    DORIAN, AL, L,  ,  ,  ,  , 05, 2019, HU, S, 2019082406, 2019090900, , , , , , ARCHIVE, , AL052019
      ERIN, AL, L,  ,  ,  ,  , 06, 2019, TS, S, 2019082612, 2019082918, , , , , , ARCHIVE, , AL062019
   FERNAND, AL, L,  ,  ,  ,  , 07, 2019, TS, S, 2019090306, 2019090500, , , , , , ARCHIVE, , AL072019
 GABRIELLE, AL, L,  ,  ,  ,  , 08, 2019, TS, S, 2019090300, 2019091112, , , , , , ARCHIVE, , AL082019
  HUMBERTO, AL, L,  ,  ,  ,  , 09, 2019, HU, S, 2019091212, 2019092012, , , , , , ARCHIVE, , AL092019
     JERRY, AL, L,  ,  ,  ,  , 10, 2019, HU, S, 2019091700, 2019092800, , , , , , ARCHIVE, , AL102019
    IMELDA, AL, L,  ,  ,  ,  , 11, 2019, TS, S, 2019091712, 2019091900, , , , , , ARCHIVE, , AL112019
     KAREN, AL, L,  ,  ,  ,  , 12, 2019, TS, S, 2019092200, 2019092712, , , , , , ARCHIVE, , AL122019
   LORENZO, AL, L,  ,  ,  ,  , 13, 2019, HU, S, 2019092218, 2019100406, , , , , , ARCHIVE, , AL132019
   MELISSA, AL, L,  ,  ,  ,  , 14, 2019, TS, S, 2019100818, 2019101418, , , , , , ARCHIVE, , AL142019
   FIFTEEN, AL, L,  ,  ,  ,  , 15, 2019, TD, S, 2019101412, 2019101712, , , , , , ARCHIVE, , AL152019
    NESTOR, AL, L,  ,  ,  ,  , 16, 2019, TS, S, 2019101712, 2019102100, , , , , , ARCHIVE, , AL162019
      OLGA, AL, L,  ,  ,  ,  , 17, 2019, TS, S, 2019102512, 2019102718, , , , , , ARCHIVE, , AL172019
     PABLO, AL, L,  ,  ,  ,  , 18, 2019, HU, S, 2019102318, 2019102900, , , , , , ARCHIVE, , AL182019
   REBEKAH, AL, L,  ,  ,  ,  , 19, 2019, SS, S, 2019102700, 2019110112, , , , , , ARCHIVE, , AL192019
 SEBASTIEN, AL, L,  ,  ,  ,  , 20, 2019, TS, S, 2019111906, 2019112712, , , , , , ARCHIVE, , AL202019
       EMA, CP, C, , , , , 01, 2019, TS, S, 2019101112, 2019101400, , , , , 2, , , CP012019
     ALVIN, EP, E,  ,  ,  ,  , 01, 2019, HU, S, 2019062512, 2019063000, , , , , , ARCHIVE, , EP012019
   BARBARA, EP, E, C,  ,  ,  , 02, 2019, HU, S, 2019063006, 2019070806, , , , , , ARCHIVE, , EP022019
     COSME, EP, E,  ,  ,  ,  , 03, 2019, TS, S, 2019070612, 2019071018, , , , , , ARCHIVE, , EP032019
      FOUR, EP, E,  ,  ,  ,  , 04, 2019, TD, S, 2019071206, 2019071506, , , , , , ARCHIVE, , EP042019
    DALILA, EP, E,  ,  ,  ,  , 05, 2019, TS, S, 2019072206, 2019072612, , , , , , ARCHIVE, , EP052019
     ERICK, EP, E, CP, , , , 06, 2019, HU, S, 2019072712, 2019080506, , 015, , , 1, , 1, EP062019
   FLOSSIE, EP, E, C,  ,  ,  , 07, 2019, HU, S, 2019072812, 2019080700, , , , , , ARCHIVE, , EP072019
       GIL, EP, E,  ,  ,  ,  , 08, 2019, TS, S, 2019080218, 2019080600, , , , , , ARCHIVE, , EP082019
 HENRIETTE, EP, E,  ,  ,  ,  , 09, 2019, TS, S, 2019081118, 2019081500, , , , , , ARCHIVE, , EP092019
       IVO, EP, E,  ,  ,  ,  , 10, 2019, LO, S, 2019082106, 2019082700, , , , , , ARCHIVE, , EP102019
  JULIETTE, EP, E,  ,  ,  ,  , 11, 2019, LO, S, 2019090100, 2019090912, , , , , , ARCHIVE, , EP112019
     AKONI, EP, E, C,  ,  ,  , 12, 2019, TS, S, 2019090306, 2019090618, , , , , , ARCHIVE, , EP122019
      KIKO, EP, E,  ,  ,  ,  , 13, 2019, HU, S, 2019091206, 2019092618, , , , , , ARCHIVE, , EP132019
     MARIO, EP, E,  ,  ,  ,  , 14, 2019, TS, S, 2019091612, 2019092418, , , , , , ARCHIVE, , EP142019
    LORENA, EP, E,  ,  ,  ,  , 15, 2019, HU, S, 2019091706, 2019092212, , , , , , ARCHIVE, , EP152019
     NARDA, EP, E,  ,  ,  ,  , 16, 2019, TS, S, 2019092812, 2019100106, , , , , , ARCHIVE, , EP162019
 SEVENTEEN, EP, E,  ,  ,  ,  , 17, 2019, DB, S, 2019101600, 2019101612, , , , , , ARCHIVE, , EP172019
    OCTAVE, EP, E,  ,  ,  ,  , 18, 2019, TS, S, 2019101700, 2019102106, , , , , , ARCHIVE, , EP182019
 PRISCILLA, EP, E,  ,  ,  ,  , 19, 2019, TS, S, 2019101912, 2019102100, , , , , , ARCHIVE, , EP192019
   RAYMOND, EP, E,  ,  ,  ,  , 20, 2019, TS, S, 2019111306, 2019111718, , , , , , ARCHIVE, , EP202019
TWENTY-ONE, EP, E,  ,  ,  ,  , 21, 2019, TD, S, 2019111512, 2019111806, , , , , , ARCHIVE, , EP212019/;
}

1;

__END__

=head1 NAME

Weather::NHC::TropicalCyclone::StormTable - convenient access to the list of historical storms
L<https://ftp.nhc.noaa.gov/atcf/archive/storm.table>, which is in ATCF format. Although it looks
like and can be treated in many cases as CSV, field width is importan when considering this type
of data operationally.

=head1 DESCRIPTION

The NHC maintains a table of all past storms going back to 1851. Information is added at the end
of each year. So during an active season, the historical information for the current season will
not be known this module. However, one may use the C<get_latest_table> to retrieve the latest state
of the C<storm.table> if the data seems to be out of date.

=head1 SYNOPSIS

   my $obj = Weather::NHC::TropicalCyclone::StormTable->new;
   
   foreach my $year ( @{ $obj->years } ) {
       print qq{$year\n};
   }
   
   foreach my $basin ( @{ $obj->basins } ) {
       print qq{$basin\n};
   }}
   
   foreach my $name ( @{ $obj->names } ) {
       print qq{$name\n};
   }
   
   foreach my $kind ( @{ $obj->storm_kinds } ) {
       print qq{$kind\n};
   }
   
   foreach my $nhc_designation ( @{ $obj->nhc_designations } ) {
       print qq{$nhc_designation\n};
   }

   print $obj->get_history_archive_url(2012, q{al}, q{01}), qq{\n};

   print $obj->get_best_track_archive_url(2012, q{al}, q{01}), qq{\n};

   print $obj->get_fixes_archive_url(2012, q{al}, q{01}), qq{\n};

   print $obj->get_archive_url(2012, q{al}, q{01}), qq{\n};

=head1 METHODS

=over 3

=item  C<new> 

Constructor.

=item  C<years>

Returns a list of all years in the history file.

=item  C<by_year> 

Accessor for all storm records for the provided year, all basins.

=item  C<names> 

Returns a list of all storm names in the history file.

=item  C<by_name>

Accessor for all storm records for the provided name, all basins.

=item  C<basins>

Returns a list of all basis in the history file.

=item  C<by_basin> 

Accessor for all storm records for the provided basin.

=item  C<get_by_year_basin>

Accessor for all storm records for the provided basin and year.

=item  C<nhc_designations>

Returns a list of all full NHC storm designations, e.g. C<al222020>.

=item  C<by_nhc_designation>

Returns the storm record for the provided year, basin, and storm number.

=item  C<storm_kinds>

Returns a list of all kinds of storms in the history file, e.g. C<HU>, C<TD>, etc.

=item  C<by_storm_kind>

Accessor for all storms of the povided kind.

=item C<get_storm_numbers>

Given the year and basin, returns the storm numbers for that year.

=item  C<get_history_archive_url>

For the given year, basin, and storm number; returns the full URL including file
name for the archived history file; e.g., C<aal112019.dat.gz>.

=item  C<get_best_track_archive_url> 

For the given year, basin, and storm number; returns the full URL including file
name for the archived best track file; e.g., C<bal112019.dat.gz>.

=item  C<get_fixes_archive_url>

For the given year, basin, and storm number; returns the full URL including file
name for the archived fixes file; e.g., C<fal112019.dat.gz>.

=item  C<get_archive_url>

For the given year, returns the URL for the directory containing all archived files
and subdirectories.

=item  C<storm_table> 

Returns the entire text of the NHC C<storm.history> file being used by this module.

=item C<get_latest_table>

Updates the data used for the query methods with the latest version of the table
being hosted by the NHC at L<https://ftp.nhc.noaa.gov/atcf/archive/storm.table>,
underneath utilizes C<HTTP::Tiny>.

=back

=head2 Internal Methods

=over 3

=item  C<_ingest_storm_table>

Takes C<storm.table> in raw text and shoves it into the reference fields that
support the other methods. Used by C<new> and C<get_latest_table>.

=item  C<_return_arrayref> 

Helper method for converting interal data representation into array references.

=item  C<_get_storm_designation>

Helper method to format provided year, basin, and storm number into the designation
format.

=item  C<_data>

Internal method that encapsulates the raw storm.history file.

=item C<_parse_line>

Parses a storm record and returns an array ref.

=back

=head1 ADDITIONAL INFORMATION

=head2 ATCF Storm Archive Information

=over 3

=item ATCF Database Description Homepage
L<https://www.nrlmry.navy.mil/atcf_web/docs/database/new/database.html#datasources>

=item C<storm.table> format description

L<https://www.nrlmry.navy.mil/atcf_web/docs/database/new/abdeck.txt>

=back

=head2 C<storm.table> ATCF Data Format Description

Presented here from L<https://www.nrlmry.navy.mil/atcf_web/docs/database/new/abdeck.txt> for convenience.

   ATCF best track, aids, bogus format 8/31/2016
   
   See the notes on missing and deprecated data at the end of this document.
   
   Common section, fields 1-36, followed by user-data section which is not predefined.
   
   
   BASIN, CY, YYYYMMDDHH, TECHNUM/MIN, TECH, TAU, LatN/S, LonE/W, VMAX, MSLP, TY, RAD, WINDCODE, RAD1, RAD2, RAD3, RAD4, POUTER, ROUTER, RMW, GUSTS, EYE, SUBREGION, MAXSEAS, INITIALS, DIR, SPEED, STORMNAME, DEPTH, SEAS, SEASCODE, SEAS1, SEAS2, SEAS3, SEAS4, USERDEFINED, userdata
   
   COMMON FIELDS
   
   BASIN      - basin, e.g. WP, IO, SH, CP, EP, AL, LS
   CY         - annual cyclone number: 1 - 99
   YYYYMMDDHH - Warning Date-Time-Group, yyyymmddhh: 0000010100 through 9999123123.
   TECHNUM/MIN- objective technique sorting number, minutes for best track: 00 - 99
   TECH       - acronym for each objective technique or CARQ or WRNG,
                BEST for best track, up to 4 chars.
   TAU        - forecast period: -24 through 240 hours, 0 for best-track, 
                negative taus used for CARQ and WRNG records.
   LatN/S     - Latitude for the DTG: 0 - 900 tenths of degrees,
                N/S is the hemispheric index.
   LonE/W     - Longitude for the DTG: 0 - 1800 tenths of degrees,
                E/W is the hemispheric index.
   VMAX       - Maximum sustained wind speed in knots: 0 - 300 kts.
   MSLP       - Minimum sea level pressure, 850 - 1050 mb.
   TY         - Highest level of tc development:
                DB - disturbance, 
                TD - tropical depression, 
                TS - tropical storm, 
                TY - typhoon, 
                ST - super typhoon, 
                TC - tropical cyclone, 
                HU - hurricane, 
                SD - subtropical depression,
                SS - subtropical storm,
                EX - extratropical systems,
                PT - post tropical,
                IN - inland,
                DS - dissipating,
                LO - low,
                WV - tropical wave,
                ET - extrapolated,
                MD - monsoon depression,
                XX - unknown.
   RAD        - Wind intensity for the radii defined in this record: 34, 50 or 64 kt.
   WINDCODE   - Radius code:
                AAA - full circle
                NEQ, SEQ, SWQ, NWQ - quadrant 
   RAD1       - If full circle, radius of specified wind intensity, or radius of
                first quadrant wind intensity as specified by WINDCODE.  0 - 999 n mi
   RAD2       - If full circle this field not used, or radius of 2nd quadrant wind
                intensity as specified by WINDCODE.  0 - 999 n mi.
   RAD3       - If full circle this field not used, or radius of 3rd quadrant wind
                intensity as specified by WINDCODE.  0 - 999 n mi.
   RAD4       - If full circle this field not used, or radius of 4th quadrant wind
                intensity as specified by WINDCODE.  0 - 999 n mi.
   POUTER     - pressure in millibars of the last closed isobar, 900 - 1050 mb.
   ROUTER     - radius of the last closed isobar, 0 - 999 n mi.
   RMW        - radius of max winds, 0 - 999 n mi.
   GUSTS      - gusts, 0 - 999 kt.
   EYE        - eye diameter, 0 - 120 n mi.
   SUBREGION  - subregion code: W,A,B,S,P,C,E,L,Q.
                A - Arabian Sea
                B - Bay of Bengal
                C - Central Pacific
                E - Eastern Pacific
                L - Atlantic
                P - South Pacific (135E - 120W)
                Q - South Atlantic
                S - South IO (20E - 135E)
                W - Western Pacific
   MAXSEAS    - max seas: 0 - 999 ft.
   INITIALS   - Forecaster's initials used for tau 0 WRNG or OFCL, up to 3 chars.
   DIR        - storm direction, 0 - 359 degrees.
   SPEED      - storm speed, 0 - 999 kts.
   STORMNAME  - literal storm name, number, NONAME or INVEST, or TCcyx where:
                cy = Annual cyclone number 01 - 99
                x  = Subregion code: W,A,B,S,P,C,E,L,Q.
   DEPTH      - system depth, 
   	     D - deep, 
   	     M - medium, 
   	     S - shallow, 
   	     X - unknown
   SEAS       - Wave height for radii defined in SEAS1 - SEAS4, 0 - 99 ft.
   SEASCODE   - Radius code:
                AAA - full circle
                NEQ, SEQ, SWQ, NWQ - quadrant 
   SEAS1      - first quadrant seas radius as defined by SEASCODE,  0 - 999 n mi.
   SEAS2      - second quadrant seas radius as defined by SEASCODE, 0 - 999 n mi.
   SEAS3      - third quadrant seas radius as defined by SEASCODE,  0 - 999 n mi.
   SEAS4      - fourth quadrant seas radius as defined by SEASCODE, 0 - 999 n mi.
   USERDEFINE1- 1 to 20 character description of user data to follow.
   userdata1  - user data section as indicated by USERDEFINED parameter (up to 100 char).
   USERDEFINE2- 1 to 20 character description of user data to follow.
   userdata2  - user data section as indicated by USERDEFINED parameter (up to 100 char).
   USERDEFINE3- 1 to 20 character description of user data to follow.
   userdata3  - user data section as indicated by USERDEFINED parameter (up to 100 char).
   USERDEFINE4- 1 to 20 character description of user data to follow.
   userdata4  - user data section as indicated by USERDEFINED parameter (up to 100 char).
   USERDEFINE5- 1 to 20 character description of user data to follow.
   userdata5  - user data section as indicated by USERDEFINED parameter (up to 100 char).
   
   ------------------------------------------------------------------------------
   
   userdata   - user data section as indicated by USERDEFINED parameter.
   Examples of USERDEFINED/userdata pairs:
   - An invest spawned from a genesis area:
       SPAWNINVEST, wp712015 to wp902015
   - An invest area transitioning to a TC:
       TRANSITIONED, shE92015 to sh152015
   - A TC dissipated to an invest area:
       DISSIPATED, sh162015 sh982015 
   - A genesis area number:
       genesis-num, 001
   ------------------------------------------------------------------------------
   
   Notes:
   
   1) No missing data allowed for first eight common fields.  Missing data for other fields are expected to be blank characters between the comma delimiters.  Although the files are not column dependent please insure that the proper number of blank characters is included in missing data so the columns line up.  This makes the files easier to read and troubleshoot.
   
   2) The USERDEFINED section is for inclusion of items not already in the common fields.  The USERDEFINED parameter is 1 to 20 characters, so there should be sufficient space to include some text describing what comes next.
   
   3) Wind records merged in from preexisting wind files (r-decks) were assigned a TECH of CNTR.  Wind records created during normal use of this combined data format are assigned the TECH corresponding to the center name as defined in $ATCFINC/atcfsite.nam.
   
   4) WINDCODE and SEASCODE other than AAA, NEQ, SEQ, SWQ and NWQ exist in older data but have been deprecated.
   
   5) RAD values of 100 exist in old data (earlier than 2005) but have been deprecated.  Currently only 34, 50 and 64 are valid for RAD.
   
   6) The fields are not column dependent, but the files are easier to read and troubleshoot if the columns line up.  The fields are comma and space delimited.  
   
   The desired field widths and preferred ATCF application ranges are as follows:
   	field    number of chars	range
   	-----    ---------------	-----
   	BASIN        2			WP, EP, CP, IO, SH, AL, SL as defined in basin.dat
   	CY           2 			01 to 99, 01 to 49 are real storms, 80 to 89 are test storms, 90 to 99 are INVESTS
   	YYYYMMDDHH  10			only valid DTGs
   	TECHNUM/MIN  2			00 <= TECHNUM <= 99,  00 <= MIN < 60
   	TECH         4			up to four alphanumeric characters
   	TAU          3 			-24 <= TAU <= 240 hours
   	LatN/S       4 			0 <= Lat <= 900  N/S, in tenths of degrees
   	LonE/W       5 			0 <= Lon <=1800  E/W, in tenths of degrees
   	VMAX         3 			10 <= VMAX <= 250 kt
   	MSLP         4 			850 to 1050 mb
   	TY           2 			as defined in tcdevel.dat
   	RAD          3 			34, 50, 64 kt
   	WINDCODE     3 			AAA, NEW, SEQ, SWQ, NWQ
   	RAD1         4 			MRD < RAD1 <= 999 n mi, 
                                           64 kt RAD1 < 50 kt RAD1 < 34 kt RAD1
                                           0 for no radius in quadrant, blank for unknown
           RAD2         4  	        See RAD1
   	RAD3         4  		See RAD1
   	RAD4         4  		See RAD1
   	POUTER       4 			MSLP < RADP < 1050 mb
   	ROUTER       4 			EYE <  RRP  <= 999 n mi
   	RMW          3			0   <  MRD  <= RAD1, RAD2, RAD3, and RAD4
   	GUSTS        3			VMAX < GUSTS < 300 kt
   	EYE          3 			RRP < EYE < 120 n mi
   	SUBREGION    3			W,E,C,A,B,S,P,L,Q   - basin.dat
   	MAXSEAS      3			0 < MAXSEAS < 200 ft
   	INITIALS     3
   	DIR          3                  0 <= DIR < 360
   	SPEED        3 			0 <= SPEED < 100 kt
   	STORMNAME   10  
   	DEPTH        1			D, M, S, X
   	SEAS         2			0 < SEAS < 100 ft
   	SEASCODE     3			AAA, NEW, SEQ, SWQ, NWQ
   	SEAS1        4			0 < SEAS1 <= 999 n mi
   	SEAS2        4 			See SEAS1
   	SEAS3        4 			See SEAS1
   	SEAS4        4 			See SEAS1
   	USERDEFINED up to 20            1 to 20 characters of alphanumeric data 
   	userdata    up to 200
