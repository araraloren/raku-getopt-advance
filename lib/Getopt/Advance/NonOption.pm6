
use Getopt::Advance::Exception:api<2>;
use Getopt::Advance::Utils:api<2>;

unit module Getopt::Advance::NonOption:api<2>;

role NonOption {
    has $.success;
    has &!callback;
    has $.name;
    has $.supply;
    has $.owner;

    #| provide an empty sub
    method index( --> Int) { }

    method value( --> Any) { }

    method set-value($) { }

    method set-callback(&!callback) { ... }

    method has-callback( --> Bool) { &!callback.defined; }

    method reset-success { $!success = False; }

    method matchIndex(Int $total, Int $index --> Bool) { ... }

    method matchName(Str $name --> Bool) { ... }

    method matchStyle($style --> Bool) { ... }

    method CALL-ME(|c) {
        my $ret;
        given &!callback.signature {
            when :($, @) {
                $ret = &!callback(|c);
            }
            when :(@) {
                $ret = &!callback(c.[* - 1]);
            }
			when :() {
				$ret = &!callback();
			}
        }
        $!success = True;
        return $ret;
    }

    method type( --> Str) { ... }

    method usage( --> Str) { ... }
}

constant QUITBLOCK = sub (\ex) { };

multi sub tapTheParser(Mu:U \parser, NonOption $no) { }

multi sub tapTheParser(Supply:D \parser, NonOption $no) {
    parser.tap(
        #| should use anon sub, point block are transparent to "return"
        sub ($v) {
            if $v.style >= Style::MAIN && $v.style <= Style::POS {
                $v.process($no);
            }
        },
        #| should have a quit named argument, or will not throw exception to outter
        quit => QUITBLOCK,
    );
}

class NonOption::Main does NonOption {
    submethod TWEAK(:&callback) {
        self.set-callback(&callback);
        &tapTheParser($!supply, self);
    }

    method set-callback(
        &callback where .signature ~~ :($, @) | :(@) | :()
    ) {
        self.NonOption::set-callback(&callback);
    }

    method matchIndex(Int $total, Int $index --> True) { }

    method matchName(Str $name --> True) {}

    method matchStyle($style --> Bool) { $style == Style::MAIN; }

    method type(--> "main") { }

    method clone(*%_) {
        nextwith(
            callback => %_<callback> // &!callback.clone,
            success  => %_<success> // $!success.clone,
            |%_
        );
    }

    method usage() { '*@args' }
}

class NonOption::Cmd does NonOption {
    submethod TWEAK(:&callback) {
        self.set-callback(&callback);
        &tapTheParser($!supply, self);
    }

    method set-callback(
        &callback where .signature ~~ :($, $) | :($) | :()
    ) {
        &!callback = &callback;
    }

    method matchIndex(Int $total, Int $index --> Bool) {
        $index == 0;
    }

    method matchName(Str $name --> Bool) {
        self.name() eq $name;
    }

    method matchStyle($style --> Bool) { $style == Style::CMD; }

    method CALL-ME(|c) {
        given &!callback.signature {
            when :($, @) {
                &!callback(|c);
            }
            when :(@) {
                &!callback(c.[* - 1]);
            }
			when :() {
				&!callback();
			}
        }
        $!success = True;
    }

    method type( --> "cmd") { }

    method clone(*%_) {
        nextwith(
            callback => %_<callback> // &!callback.clone,
            name     => %_<name> // $!name.clone,
            success  => %_<success> // $!success.clone,
            |%_
        );
    }

    method usage() { self.name(); }
}

class NonOption::Pos does NonOption {
    has $.value;
    has $.index;

    submethod TWEAK(:&callback, :$index) {
        self.set-callback(&callback);
        if $index ~~ Int && $index < 0 {
            &ga-raise-error("Index should be positive number!");
        }
        &tapTheParser($!supply, self);
    }

    method set-callback(
        &callback where .signature ~~ :($, $) | :($) | :()
    ) {
        &!callback = &callback;
    }

    method matchIndex(Int $total, $index) {
        my $expect-index = $!index ~~ WhateverCode ??
            $!index.($total) !! $!index;
        my $readl-index = $index ~~ WhateverCode ??
                $index.($total) !! $index;
        return $readl-index == $expect-index;
    }

    method matchName(Str $name) {
        self.name() eq $name;
    }

    method matchStyle($style --> Bool) { $style == Style::POS; }

    method CALL-ME(|c) {
        given &!callback.signature {
            when :($, $) {
                &!callback(|c);
            }
            when :($) {
                &!callback(c.[* - 1]);
            }
			when :() {
				&!callback();
			}
        }
        $!success = True;
    }

    method type( --> "pos") { }

    method clone(*%_) {
        nextwith(
            callback => %_<callback> // &!callback.clone,
            name     => %_<name> // $!name.clone,
            index    => %_<index> // $!index.clone,
            value    => %_<value> // $!index.clone,
            success  => %_<success> // $!success.clone,
            |%_
        );
    }

    method usage() { self.name(); }

    method set-value($value) { $!value = $value; }

    method value {
        $!value;
    }
}
