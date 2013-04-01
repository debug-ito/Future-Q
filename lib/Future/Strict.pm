package Future::Strict;
use strict;
use warnings;
use Future 0.11;
use base "Future";
use Devel::GlobalDestruction;
use Scalar::Util qw(refaddr blessed);
use Carp;
use Try::Tiny;

## ** lexical attributes to avoid collision of names.

my %catcher_callback_set_of = ();

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);
    my $id = refaddr $self;
    $catcher_callback_set_of{$id} = 0;
    return $self;
}

sub DESTROY {
    my ($self) = @_;
    return if in_global_destruction;
    my $id = refaddr $self;
    if($self->is_ready && $self->failure && !$catcher_callback_set_of{$id}) {
        $self->_warn_failure();
        my @failed_subfutures = try {
            $self->failed_futures;
        }catch {
            ();
        };
        foreach my $f (@failed_subfutures) {
            $f->_warn_failure(is_subfuture => 1) if blessed($f) && $f->can('_warn_failure');
        }
    }
    delete $catcher_callback_set_of{$id};
}

sub _warn_failure {
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

sub on_fail {
    my ($self) = @_;
    $catcher_callback_set_of{refaddr $self} = 1;
    goto $self->can('SUPER::on_fail');
}

sub on_ready {
    my ($self) = @_;
    $catcher_callback_set_of{refaddr $self} = 1;
    goto $self->can('SUPER::on_ready');
}


=head1 NAME

Future::Strict - a strict future that will complain when it fails and is not handled.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

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

=head1 DESCRIPTION

L<Future::Strict> is a subclass of L<Future>.
It extends the original L<Future> so that it warns you
when a L<Future::Strict> object in the failure state is
destroyed but its failure has never been handled.


=head2 What's the benefit of Future::Strict?

The benefit of using L<Future::Strict> instead of regular L<Future>
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

If this happens with L<Future::Strict>, it prints warning message
to motivate you to handle the failures properly.

L<Future::Strict> is even more beneficial when you use chaining methods such as C<and_then()>.
This is because as of L<Future> 0.11 B<< exceptions thrown in callbacks for C<and_then()>, C<or_else>
and C<followed_by()> are caught and transformed into failed futures. >>

For example, the following code seems to involve no failed future.

    {
        ### CASE 4: It complains (if bad_func() throws an exception)
        my $f_result = Future::Strict->new->done("start")->and_then(sub {
            my $f = shift;
            my $result = bad_func($f->get);
            return Future::Strict->new->done($result);
        });
    }

However, if C<bad_func()> throws an exception, it is silently transformed into a failed future.
As a result, C<$f_result> becomes a failed future.
If you just discard C<$f_result> like this example, the exception is never handled.
What's worse, if you don't use L<Future::Strict>, the exception is never visible to you,
which can lead to very hard-to-track bugs.

L<Future::Strict> makes failed futures visible to you.
With L<Future::Strict> you will not miss unexpected failed futures in most cases.


=head2 When and how does a Future::Strict complain?

A failed L<Future::Strict> object prints warning messages when it is destroyed.

The warning messages are printed through Perl's warning facility.
You can capture them by setting C<< $SIG{__WARN__}. >>
The warning messages can be evaluated to strings.
(They ARE strings actually, but this may change in future versions)


=head2 How can I convince a Future::Strict that its failure is handled?

To prevent a failed L<Future::Strict> from complaining,
you have to convince it that its failure is handled before it's destroyed.

L<Future::Strict> thinks failures of the following futures are handled.

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
but L<Future::Strict> thinks they are handled.


=item *

Always inspect failed subfutures by C<failed_futures()> method
in callbacks for dependent futures returned by C<wait_all()>, C<wait_any()>,
C<needs_all()> and C<needs_any()>.

This is because there may be multiple of failed subfutures.
It is even possible that some subfutures fail but the dependent future succeeds.

=back


=head1 METHODS

L<Future::Strict> inherits all the class and object methods from L<Future>.
There is no extra public method.

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


1; # End of Future::Strict
