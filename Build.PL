use 5.006;
use strict;
use warnings;
use Module::Build;
use Module::Build::Pluggable (
    'CPANfile'
);

my $builder = Module::Build::Pluggable->new(
    module_name         => 'Future::Q',
    license             => 'perl',
    dist_author         => q{Toshio Ito <toshioito@cpan.org>},
    dist_version_from   => 'lib/Future/Q.pm',
    add_to_cleanup      => [ 'Future-Q-*' ],
    ## create_makefile_pl => 'traditional',
    no_index => {
        directory => ["t", "xt", "eg", "inc"]
    },
    meta_add => {
        resources => {
            repository => "git://github.com/debug-ito/Future-Q.git",
            bugtracker => "https://github.com/debug-ito/Future-Q/issues",
        }
    }
);

$builder->create_build_script();
