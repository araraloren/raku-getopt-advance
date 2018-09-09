
use Getopt::Advance::Utils:api<2>;

unit module Getopt::Advance::Context:api<2>;

role Context is export {
    has $.success;

    method TWEAK() {
        $!success = False;
    }

    method mark-matched() {
        $!success = True;
    }

    method match(ContextProcesser, $o) { ... }

    method set(ContextProcesser, $o) { ... }

    method gist() { ... }
}

class TheContext is export {
    class Option does Context {
        has $.prefix;
        has $.name;
        has $.hasarg;
        has &.getarg;

        method match(ContextProcesser $cp, $o) {
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
            Debug::debug("    - Match " ~ ($name-r && $value-r ?? "Okay!" !! "Failed!"));
            return $name-r && $value-r;
        }

        method set(ContextProcesser $cp, $o) {
            self.mark-matched();
            $o.set-value(&!getarg(), :callback);
            Debug::debug("    - OK! Set value {&!getarg()} for [{$o.usage}], shift args: {$o.need-argument}");
        }

        method gist() { "\{{$!prefix}, {$!name}{$!hasarg ?? ":" !! ""}\}" }
    }

    class NonOption does Context {
        has @.argument;
        has $.index;

        method match(ContextProcesser $cp, $no) {
            my $style-r = $no.match-style($cp.style);
            my $name-r  = $style-r && do given $cp.style {
                when Style::MAIN {
                    $no.match-name("");
                }
                default {
                    $no.match-name(@!argument[$!index].Str);
                }
            };
            my $index-r = $name-r && $no.match-index(+@!argument, $!index);
            my $call-r  = $index-r && do {
                given $cp.style {
                    when Style::POS | Style::WHATEVERPOS {
                        Debug::debug("    - Try call {$cp.style} sub.");
                        $no.($no.owner, @!argument[$!index]);
                    }
                    when Style::CMD {
                        my @realargs = @!argument[1..*-1];
                        Debug::debug("    - Try call {$cp.style} sub.");
                        $no.($no.owner, @realargs);
                    }
                    default {
                        Debug::debug("    - Try call {$cp.style} sub.");
                        $no.($no.owner, @!argument);
                    }
                }
            };
            Debug::debug("    - Match " ~ ($call-r ?? "Okay!" !! "Failed!"));
            return $call-r;
        }

        method set(ContextProcesser $cp, $no) { }

        method gist() {
            my $gist = "\{";
            $gist ~= [ "{.Str}\@{.index}" for self.argument ].join(",");
            $gist ~ '}';
        };
    }

    class Pos is NonOption {
        method gist() {
            given self.argument[self.index] {
                "\{{.Str}\@{.index}\}";
            }
        }
    }
}