use strict;
use warnings;
use Test::More;
use App::LinkSite::Site;
use App::LinkSite::Link;
use App::LinkSite::Section;

# Test the creation of an App::LinkSite::Site object
my $site = App::LinkSite::Site->new(
    name     => 'Test Name',
    handle   => 'Test Handle',
    image    => 'test_image.jpg',
    desc     => 'Test Description',
    og_image => 'test_og_image.png',
    site_url => 'http://example.com',
);

# Test default color values (should be undef if not set)
is($site->text_color, undef, 'text_color is undefined by default');
is($site->background_color, undef, 'background_color is undefined by default');

# Test custom color values
my $site2 = App::LinkSite::Site->new(
    name     => 'Test Name',
    handle   => 'Test Handle',
    image    => 'test_image.jpg',
    desc     => 'Test Description',
    og_image => 'test_og_image.png',
    site_url => 'http://example.com',
    text_color => '#123456',
    background_color => '#abcdef',
);
is($site2->text_color, '#123456', 'text_color returns custom value');
is($site2->background_color, '#abcdef', 'background_color returns custom value');
isa_ok($site, 'App::LinkSite::Site', 'Created an App::LinkSite::Site object');

# Test the name method
is($site->name, 'Test Name', 'name method returns "Test Name"');

# Test the handle method
is($site->handle, 'Test Handle', 'handle method returns "Test Handle"');

# Test the image method
is($site->image, 'test_image.jpg', 'image method returns "test_image.jpg"');

# Test the desc method
is($site->desc, 'Test Description', 'desc method returns "Test Description"');

# Test the og_image method
is($site->og_image, 'test_og_image.png', 'og_image method returns "test_og_image.png"');

# Test the site_url method
is($site->site_url, 'http://example.com', 'site_url method returns "http://example.com"');

# Test sections functionality
my $link1 = App::LinkSite::Link->new(
    title => 'Link 1',
    link  => 'http://example.com/1',
);
my $link2 = App::LinkSite::Link->new(
    title => 'Link 2',
    link  => 'http://example.com/2',
);
my $link3 = App::LinkSite::Link->new(
    title => 'Link 3',
    link  => 'http://example.com/3',
);

my $section1 = App::LinkSite::Section->new(
    title => 'Section 1',
    links => [$link1, $link2],
);
my $section2 = App::LinkSite::Section->new(
    title => 'Section 2',
    links => [],
);

my $site_with_sections = App::LinkSite::Site->new(
    name     => 'Test Name',
    handle   => 'Test Handle',
    image    => 'test_image.jpg',
    desc     => 'Test Description',
    og_image => 'test_og_image.png',
    site_url => 'http://example.com',
    sections => [$section1, $section2],
    links    => [$link3],
);

ok($site_with_sections->has_sections, 'has_sections returns true when site has non-empty sections');
is(scalar @{$site_with_sections->sections}, 2, 'site has 2 sections');
my @all_links = $site_with_sections->all_links;
is(scalar @all_links, 3, 'all_links returns all links from sections and links array');

# Test site without sections
my $site_no_sections = App::LinkSite::Site->new(
    name     => 'Test Name',
    handle   => 'Test Handle',
    image    => 'test_image.jpg',
    desc     => 'Test Description',
    og_image => 'test_og_image.png',
    site_url => 'http://example.com',
    links    => [$link1, $link2],
);

ok(!$site_no_sections->has_sections, 'has_sections returns false when site has no sections');

done_testing;
