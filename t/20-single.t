use strict;
use warnings;
use Test::More;
use Future::Strict;
use Try::Tiny;
use FindBin;
use lib ("$FindBin::Bin");
use testlib::Utils qw(newf init_warn_handler test_log_num);

init_warn_handler;

note('--- OK/NG cases of single (non-chained) Futures');

my @ok_cases = (
    {label => "not-complete", code => sub { newf; }},
    {label => "done", code => sub { newf->done; }},
    {label => "canceled", code => sub { newf->cancel; }},
    {label => "immediate failure, and set on_fail", code => sub {
        my $f = newf->fail('failure');
        my $handled = 0;
        $f->on_fail(sub {
            my $e = shift;
            $handled = 1;
            is($e, 'failure', 'exception message OK');
        });
        ok($handled, 'failure handled');
    }},
    {label => "immediate failure, and set on_ready and try to get results", code => sub {
        my $f = newf->fail('failure');
        my $handled = 0;
        $f->on_ready(sub {
            my $f = shift;
            try {
                $f->get;
            }catch {
                my $e = shift;
                $handled = 1;
                like($e, qr/^failure/, 'exception message OK');
            };
            ok($handled, 'failure handled');
        });
    }},
    {label => "immediate failure, and set on_ready and check failure", code => sub {
        my $f = newf->fail('failure');
        my $handled = 0;
        $f->on_ready(sub {
            my $f = shift;
            if(my $e = $f->failure) {
                $handled = 1;
                is($e, 'failure', 'exception message OK');
            }
            ok($handled, 'failure handled.');
        });
    }},
    {label => "immediate die, and set on_fail", code => sub {
        my $f = newf->die('failure');
        my $handled = 0;
        $f->on_fail(sub {
            my $e = shift;
            $handled = 1;
            like($e, qr/^failure/, 'exception message OK');
        });
        ok($handled, "failure handled");
    }},
    {label => "immediate fail, no on_fail or on_ready but get is called.", code => sub {
        my $f = newf->fail('failure');
        my $handled = 0;
        try {
            my $result = $f->get;
        }catch {
            my $e = shift;
            $handled = 1;
            like($e, qr/^failure/, "exception message OK");
        };
        ok($handled, "failure handled");
    }},
    {label => "immediate fail, no on_fail or on_ready but failure is called.", code => sub {
        my $f = newf->fail('failure');
        my $handled = 0;
        if(my $e = $f->failure) {
            $handled = 1;
            is($e, "failure", "exception message OK");
        }
        ok($handled, "failure handled");
    }},
    {label => "async fail, and set on_fail", code => sub {
        my $f = newf;
        my $handled = 0;
        $f->on_fail(sub {
            my $e = shift;
            $handled = 1;
            is($e, 'failure', 'exception message OK');
        });
        $f->fail('failure');
        ok($handled, "failure handled");
    }},
    {label => 'async fail, and set on_ready and try to get results', code => sub {
        my $f = newf;
        my $handled = 0;
        $f->on_ready(sub {
            my $f = shift;
            try {
                $f->get;
            }catch {
                my $e = shift;
                $handled = 1;
                like($e, qr/^failure/, 'exception message OK');
            };
        });
        $f->fail('failure');
        ok($handled, "failure handled");
    }},
    {label => "async fail, and set on_ready and call failure", code => sub {
        my $f = newf;
        my $handled = 0;
        $f->on_ready(sub {
            my $f = shift;
            if(my $e = $f->failure) {
                $handled = 1;
                is($e, 'failure', "exception message OK");
            }
        });
        $f->fail('failure');
        ok($handled, "failure handled");
    }}
);

foreach my $case (@ok_cases) {
    note("--- -- try OK case $case->{label}");
    test_log_num($case->{code}, 0, "$case->{label}: it should warn nothing");
}


my @ng_cases = (
    {label => "failed", code => sub { newf->fail("failure") }},
    {label => "died", code => sub { newf->die("died") }},
    {label => "fail, set on_ready but no call to get or failure", code => sub {
        my $f = newf;
        my $executed = 0;
        $f->on_ready(sub { $executed = 1 });
        $f->fail('failure');
        ok($executed, "callback executed.");
    }},
    {label => "fail, set on_done and on_ready but not examine the failure", code => sub {
        my $f = newf;
        $f->on_done(sub {
            fail("This should not be executed");
        });
        $f->on_ready(sub { 1 });
        $f->fail('failure');
    }},
    {label => "async fail, called get and failure while not ready but no handling failures", code => sub {
        my $f = newf;
        try {
            my $result = $f->get;
            fail("This should not be executed.");
        }catch {
            pass("Result not ready");
        };
        try {
            my $e = $f->failure;
            fail('This should not be executed.');
        }catch {
            pass("Failure not ready");
        };
        $f->fail('failure');
    }},
    {label => "fail, attempt to cancel", code => sub {
        my $f = newf->fail("failure");
        $f->cancel();
    }},
    {label => "async fail, call is_ready before and after failure", code => sub {
        my $f = newf;
        ok(!$f->is_ready, "not ready OK");
        $f->fail('failure');
        ok($f->is_ready, "ready OK");
    }},
);

foreach my $case (@ng_cases) {
    note("--- -- try NG case $case->{label}");
    test_log_num($case->{code}, 1, "$case->{label}: it should warn a message");
}

done_testing();
