#!/usr/bin/env perl
# -*-mode:cperl; indent-tabs-mode: nil-*-

## Various code analysis

use 5.006;
use strict;
use warnings;
use Test::More;
use Data::Dumper;
select(($|=1,select(STDERR),$|=1)[1]);

if (! $ENV{RELEASE_TESTING}) {
    plan (skip_all =>  'Test skipped unless environment variable RELEASE_TESTING is set');
}

## The 'bucardo' script

my $file = 'bucardo';
my $fh;
if (! open $fh, '<', $file) {
    $file = "../$file";
    if (! open $fh, '<', $file) {
        BAIL OUT qq{Could not find the file '$file'!};
    }
}

check_subroutines($file, $fh);

check_whitespace($file, $fh);

check_hash_names($file, $fh);

close $fh or die qq{Could not close filehandle for "$file": $!\n};

pass "Scanned file $file";

$file = 'Bucardo.pm';
if (! open $fh, '<', $file) {
    $file = "../$file";
    if (! open $fh, '<', $file) {
        BAIL OUT qq{Could not find the file '$file'!};
    }
}

check_whitespace($file, $fh);

check_hash_names($file, $fh);

pass "Scanned file $file";

done_testing();

sub check_subroutines {

    ## Check that each subroutine has a contract stating a description line,
    ## an argument list, and what it returns
    ## Also check that the closing brace indicates the end of the sub
    ## Arguments: two
    ## 1. File name
    ## 2. file handle
    ## Returns: undef

    my $filename = shift;
    my $fh = shift;

    ## Rewind to the beginning
    seek $fh, 0, 0;

    my $subname = '';
    my %found;
    my $step = 1;

    ## Just in case, reset the line counter
    $. = 0;

    while (<$fh>) {

        ## Are we still in a subroutine?
        if ($subname) {

            ## Skip things that look like the end of the sub, but are not
            next if /^};$/;

            ## Check for the end of the subroutine
            if (/^}(.*)/) {

                ## Is there a comment indicating the end of the sub?
                my $end = $1;
                if ($end !~ /^ ## end of (\w+)$/) {
                    fail "No ending comment for sub ${filename}::$subname at line $.";
                }
                my $endname = $1;
                if ($endname ne $subname) {
                    fail "End of sub ${filename}::$subname has wrong name at line $.";
                }

                ## Did this subroutine have an 'Arguments' comment?
                if (! exists $found{argument}) {
                    fail "No argument line found for sub ${filename}::$subname";
                }
                delete $found{argument};

                ## Did this subroutine have a 'Returns' comment?
                if (! exists $found{returns}) {
                    fail "No returns line found for sub ${filename}::$subname";
                }
                delete $found{returns};

                if (! keys %found) {
                    pass "Subroutine ${filename}::$subname passed all tests";
                }
                undef %found;
                $subname = '';
                next;
            }

            ## Skip empty lines
            next if /^\s*$/;

            ## Make sure we have a description as the first comment
            if (1 == $step) {
                if (! /^\s*## [A-Z]/) {
                    fail "No description at start of sub ${filename}::$subname";
                }
                $step = 2;
                next;
            }

            ## Must state the number of arguments
            if (2 == $step) {
                ## Check for and process an "Arguments:" line
                if (/^\s*## Arguments: (\w+)/) {
                    my $word = $1;
                    if ($word !~ /^[a-z]/) {
                        fail "Argument line does not start with a lowercase letter for sub ${filename}::$subname";
                    }
                    $found{argument} = 1;
                    $step = 3;
                }
            }

            ## Must tell us what it returns
            if (3 == $step) {
                ## Check for an process a "Returns:" line
                if (/^\s*## Returns: \w.+/) {
                    $found{returns} = 1;
                    $step = 4;
                }
            }


        } ## end if inside a subroutine

        if (/^sub (\w+)/) {
            $subname = $1;
            $step = 1;
        }
    }

    ## Do *not* close the file handle!

    return;


} ## end of check_for_contract


sub check_whitespace {

    ## Check various whitespace rules
    ## Arguments: two
    ## 1. File name
    ## 2. file handle
    ## Returns: undef

    my $filename = shift;
    my $fh = shift;

    ## Rewind to the beginning
    seek $fh, 0, 0;

    my %found;

    ## Just in case, reset the line counter
    $. = 0;

    while (<$fh>) {

        if (/ +$/) {
            fail "Trailing whitespace found at line $. of file $filename";
        }
    }

    ## Do *not* close the file handle!

    return;


} ## end of check_whitespace


sub check_hash_names {

    ## Make sure our hashes stay simple
    ## Arguments: two
    ## 1. File name
    ## 2. file handle
    ## Returns: undef

    my $filename = shift;
    my $fh = shift;

    ## Rewind to the beginning
    seek $fh, 0, 0;

    my %found;

    ## Just in case, reset the line counter
    $. = 0;

    while (<$fh>) {
        next if /[mq]\{/;
        next if /(?:map|grep|first|eval) *\{/;
        while (m/(?<!q[wqrx])\{(.+?)\}/g) {
            my $word = $1;
            next if $word =~ /^q[wr]/;
            if ($word =~ /\w \w/) {
                fail "Invalid hash name ($word) at line $. of $filename";
            }
            last;
        }
    }

    ## Do *not* close the file handle!

    return;


} ## end of check_hash_names
