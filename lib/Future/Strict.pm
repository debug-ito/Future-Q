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
            ()
        };
        foreach my $f (@failed_subfutures) {
            $f->_warn_failure();
        }
    }
    delete $catcher_callback_set_of{$id};
}

sub _warn_failure {
    my ($self) = @_;
    if($self->is_ready && $self->failure) {
        warn "failure not handled: " . $self->failure;
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

Future::Strict - The great new Future::Strict!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

=head1 CAVEAT

(MEMO)

If you don't want to miss failed Futures, you should do the following.

=over

=item *

In callbacks for on_ready(), or_else() and followed_by() methods, always inspect the result with get() or failure() method.

=item *

In callbacks for dependent Futures returned by wait_all(), wait_any(), needs_all() and needs_any(),
always inspect failed subfutures by failed_futures() method. There may be multiple of them.

=back

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
