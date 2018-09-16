#!/usr/bin/env perl6

use Getopt::Advance::Parser;
use Getopt::Advance::Option;
use Getopt::Advance::Utils;
use Getopt::Advance::Types;
use Getopt::Advance::NonOption;

class OptionSet {
    has Supplier $!p = Supplier.new;
    has %!supply;
    has $.error;

    multi method add(Str $opt) {
        %!supply{$opt} = $!p.Supply;
    }

    multi method add(Str $opt, Supply $supply) {
        %!supply{$opt} = $supply;
    }

    method opt(Str $opt) {
        state %supply;
        if ! (%supply{$opt}:exists) {
            %supply{$opt} = supply {
                whenever %!supply{$opt} {
                    if $opt eq $_ {
                        emit ($opt, self);
                    }
                }
            }
        }
        %supply{$opt};
    }

    method fire-error() {
        # $!p.done;
        $!p.quit( "we are family" );
    }

    method parse(@args) {
         supply {
             for @args {
                fail "ERROR !" if $!error;
                my $arg = .substr(1);
                note "GET ", $arg;
                $!p.emit($arg);
            }
            emit 1;
        }
    }
}

my $os = OptionSet.new;

$os.add("w");
$os.add("f");
$os.opt("w").tap( -> ($opt, $v) {
    say "add tap success";
});

sub share(Promise $p, Supply $s) {
    supply {
        whenever $p {
            whenever $s {
                .emit;
            }
        }
    } .share;
}

my $parser = ga-parser(@*ARGS, :bsd-style, :long, :short, :xopt, :ziparg, :comb);

my $tm = TypesManager.new
        .register('b', Option::Boolean)
        .register('i', Option::Integer)
        .register('s', Option::String)
        .register('a', Option::Array)
        .register('h', Option::Hash)
        .register('f', Option::Float)
        .register('p', NonOption::Pos);

$parser = share(my $p = Promise.new, $parser);

Debug::setLevel(0);

my $bool1 = $tm.create("a|action=b", supply => $parser);
my $bool2 = $tm.create("f|float=f", supply => $parser);
my $cmd   = $tm.create("abc=p", index => 0, callback => sub () { say "callme"; }, supply => $parser);

dd $bool1;
dd $bool2;
dd $cmd;

react {
    whenever $parser {
        Debug::debug("GET IN WHENEVER {$_}");
        LAST {
            say "GO TO LAST";
        }
        QUIT {
            say "456";
        }
    }
    $p.keep(1);
}

say $bool1;
say $bool2;
