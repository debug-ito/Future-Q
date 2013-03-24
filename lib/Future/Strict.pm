package Future::Strict;
use strict;
use warnings;
use Future 0.11;
use base "Future";
use Devel::GlobalDestruction;
use Scalar::Util qw(refaddr blessed);
use Carp;

## ** lexical attributes and private functions to avoid collision of names.

my %failure_handled_of = ();

my $is_called_from_outside = sub {
    my $caller_package = caller(1);
    return $caller_package ne 'Future' && $caller_package ne 'Future::Strict';
};

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);
    $failure_handled_of{refaddr $self} = 0;
    return $self;
}

sub DESTROY {
    my ($self) = @_;
    return if in_global_destruction;
    if($self->is_ready && $self->failure && !$failure_handled_of{refaddr $self}) {
        warn "failure not handled: " . $self->failure;
    }
    delete $failure_handled_of{refaddr $self};
}

sub _mark_as_failure_handled {
    my ($self) = @_;
    $failure_handled_of{refaddr $self} = 1;
}

sub failure {
    my ($self) = @_;
    my $super = $self->can('SUPER::failure');
    if(not $is_called_from_outside->()) {
        goto $super;
    }
    if($self->is_ready) {
        $self->_mark_as_failure_handled();
    }
    goto $super;
}

sub get {
    my ($self) = @_;
    my $super = $self->can('SUPER::get');
    if(not $is_called_from_outside->()) {
        goto $super;
    }
    if($self->is_ready) {
        $self->_mark_as_failure_handled();
    }
    goto $super;
}

sub on_fail {
    my ($self) = @_;
    my $super = $self->can('SUPER::on_fail');
    if(not $is_called_from_outside->()) {
        goto $super;
    }
    $self->_mark_as_failure_handled();
    goto $super;
}

my $wrap_chain_callback = sub {
    my ($method_name, $code) = @_;
    croak "Argument must be a CODE-ref" if !defined($code) || ref($code) ne 'CODE';
    return sub {
        my ($next_future) = $code->(@_);
        if(!blessed($next_future) || !$next_future->isa('Future')) {
            croak "Return value from $method_name callback must be a Future"
        }
        if($next_future->isa('Future::Strict')) {
            ## ** handling failure of Future from the chain callback is
            ## ** delegated to the next Future in the chain.
            $next_future->_mark_as_failure_handled();
        }
        return $next_future;
    };
};

sub and_then {
    my ($self, $code) = @_;
    my $super = $self->can('SUPER::and_then');
    if(not $is_called_from_outside->()) {
        goto $super;
    }
    ## ** and_then() delegates handling of failure to the next Future in the chain.
    $self->_mark_as_failure_handled();
    @_ = ($self, $wrap_chain_callback->('and_then', $code));
    goto $super;
}


=head1 NAME

Future::Strict - The great new Future::Strict!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS


=head1 SEE ALSO

It's very tricky to throw exceptions from destructors, so I decided not to use exceptions
to report failed and ignored Futures.

=over

=item *

Exception Handling - perl5140delta: L<http://perldoc.perl.org/perl5140delta.html#Exception-Handling>

=item *

Throw from within a DESTROY block - PerlMonks: L<http://www.perlmonks.org/?node_id=924488>

=back



=head1 AUTHOR

Toshio Ito, C<< <toshioito at cpan.org> >>



=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Toshio Ito.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Future::Strict
