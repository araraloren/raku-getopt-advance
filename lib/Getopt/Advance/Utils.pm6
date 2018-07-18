
unit module Getopt::Advance::Utils:api<2>;

class Prefix is export {
    enum < LONG SHORT NULL DEFAULT >;
}

class MatchContext is export {
    has $.prefix;
    has $.name;
    has $.has-value;
    has &.pop-value;
    has $.success;

    method TWEAK() {
        $!success = False;
    }

    method mark-matched() {
        $!success = True;
    }

    method match-name($o) {
         given $!prefix {
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
                $o.?name eq $!name;
            }
         }
    }
}
