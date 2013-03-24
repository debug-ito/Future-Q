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
    {label => "done, or_else", warn_num => 0, code => sub {
        my $f = newf;
        $f->done;
        my $executed = 0;
        $f->or_else(sub {
            $executed = 1;
            return newf->done;
        });
        ok(!$executed, "callback not executed OK");
    }},
);

foreach my $chain_method (qw(and_then followed_by)) {
    ## ** Generate cases where it starts from done-future -> execute next callback
    push(@cases,
         {label => "done, $chain_method done", warn_num => 0, code => sub {
             my $f = newf;
             my $executed = 0;
             $f->$chain_method(sub {
                 $executed = 1;
                 return newf->done();
             });
             $f->done;
             ok($executed, "callback executed.");
         }},
         {label => "done, $chain_method fail, not handled", warn_num => 1, code => sub {
             my $f = newf;
             my $executed = 0;
             $f->$chain_method(sub {
                 $executed = 1;
                 return newf->fail('failure');
             });
             $f->done();
             ok($executed, "$chain_method callback executed OK");
         }},
         {label => "done, $chain_method fail, handled", warn_num => 0, code => sub {
             my $f = newf;
             $f->done();
             my $executed = 0;
             my $handled = 0;
             $f->$chain_method(sub {
                 $executed = 1;
                 return newf->fail('failure');
             })->on_ready(sub {
                 my $g = shift;
                 $handled = 1;
                 is($g->failure, 'failure', "failure message OK");
             });
             ok($executed, "$chain_method callback executed OK");
             ok($handled, "failure handled OK");
         }},
         {label => "done, $chain_method dies, not handled", warn_num => 1, code => sub {
             my $f = newf;
             $f->$chain_method(sub {
                 die "failure";
             });
             $f->done();
         }},
         {label => "done, $chain_method dies, handled", warn_num => 0, code => sub {
             my $f = newf;
             my $g = $f->$chain_method(sub {
                 die "failure";
             });
             $f->done();
             like($g->failure, qr/^failure/, "failure detected and handled.");
         }},
     );
}

foreach my $chain_method (qw(or_else followed_by)) {
    ## ** Generate cases where it starts from failed-future -> execute next callback
    push(@cases,
         {label => "fail, $chain_method handled, done", warn_num => 0, code => sub {
             my $f = newf;
             my $handled = 0;
             $f->$chain_method(sub {
                 my $g = shift;
                 is($g->failure, "failure", "failure message OK");
                 $handled = 1;
                 return newf->done;
             });
             $f->fail("failure");
             ok($handled, "failure handled.");
         }},
         {label => "fail, $chain_method not handled, done", warn_num => 1, code => sub {
             my $f = newf;
             $f->fail("failure");
             my $executed = 0;
             $f->$chain_method(sub {
                 my $g = shift;
                 $executed = 1;
                 return newf->done;
             });
             ok($executed, "$chain_method callback executed.");
         }}
     );
    fail("todo: more fail-start and next stop cases");
}


foreach my $case (@cases) {
    note("--- -- Try: $case->{label}");
    test_log_num($case->{code}, $case->{warn_num}, "$case->{label}: expected $case->{warn_num} warnings");
}

fail("todo: or_else (and other?) callback returning the original Future.");
fail("todo: fail in the callback by exception.");

done_testing();
