use 5.006;
use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Future::Q',
    license             => 'perl',
    dist_author         => q{Toshio Ito <toshioito@cpan.org>},
    dist_version_from   => 'lib/Future/Q.pm',
    build_requires => {
        'Test::More' => 0,
        'FindBin' => 0,
        'Carp' => 0,
        'Scalar::Util' => 0,
        'Test::MockModule' => "0.05",
        'Test::Identity' => 0,
        'Test::Memory::Cycle' => 0,
    },
    requires => {
        'perl' => 5.006,
        'Future' => '0.13',
        'Devel::GlobalDestruction' => 0,
        'Scalar::Util' => 0,
        'Carp' => 0,
        'Try::Tiny' => 0,
    },
    add_to_cleanup      => [ 'Future-Q-*' ],
    ## create_makefile_pl => 'traditional',
    no_index => {
        directory => ["t", "xt", "eg", "inc"]
    }
);

$builder->create_build_script();
