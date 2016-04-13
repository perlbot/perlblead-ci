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
binmode STDOUT, ":encoding(utf8)";
binmode STDERR, ":encoding(utf8)";
use List::Util qw/reduce/;


my $tests = do {local $/; open(my $fh, "<t/filtered.json"); decode_json <$fh>};
my $fulltests = reduce {[@$a, @$b]} map {$tests->{$_}} keys $tests->%*;

my $numtests = int(0.10 * @$fulltests);

plan tests => 2*$numtests;

    for my $tn (1..$numtests) {
        my ($c_out, $c_err);
        my $rand = rand()*($numtests);
        my $test = $fulltests->[$rand];
        my $code = $test->{code};

        my $c_in = "perl $code";

        my $cmd = ['sudo', './runeval.sh'];
        
#        print STDERR "${fn}[$rand]: $code";
        eval {run $cmd, \$c_in, \$c_out, \$c_err, timeout(30);};

        my $mapsub = sub {
            $c_err =~ s/\(eval \d+\)/(eval 1)/g;
            $c_out =~ s/\(eval \d+\)/(eval 1)/g;
        };
        $mapsub->();

        unless ($@) {
            is($c_err, $test->{err}, "STDERR for: $code");
            is($c_out, $test->{out}, "STDOUT for: $code");
        } else {
            diag "Eval failed, $@";
        }
    }

#done_testing();
