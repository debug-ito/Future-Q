use strict;
use warnings;
use Test::More;
use Future::Strict;
use Future::Utils qw(repeat);


note('--- all constructors should return Future::Strict object.');

{
    my $f = new_ok('Future::Strict');
    $f->done();
}

{
    my $f = new_ok('Future::Strict');
    my $g = $f->new();
    isa_ok($g, 'Future::Strict', '(obj)->new() should return Future::Strict');
    $f->done; $g->done;
}

foreach my $method (qw(followed_by and_then or_else)) {
    my $f = new_ok('Future::Strict');
    my $g = $f->$method(sub {
        return Future->new->done()
    });
    isa_ok($g, 'Future::Strict', "$method() should return Future::Strict");
    $f->done;
}

{
    my $f = new_ok('Future::Strict');
    my $g = $f->transform(done => sub { 1 }, fail => sub { 0 });
    isa_ok($g, 'Future::Strict', 'transform() should return Future::Strict');
    $f->done;
}

{
    my $ef = repeat {
        return Future::Strict->new->done;
    } while => sub { 0 }, return => Future::Strict->new;
    isa_ok($ef, 'Future::Strict', 'repeat() "while" should return Future::Strict');
}

{
    my $ef = repeat {
        return Future::Strict->new->done;
    } until => sub { 1 }, return => Future::Strict->new;
    isa_ok($ef, 'Future::Strict', 'repeat() "unless" should return Future::Strict');
}

foreach my $items ([], [1], [1,2,3]){
    my $size = @$items;
    my $ef = repeat {
        return Future::Strict->new->done;
    } foreach => $items, return => Future::Strict->new;
    isa_ok($ef, 'Future::Strict', "repeat() \"foreach\" with items size = $size should return Future::Strict");
}

foreach my $method (qw(wait_all wait_any needs_all needs_any)) {
    my @subf = map { Future::Strict->new } (1..3);
    my $f = Future::Strict->$method(@subf);
    isa_ok($f, 'Future::Strict', "$method() should return Future::Strict");
}

done_testing();
