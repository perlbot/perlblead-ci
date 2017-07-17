#!/usr/bin/env perl

use v5.20;
use feature qw/postderef/;

use strict;
use warnings;
no warnings 'experimental';

use Data::Dumper;
use JSON::MaybeXS;
use FindBin;
use lib "$FindBin::Bin/../lib";

use RunEval;

use utf8;
use open ':std', ':encoding(utf8)';
use Test::More;
use List::Util qw/reduce shuffle/;
use Storable;

use Encode qw/encode_utf8 decode_utf8 encode/;

my $builder = Test::More->builder;

sub is_eq_mask {
    my($got, $expect, $masq, $name ) = @_;
 
    my $expect_masq = encode("utf8", "$expect"); #encode_utf8($expect);
    my $got_masq = encode("utf8", "$got"); #encode_utf8($got);

    my $rmasq = pack("H*", $masq);

    if ($masq) { 
        $expect_masq &= $rmasq;
        $got_masq &= $rmasq;
    }
 
    if( !defined $got || !defined $expect ) {
        # undef only matches undef and nothing else
        my $test = !defined $got && !defined $expect;
 
        $builder->ok( $test, $name );
        unless ($test) {
            $builder->_is_diag( $got, 'eq', $expect );
            $builder->diag(sprintf q{        MASK: '%s'}, $masq =~ s/(..)/$1 eq 'ff' ? '1' : '0'/egr); 
            $builder->_is_diag($got_masq, 'eq', $expect_masq);
        };
        return $test;
    }

    my $test = $got_masq eq $expect_masq;
    my $ok = $builder->ok($test, $name);

    unless ($ok) {
        $builder->_is_diag($got, 'eq', $expect);
        $builder->diag(sprintf q{        MASK: '%s'}, $masq =~ s/(..)/$1 eq 'ff' ? '1' : '0'/egr); 
        $builder->_is_diag($got_masq, 'eq', $expect_masq);
    }

    return $test;
}


sub test_res {
    my ($res, $test) = @_;

    my $code = $res->{code};

    if ($res) {
        my ($c_out, $c_err, $t_out, $t_err) = ($res->{out}, $res->{err}, $test->{out}, $test->{err});
        my ($out_mask, $err_mask) = ($test->{out_mask}, $test->{err_mask});

        is_eq_mask($c_err, $t_err, $err_mask, "STDERR for: $code");
        is_eq_mask($c_out, $t_out, $out_mask, "STDOUT for: $code");
    }
    
    return;
}

# result is the generated one here.  $test is the one from the file
sub run_test {
    my ($test) = @_;
    
    my $code = $test->{code};

    my $res = RunEval::runner_ipc($code);

    test_res($res, $test); # check it with normal display if it fails
}

#my $tests = do {local $/; open(my $fh, "<:raw","t/filtered.json"); decode_json <$fh>};
#my $fulltests = reduce {[@$a, @$b]} map {$tests->{$_}} keys $tests->%*;
my $tests = retrieve "$FindBin::Bin/../t/defs.stor";
my $fulltests = $tests->{tests};

my $numtests = int(0.10 * @$fulltests);
my @testindexes = (shuffle (0..$#$fulltests))[1..$numtests];

plan tests => 2*$numtests;

for my $tn (@testindexes) {
    my $test = $fulltests->[$tn];

    run_test($test);
}

#done_testing();
