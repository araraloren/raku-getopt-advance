
use Getopt::Advance::Utils:api<2>;
use Getopt::Advance::Types:api<2>;
use Getopt::Advance::Parser:api<2>;
use Getopt::Advance::Option:api<2>;
use Getopt::Advance::NonOption:api<2>;

unit module Getopt::Advance:api<2>;

class OptionSet { ... }

multi sub getopt (
    *@optsets where all(@optsets) ~~ OptionSet,
    *%args) is export {
    samewith(
        @*ARGS ?? @*ARGS.clone !! $[],
        |@optsets,
        |%args
    );
}

multi sub getopt(
    @args is copy,
    *@optsets where all(@optsets) ~~ OptionSet,
    :$stdout = $*OUT,
    :$stderr = $*ERR,
    :$parser = Parser,
    :$strict = True,
    :$autohv = False,
    :$version,
    :$bsd-style = False,
    :@styles = [ :long, :xopt, :short, :ziparg, :comb ],
    :@order  = < long xopt short ziparg comb >) is export {
    my $parser-gen = Parser.new(:@args, :$strict, :$autohv, :$bsd-style, :@styles, :@order);
    for @optsets -> $optset {
        try {
            my $parser = share-supply($parser-gen.());

            given $parser {
                $optset.set-parser(.Supply);

                react {
                    whenever $parser.Supply {
                        Debug::debug("Got {$_.perl} in getopt");
                    }
                    $parser.keep();
                }
            }
            CATCH {
                default {
                    say .gist;
                }
            }
        }
    }
}

class OptionSet is export {
    has Option @!options;
    has @!radio;
    has @!multi;
    has %!cache;
    has %!main;
    has %!cmd;
    has %!pos;
    has $.types handles < create >;
    has $!counter;

    submethod TWEAK () {
        $!counter = 0;
        unless $!types.defined {
            $!types = TypesManager.new(owner => self);
            $!types.registe('b', Option::Boolean)
                   .registe('i', Option::Integer)
                   .registe('s', Option::String)
                   .registe('a', Option::Array)
                   .registe('h', Option::Hash)
                   .registe('f', Option::Float)
                   .registe('c', NonOption::Cmd)
                   .registe('m', NonOption::Main)
                   .registe('p', NonOption::Pos)
        }
    }

    #| methods for options

    method keys(::?CLASS::D:) {
        my @keys = [];
        for @!options {
            @keys.push(.long) if .has-long;
            @keys.push(.short)if .has-short;
        }
        @keys;
    }

    method values(::?CLASS::D:) {
        @!options;
    }

    method !make-cache($name, $type) {
        for @!options {
            if .match-name($name) && (
                ($type eq WhateverType) || (.type eq $!types.innername($type))
            ) {
                %!cache{.long}{$type}  := $_ if .has-long;
                %!cache{.short}{$type} := $_ if .has-short;
                return $_;
            }
        }
        return Option;
    }

    multi method get(::?CLASS::D: Str:D $name, Str:D $type = WhateverType --> Option) {
        if %!cache{$name}{$type}:exists {
            return %!cache{$name}{$type};
        }
        return self!make-cache($name, $type);
    }

    multi method has(::?CLASS::D: Str:D $name, Str:D $type = WhateverType --> Bool) {
        if %!cache{$name}{$type}:exists {
            return True;
        }
        return self!make-cache($name, $type).defined;
    }

    #| remove the option, not the option name, different from old code, now it is has correctly behavior
    multi method remove(::?CLASS::D: Str:D $name, Str:D $type = WhateverType --> Bool) {
        my Int $find = -1;

        for ^+@!options -> $index {
            given @!options[$index] {
                if .match-name($name) && (
                    ($type eq WhateverType) || (.type eq $!types.innername($type))
                ) {
                    $find = $index;
                    last;
                }
            }
        }

        if $find == -1 {
            return False;
        }

        if %!cache{$name}{$type}:exists {
            %!cache{$name}{$type}:delete;
        }
        @!options.splice($find, 1);
        for (@!radio, @!multi) -> @groups {
            for @groups -> $group {
                return True if $group.remove($name, $type);
            }
        }
        return True;
    }

    multi method reset(::?CLASS::D: Str:D $name, Str $type = WhateverType --> ::?CLASS) {
        if %!cache{$name}{$type}:exists {
            %!cache{$name}{$type}.reset-value;
        } else {
            .reset-value if self!make-cache($name, $type);
        }
        self;
    }

    #| this syntax can not check the type
    multi method EXISTS-KEY(::?CLASS::D: Str:D \key --> Bool) {
        self.has(key);
    }

    #| this return the value of option rather than the option itself
    multi method AT-KEY(::?CLASS::D: Str:D \key ) {
        self.get(key) andthen return .value;
    }

    multi method set-value(::?CLASS::D: Str:D $name, $value, :$callback = True --> ::?CLASS)  {
        with self.get($name) -> $opt {
            $opt.set-value($value, :$callback);
        }
        self;
    }

    multi method set-value(::?CLASS::D: Str:D $name, Str:D $type, $value, :$callback = True --> ::?CLASS)  {
        with self.get($name, $type) -> $opt {
            $opt.set-value($value, :$callback);
        }
        self;
    }

    multi method set-annotation(::?CLASS::D: Str:D $name, Str:D $annotation --> ::?CLASS)  {
        with self.get($name) -> $opt {
            $opt.set-annotation($annotation);
        }
        self;
    }

    multi method set-annotation(::?CLASS::D: Str:D $name, Str:D $type, Str:D $annotation --> ::?CLASS)  {
        with self.get($name, $type) -> $opt {
            $opt.set-annotation($annotation);
        }
        self;
    }

    multi method set-callback(::?CLASS::D: Str:D $name, &callback --> ::?CLASS)  {
        with self.get($name) -> $opt {
            $opt.set-callback(&callback);
        }
        self;
    }

    multi method set-callback(::?CLASS::D: Str:D $name, Str:D $type, &callback --> ::?CLASS)  {
        with self.get($name, $type) -> $opt {
            $opt.set-callback(&callback);
        }
        self;
    }

    #| push a Option to the OptionSet
    multi method push(::?CLASS::D: Option:D $option --> ::?CLASS)  {
        $option.set-owner(self);
        @!options.push($option);
        self;
    }

    multi method push(::?CLASS::D: Str:D $opt, :$value, :&callback --> ::?CLASS)  {
        @!options.push(
            self.create($opt, :$value, :&callback)
        );
        self;
    }

    multi method push(::?CLASS::D: Str:D $opt, Str:D $annotation, :$value, :&callback --> ::?CLASS)  {
        @!options.push(
            self.create($opt, :$annotation, :$value, :&callback)
        );
        self;
    }

    #| push a Option to the OptionSet
    multi method append(::?CLASS::D: @options --> ::?CLASS)  {
        self.push($_) for @options;
        self;
    }

    multi method append(::?CLASS::D: Str:D $opts --> ::?CLASS)  {
        self.push(self.create($_)) for $opts.split(';', :skip-empty);
        self;
    }

    multi method append(::?CLASS::D: *@optpairs where all(@optpairs) ~~ Pair, :$radio where !.so, :$multi where !.so --> ::?CLASS)  {
        self.push(self.create(.key, annotation => .value)) for @optpairs;
        self;
    }

    multi method append(::?CLASS::D: Str:D $opts, :$optional = True, :$radio where .so --> ::?CLASS)  {
        my @opts = [self.create($_) for $opts.split(';', :skip-empty)];
        die "Can not create radio group for only one option" if +@opts <= 1;
        @!radio.push(
            Group::Radio.new(options => @opts, :$optional, :owner(self))
        );
        @!options.append(@opts);
        self;
    }

    multi method append(::?CLASS::D: Str:D $opts, :$optional = True, :$multi where .so --> ::?CLASS)  {
        my @opts = [self.create($_) for $opts.split(';', :skip-empty)];
        die "Can not create multi group for only one option" if +@opts <= 1;
        @!multi.push(
            Group::Multi.new(options => @opts, :$optional, :owner(self))
        );
        @!options.append(@opts);
        self;
    }

    multi method append(::?CLASS::D: :$optional = True, :$radio where .so, *@optpairs where all(@optpairs) ~~ Pair --> ::?CLASS)  {
        my @opts = [ self.create(.key, annotation => .value) for @optpairs];
        die "Can not create radio group for only one option" if +@opts <= 1;
        @!radio.push(
            Group::Radio.new(options => @opts, :$optional, :owner(self))
        );
        @!options.append(@opts);
        self;
    }

    multi method append(::?CLASS::D: :$optional = True, :$multi where .so, *@optpairs where all(@optpairs) ~~ Pair --> ::?CLASS)  {
        my @opts = [ self.create(.key, annotation => .value) for @optpairs];
        die "Can not create multi group for only one option" if +@opts <= 1;
        @!multi.push(
            Group::Multi.new(options => @opts, :$optional, :owner(self))
        );
        @!options.append(@opts);
        self;
    }

    method radio() { @!radio; }

    method multi() { @!multi; }

    #| methods for non-options

    multi method get(::?CLASS::D: Int:D $id --> NonOption) {
        for %!main, %!pos, %!cmd -> $nos {
            if $nos{$id}:exists {
                return $nos{$id};
            }
        }
        NonOption;
    }

    multi method has(::?CLASS::D: Int:D $id --> False) {
        for %!main, %!pos, %!cmd -> $nos {
            if $nos{$id}:exists {
                return True;
            }
        }
    }

    multi method reset(::?CLASS::D: Int:D $id) {
        for %!main, %!pos, %!cmd -> $nos {
            if $nos{$id}:exists {
                $nos{$id}.reset-success;
            }
        }
    }

    multi method EXISTS-KEY(::?CLASS::D: Int:D $id --> Bool) {
        self.has($id);
    }

    multi method AT-KEY(::?CLASS::D: Int:D $id --> NonOption) {
        self.get($id);
    }

    multi method get-main(::?CLASS::D:) {
        return %!main;
    }

    multi method get-main(::?CLASS::D: Int:D $id --> NonOption) {
        return %!main{$id};
    }

    multi method get-cmd(::?CLASS::D: Str:D $name --> NonOption) {
        for %!main.values {
            return $_ if .name eq $name;
        }
    }

    multi method get-cmd(::?CLASS::D:) {
        %!cmd;
    }

    multi method get-cmd(::?CLASS::D: Int $id --> NonOption) {
        %!cmd{$id};
    }

    multi method get-cmd(::?CLASS::D: Str:D $name --> NonOption) {
        for %!cmd.values {
            return $_ if .name eq $name;
        }
    }

    multi method get-pos(::?CLASS::D:) {
        %!pos;
    }

    multi method get-pos(::?CLASS::D: Int $id --> NonOption) {
        %!pos{$id};
    }

    multi method get-pos(::?CLASS::D: Str:D $name, $index --> NonOption) {
        for %!pos.values {
            if .name eq $name && .match-index(MAXPOSSUPPORT, $index) {
                return $_;
            }
        }
    }

    multi method reset-main(::?CLASS::D: Int $id) {
        %!main{$id}.reset-success;
    }

    multi method reset-main(::?CLASS::D: Str:D $name) {
        for %!main.values {
            .reset-success if .name eq $name;
        }
    }

    multi method reset-cmd(::?CLASS::D: Int $id) {
        %!cmd{$id}.reset-success;
    }

    multi method reset-cmd(::?CLASS::D: Str:D $name) {
        for %!cmd.values {
            .reset-success if .name eq $name;
        }
    }

    multi method reset-pos(::?CLASS::D: Int $id) {
        %!pos{$id}.reset-success;
    }

    multi method reset-pos(::?CLASS::D: Str $name, $index) {
        for %!pos.values {
            if .name eq $name && .match-index(4096, $index) {
                .reset-success;
            }
        }
    }

    multi method insert-main(::?CLASS::D: &callback --> Int ) {
        my $id = $!counter++;
        %!main.push(
            $id => self.create("main=m", :&callback)
        );
        return $id;
    }

    multi method insert-main(::?CLASS::D: Str:D $name, &callback --> Int ) {
        my $id = $!counter++;
        %!main.push(
            $id => self.create("{$name}=m", :&callback)
        );
        return $id;
    }

    multi method insert-cmd(::?CLASS::D: Str:D $name --> Int ) {
        my $id = $!counter++;
        %!cmd.push(
            $id => self.create("{$name}=c", callback => sub () { })
        );
        return $id;
    }

    multi method insert-cmd(::?CLASS::D: Str:D $name, &callback --> Int ) {
        my $id = $!counter++;
        %!cmd.push(
            $id => self.create("{$name}=c", :&callback)
        );
        return $id;
    }

    multi method insert-pos(::?CLASS::D: Str:D $name, &callback, :$front! --> Int ) {
        my $id = $!counter++;
        %!pos.push(
            $id => self.create("{$name}=p", :&callback, index => 0)
        );
        return $id;
    }

    multi method insert-pos(::?CLASS::D: Str:D $name, &callback, :$last! --> Int ) {
        my $id = $!counter++;
        %!pos.push(
            $id => self.create("{$name}=p", :&callback, index => * - 1)
        );
        return $id;
    }

    multi method insert-pos(::?CLASS::D: Str:D $name, $index where Int:D | WhateverCode , &callback --> Int ) {
        my $id = $!counter++;
        %!pos.push(
            $id => self.create("{$name}=p", :&callback, :$index)
        );
        return $id;
    }

    method check(::?CLASS::D:) {
        for (@!radio, @!multi) -> @groups {
            for @groups -> $group {
                $group.check();
            }
        }
        .check unless .optional for @!options;
    }

    method set-parser(Supply:D $parser) {
        for (%!main, %!cmd, %!pos) -> %need-parser {
            .value.set-parser($parser) for %need-parser;
        }
        .set-parser($parser) for @!options;
        self;
    }

    method clone(*%_) {
        nextwith(
            options => %_<options> // @!options.clone,
            radio   => %_<radio> // @!radio.clone,
            multi   => %_<multi> // @!multi.clone,
            main    => %_<main> // %!main.clone,
            pos     => %_<pos> // %!pos.clone,
            cmd     => %_<cmd> // %!cmd.clone,
            types   => %_<types> // $!types,
            counter => %_<counter> // $!counter,
            |%_,
        );
    }
}
