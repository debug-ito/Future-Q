use strict;
use warnings;
use Test::More;
use Future::Strict;
use Try::Tiny;

sub newf {
    return Future::Strict->new;
}

my @logs = ();
$SIG{__WARN__} = sub {
    push(@logs, shift);
};


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
                is($e, 'failure', 'exception message OK');
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
            is($e, 'failure', 'exception message OK');
        });
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
                is($e, 'failure', 'exception message OK');
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
    @logs = ();
    note("--- -- try OK case $case->{label}");
    $case->{code}->();
    is(int(@logs), 0, "$case->{label}: it should warn nothing")
        or diag(explain @logs);
}


my @ng_cases = (
    {label => "failed", code => sub { newf->fail("failure") }},
    {label => "died", code => sub { newf->die("died") }},
    {label => "fail, set on_ready but no call to get or failure"},
    {label => "async fail, called get and failure while not ready but no handling"}
);

foreach my $case (@ng_cases) {
    @logs = ();
    note("--- -- try NG case $case->{label}");
    $case->{code}->();
    is(int(@logs), 1, "$case->{label}: it should warn a message")
        or diag(explain @logs);
}

fail("TODO: NG cases");

## - cancel after done
## - cancel after fail


done_testing();


