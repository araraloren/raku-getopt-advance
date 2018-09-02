
use Getopt::Advance::Utils:api<2>;
use Getopt::Advance::Exception:api<2>;

unit module Getopt::Advance::Option:api<2>;

constant BOOLEAN  = "boolean";
constant INTEGER  = "integer";
constant STRING   = "string";
constant FLOAT    = "float";
constant ARRAY    = "array";
constant HASH     = "hash";

constant QUITBLOCK = sub (\ex) { };

role Option { ... }

multi sub tapTheParser(Mu:U \parser, Option $option) { }

multi sub tapTheParser(Supply:D \parser, Option $option) {
    parser.tap(
        #| should use anon sub, point block are transparent to "return"
        sub ($v) {
            if $v.style >= Style::XOPT && $v.style <= Style::BSD {
                $v.process($option);
            }
        }, 
        #| should have a quit named argument, or will not throw exception to outter
        quit => QUITBLOCK,
    );
}

role Option {
    has $.long              = "";
    has $.short             = "";
    has &.callback          = Callable;
    has Bool $.optional     = True;
    has Str $.annotation    = "";
    has $.value             = Any;
    has $.default-value     = Any;
    has $.owner             = Any;

    method value {
        $!value;
    }

    method long( --> Str) {
        $!long;
    }

    method short( --> Str) {
        $!short;
    }
    
    method callback {
        &!callback;
    }

    method optional( --> Bool) {
        $!optional;
    }

    method annotation( --> Str) {
        $!annotation;
    }

    method default-value {
        $!default-value;
    }

    method set-value(Mu $value, Bool :$callback) {
        if $callback.so && self.has-callback() {
            &!callback(self, $value);
        }
        $!value = $value;
    }

    method set-long(Str:D $!long) { }

    method set-short(Str:D $!short) { }

    method set-callback( &callback where .signature ~~ :($, $) | :($) ) { 
        &!callback = &callback;
    }

    method set-optional(Bool $!optional) { }

    method set-annotation(Str:D $!annotation) { }

    method set-default-value($!default-value) { }

    method set-owner($!owner) { }

    method set-parser(Supply:D $parser) {
        &tapTheParser($parser, self);
    }

    method has-value( --> Bool) {
        $!value.defined;
    }

    method has-long( --> Bool) {
        self.long() ne "";
    }

    method has-short( --> Bool) {
        self.short() ne "";
    }

    method has-callback( --> Bool) {
        &!callback.defined;
    }

    method has-annotation( --> Bool) {
        $!annotation ne "";
    }

    method has-default-value( --> Bool) {
        $!default-value.defined;
    }

    method reset-long {
        self.set-long("");
    }

    method reset-short {
        self.set-short("");
    }

    method reset-value {
        self.set-value(Any);
    }

    method reset-callback {
        &!callback = Callable;
    }

    method reset-annotation {
        self.set-annotation("");
    }
    
    method type( --> Str) { ... }

    method check() {
        return self.optional() || self.has-value();
    }

    method match-name(Str:D $name) {
        $name eq self.long || $name eq self.short;
    }

    method match-value(Mu) { ... }

    method lprefix { '--' }

    method sprefix { '-' }

    method need-argument( --> Bool) { True; }

    method usage( --> Str) {
        my Str $usage = "";

        $usage ~= "{self.sprefix}{self.short}"
            if self.has-short;
        $usage ~= "|"
            if self.has-long && self.has-short;
        $usage ~= "{self.lprefix}{self.long}"
            if self.has-long;
        $usage ~= "=<{self.type}>"
            if self.type ne BOOLEAN;

        return $usage;
    }

    method clone() {
        nextwith(
            long        => %_<long> // $!long.clone,
            short       => %_<short> // $!short.clone,
            callback    => %_<callback> // &!callback.clone,
            optional    => %_<optional> // $!optional.clone,
            annotation  => %_<annotation> // $!annotation.clone,
            value       => %_<value> // $!value.clone,
            owner       => %_<owner>,
            default-value=> %_<default-value> // $!default-value.clone,
            |%_
        );
    }
}

class Option::Boolean does Option {
    has $!deactivate;

    submethod TWEAK(:$value, :$deactivate) {
        $!deactivate = $deactivate;
        if $deactivate {
            if $value.defined && !$value {
                ga-invalid-value("{self.usage()}: default value must be True in deactivate-style.");
            }
            self.set-default-value(True);
            self.set-value(True, :!callback);
        } else {
            if $value.defined {
                self.set-default-value($value);
                self.set-value($value, :!callback);
            }
        }
    }

    method set-value(Mu $value, Bool :$callback) {
        self.Option::set-value($value.so, :$callback);
    }

    method type() {
        BOOLEAN;
    }

    method lprefix(--> Str) { $!deactivate ?? '--/' !! '--' }

    method sprefix(--> Str) { $!deactivate ?? '-/' !! '-' }

    method need-argument(--> Bool) { False; }

    method match-value(Mu:D $value) {
        if $!deactivate && $value {
            Debug::warn("Only support deactivate style {self.usage()}");
        }
        return ! ( $!deactivate && $value.so );
    }

    method clone() {
        nextwith(
            deactivate => %_<deactivate> // $!deactivate,
            |%_,
        );
    }
}

class Option::Integer does Option {
    submethod TWEAK(:$value) {
        if $value.defined {
            self.set-default-value($value);
            self.set-value($value, :!callback);
        }
    }

    method set-value(Mu:D $value, Bool :$callback) {
        if $value ~~ Int {
            self.Option::set-value($value, :$callback);
        } elsif so +$value {
            self.Option::set-value(+$value, :$callback);
        } else {
            ga-invalid-value("{self.usage()}: Need an integer.");
        }
    }

    method type() {
        INTEGER;
    }

    method match-value(Mu:D $value) {
        $value ~~ Int || so +$value;
    }
}

class Option::Float does Option {
    submethod TWEAK(:$value) {
        if $value.defined {
            self.set-default-value($value);
            self.set-value($value, :!callback);
        }
    }

    method set-value(Mu:D $value, Bool :$callback) {
        if $value ~~ FatRat {
            self.Option::set-value($value, :$callback);
        } elsif so $value.FatRat {
            self.Option::set-value($value.FatRat, :$callback);
        } else {
            ga-invalid-value("{self.usage()}: Need float.");
        }
    }

    method type() {
        FLOAT;
    }

    method match-value(Mu:D $value) {
        $value ~~ FatRat || so $value.FatRat;
    }
}

class Option::String does Option {
    submethod TWEAK(:$value) {
        if $value.defined {
            self.set-default-value($value);
            self.set-value($value, :!callback);
        }
    }

    method set-value(Mu:D $value, Bool :$callback) {
        if $value ~~ Str {
            self.Option::set-value($value, :$callback);
        } elsif so ~$value {
            self.Option::set-value(~$value, :$callback);
        } else {
            ga-invalid-value("{self.usage()}: Need string.");
        }
    }

    method type() {
        STRING;
    }

    method match-value(Mu:D $value) {
        $value ~~ Str || so ~$value;
    }
}

class Option::Array does Option {
    submethod TWEAK(:$value) {
        if $value.defined {
            unless $value ~~ Positional {
                ga-invalid-value("{self.usage()}: Need an Positional.");
            }
            $!value = $!default-value = Array.new(|$value);
        }
    }

    method value {
        $!value ?? @$!value !! Array;
    }

    # This actually is a push-value
    method set-value($value, Bool :$callback) {
        my @array = $!value ?? @$!value !! Array.new;
        @array.push($value);
        self.Option::set-value(@array, :$callback);
    }

    method type() {
        ARRAY;
    }

    method match-value(Mu:D $value) {
        True;
    }
}

class Option::Hash does Option {
    submethod TWEAK(:$value) {
        if $value.defined {
            unless $value ~~ Hash {
                ga-invalid-value("{self.usage()}: Need a Hash.");
            }
            $!value = $!default-value = $value;
        }
    }

    method value {
        $!value ?? %$!value !! Hash;
    }

    # This actually is a push-value
    method set-value(Mu:D $value, Bool :$callback) {
        my %hash = self.has-value() ?? %$!value !! Hash.new;
        if $value ~~ Pair {
            %hash.push($value);
        } elsif try so $value.pairup {
            %hash.push($value.pairup);
        } elsif (my $evalue = self!parse-as-pair($value)) {
            %hash.push($evalue);
        } else {
            ga-invalid-value("{self.usage()}: Need a Pair.");
        }
        self.Option::set-value(%hash, :$callback);
    }

    my grammar Pair::Grammar {
        token TOP { ^ <pair> $ }

        proto rule pair {*}

        rule pair:sym<arrow> { <key> '=>' <value> }

        rule pair:sym<colon> { ':' <key> '(' $<value> = (.+ <!before $>) ')' }

    	rule pair:sym<angle> { ':' <key> '<' $<value> = (.+ <!before $>) '>' }

        rule pair:sym<true> { ':' <key> }

        rule pair:sym<false> { ':' '!' <key> }

        token value { .+ }

        token key { <[0..9A..Za..z\-_\'\"]>+ }
    }

    my class Pair::Actions {
        method TOP($/) { $/.make: $<pair>.made; }

        method pair:sym<arrow>($/) {
            $/.make: $<key>.made => $<value>.Str;
        }

        method pair:sym<colon>($/) {
            $/.make: $<key>.made => $<value>.Str;
        }

        method pair:sym<true>($/) {
            $/.make: $<key>.made => True;
        }

        method pair:sym<false>($/) {
            $/.make: $<key>.made => False;
        }

        method pair:sym<angle>($/) {
            $/.make: $<key>.made => $<value>.Str;
        }

        method value($/) {
            $/.make: ~$/;
        }

        method key($/) {
            $/.make: ~$/;
        }
    }

    method !parse-as-pair($value) {
        my $r = Pair::Grammar.parse($value, :actions(Pair::Actions));

        return $r.made if $r;
    }

    method type() {
        HASH;
    }

    method match-value(Mu:D $value) {
        $value ~~ Pair || (try so $value.pairup) || Pair::Grammar.parse($value).so;
    }
}

