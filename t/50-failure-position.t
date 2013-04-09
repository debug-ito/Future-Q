use strict;
use warnings;
use Test::More;
use FindBin;
use lib ($FindBin::RealBin);
use testlib::Utils qw(newf);
use Test::Builder;

sub test_error_here {
    my ($f, $msg) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $executed = 0;
    $f->catch(sub {
        my $e = shift;
        like($e, qr{at .*failure-position\.t +line}, $msg);
        note($e);
        $executed = 1;
    });
    ok($executed, "catcher callback executed");
}

note("------ failure should be reported from the user's perspective.");

{
    note("--- die() method");
    my $f = newf()->die("died here");
    test_error_here($f, "die() method reports the error here");
}

{
    note("--- die() method on return future");
    my $f = newf()->fulfill()->then(sub {
        return newf()->die("died here");
    });
    test_error_here($f, "die() method on return future reports the error here");
}

{
    note("--- throw in then() callback");
    my $f = newf()->fulfill()->then(sub {
        die "died here";
    });
    test_error_here($f, "throwing an exception in then() callback reports the error here");
}

{
    note("--- return died future in try()");
    my $f = Future::Q->try(sub {
        return newf()->die("died here");
    });
    test_error_here($f, "died future returned in try() callback reportes the error here");
}

{
    note("--- throw in try()");
    my $f = Future::Q->try(sub {
        die "died here";
    });
    test_error_here($f, "throwing an excetpion in try() callback reports the error here");
}

{
    note("--- try() with junk");
    my $f = Future::Q->try();
    test_error_here($f, "try() with junk reports the error here");
}

done_testing();

