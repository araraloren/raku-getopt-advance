
use Getopt::Advance::Exception;

role Constraint {
    method check() { ... }
}

class Group {
    has @.options;
    has $.optional = False;

    method usage() {
        my $usage = "";

        $usage ~= $!optional ?? "+\[ " !! "+\{ ";
        $usage ~= .usage() for @!options;
        $usage ~= $!optional ?? " \]+>" !! " \}+";
        $usage;
    }
}

class Group::Radio is Group does Constraint {
    method check() {
        given @!options.grep({ .has-value }) {
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

class Group::Multi is Group does Constraint {
    method check() {
        if $!optional {
            if @!options.grep({ .has-value }) < +@!options {
                X::GA::GroupValueInvalid
                .new(message => "Multi option group value is force required!")
                .throw;
            }
        }
    }
}
