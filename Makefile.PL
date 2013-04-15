use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'WWW::SuperAgent',
    AUTHOR              => q{David Farrell <davidnmfarrell@gmail.com>},
    VERSION_FROM        => 'lib/WWW/SuperAgent.pm',
    ABSTRACT_FROM       => 'lib/WWW/SuperAgent.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'LWP::UserAgent' =>0,
        'Encode' => 0,
        'utf8' => 0,
        'Carp' => 0,
        'URI' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'WWW-SuperAgent-*' },
);
