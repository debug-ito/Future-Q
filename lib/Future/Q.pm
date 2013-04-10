package Future::Q;
use strict;
use warnings;
use Future 0.12;
use base "Future";
use Devel::GlobalDestruction;
use Scalar::Util qw(refaddr blessed weaken);
use Carp;
use Try::Tiny ();

our @CARP_NOT;

## ** lexical attributes to avoid collision of names.

my %failure_handled_for = ();

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);
    my $id = refaddr $self;
    $failure_handled_for{$id} = 0;
    return $self;
}

sub DESTROY {
    my ($self) = @_;
    return if in_global_destruction;
    my $id = refaddr $self;
    if($self->is_ready && $self->failure && !$failure_handled_for{$id}) {
        $self->_q_warn_failure();
        my @failed_subfutures = Try::Tiny::try {
            $self->failed_futures;
        }Try::Tiny::catch {
            ();
        };
        foreach my $f (@failed_subfutures) {
            $f->_q_warn_failure(is_subfuture => 1) if blessed($f) && $f->can('_q_warn_failure');
        }
    }
    delete $failure_handled_for{$id};
}

sub _q_set_failure_handled {
    my ($self) = @_;
    $failure_handled_for{refaddr $self} = 1;
}

sub _q_warn_failure {
    my ($self, %options) = @_;
    if($self->is_ready && $self->failure) {
        my $failure = $self->failure;
        if($options{is_subfuture}) {
            carp "Failure of subfuture $self may not be handled: $failure  subfuture may be lost";
        }else {
            carp "Failure of $self is not handled: $failure  future is lost";
        }
    }
}

sub try {
    my ($class, $func, @args) = @_;
    if(!defined($func) || ref($func) ne "CODE") {
        $func = sub {
            local @CARP_NOT = ('Try::Tiny');
            croak("func parameter for try() must be a code-ref");
        };
    }
    my $result_future = Try::Tiny::try {
        my @results = $func->(@args);
        if(scalar(@results) == 1 && blessed($results[0]) && $results[0]->isa('Future')) {
            return $results[0];
        }else {
            return $class->new->fulfill(@results);
        }
    } Try::Tiny::catch {
        my $e = shift;
        return $class->new->reject($e);
    };
    return $result_future;
}

sub fcall {
    goto $_[0]->can('try');
}

sub then {
    my ($self, $on_fulfilled, $on_rejected) = @_;
    if(defined($on_fulfilled) && ref($on_fulfilled) ne "CODE") {
        $on_fulfilled = undef;
    }
    if(defined($on_rejected) && ref($on_rejected) ne "CODE") {
        $on_rejected = undef;
    }
    my $class = ref($self);
    $self->_q_set_failure_handled();
    
    my $next_future = $self->new;
    my $return_future_for_next;
    $self->on_ready(sub {
        my $invo_future = shift;
        if($invo_future->is_cancelled) {
            $next_future->cancel() if $next_future->is_pending;
            return;
        }

        ## determine return_future
        my $return_future = $invo_future;
        if($invo_future->is_rejected && defined($on_rejected)) {
            $return_future = $class->try($on_rejected, $invo_future->failure);
        }elsif($invo_future->is_fulfilled && defined($on_fulfilled)) {
            $return_future = $class->try($on_fulfilled, $invo_future->get);
        }
        $return_future->_q_set_failure_handled();
        $return_future_for_next = $return_future;
        weaken($return_future_for_next);

        ## transfer the results of return_future to next_future
        $return_future->on_ready(sub {
            my $return_future = shift;
            if($return_future->is_cancelled) {
                $next_future->cancel() if $next_future->is_pending;
                return;
            }
            return if !$next_future->is_pending;
            if($return_future->is_rejected) {
                $next_future->reject($return_future->failure);
            }else {
                $next_future->fulfill($return_future->get);
            }
        });
    });
    if($next_future->is_pending) {
        weaken(my $invo_future = $self);
        $next_future->on_cancel(sub {
            if(defined($invo_future) && $invo_future->is_pending) {
                $invo_future->cancel();
            }
            if(defined($return_future_for_next) && $return_future_for_next->is_pending) {
                $return_future_for_next->cancel();
            }
        });
    }
    return $next_future;
}

sub catch {
    my ($self, $on_rejected) = @_;
    @_ = ($self, undef, $on_rejected);
    goto $self->can('then');
}

sub fulfill {
    goto $_[0]->can('done');
}

sub reject {
    goto $_[0]->can('fail');
}

sub is_pending {
    my ($self) = @_;
    return !$self->is_ready;
}

sub is_fulfilled {
    my ($self) = @_;
    return (!$self->is_pending && !$self->is_cancelled && !$self->is_rejected);
}

sub is_rejected {
    my ($self) = @_;
    return ($self->is_ready && $self->failure);
}

foreach my $method (qw(wait_all wait_any needs_all needs_any)) {
    no strict "refs";
    my $supermethod = "SUPER::$method";
    *{$method} = sub {
        my ($self, @subfutures) = @_;
        foreach my $sub (@subfutures) {
            next if !blessed($sub) || !$sub->can('_q_set_failure_handled');
            $sub->_q_set_failure_handled();
        }
        goto $self->can($supermethod);
    };
}


=head1 NAME

Future::Q - a thenable Future like Q.js

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS


=head1 DESCRIPTION

L<Future::Q> is a subclass of L<Future>.
It extends its API with C<then()> and C<try()> etc, which are
almost completely compatible with Kris Kowal's Q module for Javascript.

For further information as to what Future (in a broad meaning) is all about, see:

=over

=item *

L<Future> - the original class

=item *

L<Promises> - based on jQuery and YUI Deferred plug-in

=item *

L<Q module:http://documentup.com/kriskowal/q/> - Javascript module

=back

=head2 Terminology of Future States

Any L<Future::Q> object is in one of the following four states.

=over

=item 1.

B<pending> - The operation represented by the L<Future::Q> object is now in progress.

=item 2.

B<fulfilled> - The operation succeeds and the L<Future::Q> object has its results.

=item 3.

B<rejected> - The operation fails and the L<Future::Q> object has the reason of the failure.

=item 4.

B<cancelled> - The operation has been cancelled.

=back

The state transition is one-way; "pending" -> "fulfilled", "pending" -> "rejected" or "pending" -> "cancelled".
Once the state transitions to a non-pending state, its state never changes anymore.

In the terminology of L<Future>, "done" and "failed" are used for "fulfilled" and "rejected", respectively.

You can check the state of a L<Future::Q> with predicate methods C<is_pending()>, C<is_fulfilled()>, C<is_rejected()> and C<is_cancelled()>.


=head1 CLASS METHODS

In addition to all class methods in L<Future>,
L<Future::Q> has the following class method.

=head2 $future = Future::Q->new()

Constructor. It creates a new pending L<Future::Q> object.

=head2 $future = Future::Q->try($func, @args)

=head2 $future = Future::Q->fcall($func, @args)

Immediately executes the C<$func> with the arguments C<@args>, and returns
a L<Future> object that represents the result of C<$func>.

C<fcall()> method is an alias of C<try()> method.

C<$func> is a subroutine reference. It is executed with the optional arguments C<@args>.

The return value (C<$future>) is determined by the following rules:

=over

=item *

If C<$func> returns a single L<Future> object, C<$future> is that object.

=item *

If C<$func> throws an exception, C<$future> is a rejected L<Future::Q> object with that exception.
The exception is never rethrown to the upper stacks.

=item *

Otherwise, C<$future> is a fulfilled L<Future::Q> object with the values returned by C<$func>.

=back

If C<$func> is not a subrouine reference, it returns a rejected L<Future::Q> object.

=head1 OBJECT METHODS

In addition to all object methods in L<Future>, L<Future::Q> has the following object methods.

=head2 $next_future = $future->then([$on_fulfilled, $on_rejected])

Registers callback functions that are executed when C<$future> becomes fulfilled or rejected,
and returns a new L<Future::Q> object that represents the result of the whole operation.

C<$on_fulfilled> and C<on_rejected> are subroutine references that are executed
when C<$future> is fulfilled or rejected, respectively.
C<$on_fulfilled> and C<$on_rejected> are both optional.

C<$next_future> is a new L<Future::Q> object.
In a nutshell, it represents the result of C<$future> and the subsequent execution of C<$on_fulfilled>
or C<$on_rejected> callback.

In detail, the state of C<$next_future> is determined by the following rules.

=over

=item *

While C<$future> is pending, C<$next_future> is pending.

=item *

When C<$future> is cancelled, neither C<$on_fulfilled> nor C<$on_rejected> is executed,
and C<$next_future> becomes cancelled.

=item *

When C<$future> is fulfilled and C<$on_fulfilled> is not provided,
C<$next_future> is fulfilled with the same values as C<$future>.

=item *

When C<$future> is rejected and C<$on_rejected> is not provided,
C<$next_future> is rejected with the same values as C<$future>.

=item *

When C<$future> is fulfilled and C<$on_fulfilled> is provided,
C<$on_fulfilled> is executed.
In this case C<$next_future> represents the result of C<$on_fulfilled> callback (see below).

=item *

When C<$future> is rejected and C<$on_rejected> is provided,
C<$on_rejected> is executed.
In this case C<$next_future> represents the result of C<$on_rejected> callback (see below).

=item *

In the above two cases where C<$on_fulfilled> or C<$on_rejected> callback is executed,
the following rules are applied to C<$next_future>.

=over

=item *

If the callback returns a single L<Future> (call it C<$returned_future>),
C<$next_future>'s state is synchronized with that of C<$returned_future>.

=item *

TODO: rejected?

=item *

TODO: otherwise?

=back

=back


TODO: arguments for on_fulfilled or on_rejected?

TODO: Note for immediate case.

TODO: cancelling $next_future

=head2 $next_future = $future->catch([$on_rejected])

Alias of $future->then(undef, $on_rejected).

=head2 $future = $future->fulfill(@result)

Alias of done().

=head2 $future = $future->reject($exception, @details)

Alias of fail(), not die().

=head2 $is_pending = $future->is_pending()

=head2 $is_fulfilled = $future->is_fulfilled()

=head2 $is_rejected = $future->is_rejected()


=head1 EXAMPLE

=head2 try() and then()

    use Future::Q;

    ## Values returned from try() callback are transformed into a
    ## fulfilled Future::Q
    Future::Q->try(sub {
        return (1,2,3);
    })->then(sub {
        print join(",", @_), "\n"; ## -> 1,2,3
    });

    ## Exception thrown from try() callback is transformed into a
    ## rejected Future::Q
    Future::Q->try(sub {
        die "oops!";
    })->catch(sub {
        my $e = shift;
        print $e;       ## -> oops! at eg/try.pl line XX.
    });

    ## A Future returned from try() callback is returned as is.
    my $f = Future::Q->new;
    Future::Q->try(sub {
        return $f;
    })->then(sub {
        print "This is not executed.";
    }, sub {
        print join(",", @_), "\n";  ## -> a,b,c
    });
    $f->reject("a", "b", "c");



----------------------------------

=head1 DESCRIPTION

L<Future::Q> is a subclass of L<Future>.
It extends the original L<Future> so that it warns you
when a L<Future::Q> object in the failure state is
destroyed but its failure has never been handled.


=head2 What's the benefit of Future::Q?

The benefit of using L<Future::Q> instead of regular L<Future>
is that it can detect the possibly dangerous situation when
a future fails but its failure is never handled.

In the L</SYNOPSIS>, the C<async_func_future()> function returns
a future that may either succeed or fail. B<Let's assume it always fails in this example>.

However, with regular L<Future> it is very easy to ignore failures
if you are not very careful.

For example, if you are interested only in the side-effect of C<async_func_future()> but
not in its result, you are very likely to write CASE 1, that is, just throwing away the
returned future. Or if you are too lazy to set the failure handler, you will probably
write CASE 2. In both cases, the returned failure is discarded.

If this happens with L<Future::Q>, it prints warning message
to motivate you to handle the failures properly.

L<Future::Q> is even more beneficial when you use chaining methods such as C<and_then()>.
This is because as of L<Future> 0.11 B<< exceptions thrown in callbacks for C<and_then()>, C<or_else>
and C<followed_by()> are caught and transformed into failed futures. >>

For example, the following code seems to involve no failed future.

    {
        ### CASE 4: It complains (if bad_func() throws an exception)
        my $f_result = Future::Q->new->done("start")->and_then(sub {
            my $f = shift;
            my $result = bad_func($f->get);
            return Future::Q->new->done($result);
        });
    }

However, if C<bad_func()> throws an exception, it is silently transformed into a failed future.
As a result, C<$f_result> becomes a failed future.
If you just discard C<$f_result> like this example, the exception is never handled.
What's worse, if you don't use L<Future::Q>, the exception is never visible to you,
which can lead to very hard-to-track bugs.

L<Future::Q> makes failed futures visible to you.
With L<Future::Q> you will not miss unexpected failed futures in most cases.


=head2 When and how does a Future::Q complain?

A failed L<Future::Q> object prints warning messages when it is destroyed.

The warning messages are printed through Perl's warning facility.
You can capture them by setting C<< $SIG{__WARN__}. >>
The warning messages can be evaluated to strings.
(They ARE strings actually, but this may change in future versions)


=head2 How can I convince a Future::Q that its failure is handled?

To prevent a failed L<Future::Q> from complaining,
you have to convince it that its failure is handled before it's destroyed.

L<Future::Q> thinks failures of the following futures are handled.

=over

=item *

Futures that C<on_fail()> or C<on_ready()> method is called on.

=item *

Futures that C<and_then()>, C<or_else()> or C<followed_by()> method is called on.

=item *

Futures returned by the callbacks for C<and_then()>, C<or_else()> or C<followed_by()> method.

=item *

Subfutures given to C<wait_all()>, C<wait_any()>, C<needs_all()> or C<needs_any()> method.

=back

Therefore, remember to call C<on_fail()> on any future that may fail and
handle the failure in its callback.


=head1 CAVEAT

If you don't want to miss failed futures, I recommend you to follow the guidelines below.

=over

=item *

Do not use C<on_ready()> or C<followed_by()> method unless it's absolutely necessary.
In callbacks for these methods you may forget to handle failures,
but L<Future::Q> thinks they are handled.


=item *

Always inspect failed subfutures by C<failed_futures()> method
in callbacks for dependent futures returned by C<wait_all()>, C<wait_any()>,
C<needs_all()> and C<needs_any()>.

This is because there may be multiple of failed subfutures.
It is even possible that some subfutures fail but the dependent future succeeds.

=back


=head1 MISSING METHODS

=over

=item promise.fail()

Unfortunately L<Future> already has C<fail()> method for a completely different meaning.
Use C<catch()> method instead.

=item promise.progress(), deferred.notify(), promise.finally(), promise.fin()

Progress handlers and "finally" callbacks are interesting features,
but they are not supported in this version of L<Future::Q>.

=item promise.done()

Unfortunately L<Future> already has C<done()> method for a completely different meaning.
There is no corresponding method in this version of L<Future::Q>.

=item promise.fcall() (object method)

Its class method form is enough to get the job done.
Use C<< Future::Q->fcall() >>.

=item promise.all(), promise.allResolve()

Use C<< Future::Q->needs_all() >> and C<< Future::Q->wait_all() >> methods, respectively.

=item deferred.resolve()

This is an interesting method, but it's not supported in this version of L<Future::Q>.
Call C<fulfill()> or C<reject()> explicitly instead.

=back

=head1 MEMO

TODO: erase the memo

  - テストと実装は完了。あとはドキュメントを書いてパッケージング！
  - Future::Qの推奨する使い方は、then(), catch(), on_cancel()のみ。
  - deferredとpromiseの区別がないことを明記
  - 第4の状態 "cancelled" があることを明記
  - thenコールバックはimmediateに実行される可能性があることを明記。
  - then()あらゆるケースにおいて、invocant_futureとnext_futureは
    別のオブジェクトであることを明記
  - try()にジャンク突っ込むとrejected future出すことを明記
  - reject()の$exceptionにはtruthyな値しか入れられないことを明記


=head1 SEE ALSO

L<Future>

=head1 ACKNOWLEDGEMENT

Paul Evans, C<< <leonerd at leonerd.org.uk> >> - author of L<Future>


=head1 AUTHOR

Toshio Ito, C<< <toshioito at cpan.org> >>


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Toshio Ito.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut


1; # End of Future::Q
