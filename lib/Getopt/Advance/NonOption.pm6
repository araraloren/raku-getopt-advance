
use Getopt::Advance::Argument;
use Getopt::Advance::Exception;

constant NOALL  = "all";
constant NOFRONT= "front";
constant NOPOS  = "position";

role NonOption {
    has $.success;

    method set-callback(&callback) { ... }
    method has-callback of Bool { ... }
    method match-index(Int $total, Int $index) { ... }
    method CALL-ME(|c) { ... }
    method type of Str { ... }
    method clone(*%_) { ... }
}

class NonOption::All does NonOption {
    has &.callback;

    submethod TWEAK(:&callback) {
        self.set-callback(&callback);
    }

    method set-callback(
        &callback # where .signature ~~ :($, Argument @) | :(Argument @)
    ) {
        &!callback = &callback;
    }

    method has-callback() {
        &!callback.defined;
    }

    method match-index(Int $total, Int $index) {
        True;
    }

    method type of Str {
        NOALL;
    }

    method CALL-ME(|c) {
        given &!callback.signature {
            when :($, @) {
                &!callback(|c);
            }
            when :(@) {
                &!callback(|c.[* - 1]);
            }
        }
        $!success = True;
    }

    method clone(*%_) {
        self.bless(
            callback    => %_<callback> // &!callback.clone,
        );
        nextwith(|%_);
    }
}

class NonOption::Front does NonOption {
    has &.callback;
    has $.name;

    submethod TWEAK(:&callback) {
        self.set-callback(&callback);
    }

    method set-callback(
        &callback #where .signature ~~ :($, Argument $) | :(Argument $)
    ) {
        &!callback = &callback;
    }

    method has-callback() {
        &!callback.defined;
    }

    method match-index(Int $total, Int $index) {
        $index == 0;
    }

    method type of Str {
        NOFRONT;
    }

    method CALL-ME(|c) {
        my Argument $arg = c.[* - 1];

        if $!name eq "" || $!name eq $arg.value {
            given &!callback.signature {
                when :($, $) {
                    &!callback(|c);
                }
                when :($) {
                    &!callback($arg);
                }
            }
            say "\tSET NAME  |{$!name}";
            $!success = True;
        } else {
            $!success = False;
        }
    }

    method clone(*%_) {
        self.bless(
            callback    => %_<callback> // &!callback.clone,
            name        => %_<name> // $!name.clone,
        );
        nextwith(|%_);
    }
}

class NonOption::Pos does NonOption {
    has &.callback;
    has $.name;
    has $.index;

    submethod TWEAK(:&callback) {
        self.set-callback(&callback);
    }

    method set-index(Int:D $index) {
        $!index = $index;
    }

    method set-callback(
        &callback # where .signature ~~ :($, Argument $) | :(Argument $)
    ) {
        &!callback = &callback;
    }

    method has-index of Bool {
        $!index || $!index >= 0;
    }

    method has-callback of Bool {
        &!callback.defined;
    }

    method match-index(Int $total, Int $index) {
        my $expect-index = $!index ~~ WhateverCode ??
            $index.($total) !! $!index;
        return $index == $expect-index;
    }

    method type of Str {
        NOPOS;
    }

    method CALL-ME(|c) {
        given &!callback.signature {
            when :($, $) {
                &!callback(|c);
            }
            when :($) {
                &!callback(c.[* - 1]);
            }
        }
        say "\tSET INDEX |<{$!name}\@{$!index}>";
        $!success = True;
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
