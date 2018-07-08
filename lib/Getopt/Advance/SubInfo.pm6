
use Getopt::Advance::Exception;

class SubInfo is export {
    has $.cmd is rw;
    has @.pos;
    has @.named;

    sub extract-info(Parameter $p) {
        say $p;
    }

    multi method new(Method $m) {

    }

    multi method new(Sub $s) {
        my (@pos, @named);

        for @($s.signature.params) -> $param {
            extract-info($param);
        }

        self.bless(cmd => $s.name);
    }

    multi method new(::T) {

    }

    method mixin($os) {

    }
}
