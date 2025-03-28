use Pcore;

{

    # amCharts4
    amcharts4 => sub ( $cdn, $native, $args ) {
        my $ver = version->parse( $args->{ver} // v4.7.11 );

        state $native_prefix = 'https://www.amcharts.com/lib/4';

        if (wantarray) {
            my @res;

            push @res, $cdn->get_script_tag( $native ? "$native_prefix/core.js"   : $cdn->("/static/amcharts/$ver/core.js") );
            push @res, $cdn->get_script_tag( $native ? "$native_prefix/charts.js" : $cdn->("/static/amcharts/$ver/charts.js") ) if $args->{charts};
            push @res, $cdn->get_script_tag( $native ? "$native_prefix/maps.js"   : $cdn->("/static/amcharts/$ver/maps.js") ) if $args->{maps};

            return @res;
        }
        else {
            return $native ? $native_prefix : $cdn->("/static/amcharts/$ver");
        }
    },

    # amCharts4 geodata
    amcharts4_geodata => sub ( $cdn, $native, $args ) {
        my $ver = version->parse( $args->{ver} // v4.1.9 );

        state $native_prefix = 'https://www.amcharts.com/lib/4/geodata';

        if (wantarray) {
            die q[Invalid usage of "amcharts4_geodata" resource];
        }
        else {
            return $native ? $native_prefix : $cdn->("/static/amcharts-geodata/$ver");
        }
    },

    # extJS
    extjs6 => sub ( $cdn, $native, $args ) {
        my $ver = version->parse( $args->{ver} // v6.7.0 );

        if (wantarray) {
            my @res;

            my $debug = $args->{devel} ? '-debug' : $EMPTY;

            # framework
            push @res, $cdn->get_script_tag( $cdn->("/static/ext/$ver/ext$debug.js") );

            # theme
            push @res, $cdn->get_css_tag( $cdn->("/static/ext/$ver/theme-$args->{theme}/resources/theme-$args->{theme}-all$debug.css") );
            push @res, $cdn->get_script_tag( $cdn->("/static/ext/$ver/theme-$args->{theme}/theme-$args->{theme}$debug.js") );

            # fashion, only for modern material theme
            push @res, $cdn->get_script_tag( $cdn->("/static/ext/$ver/css-vars.js") );

            return @res;
        }
        else {
            return $cdn->("/static/extjs/$ver");
        }
    },

    extjs7 => sub ( $cdn, $native, $args ) {
        my $ver = version->parse( $args->{ver} // v7.0.0 );

        if (wantarray) {
            my @res;

            my $debug = $args->{devel} ? '-debug' : $EMPTY;

            # framework
            push @res, $cdn->get_script_tag( $cdn->("/static/ext/$ver/ext$debug.js") );

            # theme
            push @res, $cdn->get_css_tag( $cdn->("/static/ext/$ver/theme-$args->{theme}/resources/theme-$args->{theme}-all$debug.css") );
            push @res, $cdn->get_script_tag( $cdn->("/static/ext/$ver/theme-$args->{theme}/theme-$args->{theme}$debug.js") );

            # fashion, only for modern material theme
            push @res, $cdn->get_script_tag( $cdn->("/static/ext/$ver/css-vars.js") );

            return @res;
        }
        else {
            return $cdn->("/static/extjs/$ver");
        }
    },

    # fontAwesome
    fa5 => sub ( $cdn, $native, $args ) {
        my $ver = version->parse( $args->{ver} // v5.11.2 );

        state $native_prefix = 'https://use.fontawesome.com/releases';

        if (wantarray) {
            return $cdn->get_css_tag( $native ? "$native_prefix/$ver/css/all.css" : $cdn->("/static/fa/$ver/css/all.min.css") );
        }
        else {
            return $native ? "$native_prefix/$ver" : $cdn->("/static/fa/$ver");
        }
    },

    # froala, https://www.froala.com/wysiwyg-editor
    froala3 => sub ( $cdn, $native, $args ) {
        my $ver = version->parse( $args->{ver} // v3.0.6 );

        if (wantarray) {
            my @res;

            push @res, $cdn->get_css_tag( $cdn->("/static/froala/$ver/css/froala_editor.pkgd.min.css") );
            push @res, $cdn->get_script_tag( $cdn->("/static/froala/$ver/js/froala_editor.pkgd.min.js") );

            return @res;
        }
        else {
            return $cdn->("/static/unitegallery/$ver");
        }
    },

    # jQuery3
    jquery3 => sub ( $cdn, $native, $args ) {
        my $ver = version->parse( $args->{ver} // v3.4.1 );

        state $native_prefix = 'https://ajax.googleapis.com/ajax/libs/jquery';

        if (wantarray) {
            return $cdn->get_script_tag( $native ? "$native_prefix/@{[ substr $ver, 1 ]}/jquery.min.js" : $cdn->("/static/jquery/$ver/jquery.min.js") );
        }
        else {
            return $native ? "$native_prefix/" . substr $ver, 1 : $cdn->("/static/jquery/$ver");
        }
    },

    # jsSHA, https://github.com/Caligatio/jsSHA
    jssha => sub ( $cdn, $native, $args ) {
        my $ver = version->parse( $args->{ver} // v2.3.1 );

        if (wantarray) {
            my @res;

            push @res, $cdn->get_script_tag( $cdn->("/static/jssha/$ver/sha.js") );

            return @res;
        }
        else {
            return $cdn->("/static/jssha/$ver");
        }
    },

    # pcore-api
    pcore_api => sub ( $cdn, $native, $args ) {
        if (wantarray) {
            return $cdn->get_script_tag( $cdn->("/static/pcore/api.js") );
        }
        else {
            return $cdn->("/static/pcore");
        }
    },

    # pdfjs
    pdfjs => sub ( $cdn, $native, $args ) {
        my $ver = version->parse( $args->{ver} // v2.3.200 );

        state $native_prefix = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js';

        if (wantarray) {
            my @res;

            push @res, $cdn->get_script_tag( $native ? "$native_prefix/@{[ substr $ver, 1 ]}/pdf.min.js" : $cdn->("/static/pdfjs/$ver/pdf.min.js") );

            return @res;
        }
        else {
            return $native ? "$native_prefix/" . substr $ver, 1 : $cdn->("/static/pdfjs/$ver");
        }
    },

    # vue
    vue => sub ( $cdn, $native, $args ) {
        my $ver = version->parse( $args->{ver} // v2.6.10 );

        state $native_prefix = 'https://cdn.jsdelivr.net/npm/vue@';

        if (wantarray) {
            my @res;

            my $devel = $args->{devel} ? $EMPTY : '.min';

            push @res, $cdn->get_script_tag( $native ? "$native_prefix/@{[ substr $ver, 1 ]}/dist/vue${devel}.js" : $cdn->("/static/vue/$ver/vue${devel}.js") );

            return @res;
        }
        else {
            return $native ? "$native_prefix/" . substr( $ver, 1 ) . '/dist' : $cdn->("/static/vue/$ver");
        }
    },

    # vue-router
    'vue-router' => sub ( $cdn, $native, $args ) {
        my $ver = version->parse( $args->{ver} // v3.1.3 );

        state $native_prefix = 'https://cdn.jsdelivr.net/npm/vue-router@';

        if (wantarray) {
            my @res;

            my $devel = $args->{devel} ? $EMPTY : '.min';

            push @res, $cdn->get_script_tag( $native ? "$native_prefix/@{[ substr $ver, 1 ]}/dist/vue-router${devel}.js" : $cdn->("/static/vue-router/$ver/vue-router${devel}.js") );

            return @res;
        }
        else {
            return $native ? "$native_prefix/" . substr( $ver, 1 ) . '/dist' : $cdn->("/static/vue-router/$ver");
        }
    },

    # vuetify
    vuetify => sub ( $cdn, $native, $args ) {
        my $ver = version->parse( $args->{ver} // v2.1.12 );

        state $native_prefix = 'https://cdn.jsdelivr.net/npm/vuetify@';

        if (wantarray) {
            my @res;

            my $devel = $args->{devel} ? $EMPTY : '.min';

            push @res, $cdn->get_css_tag('https://fonts.googleapis.com/css?family=Roboto:100,300,400,500,700,900');

            push @res, $cdn->get_css_tag( $native ? "$native_prefix/@{[ substr $ver, 1 ]}/dist/vuetify${devel}.css" : $cdn->("/static/vuetify/$ver/vuetify${devel}.css") );

            push @res, $cdn->get_script_tag( $native ? "$native_prefix/@{[ substr $ver, 1 ]}/dist/vuetify${devel}.js" : $cdn->("/static/vuetify/$ver/vuetify${devel}.js") );

            return @res;
        }
        else {
            return $native ? "$native_prefix/" . substr( $ver, 1 ) . '/dist' : $cdn->("/static/vuetify/$ver");
        }
    },

    # vuex
    vuex => sub ( $cdn, $native, $args ) {
        my $ver = version->parse( $args->{ver} // v3.1.2 );

        state $native_prefix = 'https://cdn.jsdelivr.net/npm/vuex@';

        if (wantarray) {
            my @res;

            my $devel = $args->{devel} ? $EMPTY : '.min';

            push @res, $cdn->get_script_tag( $native ? "$native_prefix/@{[ substr $ver, 1 ]}/dist/vuex${devel}.js" : $cdn->("/static/vuex/$ver/vuex${devel}.js") );

            return @res;
        }
        else {
            return $native ? "$native_prefix/" . substr( $ver, 1 ) . '/dist' : $cdn->("/static/vuex/$ver");
        }
    },
}
## -----SOURCE FILTER LOG BEGIN-----
##
## PerlCritic profile "pcore-config" policy violations:
## +------+----------------------+----------------------------------------------------------------------------------------------------------------+
## | Sev. | Lines                | Policy                                                                                                         |
## |======+======================+================================================================================================================|
## |    3 | 1                    | Modules::ProhibitExcessMainComplexity - Main code has high complexity score (57)                               |
## +------+----------------------+----------------------------------------------------------------------------------------------------------------+
##
## -----SOURCE FILTER LOG END-----
