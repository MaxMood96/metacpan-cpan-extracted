use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => "CleanPaste::Normalizer",
    VERSION_FROM => "lib/CleanPaste/Normalizer.pm",
    ABSTRACT     => "Local pasted-text normalization helper",
    LICENSE      => "mit",
    AUTHOR       => "CleanPaste AI",
    META_MERGE   => {
        "resources" => {
            "homepage" => "https://cleanpasteai.com/",
            "repository" => "https://cleanpasteai.com/",
            "bugtracker" => { "web" => "https://cleanpasteai.com/" }
        }
    }
);
