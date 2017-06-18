
use Getopt::Advance::Option;
use Getopt::Advance::Manager;

class OptionSet { ... }

#`(
    :$gnu-style, :$unix-style, :$x-style, :$bsd-style,
)
multi sub getopt(@args = @*ARGS, *@optset, :&usage, :&parser, :$stop = "--", :$stdin = "-") {

}

multi sub getopt(@args = @*ARGS, *@optset, |c) {

}

class OptionSet {
    has @.main;
    has %.cache;
    has @.radio;
    has @.multi;
    has %.all;
    has %.name;
    has %.pos;

    method get(::?CLASS::D: Str:D $name --> Option) {
        if %!cache{$name}:exists {
            return %!cache{$name};
        } else {
            for @!main {
                if $_ ~~ $name {
                    %!cache{$_.long} := $_ if .has-long;
                    %!cache{$_.long} := $_ if .has-short;
                    return $_;  
                }
            }
        }
        return Option;
    }

    method has(::?CLASS::D: Str:D $name --> Bool) {
        return True if $_ ~~ $name for @!main;
        False;
    }

    multi method remove(::?CLASS::D: Str:D $name --> Bool) {
        for ^+@!main -> $index {
            my $opt := @!main[$index];
            if $opt.long eq $name {
                $opt.reset-long;
            } elsif $opt.short eq $name {
                $opt.reset-short;
            }
            if ! ($opt.has-long || $opt.has-short) {
                @!main.splice($index, 1);
                return True;
            }
        }
        False;
    }

    method set-value(Str:D $name, $value, :$callback = True) {
        with self.get($name) -> $opt {
            $opt.set-value($value, :$callback);
        }
    }

    method set-annotation(Str:D $name, Str:D $annotation) {
        with self.get($name) -> $opt {
            $opt.set-annotation($annotation);
        }
    }

    method set-callback(Str:D $name, &callback) {
        with self.get($name) -> $opt {
            $opt.set-callback(&callback);
        }
    }

    multi method push(::?CLASS::D: Str:D $opt, :$value, :&callback);

    multi method push(::?CLASS::D: Str:D $opt, Str:D $annotation, :$value, :&callback);

    multi method append(::?CLASS::D: Str:D $opts);

    multi method append(::?CLASS::D: *%optpairs);

    multi method append(::?CLASS::D: Str:D $opts, :$radio!);

    multi method append(::?CLASS::D: Str:D $opts, :$multi!);

    multi method EXISTS-KEY(::?CLASS::D: Str:D \key where * !~~ /^\s+$/) {
        return self.has(key);
    }

    multi method AT-KEY(::?CLASS::D: Str:D \key where * !~~ /^\s+$/) {
        return self.get(key);
    }

    multi method DELETE-KET(::?CLASS::D: Str:D \key where * !~~ /^\s+$/) {
        return self.remove(key);
    }

    # non-option operator

    method insert-all(::?CLASS::D: &callback) returns Int;

    method insert-front(::?CLASS::D: &callback) returns Int;

    method insert-last(::?CLASS::D: &callback) returns Int;

    multi method insert(::?CLASS::D: Str:D $name, &callback) returns Int;

    multi method insert(::?CLASS::D: Int:D $index, &callback) returns Int;

    multi method insert(::?CLASS::D: Str:D $name, Int:D $index, &callback) returns Int;

    multi method remove(Int:D $id);

    multi method EXISTS-KEY(::?CLASS::D: Int:D $id) {
        return True if $_ ~~ $option
            for @!main;
        False;
    }

    multi method AT-KEY(::?CLASS::D: Int:D $id) {
        return $_ if $_ ~~ $option 
            for @!main;
    }

    multi method DELETE-KET(::?CLASS::D: Int:D $id) {
        
    }

    method check();

    method usage();

    multi method annotation();

    multi method annotation(Int $indent);

    method perl();

    method clone(*%_);
}
