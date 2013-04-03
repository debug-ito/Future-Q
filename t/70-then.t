use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::RealBin";
use testlib::Utils qw(newf init_warn_handler test_log_num);
use Test::Builder;

init_warn_handler();

my %tested_case = ();
{
    ### Case element: state of invocant object
    my @cases_invocant =
        qw(pending_done pending_fail pending_cancel
           immediate_done immediate_fail immediate_cancel);

    ### Case element: arguments for then()
    my @cases_args = qw(on_done on_fail both);

    ### Case element: return value from the callback
    my @cases_return =
        qw(normal die pending_done pending_fail pending_cancel
           immediate_done immediate_fail immediate_cancel);
    
    foreach my $invo (@cases_invocant) {
        foreach my $arg (@cases_args) {
            foreach my $ret (@cases_return) {
                $tested_case{"$invo,$arg,$ret"} = 0;
            }
        }
    }
}

sub test_then_case {
    my ($case_invo, $case_arg, $case_ret, $num_warning, $code) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    note("--- Case: $case_invo, $case_arg, $case_ret");
    test_log_num $code, $num_warning, "expected $num_warning warnings";
    $tested_case{"$case_invo,$case_arg,$case_ret"}++;
}

sub create_return {
    my ($case_ret, @values) = @_;
    my %switch = (
        normal => sub { @values },
        die => sub { die $values[0] },
        pending_done => sub { newf },
        pending_fail => sub { newf },
        pending_cancel => sub { newf },
        immediate_done => sub { newf()->fulfill(@values) },
        immediate_fail => sub { newf()->reject(@values) },
        immediate_cancel => sub { newf()->cancel() },
    );
    return $switch{$case_ret}->();
}

sub filter_callbacks {
    my ($case_arg, $on_done, $on_fail) = @_;
    return $case_arg eq "on_done" ? ($on_done) :
           $case_arg eq "on_fail" ? (undef, $on_fail) :
                                    ($on_done, $on_fail);
}

sub is_immediate {
    my ($case_string) = @_;
    return ($case_string =~ /^immediate/);
}

### - not ready(pending)とimmediateでは同じ挙動を返さないといけないはずなので、テストを一本化できるはず。
### - 結果の検証のパターンは？pending futureの絡むケースがやりづらい
### - コールバック戻り値がfailするケースは警告出すことも検証
### - つか、strict featureについてはthen()さえ検証できれば20-singleと30-chainedは要らない気がしてきた。
###   それはFuture::Qの推奨する使い方じゃない。
### - Future::Qの推奨する使い方は、then()とon_cancel()のみ。20-singleに関してはthen()を呼ばないケースのみ検証すればいい。
### - repeatはもうサポートしなくていいと思う
### - then()はvoid contextでも呼べることもテスト
### - あと、コールバック戻り値で際どいケース(空returnとかFutureとその他の値のリストとか)もテスト


foreach my $case_invo (qw(pending_done immediate_done)) {
    foreach my $case_arg ("on_done", "both") {
        foreach my $case_ret ("normal", "immediate_done") {
            test_then_case $case_invo, $case_arg, $case_ret, 0, sub {
                my $f = is_immediate($case_invo) ? newf()->fulfill(1,2,3) : newf;
                my $done_executed = 0;
                my $fail_executed = 0;
                my $nf = $f->then(filter_callbacks $case_arg, sub {
                    is_deeply(\@_, [1,2,3], "arg OK");
                    $done_executed = 1;
                    return create_return($case_ret, qw(a b c));
                }, sub {
                    $fail_executed = 1;
                });
                if(not is_immediate($case_invo)) {
                    ok(!$done_executed, "done callback not executed");
                    ok($f->is_pending, "f is pending");
                    ok($nf->is_pending, "nf is pending");
                    $f->fulfill(1,2,3);    
                }
                ok($f->is_fulfilled, "f is fulfilled");
                ok($nf->is_fulfilled, "nf is fulfilled");
                is_deeply([$nf->get()], [qw(a b c)], "nf result OK");
                ok($done_executed, "callback executed");
                ok(!$fail_executed, "on_fail callback not executed");
            };  
        }
        foreach my $case_ret (qw(die immediate_fail)) {
            test_then_case $case_invo, $case_arg, $case_ret, 1, sub {
                my $f = is_immeidate($case_invo) ? newf()->fulfill(1,2,3) : newf;
                my $fail_executed = 0;
                my $done_executed = 0;
                my $nf = $f->then(filter_callbacks $case_arg, sub {
                    is_deeply(\@_, [1, 2, 3], "then args OK");
                    $done_executed = 1;
                    return create_return($case_ret, qw(a b c));
                }, sub { $fail_executed = 1 });
                if(not is_immediate($case_invo)) {
                    ok(!$done_executed, "done callback not executed");
                    ok($f->is_pending, "f is pending");
                    ok($nf->is_pending, "nf is pending");
                    $f->fulfill(1, 2, 3);    
                }
                ok($done_executed, "done executed");
                ok(!$fail_executed, "fail not executed");
                ok($f->is_fulfilled, "f is fulfilled");
                ok($nf->is_rejected, "nf is rejected");
                is_deeply([$nf->failure], $case_ret eq "die" ? ["a"] : [qw(a b c)], "nf failure OK");
            };
        }
        test_then_case $case_invo, $case_arg, "pending_done", 0, sub {
            my $f = is_immediate($case_invo) ? newf()->fulfill(1,2,3) : newf;
            my $cf = newf;
            my $done_executed = 0;
            my $fail_executed = 0;
            my $nf = $f->then(filter_callbacks $case_arg, sub {
                is_deeply(\@_, [1, 2, 3], "then args OK");
                $done_executed = 1;
                return $cf;
            }, sub { $fail_executed = 1 });
            if(not is_immediate($case_invo)) {
                ok(!$done_executed, "done callback not executed");
                ok($f->is_pending, "f is pending");
                ok($nf->is_pending, "nf is pending");
                $f->fulfill(1, 2, 3);
            }
            ok($f->is_fulfilled, "f is fulfilled");
            ok($cf->is_pending, "cf is pending");
            ok($nf->is_pending, "nf is still pending");
            ok($done_executed, "done callback executed");
            ok(!$fail_executed, "fail callback not executed");
            $cf->fulfill(qw(a b c));
            ok($cf->is_fulfilled, "cf is fulfilled");
            ok($nf->is_fulfilled, "nf is fulfilled");
            is_deeply([$nf->get], [qw(a b c)], "nf result OK");
        };
        test_then_case $case_invo, $case_arg, "pending_fail", 1, sub {
            my $f = is_immediate($case_invo) ? newf()->fulfill(1,2,3) : newf;
            my $done_executed = 0;
            my $fail_executed = 0;
            my $cf = newf;
            my $nf = $f->then(filter_callbacks $case_arg, sub {
                is_deeply(\@_, [1, 2, 3], "then args OK");
                $done_executed = 1;
                return $cf;
            }, sub { $fail_executed = 1 });
            if(not is_immediate($case_invo)) {
                ok(!$done_executed, "done callback not yet executed");
                ok($f->is_pending, "f is pending");
                ok($nf->is_pending, "nf is pending");
                $f->fulfill(1, 2, 3);    
            }
            ok($done_executed, "done callback executed");
            ok(!$fail_executed, "fail callback not executed");
            ok($f->is_fulfilled, "f is fulfilled");
            ok($nf->is_pending, "nf is still pending");
            $cf->reject(qw(a b c));
            ok($nf->is_rejected, "nf is rejected");
            is_deeply([$nf->failure], [qw(a b c)], "nf failure OK");
        };
        test_then_case $case_invo, $case_arg, "immediate_cancel", 0, sub {
            my $f = is_immediate($case_invo) ? newf()->fulfill(1,2,3) : newf;
            my $done_executed = 0;
            my $fail_executed = 0;
            my $nf = $f->then(filter_callbacks $case_arg, sub {
                is_deeply(\@_, [1,2,3], "then args OK");
                $done_executed = 1;
                return newf()->cancel();
            }, sub { $fail_executed = 1 });
            if(not is_immediate($case_invo)) {
                ok(!$done_executed, "done callback not executed");
                ok($nf->is_pending, "nf is pending");
                $f->fulfill(1,2,3);
            }
            ok($f->is_fulfilled, "f is fulfilled");
            ok($done_executed, "done callback executed");
            ok(!$fail_executed, "fail callback not executed");
            ok(!$nf->is_pending, "nf is not pending");
            ok($nf->is_cancelled, "nf is cancelled");
        };
        test_then_case $case_invo, $case_arg, "pending_cancel", 0, sub {
            my $f = is_immediate($case_invo) ? newf()->fulfill(1,2,3) : newf;
            my $done_executed = 0;
            my $fail_executed = 0;
            my $cf = newf;
            my $nf = $f->then(filter_callbacks $case_arg, sub {
                is_deeply(\@_, [1,2,3], "then args OK");
                $done_executed = 1;
                return $cf;
            }, sub { $fail_executed = 1 });
            if(not is_immediate($case_invo)) {
                ok(!$done_executed, "done callback not called yet");
                ok($nf->is_pending, "nf is pending");
                $f->fulfill(1,2,3);
            }
            ok($f->is_fulfilled, "f is fulfilled");
            ok($done_executed, "done callback is called");
            ok(!$fail_executed, "fail callback is not called");
            ok($nf->is_pending, "nf is still pending");
            $cf->cancel();
            ok(!$nf->is_pending, "nf is not pending");
            ok($nf->is_cancelled, "nf is cancelled");
        };
    }
}


foreach my $case_invo (qw(pending_fail immediate_fail)) {
    foreach my $case_arg ("on_fail", "both") {
        ## TODO
    }
}



note("--- check if untested cases exist.");
foreach my $key (sort {$a cmp $b} keys %tested_case) {
    is($tested_case{$key}, 1, "Case $key is tested once.");
}

done_testing();


