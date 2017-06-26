
use Getopt::Advance::Exception;

constant BOOLEAN is export = "boolean";
constant INTEGER is export = "integer";
constant STRING  is export = "string";
constant FLOAT   is export = "float";
constant ARRAY   is export = "array";
constant HASH    is export = "hash";

role Option {
    method value { ... }
    method long returns Str { ... }
    method short returns Str { ... }
    method callback { ... }
    method optional returns Bool { ... }
    method annotation returns Str { ... }
    method default-value { ... }
    method set-value(Mu, Bool :$callback) { ... }
    method set-long(Str:D) { ... }
    method set-short(Str:D) { ... }
    method set-callback(&callback) { ... }
    method set-optional(Mu) { ... }
    method set-annotation(Str:D) { ... }
    method set-default-value(Mu) { ... }
    method has-value returns Bool { ... }
    method has-long returns Bool { ... }
    method has-short returns Bool { ... }
    method has-callback returns Bool { ... }
    method has-annotation returns Bool { ... }
    method has-default-value returns Bool { ... }
    method reset-long { ... }
    method reset-short { ... }
    method reset-value { ... }
    method reset-callback { ... }
    method reset-annotation { ... }
    method type returns Str { ... }
    method check() { ... }
    method match-name(Str:D) { ... }
    method match-value(Mu) { ... }
    method usage(:$bsd-style) returns Str {
        my Str $usage = "";

        $usage ~= "{$bsd-style ?? "" !! "-"}{self.short}"
            if self.has-short;
        $usage ~= "|"
            if self.has-long && self.has-short;
        $usage ~= "{$bsd-style ?? "" !! "--"}{self.long}"
            if self.has-long;
        $usage ~= "=<{self.type}>"
            if self.type ne BOOLEAN;

        return self.optional ?? "[{$usage}]" !! "\{{$usage}\}";
    }
    method clone(*%_) { ... }
}

role Option::Base does Option {
    has $.long  = "";
    has $.short = "";
    has &.callback;
    has $.optional;
    has $.annotation;
    has $.value;
    has $.default-value;

    method callback {
        &!callback;
    }

    method optional {
        $!optional;
    }

    method annotation {
        $!annotation;
    }

    method value {
        $!value;
    }

    method default-value {
        $!default-value;
    }

    method long {
        $!long;
    }

    method short {
        $!short;
    }

    method set-value(Mu $value, Bool :$callback) {
        if $callback.so && &!callback.defined {
            &!callback(self);
        }
        $!value = $value;
    }

    method set-long(Str:D $name) {
        $!long = $name;
    }

    method set-short(Str:D $name) {
        $!short = $name;
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

    method set-default-value(Mu $value) {
        $!default-value = $value;
    }

    method has-value() returns Bool {
        $!value.defined;
    }

    method has-long() returns Bool {
        $!long ne "";
    }

    method has-short() returns Bool {
        $!short ne "";
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
        $!long = "";
    }

    method reset-short {
        $!short = "";
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

    method check() {
        return $!optional || self.has-value();
    }

    method match-name(Str:D $name) {
        $name eq self.long
            ||
        $name eq self.short;
    }

    method match-value(Mu) {
        False;
    }

    method clone(*%_) {
        self.bless(
            long        => %_<long> // $!long.clone,
            short       => %_<short> // $!short.clone,
            callback    => %_<callback> // &!callback.clone,
            optional    => %_<optional> // $!optional.clone,
            annotation  => %_<annotation> // $!annotation.clone,
            value       => %_<value> // $!value.clone,
            default-value=> %_<default-value> // $!default-value.clone
        );
        nextwith(|%_);
    }
}

class Option::Boolean does Option::Base {
    submethod TWEAK(:$value, :$deactivate) {
        if $deactivate {
            if $value.defined && !$value {
                invalid-value("{self.usage()}: default value must be True in deactivate-style.");
            }
            $!default-value = True;
        }
        self.set-value($value, :!callback);
    }

    method set-value(Mu $value, Bool :$callback) {
        callwith($value.so, $callback);
    }

    method type() {
        "boolean";
    }

    method match-value(Mu:D) {
        True;
    }
}


class Option::Integer does Option::Base {
    submethod TWEAK(:$value) {
        if $value.defined {
            $!default-value = $value;
            self.set-value($value, :!callback);
        }
    }

    method set-value(Mu:D $value, Bool :$callback) {
        if $value ~~ Int {
            callsame;
        } elsif so +$value {
            callwith(+$value, :$callback);
        } else {
            invalid-value("{self.usage()}: Need integer.");
        }
    }

    method type() {
        "integer";
    }

    method match-value(Mu:D $value) {
        $value ~~ Int || so +$value;
    }
}

class Option::Float does Option::Base {
    submethod TWEAK(:$value) {
        if $value.defined {
            $!default-value = $value;
            self.set-value($value, :!callback);
        }
    }

    method set-value(FatRat:D $value, Bool :$callback) {
        if $value ~~ FatRat {
            callsame;
        } elsif so $value.FatRat {
            callwith($value.FatRat, :$callback);
        } else {
            invalid-value("{self.usage()}: Need float.");
        }
    }

    method type() {
        "float";
    }

    method match-value(Mu:D $value) {
        $value ~~ FatRat || so $value.FatRat;
    }
}

class Option::String does Option::Base {
    submethod TWEAK(:$value) {
        if $value.defined {
            $!default-value = $value;
            self.set-value($value, :!callback);
        }
    }

    method set-value(Str:D $value, Bool :$callback) {
        if $value ~~ Str {
            callsame;
        } elsif so ~$value {
            callwith(~$value, :$callback);
        } else {
            invalid-value("{self.usage()}: Need string.");
        }
    }

    method type() {
        "string";
    }

    method match-value(Mu:D $value) {
        $value ~~ Str || so ~$value;
    }
}

class Option::Hash does Option::Base {
    submethod TWEAK(:$value) {
        if $value.defined {
            unless $value ~~ Hash {
                invalid-value("{self.usage()}: Need a Hash.");
            }
            $!value = $!default-value = $value;
        }
    }

    # This actually is a push-value
    method set-value(Mu:D $value, Bool :$callback) {
        my %hash = $!value.defined ?? %$!value !! Hash.new;
        if $value ~~ Pair {
            %hash.push($value);
        } elsif so $value.pairup {
            %hash.push($value.pairup);
        } else {
            invalid-value("{self.usage()}: Need a Pair.");
        }
        callwith(%hash, :$callback);
    }

    method type() {
        "hash";
    }

    method match-value(Mu:D $value) {
        $value ~~ Pair || so $value.pairup;
    }
}

class Option::Array does Option::Base {
    submethod TWEAK(:$value) {
        if $value.defined {
            unless $value ~~ Positional {
                invalid-value("{self.usage()}: Need an Positional.");
            }
            $!value = $!default-value = Array.new(|$value);
        }
    }

    # This actually is a push-value
    method set-value($value, Bool :$callback) {
        my @array = $!value ?? @$!value !! Array.new;
        @array.push($value);
        callwith(@array, :$callback);
    }

    method type() {
        "array";
    }

    method match-value(Mu:D $value) {
        True;
    }
}
