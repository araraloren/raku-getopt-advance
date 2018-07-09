
use Getopt::Advance::Exception;

sub guess-the-type($p) {
    %(
        Int => 'i',
        IntStr => 'i',
        Str => 's',
        Array => 'a',
        Hash => 'h',
        Num => 'f',
        Rat => 'f',
        Bool => 'b',
        Any => 's',
        Positional => 'a',
        Associative => 'h',
    ){ $p.type.^name };
}

multi sub mixin-option($os, Sub $s) is export {
    my Bool $slurpy = False;

    $os.insert-cmd($s.name);
    for @($s.signature.params) -> $p {
        if $p.slurpy {
            $slurpy = True;
            next;
        }
        if $p.named {
            $os.push("{}={guess-the-type($p)}");
        }
    }
    $os;
}

multi sub mixin-option($os, Method $m) is export {

}
