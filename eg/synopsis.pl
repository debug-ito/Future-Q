use strict;
use warnings;

sub other_async_func {
    my (%args) = @_;
    warn "--- other_async_func\n";
    @_ = ("failure");
    goto $args{on_failure};
}

sub bad_func {
    die "something terrible happened.";
}


{
    use Future::Strict;

    sub async_func_future {
        my $f = Future::Strict->new;
        ## Assume other_async_func() always fails
        other_async_func(
            on_success => sub { $f->done(@_) },
            on_failure => sub { $f->fail(@_) },
        );
        return $f;
    }

    {
        ### CASE 1: It complains
        async_func_future();
    }

    {
        ### CASE 2: It complains
        async_func_future()->on_done(sub {
            my $result = shift;
            print "OK: $result\n";
        });
    }

    {
        ### CASE 3: It does NOT complain
        async_func_future()->on_done(sub {
            my $result = shift;
            print "OK: $result\n";
        })->on_fail(sub {
            my $failure = shift;
            print "NG: $failure\n";
        });
    }
}


{
    {
        ### CASE 4: It complains (if bad_func() throws an exception)
        my $f_result = Future::Strict->new->done("start")->and_then(sub {
            my $f = shift;
            my $result = bad_func($f->get);
            return Future::Strict->new->done($result);
        });
    }
}

