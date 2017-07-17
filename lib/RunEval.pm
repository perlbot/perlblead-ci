package RunEval;
use v5.20;
use strict;
use warnings;

use IPC::Run qw/run timeout/;
use Future;
use Encode qw/encode decode/;
use utf8;
use Data::Dumper;
use FindBin;
use Sereal qw/encode_sereal/;

my %options;
my %replacements;
my $replacement_re;
sub init {
    # Get the version of the perl in test, v5.25.2
    my ($version_raw, $err) = _run_eval_ipc('"$^V"');
    die "$err" if $err;
    my $version_str = $version_raw =~ s/^v//ir;
    my (@version_parts) = $version_raw =~ /v(\d+)\.(\d+)\.(\d+)/g;

    my $perlbrewroot = $ENV{PERLBREW_ROOT};
    my $script_dir = $ENV{SCRIPTDIR} // '/home/ryan/workspace/perlblead-ci/bin';
    my $perl_interp = readlink($ENV{PERLBREW_ROOT}.'/perls/perlbot-intest/bin/perl');
    my ($detect_perl_ident) = ($perl_interp =~ m|^$ENV{PERLBREW_ROOT}/perls/([^/]+)/.*$|);

    my $perl_identity = $ENV{IDENT} // $detect_perl_ident // 'perlbot-blead';

    %options = (
        version_str => $version_str,
        version_commas => join(',', @version_parts),
        version_raw => $version_raw,
        perlbrew_root => $perlbrewroot,
        perl_ident => $perl_identity,
        script_dir => $script_dir,
        perl_intest => 'perlbot-intest',
    );
    %replacements = map { ($options{$_} => "%%".uc($_)."%%") } keys %options;
    my $restring = "(" . join('|', map {"\Q$_\E"} sort {length $b <=> length $a} keys %replacements). ")";
    $replacement_re = qr/$restring/;
}
init();

sub debug {say @_ if $ENV{DEBUG}};

sub common_transforms {
    my $input = "".shift();
  
    # If this dies on decoding, it means that things went differently in the eval and it's already decoded.  some weird evals do that, so handle this non-fatally
    my $uinput = "$input"; # make a copy...
    Encode::_utf8_on($uinput);
    $input = eval {decode("utf8", $uinput)} // $input;
    # Pretend every (eval \d+) is eval 1.  might cause it to miss some things but nothing important
    $input =~ s/\(eval \d+\)/(eval 1)/g;

#     use Data::Dumper;
#     warn "REGEX => $replacement_re\n";
#     warn "REPLACEMENTS => " . Dumper(\%replacements);
#     warn "BEFORE REPLACE => $input\n";
    #recorgnize paths to perlbrew/perl here and turn them all into PERLBREW_ROOT/perls/PERL_VERSION/...
    $input =~ s/$replacement_re/$replacements{$1}/eg;
#    warn "AFTER REPLACE  => $input\n";
    #          got: '/home/ryan/workspace/perlblead-ci/bin/runeval: line 5:   473 Terminated              /home/ryan/perl5/perlbrew/perls/perlbot-intest/bin/perl /home/ryan/bots/perlbuut/lib/eval.pl
    $input =~ s/line\s+\d+:\s+\d+\s+(Killed|Terminated)\s+/line N: PID $1 /g;

# not ok 85 - STDERR for: system "perl -v"
#   Failed test 'STDERR for: system "perl -v"'
#   at t/01-supereval.t line 75.
#          got: '%%SCRIPT_DIR%%/runeval: line 6: 21024 Bad system call         %%PERLBREW_ROOT%%/perls/%%PERL_INTEST%%/bin/perl /home/ryan/bots/perlbuut/lib/eval.pl
# '
#     expected: '%%SCRIPT_DIR%%/runeval: line 6: 10845 Bad system call         %%PERLBREW_ROOT%%/perls/%%PERL_INTEST%%/bin/perl /home/ryan/bots/perlbuut/lib/eval.pl
# '
#         MASK: '1111111111111111111111111111111111110111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111'
#          got: '%%SCRIPT_DIR%%/runeval: line 6: 2102^@ Bad system call         %%PERLBREW_ROOT%%/perls/%%PERL_INTEST%%/bin/perl /home/ryan/bots/perlbuut/lib/eval.pl
# '
#     expected: '%%SCRIPT_DIR%%/runeval: line 6: 1084^@ Bad system call         %%PERLBREW_ROOT%%/perls/%%PERL_INTEST%%/bin/perl /home/ryan/bots/perlbuut/lib/eval.pl
# '

    $input =~ s|line\s+6:\s+(\d+)|line 1: 1|g;

    return $input;
}

sub compare_res {
    my ($res1, $res2) = @_;
    my $code = $res1->{code};

    # This test likely timed out in one or both branches, dump it
    if (grep {!defined} map {($_->{code}, $_->{out}, $_->{err})} ($res1, $res2)) {
        return {};
    }

    if ((length $res1->{out} == length $res2->{out}) &&
        (length $res1->{err} == length $res2->{err})) {

        debug "RES1 OUT: ", $res1->{out};
        debug "RES2 OUT: ", $res2->{out};

        debug "RES1 ERR: ", $res1->{err};
        debug "RES2 ERR: ", $res2->{err};

        # We need to decode these, so that ^ works properly on them in perl 5.24+
        my $stderr_mask = encode("utf8", $res1->{err}) ^ encode("utf8", $res2->{err});
        my $stdout_mask = encode("utf8", $res1->{out}) ^ encode("utf8", $res2->{out});

        # turn everything except \0 into \xFF and anythign else into \0.
        $stderr_mask =~ s/(.)/$1 eq "\0" ? "\xFF" : "\0"/egsi;
        $stdout_mask =~ s/(.)/$1 eq "\0" ? "\xFF" : "\0"/egsi;

        # blob close matches together, likely the same digit in the same place kind of thing, we should try to compensate
        $stderr_mask =~ s/\x00\xFF\x00/\x00\x00\x00/g;
        $stderr_mask =~ s/\x00\xFF\xFF\x00/\x00\x00\x00\x00/g;
        $stderr_mask =~ s/\x00\x00\xFF\xFF\xFF/\x00\x00\x00\x00\x00\x00/g; # take care of the last 12 bits being stable in ASLR but not between versions
        $stderr_mask =~ s/\xFF\x00\x00/\x00\x00\x00/g; # Take care of a leading address digit in ASLR configs
        $stderr_mask =~ s/\x00\x00\xFF$/\x00\x00\x00/; # take care of a trailing digit usually
        $stderr_mask =~ s/^\xFF\x00\x00/\x00\x00\x00/; # similarly take care of leading digits

        $stdout_mask =~ s/\x00\xFF\x00/\x00\x00\x00/g;
        $stdout_mask =~ s/\x00\xFF\xFF\x00/\x00\x00\x00\x00/g;
        $stdout_mask =~ s/\x00\x00\xFF\xFF\xFF/\x00\x00\x00\x00\x00\x00/g; # take care of the last 12 bits being stable in ASLR but not between versions
        $stdout_mask =~ s/\xFF\x00\x00/\x00\x00\x00/g; # Take care of a leading address digit in ASLR configs
        $stdout_mask =~ s/\x00\x00\xFF$/\x00\x00\x00/; # take care of a trailing digit usually
        $stdout_mask =~ s/^\xFF\x00\x00/\x00\x00\x00/; # similarly take care of leading digits

        return {
            code => $code,
            out => $res1->{out},
            err => $res1->{err},
            out_mask => unpack("H*", $stdout_mask),
            err_mask => unpack("H*", $stderr_mask),
        }
    } else {
        $res1->{volatile} = 1;
        return $res1;
    }
}

# Takes a code segment, returns a future that finishes when all results are ready
sub make_async {
    my ($code, $loop) = @_;

    debug "Making Async";

    my $first_future  = runner_async($code, $loop);
    my $second_future = runner_async($code, $loop);

    debug "Spawned procs, creating Future->needs_all";

    my $final_future = Future->needs_all($first_future, $second_future);

    debug "Returning";
#    $final_future->on_ready(\&future_to_result);

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

    my $c_in = encode_sereal([$code, "perl"]);

    #$c_in = encode("utf8", $c_in); # we need to treat it as a raw byte stream because of a bug

    my $cmd = ['sudo', $FindBin::Bin . '/../bin/runeval'];
 
    debug "Code out is << $c_in >>";
    debug "cmd is", @$cmd;

    my $proc_future = $loop->new_future();
    my $child_pid = $loop->run_child(command => $cmd, stdin => $c_in, on_finish => sub {
            my ($pid, $exitcode, $stdout, $stderr) = @_;

            $stdout = common_transforms $stdout;
            $stderr = common_transforms $stderr;

            $proc_future->done({code => $code, out => $stdout, err => $stderr});
        });

    debug "Child pid is $child_pid";

    my $killmepls = sub {
            kill 9, $child_pid; # Attempt to kill off the child, might need to do weird shit with root for this to work.
    };
    $proc_future->on_cancel($killmepls);
    $proc_future->on_fail($killmepls);

    debug "Procfuture filled out";

    my $timeout_future = $loop->timeout_future(after => 30);
    $timeout_future->on_fail(sub {$proc_future->cancel}); # make sure we cancel the proc future.

    debug "timeout filled out";

    return Future->wait_any($proc_future, $timeout_future);
}

# Seperate sub that doesn't do any transforms, used for init
sub _run_eval_ipc {
    my ($code) = @_;
    my ($c_out, $c_err);

    my $c_in = encode_sereal([$code, "perl"]);

    #$c_in = encode("utf8", $c_in); # we need to treat it as a raw byte stream because of a bug
    my $cmd = ['sudo', $FindBin::Bin . '/../bin/runeval'];
    
    my $res = eval {run $cmd, \$c_in, \$c_out, \$c_err, timeout(30);};

    return ($c_out, $c_err);
}

sub runner_ipc {
    my ($code) = @_;
    
    my ($c_out, $c_err) = _run_eval_ipc($code);

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
