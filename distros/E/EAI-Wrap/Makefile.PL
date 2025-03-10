use strict;
require 5.006;

use ExtUtils::MakeMaker;

WriteMakefile(
	NAME          => 'EAI::Wrap',
	AUTHOR        => 'Roland Kapl',
	LICENSE       => 'MIT',
	ABSTRACT_FROM => 'lib/EAI/Wrap.pm',
	VERSION_FROM  => 'lib/EAI/Wrap.pm',
	MIN_PERL_VERSION => 5.006,
	PREREQ_PM     => {
		'Archive::Extract' => 0,
		'Data::XLSX::Parser' => 0.20,
		'DBD::ODBC' => 0,
		'DBI' => 0,
		'Excel::Writer::XLSX' => 0,
		'Log::Dispatch::Email::MIMELite' => 0,
		'Log::Log4perl' => 0,
		'Net::FTP' => 0,
		'Net::SFTP::Foreign' => 0,
		'MIME::Lite' => 0,
		'HTML::HTML5::Entities' => 0,
		'Spreadsheet::WriteExcel' => 0,
		'Spreadsheet::ParseExcel' => 0,
		'Text::CSV' => 0,
		'Text::Glob' => 0,
		'Time::Local' => 1.27,
		'XML::LibXML' => 0,
		'XML::LibXML::Debugging' => 0
	},
	TEST_REQUIRES => {
		'Test::More' => 0,
		'Test::File' => 0,
		'Test::Timer' => 0,
		'Archive::Zip' => 0,
		'Time::Piece' => 0,
	},
	META_MERGE => {
		"meta-spec" => { version => 2 },
		provides => {
			'EAI::Wrap' => {file => 'lib/EAI/Wrap.pm', version => 1.919},
			'EAI::Common' => {file => 'lib/EAI/Common.pm', version => 1.919},
			'EAI::FTP' => {file => 'lib/EAI/FTP.pm', version => 1.919},
			'EAI::File' => {file => 'lib/EAI/File.pm', version => 1.919},
			'EAI::DB' => {file => 'lib/EAI/DB.pm', version => 1.919},
			'EAI::DateUtil' => {file => 'lib/EAI/DateUtil.pm', version => 1.919},
		},
		resources => {
			repository => {
				type => 'git',
				url  => 'https://github.com/rkapl123/EAI-Wrap.git',
				web  => 'https://github.com/rkapl123/EAI-Wrap',
			},
			bugtracker => {
				web => 'https://github.com/rkapl123/EAI-Wrap/issues',
			},
		},
		prereqs => {
			runtime => {
				recommends => {
					'Win32::Console::ANSI' => 0,
					'Text::CSV_XS' => 0,
				},
			},
		},
	},
	PL_FILES => {},    # To ignore Build.PL.
);