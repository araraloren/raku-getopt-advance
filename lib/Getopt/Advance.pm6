
use Getopt::Advance::Helper;
use Getopt::Advance::Types;
use Getopt::Advance::Parser;
use Getopt::Advance::Group;
use Getopt::Advance::Option;
use Getopt::Advance::Argument;
use Getopt::Advance::Exception;
use Getopt::Advance::NonOption;

class OptionSet { ... }

#`(
    :$gnu-style, :$unix-style, :$x-style, :$bsd-style,
)
 sub getopt (
    @args = @*ARGS.clone,
    *@optset,
    :&helper = &ga-helper,
    :$stdout = $*OUT,
    :$stderr = $*ERR,
    :&parser = &ga-parser,
    :$strict = True,
    :$bsd-style,
    :$x-style, #`(giving priority to x-style) ) is export {
    our $*ga-bsd-style = $bsd-style;
    my ($index, $count, @noa, $optset) = (0, +@optset, []);

    while $index < $count {
        $optset := @optset[$index++];
        try {
            @noa = &parser(
                @args,
                $optset,
                :$strict,
                :$bsd-style,
                :$x-style,
            );
            CATCH {
                when X::GA::ParseFailed {
                    if $index == $count {
                        if &ga-helper {
                            $stderr.say(.message);
                            &ga-helper($optset, $stdout);
                        }
                        .throw;
                    }
                }

                default {
                    if &ga-helper {
                        $stderr.say(.message);
                        &ga-helper($optset, $stdout);
                    }
                    ...
                }
            }
        }
    }

    return $optset, @noa;
}

class OptionSet {
    has @.main;
    has %!cache;
    has @.radio;
    has @.multi;
    has %.no-all;
    has %.no-pos;
    has %.no-cmd;
    has $!types;
    has $!counter;

    submethod TWEAK() {
        $!types = Types::Manager.new;
        $!types.register('b', Option::Boolean)
              .register('i', Option::Integer)
              .register('s', Option::String)
              .register('a', Option::Array)
              .register('h', Option::Hash)
              .register('f', Option::Float);
    }

    method keys() {
        my @keys = [];
        for @!main {
            @keys.push(.long) if .has-long;
            @keys.push(.short)if .has-short;
        }
        @keys;
    }

    method values() {
        @!main;
    }

    method get(::?CLASS::D: Str:D $name --> Option) {
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

    multi method has(::?CLASS::D: Str:D @names --> Bool) {
        [&&] [self.has($_) for @names];
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

    multi method remove(::?CLASS::D: Str:D @names --> Bool) {
        [&&] [self.remove($_) for @names];
    }

    multi method reset(::?CLASS::D: Str:D $name) {
        if %!cache{$name}:exists {
            %!cache{$name}.reset-value;
        } else {
            for ^+@!main -> $index {
                if @!main[$index].match-name($name) {
                    @!main[$index].reset-value;
                    last;
                }
            }
        }
        self;
    }

    multi method reset(::?CLASS::D: Str:D @names) {
        self.reset($_) for @names;
        self;
    }

    multi method EXISTS-KEY(::?CLASS::D: Str:D \key where * !~~ /^\s+$/) {
        return self.has(key);
    }

    multi method EXISTS-KEY(::?CLASS::D: Str:D @key) {
        return [&&] [ self.has($_) for @key ];
    }

    # NOTICE: this return the value of option
    multi method AT-KEY(::?CLASS::D: Str:D \key where * !~~ /^\s+$/) {
        return self.get(key).value;
    }

    multi method AT-KEY(::?CLASS::D: Str:D @key) {
        return [self.get($_).value for @key];
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

    multi method append(::?CLASS::D: *@optpairs where all(@optpairs) ~~ Pair) {
        for @optpairs {
            @!main.push($!types.create(.key, .value));
        }
        self;
    }

    multi method append(::?CLASS::D: Str:D $opts, :$optional = True, :$radio!) {
        my @opts = [$!types.create($_) for $opts.split(';', :skip-empty)];
        ga-raise-error("Can not create radio group for only one option") if +@opts <= 1;
        @!radio.push(
            Group::Radio.new(options => @opts, :$optional, :optsetref(self))
        );
        @!main.append(@opts);
        self;
    }

    multi method append(::?CLASS::D: Str:D $opts, :$optional = True, :$multi!) {
        my @opts = [$!types.create($_) for $opts.split(';', :skip-empty)];
        ga-raise-error("Can not create multi group for only one option") if +@opts <= 1;
        @!multi.push(
            Group::Multi.new(options => @opts, :$optional, :optsetref(self))
        );
        @!main.append(@opts);
        self;
    }

    multi method append(::?CLASS::D: :$optional = True, :$radio!, *@optpairs where all(@optpairs) ~~ Pair) {
        my @opts = [ $!types.create(.key, .value) for @optpairs];
        ga-raise-error("Can not create radio group for only one option") if +@opts <= 1;
        @!radio.push(
            Group::Radio.new(options => @opts, :$optional, :optsetref(self))
        );
        @!main.append(@opts);
        self;
    }

    multi method append(::?CLASS::D: :$optional = True, :$multi!, *@optpairs where all(@optpairs) ~~ Pair) {
        my @opts = [ $!types.create(.key, .value) for @optpairs];
        ga-raise-error("Can not create multi group for only one option") if +@opts <= 1;
        @!multi.push(
            Group::Multi.new(options => @opts, :$optional, :optsetref(self))
        );
        @!main.append(@opts);
        self;
    }

    # non-option operator
    method non-option(:$pos, :$cmd) {
        return %!no-pos if ?$pos;
        return %!no-cmd if ?$cmd;
        return %!no-all;
    }

    multi method has(::?CLASS::D: Int:D $id --> Bool) {
        my @r = [];
        @r.push((sub (\noref) {
            for @(noref).keys {
                if $id == $_ {
                    return True;
                }
            }
            return False;
        }($_))) for (%!no-all, %!no-pos, %!no-cmd);
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
        }($_) for (%!no-all, %!no-pos, %!no-cmd);
    }

    multi method EXISTS-KEY(::?CLASS::D: Int:D $id) {
        self.has($id);
    }

    multi method insert-main(::?CLASS::D: &callback) of Int {
        my $id = $!counter++;
        %!no-all.push(
            $id => NonOption::All.new( :&callback)
        );
        return $id;
    }

    method get-cmd(Str $name) {
        for %!no-cmd.values {
            if .name eq $name {
                return $_;
            }
        }
    }

    multi method reset(Str $name, :$cmd!) {
        for %!no-cmd.values {
            if .name eq $name {
                .reset-success;
            }
        }
    }

    multi method insert-cmd(::?CLASS::D: Str:D $name) of Int {
        my $id = $!counter++;
        %!no-cmd.push(
            $id => NonOption::Cmd.new( callback => -> Argument $a {}, :$name)
        );
        return $id;
    }

    multi method insert-cmd(::?CLASS::D: Str:D $name, &callback) of Int {
        my $id = $!counter++;
        %!no-cmd.push(
            $id => NonOption::Cmd.new( :&callback, :$name)
        );
        return $id;
    }

    multi method insert-pos(::?CLASS::D: Str:D $name, &callback, :$front!) of Int {
        my $id = $!counter++;
        %!no-pos.push(
            $id => NonOption::Pos.new-front( :&callback, :$name)
        );
        return $id;
    }

    multi method insert-pos(::?CLASS::D: Str:D $name, &callback, :$last!) of Int {
        my $id = $!counter++;
        %!no-pos.push(
            $id => NonOption::Pos.new-last( :&callback, :$name)
        );
        return $id;
    }

    multi method insert-pos(::?CLASS::D: Str:D $name, $index where * ~~ Int:D | WhateverCode , &callback) of Int {
        my $id = $!counter++;
        %!no-pos.push(
            $id => NonOption::Pos.new( :$name, :$index, :&callback)
        );
        return $id;
    }

    method check() {
        for (@!radio, @!multi) -> @groups {
            for @groups -> $group {
                $group.check();
            }
        }
        .check unless .optional for @!main;
    }

    method usage() {
        my $usage = "Usage:\n{$*PROGRAM-NAME} ";

        # add command
        my $command = "";
        if %!no-cmd.elems > 0 {
            $command ~= (join "|", %!no-cmd.values>>.usage);
        }

        # add pos
        my $front = "";
        my $pos = "";
        my $wepos = "";
        if %!no-pos.elems > 0 {
            my $fake = 4096;
            my %kind = classify {
                $_.index ~~ Int ?? ($_.index == 0 ?? 0 !! 'index' ) !! '-1'
            }, %!no-pos.values;

            if %kind{0}:exists && %kind<0>.elems > 0 {
                $front ~= "<";
                $front ~= (join "|", @(%kind<0>)>>.usage);
                $front ~= ">";
            }

            if %kind<index>:exists && %kind<index>.elems > 0 {
                my %pos = classify { $_.index }, @(%kind<index>);

                for %pos.sort(*.key)>>.value -> $value {
                    $pos ~= "<";
                    $pos ~= (join("|", @($value)>>.usage));
                    $pos ~= "> ";
                }
            }

            if %kind{-1}:exists && %kind{-1}.elems > 0 {
                my %pos = classify { $_.index.($fake) }, @(%kind{-1});

                for %pos.sort(*.key)>>.value -> $value {
                    $wepos ~= "<";
                    $wepos ~= (join("|", @($value)>>.usage));
                    $wepos ~= "> ";
                }
            }
        }

        $usage ~= "[" if $command ne "" or $front ne "";
        $usage ~= "{$command}" if $command ne "";
        $usage ~= "|" if $command ne "" and $front ne "";
        $usage ~= $front if $front ne "";
        $usage ~= "] " if $command ne "" or $front ne "";
        $usage ~= $pos;

        for @!main -> $opt {
            $usage ~= $opt.optional ?? "[{$opt.usage}] " !! "<{$opt.usage}> ";
        }

        $usage ~= $wepos;

        $usage;
    }

    method annotation() {
        return [] if @!main.elems == 0;
        require Terminal::Table <&array-to-table>;
        my @annotation;

        for @!main -> $opt {
            @annotation.push([
                $opt.usage,
                $opt.annotation ~ (do {
                    if $opt.default-value.defined {
                        "[{$opt.default-value}]";
                    } else {
                        "";
                    }
                })
            ]);
        }

        &array-to-table(@annotation, style => 'none');
    }

    method clone(*%_) {
        self.bless(
            main => %_<main> // @!main.clone,
            radio => %_<radio> // @!radio.clone,
            multi => %_<multi> // @!multi.clone,
            no-all => %_<no-all> // %!no-all.clone,
            no-pos => %_<no-pos> // %!no-pos.clone,
            no-cmd => %_<no-cmd> // %!no-cmd.clone,
        );
        nextwith(|%_);
    }
}
