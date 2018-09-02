
use Getopt::Advance::Types:api<2>;
use Getopt::Advance::Exception:api<2>;

unit module Getopt::Advance::Group:api<2>;

class OptionInfo {
    has $.long;
    has $.short;
    has $.type;
}

role Group {
    has $.owner;
    has @.infos;
    has $.optional = True;

    # @options are names of options in group
    submethod TWEAK(:@options) {
        @!infos = [];
        for @options {
            @!infos.push(
                OptionInfo.new(long => .long, short => .short, type => .type)
            );
        }
    }

    method usage( --> Str) {
        my $usage = "";

        $usage ~= $!optional ?? "+\[ " !! "+\< ";
        $usage ~= $!owner.get(.long eq "" ?? .short !! .long).usage() for @!infos;
        $usage ~= $!optional ?? " \]+" !! " \>+";
        $usage;
    }

    method has(Str:D $name, Str:D $type = WhateverType --> False) {
        for @!infos {
            if $type eq .type && ($name eq .long || $name eq .short) {
                return True;
            }
        }
    }

    method remove(Str:D $name, Str:D $type = WhateverType --> False) {
        for ^+@!infos -> $index {
            given @!infos[$index] {
                if $type eq .type && ($name eq .long || $name eq .short) {
                    @!infos.splice($index, 1);
                    return True;
                }
            }
        }
    }

    method check() { ... }

    method clone(*%_) {
        nextwith(
            owner => %_<owner> // $!owner,
            infos => %_<infos> // @!infos.clone,
            optional => %_<optional> // $!optional,
            |%_
        );
    }
}

class Group::Radio does Group {
    method check() {
        my $count = 0;

        for @!infos {
            my $name = .long eq "" ?? .short !! .long;
            $count += 1 if $!owner.get($name).has-value;
        }
        given $count {
            when 0 {
                unless $!optional {
                    ga-group-error("{self.usage}: Radio option group value is force required!");
                }
            }
            when * > 1 {
                ga-group-error("{self.usage}: Radio group value only allow set one!");
            }
        }
    }
}

class Group::Multi does Group {
    method check() {
        unless $!optional {
            my $count = 0;

            for @!infos {
                my $name = .long eq "" ?? .short !! .long;
                $count += 1 if $!owner.get($name).has-value;
            }
            if $count < +@!infos {
                ga-group-error("{self.usage}: Multi option group value is force required!");
            }
        }
    }
}
