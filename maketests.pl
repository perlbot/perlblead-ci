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

my %tests;
binmode \*STDOUT, ":encoding(utf8)";

open(my $test_out, ">t/defs.json") or die "$!: defs.json";
binmode($test_out, ":encoding(utf8)");

for my $fn (glob('evals/*.lst')) {
    open(my $fh, "<", $fn) or die "$!: $fn";
    my $c = 0;
    while (my $code = <$fh>) {
        $c++;
        
        print "${fn}[$c]: $code";

        my $res = RunEval::make_result($code);

        if ($res->{code}) {
            push $tests{$fn}->@*, $res;
        } else {
            print "FAILED TO EVAL!\n";
        }
    }
    close($fh);
}

print $test_out encode_json(\%tests);
close($test_out);
