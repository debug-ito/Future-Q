package Future::Strict;
use strict;
use warnings;
use base "Future";
use Devel::GlobalDestruction;

sub DESTROY {
    return if in_global_destruction;
    warn "fail!";
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
