package testlib::Generator;
use strict;
use warnings;
use Carp;
use Future::Strict;
use Future::Utils qw(repeat);

sub new {
    my ($class, $method, $num) = @_;
    my $self = bless {
        futures => [],
        first_state => $method,
        first_state_num => $num,
        last_state => undef,
        count => 0
    }, $class;
    if($method eq 'done') {
        push(@{$self->{futures}}, map { Future::Strict->new->done($_) } 1..$num);
        $self->{last_state} = "fail";
    }elsif($method eq 'fail') {
        push(@{$self->{futures}}, map { Future::Strict->new->fail($_) } 1..$num);
        $self->{last_state} = "done";
    }else {
        croak "method must be done or fail";
    }
    return $self;
}

sub describe {
    return "Generator($_[0]->{first_state}, $_[0]->{first_state_num})";
}

sub next {
    my ($self) = @_;
    $self->{count}++;
    my $method = $self->{last_state};
    return @{$self->{futures}} ? shift(@{$self->{futures}})
        : Future::Strict->new->$method($self->{count});
}

sub count {
    return $_[0]->{count};
}

sub while_loop {
    my ($self, $loop_count) = @_;
    return repeat {
        $self->next;
    } while => sub { $self->count < $loop_count };
}

sub until_loop {
    my ($self, $loop_count) = @_;
    return repeat {
        $self->next;
    } until => sub { $self->count >= $loop_count };
}

sub foreach_loop {
    my ($self, $loop_count) = @_;
    return repeat {
        $self->next;
    } foreach => [1 .. $loop_count];
}

package main;
use strict;
use warnings;
use Test::More;
use Future::Strict;
use FindBin;
use lib ("$FindBin::Bin");
use testlib::Utils qw(newf init_warn_handler test_log_num);

init_warn_handler;

sub gen {
    return testlib::Generator->new(@_);
}

note("--- Future::Utils::repeat function:");
note("---   Failed trial futures are considered handled.");
note("---   Handling eventual futures are up to the user.");

{
    my $loop_count = 10;
    foreach my $loop_type (qw(while until foreach)) {
        foreach my $case (
            {generator => gen(done => 15), warn_num => 0},
            {generator => gen(done => 5),  warn_num => 1},
            {generator => gen(fail => 15), warn_num => 1},
            {generator => gen(fail => 5),  warn_num => 0},
        ) {
            my $msg = $case->{generator}->describe . ", $loop_type: expect $case->{warn_num} warnings";
            my $method = "${loop_type}_loop";
            ## note("--- -- Try: " . $msg);
            test_log_num(sub {
                $case->{generator}->$method($loop_count);
                is($case->{generator}->count, $loop_count, "loop $loop_count times");
            }, $case->{warn_num}, $msg);
        }
    }
}


done_testing();

