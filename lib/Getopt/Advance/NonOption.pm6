
use Getopt::Advance::Exception:api<2>;
use Getopt::Advance::Utils:api<2>;

unit module Getopt::Advance::NonOption:api<2>;

constant QUITBLOCK = sub (\ex) { };

role NonOption { ... }

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


role NonOption {
    has $.success;
    has &!callback;
    has $.name;
    has $.owner;

    #| provide an empty sub
    method index( --> Int) { }

    method value( --> Any) { }

    method set-value($) { }

    method set-callback(&!callback) { ... }

    method set-owner($!owner) { }

    method set-parser(Supply:D $parser) {
        &tapTheParser($parser, self);
    }

    method has-callback( --> Bool) { &!callback.defined; }

    method reset-success { $!success = False; }

    method match-index(Int $total, Int $index --> Bool) { ... }

    method match-name(Str $name --> Bool) { ... }

    method match-style($style --> Bool) { ... }

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

    method clone() {
        nextwith(
            success  => %_<success> // $!success.clone,
            |%_
        );
    }
}

class NonOption::Main does NonOption {
    submethod TWEAK(:&callback) {
        self.set-callback(&callback);
    }

    method set-callback(
        &callback where .signature ~~ :($, @) | :(@) | :()
    ) {
        self.NonOption::set-callback(&callback);
    }

    method match-index(Int $total, Int $index --> True) { }

    method match-name(Str $name --> True) {}

    method match-style($style --> Bool) { $style == Style::MAIN; }

    method type(--> "main") { }

    method usage() { '*@args' }
}

class NonOption::Cmd does NonOption {
    submethod TWEAK(:&callback) {
        self.set-callback(&callback);
    }

    method set-callback(
        &callback where .signature ~~ :($, $) | :($) | :()
    ) {
        &!callback = &callback;
    }

    method match-index(Int $total, Int $index --> Bool) {
        $index == 0;
    }

    method match-name(Str $name --> Bool) {
        self.name() eq $name;
    }

    method match-style($style --> Bool) { $style == Style::CMD; }

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
    }

    method set-callback(
        &callback where .signature ~~ :($, $) | :($) | :()
    ) {
        &!callback = &callback;
    }

    method match-index(Int $total, $index) {
        my $expect-index = $!index ~~ WhateverCode ??
            $!index.($total) !! $!index;
        my $readl-index = $index ~~ WhateverCode ??
                $index.($total) !! $index;
        return $readl-index == $expect-index;
    }

    method match-name(Str $name) {
        self.name() eq $name;
    }

    method match-style($style --> Bool) { $style == Style::POS; }

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

    method clone() {
        nextwith(
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
