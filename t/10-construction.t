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
    fail('TODO: Future::Util::repeat() should return Future::Strict');
}

done_testing();
