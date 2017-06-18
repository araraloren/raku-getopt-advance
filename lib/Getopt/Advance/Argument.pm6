
unit class Argument;

has $.index;
has $.value;

method pairup() returns Pair {
    return Pair.new($!index, $!value);
}

method Str() {
    return $!value.Str;
}

method Int() {
    return $!value.Int;
}
