use strict;
use warnings;
use Test::More;
use Future::Strict;
use Try::Tiny;
use FindBin;
use lib ("$FindBin::Bin");
use testlib::Utils qw(newf init_warn_handler test_log_num);

init_warn_handler;

note("--- Futures chained by followed_by() etc. methods.");

my @cases = (
    {label => "fail, and_then, not handled", warn_num => 1, code => sub {
        my $f = newf;
        $f->and_then(sub {
            fail('This should not be executed.');
            return newf->done();
        });
        $f->fail('failure');
    }},
    {label => "fail, and_then, handled", warn_num => 0, code => sub {
        my $f = newf;
        my $g = $f->and_then(sub {
            fail('This should not executed.');
            return newf->done();
        });
        $f->fail('failure');
        my $handled = 0;
        $g->on_fail(sub {
            my $e = shift;
            $handled = 1;
            is($e, "failure", "exception message OK");
        });
        ok($handled, "failure handled");
    }},
    {label => "done, and_then fail, not handled", warn_num => 1, code => sub {
        my $f = newf;
        my $executed = 0;
        $f->and_then(sub {
            $executed = 1;
            return newf->fail('failure');
        });
        $f->done();
        ok($executed, "and_then callback executed OK");
    }},
    {label => "done, and_then fail, handled", warn_num => 0, code => sub {
        my $f = newf;
        $f->done();
        my $executed = 0;
        my $handled = 0;
        $f->and_then(sub {
            $executed = 1;
            return newf->fail('failure');
        })->on_ready(sub {
            my $g = shift;
            $handled = 1;
            is($g->failure, 'failure', "failure message OK");
        });
        ok($executed, "and_then callback executed OK");
        ok($handled, "failure handled OK");
    }},
    {label => "done, and_then dies, not handled", warn_num => 1, code => sub {
        my $f = newf;
        $f->and_then(sub {
            die "failure";
        });
        $f->done();
    }},
    {label => "done, and_then dies, handled", warn_num => 0, code => sub {
        my $f = newf;
        my $g = $f->and_then(sub {
            die "failure";
        });
        $f->done();
        like($g->failure, qr/^failure/, "failure detected and handled.");
    }},
    {label => "fail, or_else handled, done", warn_num => 0, code => sub {
        my $f = newf;
        my $handled = 0;
        $f->or_else(sub {
            my $g = shift;
            is($g->failure, "failure", "failure message OK");
            $handled = 1;
            return newf->done;
        });
        $f->fail("failure");
        ok($handled, "failure handled.");
    }},
    {label => "fail, or_else not handled, done", warn_num => 1, code => sub {
        my $f = newf;
        $f->fail("failure");
        my $executed = 0;
        $f->or_else(sub {
            my $g = shift;
            $executed = 1;
            return newf->done;
        });
        ok($executed, "or_else callback executed.");
    }}
);

foreach my $case (@cases) {
    note("--- -- Try: $case->{label}");
    test_log_num($case->{code}, $case->{warn_num}, "$case->{label}: expected $case->{warn_num} warnings");
}

fail("todo: or_else callback returning the original Future.");
fail("todo: fail in the callback by exception.");

done_testing();
