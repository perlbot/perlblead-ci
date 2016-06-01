#!/usr/bin/env perl

use v5.20;
use feature qw/postderef/;

use strict;
use warnings;
use lib './lib';

use Data::Dumper;
use JSON::MaybeXS;
use utf8;
use open ':utf8';
use RunEval;

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


# Make a future for everything! then go ahead and coallesce them.
my $counter = 0;
my @tests;
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

for (1..4) {
    make_new_future();
}
$loop->run;

my $json = JSON::MaybeXS->new(utf8 => 0, pretty => 1);


open(my $test_out, ">t/defs.json") or die "$!: defs.json";
binmode($test_out, ":encoding(utf8)");
print $test_out $json->encode({tests => \@tests});
close($test_out);
