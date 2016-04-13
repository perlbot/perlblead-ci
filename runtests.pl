#!/usr/bin/env perl

use v5.20;
use feature qw/postderef/;

use strict;
use warnings;
no warnings 'experimental';

use Data::Dumper;
use JSON::MaybeXS;
use IPC::Run qw/run timeout/;
use utf8;
use open ':encoding(utf8)';
use Test::More;
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

my $tests = do {local $/; open(my $fh, "<t/filtered.json"); decode_json <$fh>};

for my $fn (keys $tests->%*) {
    my $size = $tests->{$fn}->@*;
    my $pct = $size * 0.10;
    for my $tn (0..$pct) {
        my ($c_out, $c_err);
        my $rand = rand()*($tests->{$fn}->@*);
        my $test = $tests->{$fn}[$rand];
        my $code = $test->{code};

        my $c_in = "perl $code";

        my $cmd = ['sudo', './runeval.sh'];
        
#        print STDERR "${fn}[$rand]: $code";
        eval {run $cmd, \$c_in, \$c_out, \$c_err, timeout(30);};

        unless ($@) {
            is($c_err, $test->{err}, "STDERR for ${fn}[$rand]: $code");
            is($c_out, $test->{out}, "STDOUT for ${fn}[$rand]: $code");
        } else {
            diag "Eval failed, $@";
        }
    }
}

done_testing();
