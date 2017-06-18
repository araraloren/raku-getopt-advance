
use Getopt::Advance::Argument;

constant NOALL  = "all";
constant NOPOS  = "position";
constant NONAME = "name";

role NonOption {
    method name returns Str { ... }
    method index returns Int { ... }
    method callback { ... }
    method set-name(Str:D) { ... }
    method set-index(Int:D) { ... }
    method set-callback(Callable:D) { ... }
    method has-name returns Bool { ... }
    method has-index returns Bool { ... }
    method has-callback returns Bool { ... }
    method type returns Str { ... }
    multi method ACCEPT(Int:D) { ... }
    multi method ACCEPT(Str:D) { ... }
    method clone(*%_) { ... }
}

class NonOption::Base does NonOption {
    has &.callback;
    has $.name;
    has $.index;

    method set-name(Str:D $name) {
        $!name = $name;
    }

    method set-index(Int:D $index) {
        $!index = $index;
    }

    method set-callback(&callback) {
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
        die "{$?CLASS} has no type!";
    }

    multi method ACCEPT(Int:D $index) {
        not $!index.defined || $!index == $index;
    }

    multi method ACCEPT(Str:D $name) {
        not $!name.defined || $name eq $!name;
    }

    method clone(*%_) {
        self.bless(
            callback    => %_<callback> // &!callback.clone,
            name        => %_<name> // $!name.clone,
            index       => %_<index> // $!index.clone,
        )
        nextwith(|%_);
    }
}

class NonOption::All is NonOption::Base {
    method set-callback(
        &callback where .signature ~~ :($, Argument @) | :(Argument @)
    ) {
        &!callback = &callback;
    }

    method type returns Str {
        NOALL;
    }
}

class NonOption::Index is NonOption::Base {
    method set-callback(
        &callback where .signature ~~ :($, Argument $) | :(Argument $)
    ) {
        &!callback = &callback;
    }

    method type returns Str {
        NOPOS;
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
