package testlib::Utils;
use strict;
use warnings;
use Exporter qw(import);
use Future::Strict;
use Test::Builder;
use Test::More;

our @EXPORT_OK = qw(newf init_warn_handler test_log_num);

my @logs = ();

sub newf {
    return Future::Strict->new;
}

sub init_warn_handler {
    $SIG{__WARN__} = sub {
        push(@logs, shift);
    };
}

sub test_log_num {
    my ($testee_code, $exp_log_num, $msg) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    @logs = ();
    $testee_code->();
    is(int(@logs), $exp_log_num, $msg) or diag(explain @logs);
}

1;