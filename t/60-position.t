use strict;
use warnings;
use Test::More;
use Future::Strict;
use FindBin;
use lib ("$FindBin::Bin");
use testlib::Utils qw(newf init_warn_handler test_log_num);
use Carp;

init_warn_handler;

sub create_future {
    return Future::Strict->new;
}

sub fail_future {
    return create_future()->fail("failure");
}

sub discard_failed_future {
    my $f = fail_future();
}

$Carp::Verbose = 0;

{
    my @logs = ();
    local $SIG{__WARN__} = sub {
        push(@logs, shift);
    };
    discard_failed_future;
    is(int(@logs), 1, "1 warning");
    note(explain @logs);
    ok($logs[0] =~ qr/constructed at .* line (\d+).*lost at .* line (\d+)/s, "log format OK");
    my ($line_construct, $line_lost) = ($1, $2);
    my $exp_lost = 31;
    is($line_construct, 13, "constructed at line 13");
    cmp_ok($line_lost, ">=", $exp_lost - 1, "lost around $exp_lost");
    cmp_ok($line_lost, "<=", $exp_lost + 1, "lost around $exp_lost");

    {
        local $Carp::Verbose = 1;
        @logs = ();
        discard_failed_future;
        is(int(@logs), 1, "1 warning");
        note(explain @logs);
        my $line_occurrence = 0;
        while($logs[0] =~ /line/g) {
            $line_occurrence++;
        }
        cmp_ok($line_occurrence, ">", 2, "verbose 'line's");
    }
}



sub create_subfuture {
    my $msg = shift;
    return Future::Strict->new->fail($msg);
}

sub call_wait_any {
    return Future::Strict->wait_any(
        map { create_subfuture($_) } qw(one two three)
    );
}

sub discard_dependent_future {
    my $df = call_wait_any;
    undef $df;
    1;
}

{
    my @logs = ();
    local $SIG{__WARN__} = sub {
        push(@logs, shift);
    };
    discard_dependent_future;

    my $exp_cons_dependent = 64;
    my $exp_cons_sub = 59;
    my $exp_lost = 70;
    is(int(@logs), 4, "4 warnings");
    note(explain @logs);
    ok($logs[0] =~ /constructed at.* line (\d+).*lost at.* line (\d+)/s, "log format OK");
    my ($got_cons_dependent, $got_lost) = ($1, $2);
    is($got_cons_dependent, $exp_cons_dependent, "constructed_at for dependent future OK");
    cmp_ok($got_lost, ">=", $exp_lost - 1, "lost_at for dependent future OK");
    cmp_ok($got_lost, "<=", $exp_lost + 1, "lost_at for dependent future OK");
    shift @logs;
    foreach my $i (0 .. $#logs) {
        my $log = $logs[$i];
        ok($log =~ /constructed at.* line (\d+)/, "log format for subfuture $i OK") or diag("got: $log");
        my ($got_cons_sub) = ($1);
        is($got_cons_sub, $exp_cons_sub, "constructed_at for subfuture $i OK");
    }
}

done_testing();

