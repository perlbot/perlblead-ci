
#!/usr/bin/env perl

use v5.20;
use feature qw/postderef/;

use strict;
use warnings;

use Data::Dumper;
use JSON::MaybeXS;
use IPC::Run qw/run timeout/;

my $tests = do {local $/; open(my $fh, "<t/filtered.json"); decode_json <$fh>};

for my $fn (keys $tests->%*) {
    for my $tn (0..10) {
        my ($c_out, $c_err);
        my $rand = rand()*($tests->{$fn}->@*);
        my $test = $tests->{$fn}[$rand];
        my $code = $test->{code};

        my $c_in = "perl $code";

        my $cmd = ['sudo', '/home/ryan/perl5/perlbrew/perls/perlbot-blead-intest/bin/perl', '/home/ryan/bots/perlbuut/lib/eval.pl'];
        
        print "${fn}[$rand]: $code";
        eval {run $cmd, \$c_in, \$c_out, \$c_err, timeout(30);};

        unless ($@) {
            if ($test->{err} eq $c_err) {
                print "ok\n";
            } else {
                print "not ok # expected '",$test->{err},"' got '",$c_err,"'\n";
            }
            if ($test->{out} eq $c_out) {
                print "ok\n";
            } else {
                print "not ok # expected '",$test->{out},"' got '",$c_out,"'\n";
            }
        } else {
            print "not ok # failed to eval $@\n";
        }
    }
}
