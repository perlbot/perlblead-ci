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
    my $grepsub = sub {
           (length($_->{err} . $_->{out}) < 1024) # Ignore long outputs, they're unlikely to be stable (likely %INC and such)
        && !($_->{code} =~ /(ENV|%::|%main|->now|time|\$\^V|\$\^T|version|rand|Time::Piece|[@%]INC)/) 
        && !($_->{err} =~ /Unrecognized character/)
        && !($_->{out} =~ /(HASH|SCALAR|REF|ARRAY)\(0/) # ignore stuff with refs in output
    };

    my $mapsub = sub {
        $_->{err} =~ s/\(eval \d+\)/(eval 1)/g;
        $_->{out} =~ s/\(eval \d+\)/(eval 1)/g;
        $_
    };

    my @filtered = grep {!$grepsub->()} $data->{$f}->@*; 
    $data->{$f} = [map {$mapsub->()} grep {$grepsub->()} $data->{$f}->@* ];
}

open(my $fh, ">", "t/filtered.json");
print $fh encode_json($data);
close($fh);
