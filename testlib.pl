#!/usr/bin/env perl

use strict;
use warnings;

use lib './lib';

use RunEval;

use Data::Dumper;

my $code = q[my $q={}; "FOO $q\n\n"];

my $res = RunEval::make_result($code);
print Dumper($res, unpack("H*", $res->{out_mask}));
