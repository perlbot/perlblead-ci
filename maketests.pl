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

binmode \*STDOUT, ":encoding(utf8)";

print "Loading code\n";
my @code;

for my $fn (glob('evals/*.lst')) {
    open(my $fh, "<", $fn) or die "$!: $fn";
    push @code, <$fh>; # just slurp it!
    close($fh);
}

my $loop = IO::Async::Loop->new();

my $func = IO::Async::Function->new(code => sub {
        my ($code, $count) = @_;
        print "[$count]: $code";

        my $res = RunEval::make_result($code);

        if ($res->{code}) {
            return $res;
        } else {
            print "FAILED TO EVAL!\n";
            return;
        }
});

$loop->add($function);

# Make a future for everything! then go ahead and coallesce them.
my $counter = 0;
my @futures = map {$function->call(args => [$_, $counter++])} @code;
my @tests = map {$_->get} @futures; 

open(my $test_out, ">t/defs.json") or die "$!: defs.json";
binmode($test_out, ":encoding(utf8)");
print $test_out encode_json({tests => \@tests});
close($test_out);
