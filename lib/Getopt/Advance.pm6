
use Getopt::Advance::Types;
use Getopt::Advance::Group;
use Getopt::Advance::Option;
use Getopt::Advance::Exception;
use Getopt::Advance::NonOption;

class OptionSet { ... }

#`(
    :$gnu-style, :$unix-style, :$x-style, :$bsd-style,
)
multi sub getopt(
    @args = @*ARGS,
    *@optset,
    :&usage,
    :&parser,
    :$bsd-style,
    :$x-style, # giving priority to x-style
    :$enable-stop #`("--"),
    :$enable-stdin #`("-") ) is export {
    while +@args {

    }
}

class OptionSet {
    has @.main;
    has %!cache;
    has @.radio;
    has @.multi;
    has %.no-all;
    has %.no-pos;
    has $!types;
    has $!counter;

    submethod TWEAK() {
        $!types = Types::Manager.new;
        $!type.register('b', Option::Boolean)
              .register('i', Option::Integer)
              .register('s', Option::String)
              .register('a', Option::Array)
              .register('h', Option::Hash)
              .register('f', Option::Float);
    }

    method keys() {
        my @keys = [];
        @keys.append(.long, .short) for @!main;
        @keys;
    }

    method values() {
        @!main;
    }

    multi method get(::?CLASS::D: Str:D $name --> Option) {
        if %!cache{$name}:exists {
            return %!cache{$name};
        } else {
            for @!main {
                if .match-name($name) {
                    %!cache{.long}  := $_ if .has-long;
                    %!cache{.short} := $_ if .has-short;
                    return $_;
                }
            }
        }
        return Option;
    }

    multi method has(::?CLASS::D: Str:D $name --> Bool) {
        if %!cache{$name}:exists {
            return True;
        } else {
            for @!main {
                if .match-name($name) {
                    %!cache{.long}  := $_ if .has-long;
                    %!cache{.short} := $_ if .has-short;
                    return True;
                }
            }
        }
        return False;
    }

    multi method remove(::?CLASS::D: Str:D $name --> Bool) {
        my $find = -1;
        if %!cache{$name}:exists {
            for ^+@!main -> $index {
                if @!main[$index] === %!cache{$name} {
                    $find = $index;
                    last;
                }
            }
            %!cache{$name}:delete;
        } else {
            for ^+@!main -> $index {
                if @!main[$index].match-name($name) {
                    $find = $index;
                    last;
                }
            }
        }
        if $find == -1 {
            return False;
        } else {
            my $option := @!main[$find];
            if $option.long eq $name {
                $option.reset-long;
            } elsif $option.short eq $name {
                $option.reset-short;
            }
            unless $option.has-long || $option.has-short {
                @!main.splice($find, 1);
            }
            for (@!radio, @!multi) -> @groups {
                for @groups -> $group {
                    if $group.has($name) {
                        $group.remove($name);
                    }
                }
            }
            return True;
        }
    }

    method set-value(Str:D $name, $value, :$callback = True) {
        with self.get($name) -> $opt {
            $opt.set-value($value, :$callback);
        }
        self;
    }

    method set-annotation(Str:D $name, Str:D $annotation) {
        with self.get($name) -> $opt {
            $opt.set-annotation($annotation);
        }
        self;
    }

    method set-callback(Str:D $name, &callback) {
        with self.get($name) -> $opt {
            $opt.set-callback(&callback);
        }
        self;
    }

    multi method push(::?CLASS::D: Str:D $opt, :$value, :&callback) {
        @!main.push(
            $!types.create( $opt, :$value, :&callback)
        );
        self;
    }

    multi method push(::?CLASS::D: Str:D $opt, Str:D $annotation, :$value, :&callback) {
        @!main.push(
            $!types.create($opt, $annotation, :$value, :&callback)
        );
        self;
    }

    multi method append(::?CLASS::D: Str:D $opts) {
        for $opts.split(';', :skip-empty) {
            @!main.push($!types.create($_));
        }
        self;
    }

    multi method append(::?CLASS::D: *%optpairs) {
        for %optpairs.pairs {
            @!main.push($!types.create(.key, .value));
        }
        self;
    }

    multi method append(::?CLASS::D: Str:D $opts, :$radio!) {
        my @opts = [$!tyles.create($_) for $opts.split(';', :skip-empty)];
        @!radio.push(
            Group::Radio.new(options => @opts)
        );
        @!main.append(@opts);
        self;
    }

    multi method append(::?CLASS::D: Str:D $opts, :$multi!) {
        my @opts = [$!tyles.create($_) for $opts.split(';', :skip-empty)];
        @!radio.push(
            Group::Multi.new(options => @opts)
        );
        @!main.append(@opts);
        self;
    }

    multi method append(::?CLASS::D: *%optpairs, :$radio!) {
        my @opts = [ @!main.push($!types.create(.key, .value)) for %optpairs.pairs];
        @!radio.push(
            Group::Radio.new(options => @opts)
        );
        @!main.append(@opts);
        self;
    }

    multi method append(::?CLASS::D: *%optpairs, :$multi!) {
        my @opts = [ @!main.push($!types.create(.key, .value)) for %optpairs.pairs];
        @!radio.push(
            Group::Multi.new(options => @opts)
        );
        @!main.append(@opts);
        self;
    }

    multi method EXISTS-KEY(::?CLASS::D: Str:D \key where * !~~ /^\s+$/) {
        return self.has(key);
    }

    # NOTICE: this return the value of option
    multi method AT-KEY(::?CLASS::D: Str:D \key where * !~~ /^\s+$/) {
        return self.get(key).value;
    }

    multi method DELETE-KET(::?CLASS::D: Str:D \key where * !~~ /^\s+$/) {
        return self.remove(key);
    }

    # non-option operator
    multi method has(::?CLASS::D: Int:D $id --> Bool) {
        my @r = [];
        @r.((sub (\noref) {
            for @(noref).keys {
                if $id == $_ {
                    return True;
                }
            }
            return False;
        }($_)) for (@!no-all, @!no-pos);
        return [||] @r;
    }

    multi method remove(Int:D $id) {
        -> \noref {
            for @(noref).keys {
                if $id == $_ {
                    noref{$id}:delete;
                    last;
                }
            }
        }($_) for (@!no-all, @!no-pos);
    }

    multi method insert(::?CLASS::D: &callback) returns Int {
        my $id = $!counter++;
        %!no-all.push(
            $id => NonOption::All.new( :&callback, optsetref => self)
        );
        return $id;
    }

    multi method insert(::?CLASS::D: &callback, :$front) returns Int {
        my $id = $!counter++;
        %!no-all.push(
            $id => NonOption::Pos.new-front( :&callback, optsetref => self)
        );
        return $id;
    }

    multi method insert(::?CLASS::D: &callback, :$last) returns Int {
        my $id = $!counter++;
        %!no-all.push(
            $id => NonOption::Pos.new-last( :&callback, optsetref => self)
        );
        return $id;
    }

    multi method insert(::?CLASS::D: Str:D $name, &callback) returns Int {
        my $id = $!counter++;
        %!no-all.push(
            $id => NonOption::Pos.new(:$name,  :&callback, optsetref => self)
        );
        return $id;
    }

    multi method insert(::?CLASS::D: Int:D $index, &callback) returns Int {
        my $id = $!counter++;
        %!no-all.push(
            $id => NonOption::Pos.new( :$index, :&callback, optsetref => self)
        );
        return $id;
    }

    multi method insert(::?CLASS::D: Str:D $name, Int:D $index, &callback) returns Int {
        my $id = $!counter++;
        %!no-all.push(
            $id => NonOption::Pos.new( :$name, :$index, :&callback, optsetref => self)
        );
        return $id;
    }

    multi method EXISTS-KEY(::?CLASS::D: Int:D $id) {
        self.has($id);
    }

    multi method DELETE-KET(::?CLASS::D: Int:D $id) {
        self.remove($id);
    }

    method check() {
        for (@!radio, @!multi) -> @groups {
            for @groups -> $group {
                $group.check();
            }
        }
        .check unless .optional for @!main;
    }

    method usage() {}

    multi method annotation() {}

    multi method annotation(Int $indent) {}

    method perl() {}

    method clone(*%_) {}
}
