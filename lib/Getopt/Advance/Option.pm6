
use Getopt::Advance::Utils;
use Getopt::Advance::Exception;

unit module Getopt::Advance::Option:api<2>;

constant BOOLEAN  = "boolean";
constant INTEGER  = "integer";
constant STRING   = "string";
constant FLOAT    = "float";
constant ARRAY    = "array";
constant HASH     = "hash";

class Style is export {
    enum < XOPT LONG SHORT ZIPARG COMB DEFAULT >;
}

role Option {
    method value { ... }
    method long of Str { ... }
    method short of Str { ... }
    method callback { ... }
    method optional of Bool { ... }
    method annotation of Str { ... }
    method default-value { ... }
    method set-value(Mu, Bool :$callback) { ... }
    method set-long(Str:D) { ... }
    method set-short(Str:D) { ... }
    method set-callback(&callback) { ... }
    method set-optional(Mu) { ... }
    method set-annotation(Str:D) { ... }
    method set-default-value(Mu) { ... }
    method has-value of Bool { ... }
    method has-long of Bool { ... }
    method has-short of Bool { ... }
    method has-callback of Bool { ... }
    method has-annotation of Bool { ... }
    method has-default-value of Bool { ... }
    method reset-long { ... }
    method reset-short { ... }
    method reset-value { ... }
    method reset-callback { ... }
    method reset-annotation { ... }
    method type of Str { ... }
    method check() { ... }
    method match-name(Str:D) { ... }
    method match-value(Mu) { ... }
    method lprefix { ... }
    method sprefix { ... }
    method need-argument of Bool { True; }
    method usage() of Str {
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
    method clone(*%_) { ... }
}

role Option::Base does Option {
    has $.long  = "";
    has $.short = "";
    has &.callback;
    has $.optional = True;
    has $.annotation = "";
    has $.value;
    has $.default-value;
    has $.supply;

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
            &!callback(self, $value);
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

    method has-value() of Bool {
        $!value.defined;
    }

    method has-long() of Bool {
        $!long ne "";
    }

    method has-short() of Bool {
        $!short ne "";
    }

    method has-callback() of Bool {
        &!callback.defined;
    }

    method has-annotation() of Bool {
        $!annotation.defined;
    }

    method has-default-value() of Bool {
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

    method lprefix { '--' }

    method sprefix { '-' }

    method clone(*%_) {
        nextwith(
            long        => %_<long> // $!long.clone,
            short       => %_<short> // $!short.clone,
            callback    => %_<callback> // &!callback.clone,
            optional    => %_<optional> // $!optional.clone,
            annotation  => %_<annotation> // $!annotation.clone,
            value       => %_<value> // $!value.clone,
            default-value=> %_<default-value> // $!default-value.clone,
            supply      => %_<supply> // $!supply.clone,
            |%_
        );
    }
}

class Option::Boolean does Option::Base {
    submethod TWEAK(:$value, :$deactivate) {
        if $deactivate {
            if $value.defined && !$value {
                ga-invalid-value("{self.usage()}: default value must be True in deactivate-style.");
            }
            $!default-value = True;
            self.set-value(True, :!callback);
        } else {
            if $value.defined {
                $!default-value = $value;
                self.set-value($value, :!callback);
            }
        }
        $!supply.tap(
            -> $v {
                given $v {
                    if ! .success {
                        if .match-name(self) {
                            .mark-matched;
                            self.set-value(True, :callback);
                        }
                    }
                }
            }
        );
    }

    method value {
        so $!value;
    }

    method set-value(Mu $value, Bool :$callback) {
        self.Option::Base::set-value($value.so, :$callback);
    }

    method type() {
        "boolean";
    }

    method lprefix { $!default-value ?? '--/' !! '--' }

    method need-argument of Bool { False; }

    method match-value(Mu:D) {
        True;
    }
}
