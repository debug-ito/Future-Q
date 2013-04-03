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
    ### Case element: arguments for then()
    my @cases_args = qw(on_done on_fail both);

    ### Case element: state of invocant object
    my @cases_invocant =
        qw(pending_done pending_fail pending_cancel
           immediate_done immediate_fail immediate_cancel);

    ### Case element: return value from the callback
    my @cases_return =
        qw(normal die pending_done pending_fail pending_cancel
           immediate_done immediate_fail immediate_cancel);
    
    foreach my $arg (@cases_args) {
        foreach my $invo (@cases_invocant) {
            foreach my $ret (@cases_return) {
                $tested_case{"$arg,$invo,$ret"} = 0;
            }
        }
    }
}

sub test_then_case {
    my ($case_arg, $case_invo, $case_ret, $num_warning, $code) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    note("--- Case: $case_arg, $case_invo, $case_ret");
    test_log_num $code, $num_warning, "expected $num_warning warnings";
    $tested_case{"$case_arg,$case_invo,$case_ret"} = 1;
}

sub create_return {
    my ($case_ret, @values) = @_;
    my %switch = (
        normal => sub { @values },
        die => sub { die $values[0] },
        pending_done => sub { newf },
        pending_fail => sub { newf },
        pending_cancel => sub { newf },
        immediate_done => sub { newf->fulfill(@values) },
        immediate_fail => sub { newf->reject(@values) },
        immediate_cancel => sub { newf->cancel() },
    );
    return $switch{$case_ret}->();
}

sub filter_callbacks {
    my ($case_arg, $on_done, $on_fail) = @_;
    return $case_arg eq "on_done" ? ($on_done) :
           $case_arg eq "on_fail" ? ($on_fail) :
                                    ($on_done, $on_fail);
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

foreach my $case_arg ("on_done", "both") {
    foreach my $case_ret ("normal", "immediate_done") {
        test_then_case $case_arg, "pending_done", $case_ret, 0, sub {
            my $f = newf;
            my $executed = 0;
            my $fail_executed = 0;
            my $nf = $f->then(filter_callbacks $case_arg, sub {
                is_deeply(\@_, [1,2,3], "arg OK");
                $executed = 1;
                return create_return($case_ret, qw(a b c));
            }, sub {
                $fail_executed = 1;
            });
            ok($f->is_pending, "f is pending");
            ok($nf->is_pending, "nf is pending");
            $f->fulfill(1,2,3);
            ok($f->is_fulfilled, "f is fulfilled");
            ok($nf->is_fulfilled, "nf is fulfilled");
            is_deeply([$nf->get()], [qw(a b c)], "nf result OK");
            ok($executed, "callback executed");
            ok(!$fail_executed, "on_fail callback not executed");
        };
        test_then_case $case_arg, "immediate_done", $case_ret, 0, sub {
            my $f = newf->fulfill(1,2,3);
            my $executed = 0;
            my $fail_executed = 0;
            my $nf = $f->then(filter_callbacks $case_arg, sub {
                is_deeply(\@_, [1,2,3], "arg OK");
                $executed = 1;
                return create_return($case_ret, qw(a b c));
            }, sub { $fail_executed = 1 });
            ok($nf->is_fulfilled, "nf is fulfilled");
            is_deeply([$nf->get], [qw(a b c)], "nf resutl OK");
            ok($executed, "callback executed");
            ok(!$fail_executed, "fail callback not executed");
        };
    }
}



note("--- check if untested cases exist.");
foreach my $key (keys %tested_case) {
    ok($tested_case{$key}, "Case $key is tested.");
}

done_testing();


