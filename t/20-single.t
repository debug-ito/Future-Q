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

my @cases = (
    ## ** OK cases
    {label => "not-complete", warn_num => 0, code => sub { newf; }},
    {label => "done", warn_num => 0, code => sub { newf->done; }},
    {label => "canceled", warn_num => 0, code => sub { newf->cancel; }},
    {label => "immediate failure, and set on_fail", warn_num => 0, code => sub {
        my $f = newf->fail('failure');
        my $handled = 0;
        $f->on_fail(sub {
            my $e = shift;
            $handled = 1;
            is($e, 'failure', 'exception message OK');
        });
        ok($handled, 'failure handled');
    }},
    {label => "immediate failure, and set on_ready and try to get results", warn_num => 0, code => sub {
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
    {label => "immediate failure, and set on_ready and check failure", warn_num => 0, code => sub {
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
    {label => "immediate die, and set on_fail", warn_num => 0, code => sub {
        my $f = newf->die('failure');
        my $handled = 0;
        $f->on_fail(sub {
            my $e = shift;
            $handled = 1;
            like($e, qr/^failure/, 'exception message OK');
        });
        ok($handled, "failure handled");
    }},
    {label => "async fail, and set on_fail", warn_num => 0, code => sub {
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
    {label => 'async fail, and set on_ready and try to get results', warn_num => 0, code => sub {
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
    {label => "async fail, and set on_ready and call failure", warn_num => 0, code => sub {
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
    }},
    {label => "async fail, set on_ready but no call to get or failure. This does not warn, so beware.", warn_num => 0, code => sub {
        my $f = newf;
        my $executed = 0;
        $f->on_ready(sub { $executed = 1 });
        $f->fail('failure');
        ok($executed, "callback executed.");
    }},
    {label => "async fail, set on_done and on_ready but not examine the failure. This does not warn, so beware.", warn_num => 0, code => sub {
        my $f = newf;
        $f->on_done(sub {
            fail("This should not be executed");
        });
        $f->on_ready(sub { 1 });
        $f->fail('failure');
    }},


    ####### ** NG cases

    
    {label => "failed", warn_num => 1, code => sub { newf->fail("failure") }},
    {label => "died", warn_num => 1, code => sub { newf->die("died") }},
    {label => "immediate fail, only on_done is called", warn_num => 1, code => sub {
        my $f = newf->fail("failure");
        $f->on_done(sub {
            fail("This should not be executed.");
        });
    }},
    {label => "async fail, only on_done is called", warn_num => 1, code => sub {
        my $f = newf;
        $f->on_done(sub {
            fail("This should not be executed.");
        });
        $f->fail("failure");
    }},
    {label => "immediate fail, get is called but no on_fail or on_ready", warn_num => 1, code => sub {
        my $f = newf->fail('failure');
        my $handled = 0;
        try {
            my $result = $f->get;
        }catch {
            my $e = shift;
            $handled = 1;
            like($e, qr/^failure/, "exception message OK");
        };
        ok($handled, "failure handled, actually");
    }},
    {label => "immediate fail, failure is called but no on_fail or on_ready", warn_num => 1, code => sub {
        my $f = newf->fail('failure');
        my $handled = 0;
        if(my $e = $f->failure) {
            $handled = 1;
            is($e, "failure", "exception message OK");
        }
        ok($handled, "failure handled, actually");
    }},
    {label => "async fail, called get and failure while not ready but no handling failures", warn_num => 1, code => sub {
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
    {label => "fail, attempt to cancel", warn_num => 1, code => sub {
        my $f = newf->fail("failure");
        $f->cancel();
    }},
    {label => "async fail, call is_ready before and after failure", warn_num => 1, code => sub {
        my $f = newf;
        ok(!$f->is_ready, "not ready OK");
        $f->fail('failure');
        ok($f->is_ready, "ready OK");
    }},
);

foreach my $case (@cases) {
    note("--- -- try $case->{label}: expecting $case->{warn_num} warning");
    test_log_num($case->{code}, $case->{warn_num}, "$case->{label}: it should emit $case->{warn_num} warning");
}


done_testing();
