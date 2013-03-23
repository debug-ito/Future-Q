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
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Future-Strict-*' },
);
