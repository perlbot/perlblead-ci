package RunEval;

use strict;
use warnings;

use IPC::Run qw/run timeout/;
use utf8;

sub run_eval {
    my ($code) = @_;
    my ($c_out, $c_err);

    my $c_in = "perl $code";

    my $cmd = ['sudo', './runeval.sh'];
    
    my $res = eval {run $cmd, \$c_in, \$c_out, \$c_err, timeout(30);};
    
    return {code => $code, out => $c_out, err => $c_err};
}

sub make_result {
    my ($code) = @_;

    # run it twice, record both results
    my $res1 = run_eval($code);
    my $res2 = run_eval($code);

    if ((length $res1->{out} == length $res2->{out}) &&
        (length $res1->{err} == length $res2->{err})) {
        my $stderr_mask = $res1->{err} ^ $res2->{err};
        my $stdout_mask = $res1->{out} ^ $res2->{out};

        # turn everything except \0 into \xFF and anythign else into \0.
        $stderr_mask =~ s/(.)/$1 eq "\0" ? "\xFF" : "\0"/eg;
        $stdout_mask =~ s/(.)/$1 eq "\0" ? "\xFF" : "\0"/eg;

        # blob close matches together, likely the same digit in the same place kind of thing, we should try to compensate
        $stderr_mask =~ s/\xFF\0\xFF/\xFF\xFF\xFF/g;
        $stderr_mask =~ s/\xFF\0\0\xFF/\xFF\xFF\xFF\xFF/g;

        $stdout_mask =~ s/\xFF\0\xFF/\xFF\xFF\xFF/g;
        $stdout_mask =~ s/\xFF\0\0\xFF/\xFF\xFF\xFF\xFF/g;

        return {
            code => $code,
            out => $res1->{out},
            err => $res1->{err},
            out_mask => $stdout_mask,
            err_mask => $stderr_mask,
        }
    } else {
        print "^^^ VOLATILE TEST!\n";
        return $res1;
    }

    return {};
}

1;
