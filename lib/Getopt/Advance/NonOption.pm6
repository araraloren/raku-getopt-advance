
use Getopt::Advance::Argument;

constant NOALL  = "all";
constant NOPOS  = "position";

role NonOption {
    method set-callback(&callback) { ... }
    method has-callback returns Bool { ... }
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

    method type returns Str {
        NOALL;
    }

    method CALL-ME(|c) {
        &!callback(|c);# add !!!!
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

    method type returns Str {
        NOPOS;
    }

    method CALL-ME(|c) {
        &!callback(|c);
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
            index => 1
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
