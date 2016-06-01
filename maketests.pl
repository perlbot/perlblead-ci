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
    push @code, <$fh>; # just slurp it!
    close($fh);
}

my $loop = IO::Async::Loop->new();


# Make a future for everything! then go ahead and coallesce them.
my $counter = 0;
my @tests;
my $cs = @code;

for my $c (@code[0..100]) {
    chomp $c;
    my $p = sprintf "%0.02f%%", (100*$counter++)/($cs);
    say "Running $counter/$cs [$p] $c";

    my $fut = RunEval::make_async($c, $loop);

    debug "Got future, waiting on it";

    while(!$fut->is_ready) {sleep 1; $loop->loop_once(); debug "waiting ", $fut->is_ready;};

    debug "Future is done!";

    my $res = RunEval::future_to_result($fut);

    debug "Ran $c!\n\t" . Dumper($res);
    #debug "Masks out: ";
    #debug unpack("H*", $res->{out_mask});
    #debug unpack("H*", $res->{err_mask});

    $res->{code} = $c if $res->{code};

    push @tests, $res if $res->{code};
}

my $json = JSON::MaybeXS->new(utf8 => 0, pretty => 1);


open(my $test_out, ">t/defs.json") or die "$!: defs.json";
#binmode($test_out, ":encoding(utf8)");
print $test_out $json->encode({tests => \@tests});
close($test_out);
