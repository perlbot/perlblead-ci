#!/usr/bin/env perl

use v5.20;
use feature qw/postderef/;

use strict;
use warnings;
no warnings 'experimental';

use Data::Dumper;
use JSON::MaybeXS;
use lib './lib';
use RunEval;

use utf8;
use open ':std', ':encoding(utf8)';
use Test::More;
use List::Util qw/reduce shuffle/;

use Encode qw/encode_utf8 decode_utf8/;

my $tests = do {local $/; open(my $fh, "<:raw","t/filtered.json"); decode_json <$fh>};
my $fulltests = reduce {[@$a, @$b]} map {$tests->{$_}} keys $tests->%*;

my $numtests = int(0.10 * @$fulltests);
my @testindexes = (shuffle (0..$#$fulltests))[1..$numtests];

plan tests => 2*$numtests;

    for my $tn (@testindexes) {
        my ($c_out, $c_err);
        my $test = $fulltests->[$tn];
        my $code = $test->{code};

        print Dumper($test);
#        print STDERR "${fn}[$rand]: $code";
        my $res = RunEval::runner_ipc($code);

        if ($res) {
            my ($c_out, $c_err, $t_out, $t_err) = ($res->{out}, $res->{err}, $test->{out}, $test->{err});
            my ($out_mask, $err_mask) = ($test->{out_mask}, $test->{err_mask});

            if ($out_mask) {
                $c_out &= $out_mask;
                $t_out &= $out_mask;
            }
            if ($err_mask) {
                $c_err &= $err_mask;
                $t_err &= $err_mask;
            }

            is($c_err, $t_err, "STDERR for: $code");
            is($c_out, $t_out, "STDOUT for: $code");
        } else {
            diag "Eval failed, $@";
        }
    }

#done_testing();
