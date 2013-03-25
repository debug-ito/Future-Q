use strict;
use warnings;
use Test::More;
use Future::Strict;
use FindBin;
use lib ("$FindBin::Bin");
use testlib::Utils qw(newf init_warn_handler test_log_num);

init_warn_handler;

note("--- Futures chained by followed_by() etc. methods.");

my @cases = (
    ## ** cases where the chain callback is not executed.
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
    ## ** cases where it starts from done-future -> execute next callback
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
         {label => "done, $chain_method returns the original future", warn_num => 0, code => sub {
             my $f = newf;
             my $executed = 0;
             $f->$chain_method(sub {
                 my $g = shift;
                 $executed = 1;
                 return $g;
             });
             $f->done();
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
             $g->on_ready(sub {
                 my $h = shift;
                 like($h->failure, qr/^failure/, "failure detected and handled.");
             });
         }},
         {label => "done, $chain_method returns the original future", warn_num => 0, code => sub {
             my $f = newf;
             my $executed = 0;
             $f->$chain_method(sub {
                 my $g = shift;
                 $executed = 1;
                 return $f;
             });
             $f->done();
             ok($executed, "callback executed");
         }}
     );
}

foreach my $chain_method (qw(or_else followed_by)) {
    ## ** cases where it starts from failed-future -> execute next callback
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
         {label => "fail, $chain_method not handled, done", warn_num => 0, code => sub {
             note('In this case, the failure is not actually handled.');
             note('But Future::Strict treats just executing or_else/followed_by callbacks');
             note('as handling failures. So be sure to check the results in these callbacks.');
             my $f = newf;
             $f->fail("failure");
             my $executed = 0;
             $f->$chain_method(sub {
                 my $g = shift;
                 $executed = 1;
                 return newf->done;
             });
             ok($executed, "$chain_method callback executed.");
         }},
         {label => "fail, $chain_method handled, another failure", warn_num => 1, code => sub {
             my $f = newf;
             my $handled = 0;
             $f->$chain_method(sub {
                 my $g = shift;
                 $handled = 1;
                 is($g->failure, "failure", "failure message OK");
                 return newf->fail("another failure");
             });
             $f->fail('failure');
             ok($handled, "failure handled");
         }},
         {label => "fail, $chain_method not handled, another failure", warn_num => 1, code => sub {
             note("In this case, Future::Strict thinks the original failure is handled,");
             note("which is not exactly true.");
             my $f = newf;
             $f->fail("failure");
             $f->$chain_method(sub {
                 return newf->fail("another failure");
             });
         }},
         {label => "fail, $chain_method handled, dies", warn_num => 1, code => sub {
             my $f = newf;
             $f->fail("failure");
             my $handled = 0;
             $f->$chain_method(sub {
                 my $g = shift;
                 $handled = 1;
                 is($g->failure, "failure", "failure message OK");
                 die "exception";
             });
             ok($handled, "failure handled");
         }},
         {label => "fail, $chain_method not handled, dies", warn_num => 1, code => sub {
             note("In this case, Future::Strict thinks the original failure is handled,");
             note("which is not exactly true.");
             my $f = newf;
             $f->$chain_method(sub {
                 die "exception";
             });
             $f->fail("failure");
         }},
         {label => "fail, $chain_method not handled, returning the original future", warn_num => 1, code => sub {
             note("Returninig the original failed Future is analogous to re-throwing an exception.");
             my $f = newf;
             $f->$chain_method(sub {
                 my $g = shift;
                 return $g;
             });
             $f->fail('failure');
         }},
         {label => "fail, $chain_method handled, returning the original future", warn_num => 1, code => sub {
             my $f = newf;
             $f->fail('failure');
             $f->$chain_method(sub {
                 my $g = shift;
                 is($g->failure, "failure", "failure message OK");
                 return $g;
             });
         }},
     );
}

## ** cancel cases
foreach my $chain_method (qw(followed_by or_else)) {
    push(@cases,
         {label =>  "fail, $chain_method handled, cancel before f2 completes", warn_num => 0, code => sub {
             my $f = newf;
             my $handled = 0;
             my $g = $f->$chain_method(sub {
                 my $h = shift;
                 $handled = 1;
                 is($h->failure, "failure", "failure message OK");
                 return newf;
             });
             $f->fail("failure");
             ok($handled, "failure handled");
             $g->cancel;
         }},
         {label => "fail, $chain_method not handled, cancel before f2 completes", warn_num => 0, code => sub {
             note("Future::Strict thinks the original failure is handled by executing or_else/followed_by callbacks.");
             my $f = newf;
             $f->fail("failure");
             my $executed = 0;
             my $g = $f->$chain_method(sub {
                 $executed = 1;
                 return newf;
             });
             ok($executed, "callback executed");
             $g->cancel;
         }}
     );
}

## ** transform() method
push(@cases,
     {label => "done, transform", warn_num => 0, code => sub {
         my $f = newf;
         my $g = $f->transform(done => sub {});
         $f->done("a");
     }},
     {label => "fail, transform, not handled", warn_num => 1, code => sub {
         my $f = newf;
         $f->fail("failure");
         my $g = $f->transform(fail => sub { uc shift });
     }},
     {label => "fail, transform, handled", warn_num => 0, code => sub {
         my $f = newf;
         my $handled = 0;
         $f->transform(fail => sub { uc shift })->on_ready(sub {
             my $g = shift;
             if($g->failure) {
                 $handled = 1;
                 is($g->failure, "FAILURE", "failure message OK");
             }
         });
         $f->fail("failure");
     }},
 );

foreach my $case (@cases) {
    note("--- -- Try: $case->{label}");
    test_log_num($case->{code}, $case->{warn_num}, "$case->{label}: expected $case->{warn_num} warnings");
}

done_testing();
