use ExtUtils::MakeMaker;

WriteMakefile (
  NAME            => 'App::digitdemog' ,
  VERSION_FROM    => 'digitdemog.pm' , 
  EXE_FILES => [ 'digitdemog' ] ,
  AUTHOR => 'Toshiyuki SHIMONO (bin4tsv at gmail.com)' , 
  LICENSE => 'perl_5' 
) ;
 
