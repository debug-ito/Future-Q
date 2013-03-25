use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Future::Strict',
    AUTHOR              => q{Toshio Ito <toshioito@cpan.org>},
    VERSION_FROM        => 'lib/Future/Strict.pm',
    ABSTRACT_FROM       => 'lib/Future/Strict.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Future' => '0.11',
        'Devel::GlobalDestruction' => 0,
        'Scalar::Util' => 0,
        'Carp' => 0,
        'Try::Tiny' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
        'FindBin' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Future-Strict-*' },
);
