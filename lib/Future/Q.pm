package Future::Q;
use strict;
use warnings;
use Future 0.13;
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
        if($return_future->can("_q_set_failure_handled")) {
            $return_future->_q_set_failure_handled();
        }
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
            if($return_future->failure) {
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
            if(defined($return_future_for_next) && !$return_future_for_next->is_ready) {
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

our $VERSION = '0.030';

1;

__END__

=head1 NAME

Future::Q - a thenable Future like Q module for JavaScript

=head1 VERSION

Version 0.030

=head1 SYNOPSIS

    use Future::Q;

    sub async_func_future {
        my @args = @_;
        my $f = Future::Q->new;
        other_async_func(   ## This is a regular callback-style async function
            args => \@args,
            on_success => sub { $f->fulfill(@_) },
            on_failure => sub { $f->reject(@_) },
        );
        return $f;
    }

    async_func_future()->then(sub {
        my @results = @_;
        my @processed_values = do_some_processing(@results);
        return @processed_values;
    })->then(sub {
        my @values = @_;   ## same values as @processed_values
        return async_func_future(@values);
    })->then(sub {
        warn "Operation finished.\n";
    })->catch(sub {
        ## failure handler
        my $error = shift;
        warn "Error: $error\n";
    });

=head1 DESCRIPTION

L<Future::Q> is a subclass of L<Future>.
It extends its API with C<then()> and C<try()> etc, which are
almost completely compatible with Kris Kowal's Q module for Javascript.

Basically a Future (in a broad meaning) represents an operation (whether it's in progress
or finished) and its results.
For further information as to what Future is all about, see:

=over

=item *

L<Future> - the base class

=item *

L<Promises> - based on jQuery and YUI Deferred plug-in

=item *

L<Q module|http://documentup.com/kriskowal/q/> - Javascript module

=back

=head2 Terminology of Future States

Any L<Future::Q> object is in one of the following four states.

=over

=item 1.

B<pending> - The operation represented by the L<Future::Q> object is now in progress.

=item 2.

B<fulfilled> - The operation has succeeded and the L<Future::Q> object has its results.
The results can be obtained by C<get()> method.

=item 3.

B<rejected> - The operation has failed and the L<Future::Q> object has the reason of the failure.
The reason of the failure can be obtained by C<failure()> method.

=item 4.

B<cancelled> - The operation has been cancelled.

=back

The state transition is one-way; "pending" -> "fulfilled", "pending" -> "rejected" or "pending" -> "cancelled".
Once the state moves to a non-pending state, its state never changes anymore.

In the terminology of L<Future>, "done" and "failed" are used for "fulfilled" and "rejected", respectively.

You can check the state of a L<Future::Q> with predicate methods C<is_pending()>, C<is_fulfilled()>, C<is_rejected()> and C<is_cancelled()>.

=head2 then() Method

Using C<then()> method, you can register callback functions with a L<Future::Q> object.
The callback functions are executed when the L<Future::Q> object is fulfilled or rejected.
You can obtain and use the results of the L<Future::Q> within the callbacks.

The return value of C<then()> method represents the results of the callback function (if it's executed).
Since the callback function is also an operation in progress, the return value of C<then()> is naturally a L<Future::Q> object.
By calling C<then()> method on the returned L<Future::Q> object, you can chain a series of operations
that are executed sequentially.

See the specification of C<then()> method below for details.

=head2 Reporting Unhandled Failures

L<Future::Q> warns you when a rejected L<Future::Q> object is destroyed without its failure handled.
This is because ignoring a rejected L<Future::Q> is just as dangerous as ignoring a thrown exception.
Any rejected L<Future::Q> object must be handled properly.

When a rejected but unhandled L<Future::Q> is destroyed,
the reason of the failure is printed through Perl's warning facility.
You can capture them by setting C<$SIG{__WARN__}>.
The warning messages can be evaluated to strings.
(They ARE strings actually, but this may change in future versions)

L<Future::Q> thinks failures of the following futures are "handled".

=over

=item *

Futures that C<then()> or C<catch()> method has been called on.

=item *

Futures that are returned by C<$on_fulfilled> or C<$on_rejected> callbacks for C<then()> method.

=item *

Subfutures given to C<wait_all()>, C<wait_any()>, C<needs_all()> and C<needs_any()> method.

=back

So make sure to call C<catch()> method at the end of any callback chain to handle failures.

I also recommend always inspecting failed subfutures using C<failed_futures()> method
in callbacks for dependent futures returned by C<wait_all()>, C<wait_any()>, C<needs_all()> and C<needs_any()>.
This is because there may be multiple of failed subfutures.
It is even possible that some subfutures fail but the dependent future succeeds.

=head1 CLASS METHODS

In addition to all class methods in L<Future>,
L<Future::Q> has the following class methods.

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

If C<$func> is not a subroutine reference, it returns a rejected L<Future::Q> object.

=head1 OBJECT METHODS

In addition to all object methods in L<Future>, L<Future::Q> has the following object methods.

=head2 $next_future = $future->then([$on_fulfilled, $on_rejected])

Registers callback functions that are executed when C<$future> is fulfilled or rejected,
and returns a new L<Future::Q> object that represents the result of the whole operation.

B<< Difference from then() method of L<Future> >>

L<Future::Q> overrides the C<then()> method of the base L<Future> class.
Basically they behave in the same way, but in C<then()> method of L<Future::Q>,

=over

=item *

the callback funcions do not have to return a L<Future> object.
If they do not, the return values are automatically transformed into a fulfilled L<Future::Q> object.

=item *

it will not warn you even if you call the C<then()> method in void context.

=back

B<< Detailed specification >>

Below is the detailed specification of C<then()> method.

C<$on_fulfilled> and C<$on_rejected> are subroutine references.
When C<$future> is fulfilled, C<$on_fulfilled> callback is executed.
Its arguments are the values of the C<$future>, which are obtained by C<< $future->get >> method.
When C<$future> is rejected, C<$on_rejected> callback is executed.
Its arguments are the reason of the failure, which are obtained by C<< $future->failure >> method.
Both C<$on_fulfilled> and C<$on_rejected> are optional.

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

When C<$future> is fulfilled and C<$on_fulfilled> is C<undef>,
C<$next_future> is fulfilled with the same values as C<$future>.

=item *

When C<$future> is rejected and C<$on_rejected> is C<undef>,
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

If the callback throws an exception,
C<$next_future> is rejected with that exception.
The exception is never rethrown to the upper stacks.

=item *

Otherwise, C<$next_future> is fulfilled with the values returned by the callback.

=back

=back

Note that the whole operation can be executed immediately.
For example, if C<$future> is already fulfilled,
C<$on_fulfilled> callback is executed before C<$next_future> is returned.
And if C<$on_fulfilled> callback does not return a pending L<Future>,
C<$next_future> is already in a non-pending state.

You can call C<cancel()> method on C<$next_future>.
If C<$future> is pending, it is cancelled when C<$next_future> is cancelled.
If either C<$on_fulfilled> or C<$on_rejected> is executed and its C<$returned_future>
is pending, the C<$returned_future> is cancelled when C<$next_future> is cancelled.

You should not call C<fulfill()> or C<reject()> on C<$next_future>.

=head2 $next_future = $future->catch([$on_rejected])

Alias of C<< $future->then(undef, $on_rejected) >>.

=head2 $future = $future->fulfill(@result)

Fulfills the pending C<$future> with the values C<@result>.

This method is an alias of C<< $future->done(@result) >>.

=head2 $future = $future->reject($exception, @details)

Rejects the pending C<$future> with the C<$exception> and optional C<@details>.
C<$exception> must be a scalar evaluated as boolean true.

This method is an alias of C<fail()> method (not C<die()> method).

=head2 $is_pending = $future->is_pending()

Returns true if the C<$future> is pending. It returns false otherwise.

=head2 $is_fulfilled = $future->is_fulfilled()

Returns true if the C<$future> is fulfilled. It returns false otherwise.

=head2 $is_rejected = $future->is_rejected()

Returns true if the C<$future> is rejected. It returns false otherwise.

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



=head1 DIFFERENCE FROM Q

Although L<Future::Q> tries to emulate the behavior of Q module for JavaScript as much as possible,
there is difference in some respects.

=over

=item *

L<Future::Q> has both roles of "promise" and "deferred" in Q.
Currently there is no read-only future like "promise".

=item *

L<Future::Q> has the fourth state "cancelled", while promise in Q does not.

=item *

In L<Future::Q>, callbacks for C<then()> method can be executed immediately.
This is because L<Future::Q> does not assume any event loop mechanism.

=item *

In L<Future::Q>, you must pass a truthy value to C<reject()> method.
This is required by the original L<Future> class.

=back



=head2 Missing Methods

Some methods in Q module are missing in L<Future::Q>.
Some of them worth noting are listed below.

=over

=item promise.fail()

L<Future> already has C<fail()> method for a completely different meaning.
Use C<catch()> method instead.

=item promise.progress(), deferred.notify(), promise.finally(), promise.fin()

Progress handlers and "finally" callbacks are interesting features,
but they are not supported in this version of L<Future::Q>.

=item promise.done()

L<Future> already has C<done()> method for a completely different meaning.
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

