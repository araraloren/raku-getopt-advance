
unit module Getopt::Advance::Utils:api<2>;

constant MAXPOSSUPPORT is export = 10240;

class Prefix is export {
    enum < LONG SHORT NULL DEFAULT >;
}

class Style is export {
    enum < XOPT LONG SHORT ZIPARG COMB BSD MAIN CMD POS DEFAULT >;
}

class Debug { ... }
class MatchContext { ... }

role RefOptionSet is export {
    has $.owner;

    method set-owner($!owner) { }

    method owner() { $!owner; }
}

role Context is export {
    has $.success;

    method TWEAK() {
        $!success = False;
    }

    method mark-matched() {
        $!success = True;
    }

    method match(MatchContext , $o) { ... }

    method set(MatchContext , $o) { ... }

    method gist() { ... }
}

class MatchContext is export {
    class Option does Context {
        has $.prefix;
        has $.name;
        has $.hasarg;
        has &.getarg;

        method match(MatchContext $mc, $o) {
            my $name-r = do given $!prefix {
                    when Prefix::LONG {
                        $o.long eq $!name;
                    }
                    when Prefix::SHORT {
                        $o.short eq $!name;
                    }
                    when Prefix::NULL {
                        $o.long eq $!name || $o.short eq $!name
                    }
                    default {
                        False;
                    }
                };
            my $value-r = False;

            if $o.need-argument == $!hasarg {
                Debug::debug("    - Match value [{&!getarg()}] for [{$o.usage}]");
                $value-r = &!getarg.defined ?? $o.match-value(&!getarg()) !! True;
            }
            return $name-r && $value-r;
        }

        method set(MatchContext $mc, $o) {
            self.mark-matched();
            $o.set-value(&!getarg(), :callback);
            Debug::debug("    - OK! Set value {&!getarg()} for [{$o.usage}], shift args: {$o.need-argument}");
        }

        method gist() { "\{{$!prefix}, {$!name}{$!hasarg ?? ":" !! ""}\}" }
    }

    class NonOption does Context {
        has $.argument;

        method match(MatchContext $mc, $no) {
            my $style-r = $no.match-style($mc.style);
            my $name-r = do given $mc.style {
                when Style::MAIN {
                    $no.match-name("");
                }
                when Style::CMD {
                    $no.match-name(@($!argument)[0].Str);
                }
                default {
                    $no.match-name($!argument.Str);
                }
            };
            my $index-r = do given $mc.style {
                when Style::MAIN {
                    $no.match-index(MAXPOSSUPPORT, -1);
                }
                when Style::CMD {
                    $no.match-index(MAXPOSSUPPORT, 0);
                }
                default {
                    $no.match-index(MAXPOSSUPPORT, $!argument.index);
                }
            };
            my $check-r = $style-r && $name-r && $index-r;
            my $call-r = $check-r && do {
                given $mc.style {
                    when Style::MAIN {
                        Debug::debug("    - Try call {$mc.style} sub.");
                        $no.($no.owner, @$!argument);
                    }
                    when Style::CMD {
                        my @realargs = @($!argument).[1..*-1];
                        Debug::debug("    - Try call {$mc.style} sub.");
                        $no.($no.owner, @realargs);
                    }
                    default {
                        Debug::debug("    - Try call {$mc.style} sub.");
                        $no.($no.owner, $!argument);
                    }
                }
            };
            Debug::debug("    - Match " ~ ($call-r ?? "Okay!" !! "Failed!"));
            return $call-r;
        }

        method set(MatchContext $mc, $no) { }

        method gist() { "\{{self.argument.Str}\@{self.argument.?index}\}" }
    }

    class MainOrCmd is NonOption {
        method gist() {
            my $gist = "\{";
            $gist ~= [ "{.Str}\@{.index}" for @(self.argument) ].join(",");
            $gist ~ '}';
        };
    }

    has $.style;
    has @.contexts;
    has $.handler;

    method matched() {
        $!handler.success;
    }

    method process($o) {
        if $!handler.success {
            Debug::debug("- Skip  [{self.style}|{self.contexts>>.gist.join(" + ")}]");
        } else {
            Debug::debug("- Match [{self.style}|{self.contexts>>.gist.join(" + ")}] <-> {$o.usage}");
            my $matched = True;
            for @!contexts -> $context {
                if ! $context.success {
                    Debug::debug("  - Match {$context.gist} <=> {$o.usage}");
                    if $context.match(self, $o) {
                        $context.set(self, $o);
                    } else {
                        Debug::debug("    - Falied!");
                        $matched = False;
                    }
                }
            }
            if $matched {
                if $o.?need-argument {
                    Debug::debug("  - Call handler to shift argument.");
                    $!handler.skip-next-arg();
                }
                $!handler.set-success();
            }
        }
    }
}

class Debug is export {
    enum < DEBUG INFO WARN ERROR DIE NOLOG >;

    subset LEVEL of Int where { $_ >= DEBUG.Int && $_ <= ERROR.Int };

    our $g-level = DEBUG;

    our sub setLevel(LEVEL $level) {
        $g-level = $level;
    }

    our sub print(Str $log, LEVEL $level = $g-level) {
        if $level >= $g-level {
            note sprintf "[%-5s]: %s", $level, $log;
        }
    }

    our sub debug(Str $log) {
        Debug::print($log, Debug::DEBUG);
    }

    our sub info(Str $log) {
        Debug::print($log, Debug::INFO);
    }

    our sub warn(Str $log) {
        Debug::print($log, Debug::WARN);
    }

    our sub error(Str $log) {
        Debug::print($log, Debug::ERROR);
    }

    our sub die(Str $log) {
        die $log;
    }
}

sub share-supply(Supply $s) is export {
    my $p   = Promise.new;
    my $sup = Supplier.new;
    my $s2  = supply {
        whenever $p {
            whenever $s {
                .emit;
                LAST { say 1111; }
                QUIT { say 2222; }
            }
            LAST { say 33333; }
            QUIT { say 44444; }
        }
        LAST { say 15555; }
        QUIT { say 16666; }
    };
    $s2.tap(
        sub (\msg) { $sup.emit(msg); },
        done => sub () { $sup.done(); },
        quit => sub (\ex) { $sup.quit(ex); }
    );
    return class :: {
        has $.p;
        has $.d;

        method Supply {
            $!d;
        }

        method keep() {
            $!p.keep(1);
        }
    }.new(p => $p, d => $sup.Supply);
}
