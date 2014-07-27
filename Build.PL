use 5.006;
use strict;
use warnings;
use Module::Build::Pluggable (
    'CPANfile'
);
 
my $builder = Module::Build::Pluggable->new(
    module_name         => 'Future::Q',
    license             => 'perl',
    dist_author         => q{Toshio Ito <toshioito@cpan.org>},
    dist_version_from   => 'lib/Future/Q.pm',
    release_status      => 'stable',
    add_to_cleanup     => [ 'Future-Q-*' ],
    recursive_test_files => 1,
    no_index => {
        directory => ["t", "xt", "eg", "inc"],
        file => ['README.pod'],
    },
    meta_add => {
        'meta-spec' => {
            version => 2,
            url => 'https://metacpan.org/pod/CPAN::Meta::Spec',
        },
        resources => {
            bugtracker => {
                web => 'https://github.com/debug-ito/Future-Q/issues',
            },
            repository => {
                url => 'git://github.com/debug-ito/Future-Q.git',
                web => 'https://github.com/debug-ito/Future-Q',
            },
        }
    }
);
 
$builder->create_build_script();
