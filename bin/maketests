#!/usr/bin/env perl

use v5.20;
use feature qw/postderef/;

use strict;
use warnings;
use lib './lib';

use Data::Dumper;
use utf8;
use open ':utf8';
use RunEval;
use Storable qw/store/;

use IO::Async::Function;
use IO::Async::Loop;

sub debug {say @_ if $ENV{DEBUG}};

binmode \*STDOUT, ":encoding(utf8)";

print "Loading code\n";
my @code;

for my $fn (glob('evals/*.lst')) {
    open(my $fh, "<", $fn) or die "$!: $fn";

    while(my $c = <$fh>) {
    chomp $c;
    push @code, $c; # just slurp it!
    }
    close($fh);
}

my $loop = IO::Async::Loop->new();

# Filter out code that will have changing lengths, or other weird things that i just can't count on being stable in any way
@code = grep {$_ !~ /(ENV|%::|%main|->now|time|\$\^V|\$\^T|\$\^O|\$\^X|version|rand|Time::Piece|[@%]INC|\$\$\W|\$\]|\$code|Carp)/} @code;

# Make a future for everything! then go ahead and coallesce them.
my $counter = 0;
my @tests;

#@code = (q{binmode STDOUT; 'Just another Unicode hacker,' =~ tr[\x20-\x7f][\xff30-\xff5f]r;}, q{print q;This is a test;;});

my $cs = @code;

my %active_futures;

sub make_new_future {
    my ($cur_future) = @_;
    my $code = pop @code;

    if ($cur_future) { # don't do this if we're initting
        # TODO handle current future
        my $res = RunEval::future_to_result($cur_future);
        debug "Found Future" if (exists($active_futures{$cur_future}));
        delete $active_futures{$cur_future};
        debug "Future Ready\n\t" . Dumper($res);
        push @tests, $res if $res->{code};
    }

    if ($code) {
        # Replace ourselves with a new future
        my $p = sprintf "%0.02f%%", (100*$counter++)/($cs);
        say "Running $counter/$cs [$p] $code";
        
        my $new_fut =  RunEval::make_async($code, $loop);
        $new_fut->on_ready(__SUB__);
        $active_futures{$new_fut} = $new_fut;
    } else {
        # There's no more code, and no active futures.  We're done running.
        if (keys %active_futures == 0) {
            $loop->stop;
        }
    }
}

for (1..3) {
    make_new_future();
}
$loop->run;

# Filter out some most likely unstable outputs that i don't want to test
my $grepsub = sub {
       (length($_->{err} . $_->{out}) < 1024) # Ignore long outputs, they're unlikely to be stable (likely %INC and such)
    && !($_->{err} =~ /Unrecognized character/)
    && !($_->{err} =~ /Killed/
       ||$_->{out} =~ /Killed/)
};

@tests = grep {$grepsub->($_)} @tests;

store {tests => \@tests}, 't/defs.stor';

