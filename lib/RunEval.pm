package RunEval;

use strict;
use warnings;

use IPC::Run qw/run timeout/;
use Future;
use utf8;

sub common_transforms {
   my $input = shift;
  
   # Pretend every (eval \d+) is eval 1.  might cause it to miss some things but nothing important
   $input =~ s/\(eval \d+\)/(eval 1)/g;

   # TODO recorgnize paths to perlbrew/perl here and turn them all into PERLBREW_ROOT/perls/PERL_VERSION/...

   return $input;
}

sub compare_res {
    my ($res1, $res2) = @_;
    my $code = $res1->{code};

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
}

# Takes a code segment, returns a future that finishes when all results are ready
sub make_async {
    my ($code, $loop) = @_;

    my $first_future  = runner_async($code, $loop);
    my $second_future = runner_async($code, $loop);

    my $final_future = Future->needs_all($first_future, $last_future);

    $final_future->on_ready(\&future_to_result);

    return $final_future;
}

sub future_to_result {
    my ($final_future) = @_;

    my ($first_future, $second_future) = $final_future->done_futures;

    # unwrap the futures, pretending they gave empty hashes if they failed
    my $res1 = eval {$first_future->get} // {};
    my $res2 = eval {$second_future->get} // {};

    return compare_res($res1, $res2);
}

sub runner_async {
    my ($code, $loop) = @_;

    my $c_in = "perl $code";

    my $cmd = ['sudo', './runeval.sh'];
  
    my $proc_future = $loop->new_future();
    my $child_pid = $loop->run_child(command => $cmd, stdin => $c_in, on_finish => sub {
            my ($pid, $exitcode, $stdout, $stderr) = @_;

            $stdout = common_transforms $stdout;
            $stderr = common_transforms $stderr;

            $proc_future->done({code => $code, out => $stdout, err => $stderr});
        });

    my $killmepls = sub {
            kill 9, $child_pid; # Attempt to kill off the child, might need to do weird shit with root for this to work.
    };
    $proc_future->on_cancel($killmepls);
    $proc_future->on_failure($killmepls);

    my $timeout_future = $loop->timeout_future(after => 30);
    $timeout_future->on_failure(sub {$proc_future->cancel}); # make sure we cancel the proc future.

    return Future->wait_any($proc_future, $timeout_future);
}

sub runner_ipc {
    my ($code) = @_;
    my ($c_out, $c_err);

    my $c_in = "perl $code";

    my $cmd = ['sudo', './runeval.sh'];
    
    my $res = eval {run $cmd, \$c_in, \$c_out, \$c_err, timeout(30);};
   
    $c_out = common_transforms $c_out;
    $c_err = common_transforms $c_err;

    return {code => $code, out => $c_out, err => $c_err};
}

sub make_result {
    my ($code) = @_;

    # run it twice, record both results
    my $res1 = run_eval($code);
    my $res2 = run_eval($code);

    return compare_res($res1, $res2);
}

1;
