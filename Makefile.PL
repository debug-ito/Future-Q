use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Future::Q',
    AUTHOR              => q{Toshio Ito <toshioito@cpan.org>},
    VERSION_FROM        => 'lib/Future/Q.pm',
    ABSTRACT_FROM       => 'lib/Future/Q.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Future' => '0.13',
        'Devel::GlobalDestruction' => 0,
        'Scalar::Util' => 0,
        'Carp' => 0,
        'Try::Tiny' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
        'FindBin' => 0,
        'Carp' => 0,
        'Scalar::Util' => 0,
        'Test::MockModule' => "0.05",
        'Test::Identity' => 0,
        'Test::Memory::Cycle' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Future-Q-*' },
);
