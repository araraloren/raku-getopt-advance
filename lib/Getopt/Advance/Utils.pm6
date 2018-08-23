
unit module Getopt::Advance::Utils:api<2>;

class Prefix is export {
    enum < LONG SHORT NULL DEFAULT >;
}

class Style is export {
    enum < XOPT LONG SHORT ZIPARG COMB BSD MAIN CMD POS DEFAULT >;
}

class Debug { ... }
class MatchContext { ... }

role Context {
    has $.success;

    method TWEAK() {
        $!success = False;
    }

    method markMatched() {
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
            self.markMatched();
            $o.set-value(&!getarg(), :callback);
            Debug::debug("    - OK! Set value {&!getarg()} for [{$o.usage}], shift args: {$o.need-argument}");
        }

        method gist() { "\{{$!prefix}, {$!name}{$!hasarg ?? ":" !! ""}\}" }
    }

    my constant MAXPOSSUPPORT = 10240;

    class NonOption does Context {
        has $.argument;

        method match(MatchContext $mc, $no) {
            my $style-r = $no.matchStyle($mc.style);
            my $name-r = do given $mc.style {
                when Style::MAIN {
                    $no.matchName("");
                }
                default {
                    $no.matchName($!argument.Str);
                }
            };
            my $index-r = do given $mc.style {
                when Style::MAIN {
                    $no.matchIndex(MAXPOSSUPPORT, -1);
                }
                default {
                    $no.matchIndex(MAXPOSSUPPORT, $!argument.index);
                }
            };
            Debug::debug("    - Match " ~ ($style-r && $name-r && $index-r ?? "Okay!" !! "Failed!"));
            return $style-r && $name-r && $index-r;
        }

        method set(MatchContext $mc, $no) {
            given $mc.style {
                when Style::MAIN {
                    $no.($no.owner, @$!argument);
                    Debug::debug("    - OK! Call {$mc.style} sub okay.");
                }
                default {
                    $no.($no.owner, $!argument);
                    $no.set-value($!argument.Str);
                    Debug::debug("    - OK! Call {$mc.style} sub okay.");
                }
            }
        }

        method gist() { "\{{self.argument.Str}\@{self.argument.?index}\}" }
    }

    class Main is NonOption {
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
                    Debug::debug("  - Match {$context.gist} <-> {$o.usage}");
                    if $context.match(self, $o) {
                        $context.set(self, $o);
                    } else {
                        Debug::debug("    - Falied!");
                        $matched = False;
                    }
                }
            }
            if $matched {
                Debug::debug("Call handler to shift argument.");
                $!handler.shiftArgs();
                $!handler.setSuccess();
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

sub shareSupply(Supply $s) is export {
    my $p = Promise;
    my $d = supply {
        whenever $p {
            whenever $s {
                .emit;
            }
        }
    } .share;
    return class :: {
        has $.p;
        has $.d;

        method Supply {
            $d;
        }

        method keep() {
            $!p.keep(True);
        }
    }.new(p => $p, d => $d);
}
