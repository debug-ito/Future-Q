use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::RealBin";
use testlib::Utils qw(newf init_warn_handler test_log_num);

init_warn_handler();

### テストの方針
### 
### - コールバック引数:
### 
###   - fulfilledのみ
###   - rejectedのみ
###   - 両方
### 
### - invocantの状態:
### 
###   - not ready -> done
###   - not ready -> fail
###   - not ready -> cancel
###   - done
###   - failed
###   - cancelled
### 
### - コールバック戻り値
### 
###   - normal return
###   - die
###   - not ready -> done
###   - not ready -> fail
###   - not ready -> cancel
###   - done
###   - failed
###   - cancelled
### 
### パターン数: 3 * 6 * 8 = 144
### 
### - not ready(pending)とimmediateでは同じ挙動を返さないといけないはずなので、テストを一本化できるはず。
### - 結果の検証のパターンは？pending futureの絡むケースがやりづらい
### - コールバック戻り値がfailするケースは警告出すことも検証
### - つか、strict featureについてはthen()さえ検証できれば20-singleと30-chainedは要らない気がしてきた。
###   それはFuture::Qの推奨する使い方じゃない。
### - Future::Qの推奨する使い方は、then()とon_cancel()のみ。20-singleに関してはthen()を呼ばないケースのみ検証すればいい。
### - then()はvoid contextでも呼べることもテスト
### - あと、コールバック戻り値で際どいケース(空returnとかFutureとその他の値のリストとか)もテスト

=pod

うーん、1個ずつ書いていってもいいけどさすがにもう少し効率化したい。
例えば、

コールバック戻り値の
  (normal return, done), (die, failed)は同じ結果を返すべき


=cut

test_log_num sub {
    note("--- on_fulfilled, invocant pending -> done, normal return");
    my $f = newf;
    my $executed = 0;
    my $nf = $f->then(sub {
        is_deeply(\@_, [1,2,3], "arg OK");
        $executed = 1;
        return qw(a b c);
    });
    ok($f->is_pending, "f is pending");
    ok($nf->is_pending, "nf is pending");
    $f->fulfill(1,2,3);
    ok($f->is_fulfilled, "f is fulfilled");
    ok($nf->is_fulfilled, "nf is fulfilled");
    ok($executed, "callback executed");
}, 0, "no warning";

test_log_num sub {
    note("--- on_fufilled, ")
}


done_testing();


