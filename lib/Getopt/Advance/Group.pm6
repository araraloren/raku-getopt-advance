
use Getopt::Advance::Exception;

class Group::OptionName {
    has $.long is rw;
    has $.short is rw;
}

role Group {
    has $.optsetref;
    has @.names;
    has $.optional = False;

    # @options are names of options in group
    submethod TWEAK(:@options) {
        @!names = [];
        for @options {
            @!names.push(
                Group::OptionName.new(long => .long, short => .short)
            );
        }
    }

    method usage() {
        my $usage = "";

        $usage ~= $!optional ?? "+\[ " !! "+\{ ";
        $usage ~= $!optsetref.get($_).usage() for @!names;
        $usage ~= $!optional ?? " \]+>" !! " \}+";
        $usage;
    }

    method has(Str:D $name --> Bool) {
        for @!names {
            return True if $name eq .long | .short;
        }
        False;
    }

    method remove(Str:D $name where $name !~~ /^\s+$/) {
        for ^+@!names -> $index {
            my $optn := @!names[$index];
            if $name eq $optn.long {
                $optn.long = "";
            }
            if $name eq $optn.short {
                $optn.short = "";
            }
            if $optn.long eq "" and $optn.short eq "" {
                @!names.splice($index, 1);
                return True;
            }
        }
    }

    method check() { ... }

    method clone(*%_) {
        self.bless(
            optsetref => %_<optsetref> // $!optsetref,
            names => %_<names> // @!names.clone,
            optional => %_<optional> // $!optional,
        );
        nextwith(|%_);
    }
}

class Group::Radio does Group {
    method check() {
        given @!names.grep({ .has-value }) {
            when 0 {
                unless $!optional {
                    X::GA::GroupValueInvalid
                    .new(message => "Radio option group value is force required!")
                    .throw;
                }
            }
            when * > 1 {
                X::GA::GroupValueInvalid
                .new(message => "Radio group value only allow set one!")
                .throw;
            }
        }
    }
}

class Group::Multi does Group {
    method check() {
        if $!optional {
            if @!names.grep({ .has-value }) < +@!names {
                X::GA::GroupValueInvalid
                .new(message => "Multi option group value is force required!")
                .throw;
            }
        }
    }
}
