use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::RealBin";
use testlib::Utils qw(newf filter_callbacks);
use Future::Q;

note("------ tests to cancel next_future of then");

{
    note("--- Case: pending invocant future");
    my $f = newf;
    my $nf = $f->then(sub {
        fail("this should not be executed.");
    }, sub {
        fail("this should not be executed.");
    });
    ok($f->is_pending, "f is pending");
    ok($nf->is_pending, "nf is pending");
    $nf->cancel();
    ok($nf->is_cancelled, "nf is cancelled");
    ok($f->is_cancelled, "If invocant future (f) is still pending, f is cancelled when nf is cancelled.");
}

foreach my $case (
    {invo => newf()->fulfill(1), arg => "on_done"},
    {invo => newf()->fulfill(2), arg => "both"},
    {invo => newf()->reject(3), arg => "on_fail"},
    {invo => newf()->reject(4), arg => "both"},
){
    my $case_str = ($case->{invo}->is_fulfilled ? "immediate_done" : "immediate_fail") . ",$case->{arg}";
    note("--- Case: $case_str -> pending returned future");
    my $rf = newf;
    my $callbacked = 0;
    my $nf = $case->{invo}->then(filter_callbacks $case->{arg}, sub {
        $callbacked++;
        return $rf;
    }, sub {
        $callbacked++;
        return $rf;
    });
    is($callbacked, 1, "callback executed once");
    ok($nf->is_pending, "nf is pending");
    ok($rf->is_pending, "rf is pending");
    $nf->cancel();
    ok($rf->is_cancelled, "If returned future (rf) is pending, rf is cancelled when nf is cancelled.");
}


done_testing();


