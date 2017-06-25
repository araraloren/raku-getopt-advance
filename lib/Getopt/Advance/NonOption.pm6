
use Getopt::Advance::Argument;
use Getopt::Advance::Exception;

constant NOALL  = "all";
constant NOPOS  = "position";

role NonOption {
    method set-callback(&callback) { ... }
    method has-callback returns Bool { ... }
    method match-index(Int $total, Int $index) { ... }
    method CALL-ME(|c) { ... }
    method type returns Str { ... }
    method clone(*%_) { ... }
}

class NonOption::All does NonOption {
    has &.callback;

    submethod TWEAK(:&callback) {
        self.set(&callback);
    }

    method set-callback(
        &callback where .signature ~~ :($, Argument @) | :(Argument @)
    ) {
        &!callback = &callback;
    }

    method has-callback() {
        &!callback.defined;
    }

    method match-index(Int $total, Int $index) {
        True;
    }

    method type returns Str {
        NOALL;
    }

    method CALL-ME(|c) {
        given &!callback.signature {
            when :($, Argument @) {
                &!callback(|c);
            }
            when :(Argument @) {
                &!callback(|c.[* - 1]);
            }
        }
    }

    method clone(*%_) {
        self.bless(
            callback    => %_<callback> // &!callback.clone,
        );
        nextwith(|%_);
    }
}

class NonOption::Pos does NonOption {
    has &.callback;
    has $.name = "";
    has $.index = -1;

    submethod TWEAK(:&callback) {
        self.set(&callback);
    }

    method set-name(Str:D $name) {
        $!name = $name;
    }

    method set-index(Int:D $index) {
        $!index = $index;
    }

    method set-callback(
        &callback where .signature ~~ :($, Argument $) | :(Argument $)
    ) {
        &!callback = &callback;
    }

    method has-name returns Bool {
        $!name.defined;
    }

    method has-index returns Bool {
        $!index || $!index >= 0;
    }

    method has-callback returns Bool {
        &!callback.defined;
    }

    method match-index(Int $total, Int $index) {
        my $expect-index = $!index ~~ WhateverCode ??
            $index.($total) !! $!index;
        return $index == $expect-index;
    }

    method type returns Str {
        NOPOS;
    }

    method CALL-ME(|c) {
        my Argument $arg = c.[* - 1];

        if $!name eq "" || $!name eq $arg.value {
            given &!callback.signature {
                when :($, Argument $) {
                    &!callback(|c);
                }
                when :(Argument $) {
                    &!callback($arg);
                }
            }
        } else {
            may-usage("Not recongnize non-option name: {$arg.value}");
        }
    }

    method clone(*%_) {
        self.bless(
            callback    => %_<callback> // &!callback.clone,
            name        => %_<name> // $!name.clone,
            index       => %_<index> // $!index.clone,
        );
        nextwith(|%_);
    }

    method new-front(*%_) {
        %_<index>:delete;
        self.new(
            |%_,
            index => 0
        );
    }

    method new-last(*%_) {
        %_<index>:delete;
        self.new(
            |%_,
            index => * - 1
        );
    }
}
