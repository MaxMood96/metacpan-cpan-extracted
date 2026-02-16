#!/usr/bin/perl

use 5.36.0;

use File::Slurper 'read_text';

use Text::Balanced qw/extract_tagged gen_extract_tagged/;

# -----------------

my($in_file_name) 			= './data/TextAnalysisAndFormatting.txt'; # A topic in Perl.Wiki containing '...<pre>...</pre>...'.
my($text)					= read_text($in_file_name);
my($open_tag)				= '<pre>';
my($close_tag)				= '</pre>';
my($matcher)				= gen_extract_tagged($open_tag, $close_tag);
my($extracted, $remainder)	= $matcher -> ($text);

say "Tags: $open_tag. $close_tag";

print 'Using gen_extract_tagged(). ';
say $extracted ? "Extracted: $extracted." : "No tags found";

($extracted, $remainder)	= extract_tagged($text, $open_tag, $close_tag, '/.*/', undef);

print 'Using extract_tagged(). ';
say $extracted ? "Extracted: $extracted." : 'No tags found';

$text			=~ /(.*?)$open_tag(.*)$close_tag(.*)/s;
my($prefix)		= $1 || '';
my($match)		= $2 || '';
my($suffix)		= $3 || '';
my(@lines)		= split(/\n/, $match);
my($line_count)	= $#lines + 1;

print 'Using regexp. ';

if ($match)
{
	say "Extracted. Line count: $line_count";
	#say "prefix: \n", '-' x 20, "\n", $prefix, "\n", , '=' x 20;
	say "infix: \n", '-' x 20, join("\n", @lines), "\n", , '=' x 20;
	#say "suffix: \n", '-' x 20, "\n", $suffix, "\n", , '=' x 20;
}
else
{
	say 'No <pre>...</pre> tags found';
}
