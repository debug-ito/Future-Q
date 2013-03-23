use strict;
use warnings;
use Test::More;
use Future::Strict;
use Try::Tiny;

sub newf {
    return Future::Strict->new;
}

note('--- OK/NG cases of single (non-chained) Futures');

my @ok_cases = (
    {label => "not-complete future", code => sub { newf; }},
    {label => "done future", code => sub { newf->done; }},
    {label => "canceled futrue", code => sub { newf->cancel; }},
);

fail("TODO: OK cases with failed Futures");

foreach my $case (@ok_cases) {
    my $msg = "$case->{label}: it should survive";
    try {
        $case->{code}->();
        ok($msg);
    }catch {
        fail($msg);
    };
}

fail("TODO: NG cases");

## - canceled
## - cancel after done
## - cancel after fail


done_testing();


