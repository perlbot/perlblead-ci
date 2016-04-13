#!/usr/bin/env perl

use feature 'postderef';

use JSON::MaybeXS;
use Data::Dumper;
    use open ':encoding(utf8)';
    use utf8;

my $json = do {local $/; open(my $fh, "<", "t/defs.json"); <$fh>};
my $data = decode_json $json;

my ($dc, $lc, $ic);

for my $f (keys $data->%*) {
    $data->{$f} = [grep {(length($_->{err} . $_->{out}) < 1024) && !($_->{code} =~ /ENV|%::|%main|->now|time|\$^V/) && !($_->{err} =~ /Unrecognized character/) } $data->{$f}->@* ];
}

open(my $fh, ">", "t/filtered.json");
print $fh encode_json($data);
close($fh);
