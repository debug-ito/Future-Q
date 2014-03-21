use strict;
use warnings;
use Test::More;
use Test::Identity;
use Future;
use Future::Q;
use FindBin;
use lib "$FindBin::RealBin";
use testlib::Utils qw(newf);

foreach my $case (
    {label => "string", args => ["aaa"]},
    {label => "empty", args => []},
    {label => "undef", args => [undef]},
    {label => "multi", args => [1,2,3]},
    {label => "done Future", args => [Future->new->done(10,20)], exp_get => [10, 20]},
    {label => "failed Future", args => [Future->new->fail("hoge")], exp_fail => ["hoge"]},
    {label => "cancelled Future", args => [Future->new->cancel()], exp_cancel => 1},
) {
    note("--- immediate $case->{label}");
    my $f = newf;
    identical($f->resolve(@{$case->{args}}), $f, "$case->{label}: resolve() should return the object");
    my $exp_get = $case->{exp_get};
    my $exp_fail = $case->{exp_fail};
    if($case->{exp_cancel}) {
        ok $f->is_cancelled, "$case->{label}: f is cancelled";
    }elsif($exp_fail) {
        is_deeply([$f->failure], $exp_fail, "$case->{label}: resolve() rejects ok");
        $f->catch(sub {}); ## to handle the failure.
    }else {
        $exp_get ||= $case->{args};
        is_deeply([$f->get], $exp_get, "$case->{label}: resolve() fulfills ok");
    }
}

{
    note("--- Future and other stuff");
    my $f = newf;
    my $given_f = Future->new->done();
    $f->resolve($given_f, 10, 20);
    is_deeply([$f->get], [$given_f, 10, 20], "get Future and other stuff. given Future is not expanded");
}

{
    note("--- pending done Future");
    my $f = newf;
    my $given_f = Future->new;
    identical($f->resolve($given_f), $f, "resolve should return the object");
    ok $f->is_pending, "f is still pending";
    
}

## deep resolve chain;

## cancel() afterward

## memory cycle

## failure handled

done_testing;
