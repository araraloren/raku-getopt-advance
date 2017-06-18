
use Getopt::Advance::Exception;

constant BOOLEAN = "boolean";
constant INTEGER = "integer";
constant STRING  = "string";
constant FLOAT   = "float";
constant ARRAY   = "array";
constant HASH    = "hash";

role Option {
    method value { ... }
    method long returns Str { ... }
    method short returns Str { ... }
    method callback { ... }
    method optional returns Bool { ... }
    method annotation returns Str { ... }
    method default-value { ... }
    method set-value(Mu:D, Bool :$callback) { ... }
    method set-long(Str:D) { ... }
    method set-short(Str:D) { ... }
    method set-callback(&callback) { ... }
    method set-optional(Mu) { ... }
    method set-annotation(Str:D) { ... }
    method set-default-value(Mu:D) { ... }
    method has-value returns Bool { ... }
    method has-long returns Bool { ... }
    method has-short returns Bool { ... }
    method has-callback returns Bool { ... }
    method has-annotation returns Bool { ... }
    method has-default-value(Mu:D) returns Bool { ... }
    method reset-long { ... }
    method reset-short { ... }
    method reset-value { ... }
    method reset-callback { ... }
    method reset-annotation { ... }
    method type returns Str { ... }
    multi method ACCEPT(Str:D) { ... }
    multi method ACCEPT(Mu:D) { ... }
    method usage() returns Str {
        my Str $usage = "";

        $usage ~= "{self.short-prefix}{self.short}"
            if self.has-short;
        $usage ~= "|"
            if self.has-long && self.has-short;
        $usage ~= "{self.long-prefix}{self.long}"
            if self.has-long;
        $usage ~= "=<{self.type}>"
            if self.type ne BOOLEAN;

        return self.optional ?? "[{$usage}]" !! "\{{$usage}\}";
    }
    method clone(*%_) { ... }
}

class Option::Base does Option {
    constant LN = 0;
    constant SN = 1;

    has @.name;
    has &.callback;
    has $.optional;
    has $.annotation;
    has $.value;
    has $.default-value;

    method long {
        @!name[SN];
    }

    method short {
        @!name[LN];
    }

    method set-value(Mu:D $value, Bool :$callback) {
        if $callback.so && &!callback.defined {
            &!callback(self);
        }
        $!value = $value;
    }

    method set-long(Str:D $name) {
        @!name[LN] = $name;
    }

    method set-short(Str:D $name) {
        @!name[SN] = $name;
    }

    method set-callback(
        &callback where .signature ~~ :($, $) | :($)
    ) {
        &!callback = &callback;
    }

    method set-optional(Mu $optional) {
        $!optional = $optional.so;
    }

    method set-annotation(Str:D $annotation) {
        $!annotation = $annotation;
    }

    method set-default-value(Mu:D $value) {
        $!default-value = $value;
    }

    method has-value() returns Bool {
        $!value.defined;
    }

    method has-long() returns Bool {
        @!name[LN] ne "";
    }

    method has-short() returns Bool {
        @!name[SN] ne "";
    }

    method has-callback() returns Bool {
        &!callback.defined;
    }

    method has-annotation() returns Bool {
        $!annotation.defined;
    }

    method has-default-value() returns Bool {
        $!default-value.defined;
    }

    method reset-long {
        @!name[LN] = "";
    }

    method reset-short {
        @!name[SN] = "";
    }

    method reset-value {
        $!value = $!default-value;
    }

    method reset-callback {
        &!callback = Callable;
    }

    method reset-annotation {
        $!annotation = Mu;
    }

    method type() {
        die "{$?CLASS} has no type!";
    }

    multi method ACCEPT(Str:D $name) {
        $name eq self.long
            ||
        $name eq self.short;
    }

    multi method ACCEPT(Mu:D) {
        False;
    }

    method clone(*%_) {
        self.bless(
            name        => %_<name>   // @!name.clone,
            callback    => %_<callback> // &!callback.clone,
            optional    => %_<optional> // $!optional.clone,
            annotation  => %_<annotation> // $!annotation.clone,
            value       => %_<value> // $!value.clone,
            default-value=> %_<default-value> // $!default-value.clone
        );
        nextwith(|%_);
    }
}

class Option::Boolean is Option::Base {
    submethod TWEAK(:$value, :$deactivate) {
        if $deactivate {
            if $value.defined && !$value {
                &invalid-value("{self.usage()}: default value must be True in deactivate-style.");
            }
            $!default-value = $!value = True;
        }
    }

    method set-value(Bool:D $value, Bool :$callback) {
        callsame;
    }

    method type() {
        "boolean";
    }

    multi method ACCEPT(Mu:D) {
        True;
    }
}


class Option::Integer is Option::Base {
    submethod TWEAK(:$value) {
        if $value.defined {
            $!default-value = $value;
        }
    }

    method set-value(Mu:D $value, Bool :$callback) {
        if $value ~~ Int {
            callsame;
        } elsif so +$value {
            callwith(+$value, :$callback);
        } else {
            &invalid-value("{self.usage()}: Need integer.");
        }
    }

    method type() {
        "integer";
    }

    multi method ACCEPT(Mu:D $value) {
        $value ~~ Int || so +$value;
    }
}

class Option::Float is Option::Base {
    submethod TWEAK(:$value) {
        if $value.defined {
            $!default-value = $value;
        }
    }

    method set-value(FatRat:D $value, Bool :$callback) {
        if $value ~~ FatRat {
            callsame;
        } elsif so $value.FatRat {
            callwith($value.FatRat, :$callback);
        } else {
            &invalid-value("{self.usage()}: Need float.");
        }
    }

    method type() {
        "float";
    }

    multi method ACCEPT(Mu:D $value) {
        $value ~~ FatRat || so $value.FatRat; 
    }
}

class Option::String is Option::Base {
    submethod TWEAK(:$value) {
        if $value.defined {
            $!default-value = $value;
        }
    }

    method set-value(Str:D $value, Bool :$callback) {
        if $value ~~ Str {
            callsame;
        } elsif so ~$value {
            callwith(~$value, :$callback);
        } else {
            &invalid-value("{self.usage()}: Need string.");
        }
    }

    method type() {
        "string";
    }

    multi method ACCEPT(Mu:D $value) {
        $value ~~ Str || so ~$value;
    }
}

class Option::Hash is Option::Base {
    submethod TWEAK(:$value) {
        if $value.defined {
            unless $value ~~ Hash {
                &invalid-value("{self.usage()}: Need a Hash.");
            }
            $!value = $!default-value = $value;
        }
    }

    method set-value(Pair:D $value, Bool :$callback) {
        my %hash = $!value.defined ?? %$!value !! Hash.new;
        %hash.push($value);
        callwith(%hash, :$callback);
    }

    method type() {
        "hash";
    }

    multi method ACCEPT(Mu:D $value) {
        $value ~~ Pair || $value.^can("pairup");
    }
}

class Option::Array is Option::Base {
    submethod TWEAK(:$value) {
        if $value.defined {
            unless $value ~~ Positional {
                &invalid-value("{self.usage()}: Need an Positional.");
            }
            $!value = $!default-value = Array.new(|$value);
        }
    }

    method set-value($value, Bool :$callback) {
        my @array = $!value ?? @$!value !! Array.new;
        @array.push($value);
        callwith(@array, :$callback);
    }

    method type() {
        "array";
    }

    multi method ACCEPT(Mu:D $value) {
        True;
    }
}
