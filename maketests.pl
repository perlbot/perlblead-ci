#!/usr/bin/env perl

use v5.20;
use feature qw/postderef/;

use strict;
use warnings;

use Data::Dumper;
use JSON::MaybeXS;
use IPC::Run qw/run timeout/;

my %tests;

$ENV{PERL_HASH_SEED}=0xB075;
$ENV{PERL_PERTURB_KEYS}=0;

open(my $test_out, ">t/defs.json") or die "$!: defs.json";

for my $fn (glob('evals/*.lst')) {
    open(my $fh, "<", $fn) or die "$!: $fn";
    my $c = 0;
    while (my $code = <$fh>) {
        my ($c_out, $c_err);

        my $c_in = "perl $code";

        my $cmd = ['sudo', '/home/ryan/perl5/perlbrew/perls/perlbot-blead-intest/bin/perl', '/home/ryan/bots/perlbuut/lib/eval.pl'];
        $c++;
        
        print "${fn}[$c]: $code";
        eval {run $cmd, \$c_in, \$c_out, \$c_err, timeout(30);};

        unless ($@) {
            push $tests{$fn}->@*, {code => $code, out => $c_out, err => $c_err};
        } else {
            print "FAILED TO EVAL!\n";
        }
    }
    close($fh);
}

print $test_out encode_json(\%tests);
close($test_out);
