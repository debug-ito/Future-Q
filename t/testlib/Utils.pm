package testlib::Utils;
use strict;
use warnings;
use Exporter qw(import);
use Future::Q;
use Test::Builder;
use Test::More;

our @EXPORT_OK = qw(newf init_warn_handler test_log_num filter_callbacks);

my @logs = ();

sub newf {
    return Future::Q->new;
}

sub init_warn_handler {
    delete $ENV{PERL_FUTURE_DEBUG};
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

sub filter_callbacks {
    my ($case_arg, $on_done, $on_fail) = @_;
    my %switch = (
        on_done => sub { ($on_done) },
        on_fail => sub { (undef, $on_fail) },
        both    => sub { ($on_done, $on_fail) },
    );
    return $switch{$case_arg}->();
}


1;
