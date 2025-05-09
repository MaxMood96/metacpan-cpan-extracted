
# main window, menu, functions

use v5.12;
use warnings;
use utf8;
use Wx::AUI;

package App::GUI::Cellgraph::Frame;
use base qw/Wx::Frame/;
use App::GUI::Cellgraph::Dialog::About;
use App::GUI::Cellgraph::Frame::Tab::General;
use App::GUI::Cellgraph::Frame::Tab::Start;
use App::GUI::Cellgraph::Frame::Tab::Rules;
use App::GUI::Cellgraph::Frame::Tab::Action;
use App::GUI::Cellgraph::Frame::Tab::Color;
use App::GUI::Cellgraph::Frame::Panel::Board;
use App::GUI::Cellgraph::Widget::ProgressBar;
use App::GUI::Cellgraph::Settings;
use App::GUI::Cellgraph::Config;

sub new {
    my ( $class, $parent, $title ) = @_;
    my $self = $class->SUPER::new( $parent, -1, $title );
    $self->SetIcon( Wx::GetWxPerlIcon() );
    $self->CreateStatusBar( 1 );
    $self->SetStatusWidths(2, 800, 100);
    Wx::InitAllImageHandlers();
    $self->{'title'} = $title;
    $self->{'config'} = App::GUI::Cellgraph::Config->new();
    my $sr_calc = App::GUI::Cellgraph::Compute::Subrule->new( 3, 2, 'all' );
    $self->{'img_size'} = 700;
    $self->{'img_format'} = 'png';
    my $window_size = [1200, 840];

    # create GUI parts
    $self->{'tabs'}            = Wx::AuiNotebook->new( $self, -1, [-1,-1], [-1,-1], &Wx::wxAUI_NB_TOP );
    $self->{'tab'}{'global'} = App::GUI::Cellgraph::Frame::Tab::General->new( $self->{'tabs'}, $sr_calc );
    $self->{'tab'}{'start'}  = App::GUI::Cellgraph::Frame::Tab::Start->new(  $self->{'tabs'} );
    $self->{'tab'}{'rules'}  = App::GUI::Cellgraph::Frame::Tab::Rules->new(  $self->{'tabs'}, $sr_calc );
    $self->{'tab'}{'action'} = App::GUI::Cellgraph::Frame::Tab::Action->new( $self->{'tabs'}, $sr_calc );
    $self->{'tab'}{'color'}  = App::GUI::Cellgraph::Frame::Tab::Color->new(  $self->{'tabs'}, $self->{'config'} );
    $self->{'tab_names'} = [keys %{$self->{'tab'}}];
    $self->{'tab'}{$_}->set_callback( sub { $self->sketch( $_[0] ) } ) for @{$self->{'tab_names'}};
    $self->{'tabs'}->AddPage( $self->{'tab'}{'global'}, 'General Settings');
    $self->{'tabs'}->AddPage( $self->{'tab'}{'start'},  'Starting Row');
    $self->{'tabs'}->AddPage( $self->{'tab'}{'rules'},  'State Rules');
    $self->{'tabs'}->AddPage( $self->{'tab'}{'action'}, 'Action Rules');
    $self->{'tabs'}->AddPage( $self->{'tab'}{'color'},  'Colors');
    $self->{'tabs'}{'selected'} = 0;
    $self->{'progress_bar'} = App::GUI::Cellgraph::Widget::ProgressBar->new( $self, 320, 10, $self->{'tab'}{'color'}->get_active_colors);

    $self->{'board'}               = App::GUI::Cellgraph::Frame::Panel::Board->new( $self, 700 );
    $self->{'dialog'}{'about'}     = App::GUI::Cellgraph::Dialog::About->new();
    $self->{'btn'}{'draw'} = $self->{'btn'}{'draw'}      = Wx::Button->new( $self, -1, '&Draw', [-1,-1],[50, 40] );

    Wx::Event::EVT_AUINOTEBOOK_PAGE_CHANGED( $self, $self->{'tabs'}, sub {
        $self->{'tabs'}{'selected'} = $self->{'tabs'}->GetSelection unless $self->{'tabs'}->GetSelection == $self->{'tabs'}->GetPageCount - 1;
    });
    Wx::Event::EVT_CLOSE( $self, sub {
        $self->{'tab'}{'color'}->update_config;
        $self->{'config'}->save();
        $self->{'dialog'}{$_}->Destroy() for qw/about/; # interface function
        $_[1]->Skip(1)
    });
    Wx::Event::EVT_BUTTON( $self, $self->{'btn'}{'draw'}, sub { $self->draw });

    # GUI layout assembly
    my $settings_menu = $self->{'setting_menu'} = Wx::Menu->new();
    $settings_menu->Append( 11100, "&Init\tCtrl+I", "put all settings to default" );
    $settings_menu->Append( 11200, "&Open\tCtrl+O", "load settings from an INI file" );
    $settings_menu->Append( 11400, "&Write\tCtrl+W", "store curent settings into an INI file" );
    $settings_menu->AppendSeparator();
    $settings_menu->Append( 11500, "&Quit\tAlt+Q", "save configs and close program" );

    my $image_size_menu = Wx::Menu->new();
    for (1 .. 20) {
        my $size = $_ * 100;
        $image_size_menu->AppendRadioItem(12100 + $_, $size, "set image size to $size x $size");
        Wx::Event::EVT_MENU( $self, 12100 + $_, sub {
            $self->{'img_size'} = 100 * ($_[1]->GetId - 12100);
            $self->{'board'}->set_size( $self->{'img_size'} );
        });

    }
    $image_size_menu->Check( 12100 +($self->{'img_size'} / 100), 1);

    my $image_menu = Wx::Menu->new();
    $image_menu->Append( 12300, "&Draw\tCtrl+D", "complete a sketch drawing" );
    $image_menu->Append( 12100, "S&ize",  $image_size_menu,   "set image size" );
    $image_menu->Append( 12400, "&Save\tCtrl+S", "save currently displayed image" );

    my $help_menu = Wx::Menu->new();
    $help_menu->Append( 13300, "&About\tAlt+A", "Dialog with general information about the program" );

    my $menu_bar = Wx::MenuBar->new();
    $menu_bar->Append( $settings_menu, '&Settings' );
    $menu_bar->Append( $image_menu,    '&Image' );
    $menu_bar->Append( $help_menu,     '&Help' );
    $self->SetMenuBar($menu_bar);

    Wx::Event::EVT_MENU( $self, 11100, sub { $self->init });
    Wx::Event::EVT_MENU( $self, 11200, sub { $self->open_settings_dialog });
    Wx::Event::EVT_MENU( $self, 11400, sub { $self->write_settings_dialog });
    Wx::Event::EVT_MENU( $self, 11500, sub { $self->Close });
    Wx::Event::EVT_MENU( $self, 12300, sub { $self->draw });
    Wx::Event::EVT_MENU( $self, 12400, sub { $self->save_image_dialog });
    Wx::Event::EVT_MENU( $self, 13300, sub { $self->{'dialog'}{'about'}->ShowModal });

    my $std_attr = &Wx::wxALIGN_LEFT|&Wx::wxGROW|&Wx::wxALIGN_CENTER_VERTICAL;
    my $vert_attr = $std_attr | &Wx::wxTOP;
    my $vset_attr = $std_attr | &Wx::wxTOP| &Wx::wxBOTTOM;
    my $horiz_attr = $std_attr | &Wx::wxLEFT;
    my $all_attr    = $std_attr | &Wx::wxALL;
    my $line_attr    = $std_attr | &Wx::wxLEFT | &Wx::wxRIGHT ;

    my $board_sizer = Wx::BoxSizer->new(&Wx::wxVERTICAL);
    $board_sizer->Add( $self->{'board'}, 0, $all_attr,  5);
    $board_sizer->Add( 0, 0, &Wx::wxEXPAND | &Wx::wxGROW);

    my $paint_lbl = Wx::StaticText->new( $self, -1, 'Grid Status:' );
    my $draw_sizer = Wx::BoxSizer->new( &Wx::wxHORIZONTAL );
    $draw_sizer->Add( $paint_lbl,                  0, $all_attr, 15 );
    $draw_sizer->Add( $self->{'progress_bar'},         0, &Wx::wxALIGN_CENTER_VERTICAL, 10 );
    $draw_sizer->AddSpacer(5);
    $draw_sizer->Add( $self->{'btn'}{'draw'},      0, $all_attr, 5 );
    $draw_sizer->Add( 0, 1, &Wx::wxEXPAND | &Wx::wxGROW);

    my $setting_sizer = Wx::BoxSizer->new(&Wx::wxVERTICAL);
    $setting_sizer->Add( $self->{'tabs'}, 1, &Wx::wxEXPAND | &Wx::wxGROW);
    $setting_sizer->AddSpacer(10);
    $setting_sizer->Add( $draw_sizer,      0,  0, 0);
    $setting_sizer->AddSpacer(5);
    # $setting_sizer->Add( 0, 1, &Wx::wxEXPAND | &Wx::wxGROW);

    my $main_sizer = Wx::BoxSizer->new( &Wx::wxHORIZONTAL );
    $main_sizer->Add( $board_sizer, 0, &Wx::wxEXPAND, 0);
    $main_sizer->Add( $setting_sizer, 1, &Wx::wxEXPAND, 0);

    $self->SetSizer($main_sizer);
    $self->SetAutoLayout( 1 );
    $self->{'tabs'}->SetFocus;
    #$self->SetMinSize( $window_size );
    $self->SetMaxSize( $window_size );
    $self->SetSize( $window_size );

    $self->update_recent_settings_menu();
    $self->sketch( );
    $self->SetStatusText( "settings in init state", 0 );
    $self->{'last_file_settings'} = $self->get_settings;
    $self;
}

sub update_recent_settings_menu {
    my ($self) = @_;
    my $recent = $self->{'config'}->get_value('last_settings');
    return unless ref $recent eq 'ARRAY';
    my $set_menu_ID = 11300;
    $self->{'setting_menu'}->Destroy( $set_menu_ID );
    my $Recent_ID = $set_menu_ID + 1;
    $self->{'recent_menu'} = Wx::Menu->new();
    for (reverse @$recent){
        my $path = $_;
        $self->{'recent_menu'}->Append($Recent_ID, $path);
        Wx::Event::EVT_MENU( $self, $Recent_ID++, sub { $self->open_setting_file( $path ) });
    }
    $self->{'setting_menu'}->Insert( 2, $set_menu_ID, '&Recent', $self->{'recent_menu'}, 'recently saved settings' );
}

sub init {
    my ($self) = @_;
    $self->{'tab'}{ $_ }->init() for @{$self->{'tab_names'}};
    $self->sketch( );
    $self->SetStatusText( "all settings are set to default", 0);
    $self->set_settings_save(1);
}

sub get_state    { return { map { $_ => $_[0]->{'tab'}{$_}->get_state } @{$_[0]->{'tab_names'}} }}
sub get_settings { return { map { $_ => $_[0]->{'tab'}{$_}->get_settings } @{$_[0]->{'tab_names'}} }}

sub set_settings {
    my ($self, $settings) = @_;
    $self->{'tab'}{ $_ }->set_settings( $settings->{ $_ } ) for @{$self->{'tab_names'}};
    $self->spread_setting_changes;
}

sub set_settings_save {
    my ($self, $status)  = @_;
    $self->{'saved'} = $status;
    $self->SetTitle( $self->{'title'} .($self->{'saved'} ? '': ' *'));
}

sub spread_setting_changes {
    my ($self, $settings) = @_;
    my $global = (ref $settings eq 'HASH') ? $settings->{'global'} : $self->{'tab'}{'global'}->get_settings;
    $self->{'tab'}{'color'}->set_state_count( $global->{'state_count'} );
    $self->{'tab'}{'color'}->set_settings( $settings->{'color'} ) if ref $settings eq 'HASH';
    $self->{'tab'}{'global'}->set_settings( $settings->{'global'} ) if ref $settings eq 'HASH';
    my @state_colors = $self->{'tab'}{'color'}->get_active_colors;
    $self->{'tab'}{'start'}->update_cell_colors( @state_colors );
    $self->{'tab'}{'rules'}->regenerate_rules( @state_colors );
    $self->{'tab'}{'action'}->regenerate_rules( @state_colors );
    $self->{'progress_bar'}->set_colors( @state_colors );
}
sub sketch {
    my ($self) = @_;
    $self->spread_setting_changes();
    $self->{'board'}->sketch( $self->get_state );
    $self->{'progress_bar'}->reset;
    $self->set_settings_save( 0 );
}
sub draw {
    my ($self) = @_;
    $self->spread_setting_changes();
    $self->{'board'}->draw( $self->get_state );
    $self->{'progress_bar'}->full;
}

sub open_settings_dialog {
    my ($self) = @_;
    my $dialog = Wx::FileDialog->new ( $self, "Select a settings file to load", $self->{'config'}->get_value('open_dir'), '',
                   ( join '|', 'INI files (*.ini)|*.ini', 'All files (*.*)|*.*' ), &Wx::wxFD_OPEN );
    return if $dialog->ShowModal == &Wx::wxID_CANCEL;
    my $path = $dialog->GetPath;
    my $ret = $self->open_setting_file ( $path );
    if (not ref $ret) { $self->SetStatusText( $ret, 0) }
    else {
        my $dir = App::GUI::Cellgraph::Settings::extract_dir( $path );
        $self->{'config'}->set_value('open_dir', $dir);
        $self->SetStatusText( "loaded settings from ".$dialog->GetPath, 0);
    }
}
sub write_settings_dialog {
    my ($self) = @_;
    my $dialog = Wx::FileDialog->new ( $self, "Select a file name to store data", $self->{'config'}->get_value('write_dir'), '',
               ( join '|', 'INI files (*.ini)|*.ini', 'All files (*.*)|*.*' ), &Wx::wxFD_SAVE );
    return if $dialog->ShowModal == &Wx::wxID_CANCEL;
    my $path = $dialog->GetPath;
    return if -e $path and
              Wx::MessageDialog->new( $self, "\n\nReally overwrite the settings file?", 'Confirmation Question',
                                      &Wx::wxYES_NO | &Wx::wxICON_QUESTION )->ShowModal() != &Wx::wxID_YES;
    $self->write_settings_file( $path );
    $self->update_recent_settings_menu();
    my $dir = App::GUI::Cellgraph::Settings::extract_dir( $path );
    $self->{'config'}->set_value('write_dir', $dir);
}
sub open_setting_file {
    my ($self, $file ) = @_;
    my $settings = App::GUI::Cellgraph::Settings::load( $file );
    if (ref $settings) {
        $self->spread_setting_changes( $settings );
        $self->set_settings( $settings );
        $self->draw;
        $self->SetStatusText( "loaded settings from ".$file, 1) ;
        my $dir = App::GUI::Cellgraph::Settings::extract_dir( $file );
        $self->{'config'}->add_setting_file( $file ); # remember file in recents menu
        $self->update_recent_settings_menu();
        $self->set_settings_save(1);
        $settings;
    } else {
         $self->SetStatusText( $settings, 0);
    }
}
sub write_settings_file {
    my ($self, $file)  = @_;
    $file = substr ($file, 0, -4) if lc substr ($file, -4) eq '.ini';
    $file .= '.ini' unless lc substr ($file, -4) eq '.ini';
    my $ret = App::GUI::Cellgraph::Settings::write( $file, $self->get_settings );
    if ($ret){ $self->SetStatusText( $ret, 0 ) }
    else     {
        $self->{'config'}->add_setting_file( $file ); # remember file in recents menu
        $self->update_recent_settings_menu();
        $self->SetStatusText( "saved settings into file $file", 1 );
        $self->set_settings_save(1);
    }
}

sub write_image {
    my ($self, $file)  = @_;
    $self->{'board'}->save_file( $file );
    $file = App::GUI::Cellgraph::Settings::shrink_path( $file );
    $self->SetStatusText( "saved image under: $file", 0 );
}

sub save_image_dialog {
    my ($self) = @_;
    my @wildcard = ( 'SVG files (*.svg)|*.svg', 'PNG files (*.png)|*.png', 'JPEG files (*.jpg)|*.jpg');
    my $wildcard = '|All files (*.*)|*.*';
    my $default_ending = $self->{'config'}->get_value('file_base_ending');
    $wildcard = ($default_ending eq 'jpg') ? ( join '|', @wildcard[2,1,0]) . $wildcard :
                ($default_ending eq 'png') ? ( join '|', @wildcard[1,0,2]) . $wildcard :
                                             ( join '|', @wildcard[0,1,2]) . $wildcard ;
    my @wildcard_ending = ($default_ending eq 'jpg') ? (qw/jpg png svg/) :
                          ($default_ending eq 'png') ? (qw/png svg jpg/) :
                                                       (qw/svg jpg png/) ;

    my $dialog = Wx::FileDialog->new ( $self, "select a file name to save image", $self->{'config'}->get_value('save_dir'), '', $wildcard, &Wx::wxFD_SAVE );
    return if $dialog->ShowModal == &Wx::wxID_CANCEL;
    my $path = $dialog->GetPath;
    return if -e $path and
              Wx::MessageDialog->new( $self, "\n\nReally overwrite the image file?", 'Confirmation Question',
                                      &Wx::wxYES_NO | &Wx::wxICON_QUESTION )->ShowModal() != &Wx::wxID_YES;
    my $file_ending = lc substr ($path, -4);
    unless ($dialog->GetFilterIndex == 3 or # filter set to all endings
            ($file_ending eq '.jpg' or $file_ending eq '.png' or $file_ending eq '.svg')){
            $path .= '.' . $wildcard_ending[$dialog->GetFilterIndex];
    }
    my $ret = $self->write_image( $path );
    if ($ret){ $self->SetStatusText( $ret, 0 ) }
    else     { $self->{'config'}->set_value('save_dir', App::GUI::Cellgraph::Settings::extract_dir( $path )) }
}

1;
