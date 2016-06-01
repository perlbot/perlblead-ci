#!/usr/bin/env perl

use strict;
use warnings;

use utf8;

use IO::Async::Loop;
use Data::Dumper;

my $loop = IO::Async::Loop->new();

# This line actually has the greek question mark unicode character as the first semicolon
my $stdin = 'print q;This is a test;;';

my $child = $loop->run_child(command => "/bin/cat", stdin => $stdin, on_finish => sub {print Dumper(\@_); $loop->stop});

$loop->run;

print "I died before I got here";
