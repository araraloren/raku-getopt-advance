
use Getopt::Advance::Utils:api<2>;
use Getopt::Advance::Types:api<2>;
use Getopt::Advance::Group:api<2>;
use Getopt::Advance::Parser:api<2>;
use Getopt::Advance::Option:api<2>;
use Getopt::Advance::NonOption:api<2>;
use Getopt::Advance::Exception:api<2>;

unit module Getopt::Advance:api<2>;

class OptionSet { ... }
class ReturnValue { ... }

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
    :$grammar = OptionGrammar,
    :$actions = OptionActions,
    :@styles = [ :long, :xopt, :short, :ziparg, :comb ],
    :@order  = < long xopt short ziparg comb >) is export {

    my $parserobj = Parser.new(
        :@args,
        :$strict,
        :$autohv,
        :$bsd-style,
        :@styles,
        :@order,
        optgrammar => $grammar,
        optactions => $actions,
    );

    loop (my $index = 0; $index < +@optsets; $index += 1) {

        my $optset := @optsets[$index];

        try {
            $parserobj.init(@args);
            $optset.set-parser($parserobj);
            $parserobj.($optset);
            $optset.check();

            return ReturnValue.new(
                optionset   => $optset,
                noa         => $parserobj.noa,
                parser      => $parserobj,
                return-value=> do {
                    my %rvs;
                    for %($optset.get-main()) {
                        %rvs{.key} = .value.value;
                    }
                    %rvs;
                }
            );

            CATCH {
                when X::GA::ParseError  |
                     X::GA::OptionError |
                     X::GA::GroupError  |
                     X::GA::NonOptionError {
                    say "Will try next OptionSet.";
                    Debug::debug("Will try next OptionSet.");
                }

                when X::GA::WantPrintHelper | X::GA::WantPrintAllHelper
                { }

                default {
                    say "IN Exception !!! ", .gist;
                }
            }
        }
    }

    say "IN OUT RETURN";

    return ReturnValue;
}

class ReturnValue is export {
    has $.optionset;
    has $.noa;
    has $.parser;
    has %.return-value;
}

class OptionSet is export {
    has Option @.options;
    has @.radio;
    has @.multi;
    has %!cache;
    has %.main;
    has %.cmd;
    has %.pos;
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
        return Any;
    }

    multi method get(::?CLASS::D: Str:D $name, Str:D $type = WhateverType) {
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

    multi method Supply(::?CLASS::D: Str:D $name, Str:D $type = WhateverType --> Supply) {
        self.get($name, $type) andthen return .Supply;
        Supply;
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

        return False if $find == -1;

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

    multi method EXISTS-KEY(::?CLASS::D: Str:D @key --> Bool) {
        return [&&] [ self.has($_) for @key ];
    }

    #| this return the value of option rather than the option itself
    multi method AT-KEY(::?CLASS::D: Str:D \key) {
        self.get(key) andthen return .value;
        Any;
    }

    multi method AT-KEY(::?CLASS::D: Str:D @key) {
        return [ self.get($_).?value for @key ];
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

    #| methods for non-options

    multi method get(::?CLASS::D: Int:D $id) {
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

    multi method Supply(::?CLASS::D: Int:D $id --> Supply) {
        self.get($id) andthen return .Supply;
        Supply;
    }

    multi method reset(::?CLASS::D: Int:D $id) {
        for %!main, %!pos, %!cmd -> $nos {
            if $nos{$id}:exists {
                $nos{$id}.reset;
            }
        }
    }

    multi method remove(::?CLASS::D: Int:D $id) {
        for %!main, %!pos, %!cmd -> $nos {
            if $nos{$id}:exists {
                $nos{$id}:delete;
                last;
            }
        }
    }

    multi method EXISTS-KEY(::?CLASS::D: Int:D $id --> Bool) {
        self.has($id);
    }

    multi method AT-KEY(::?CLASS::D: Int:D $id) {
        self.get($id);
    }

    multi method get-main(::?CLASS::D:) {
        return %!main;
    }

    multi method get-main(::?CLASS::D: Int:D $id) {
        return %!main{$id};
    }

    multi method get-main(::?CLASS::D: Str:D $name) {
        for %!main.values {
            return $_ if .match-name($name);
        }
    }

    multi method Supply(::?CLASS::D: Int:D $id, :$main! --> Supply) {
        self.get-main($id) andthen return .Supply;
        Supply;
    }

    multi method get-cmd(::?CLASS::D:) {
        %!cmd;
    }

    multi method get-cmd(::?CLASS::D: Int:D $id) {
        %!cmd{$id};
    }

    multi method get-cmd(::?CLASS::D: Str:D $name) {
        for %!cmd.values {
            return $_ if .match-name($name);
        }
    }

    multi method Supply(::?CLASS::D: Int:D $id, :$cmd! --> Supply) {
        self.get-cmd($id) andthen return .Supply;
        Supply;
    }

    multi method get-pos(::?CLASS::D:) {
        %!pos;
    }

    multi method get-pos(::?CLASS::D: Int $id) {
        %!pos{$id};
    }

    multi method get-pos(::?CLASS::D: Str:D $name, $index) {
        for %!pos.values {
            if .match-name($name) && .match-index(MAXPOSSUPPORT, $index) {
                return $_;
            }
        }
    }

    multi method Supply(::?CLASS::D: Int:D $id, :$pos! --> Supply) {
        self.get-pos($id) andthen return .Supply;
        Supply;
    }

    multi method reset-main(::?CLASS::D: Int $id) {
        %!main{$id}.reset;
    }

    multi method reset-main(::?CLASS::D: Str:D $name) {
        for %!main.values {
            .reset if .name eq $name;
        }
    }

    multi method reset-cmd(::?CLASS::D: Int $id) {
        %!cmd{$id}.reset;
    }

    multi method reset-cmd(::?CLASS::D: Str:D $name) {
        for %!cmd.values {
            .reset if .name eq $name;
        }
    }

    multi method reset-pos(::?CLASS::D: Int $id) {
        %!pos{$id}.reset;
    }

    multi method reset-pos(::?CLASS::D: Str $name, $index) {
        for %!pos.values {
            if .name eq $name && .match-index(4096, $index) {
                .reset;
            }
        }
    }

    my constant &true-block = sub () { True; };

    multi method insert-main(::?CLASS::D: &callback = &true-block --> Int ) {
        my $id = $!counter++;
        %!main.push(
            $id => self.create("main=m", :&callback)
        );
        return $id;
    }

    multi method insert-main(::?CLASS::D: Str:D $name, &callback = &true-block --> Int ) {
        my $id = $!counter++;
        %!main.push(
            $id => self.create("{$name}=m", :&callback)
        );
        return $id;
    }

    method insert-cmd(::?CLASS::D: Str:D $name, &callback = &true-block --> Int ) {
        my $id = $!counter++;
        %!cmd.push(
            $id => self.create("{$name}=c", :&callback)
        );
        return $id;
    }

    multi method insert-pos(::?CLASS::D: Str:D $name, &callback = &true-block, :$front! --> Int ) {
        my $id = $!counter++;
        %!pos.push(
            $id => self.create("{$name}=p", :&callback, index => 0)
        );
        return $id;
    }

    multi method insert-pos(::?CLASS::D: Str:D $name, &callback = &true-block, :$last! --> Int ) {
        my $id = $!counter++;
        %!pos.push(
            $id => self.create("{$name}=p", :&callback, index => * - 1)
        );
        return $id;
    }

    multi method insert-pos(::?CLASS::D: Str:D $name, $index where Int:D | WhateverCode , &callback = &true-block --> Int ) {
        my $id = $!counter++;
        %!pos.push(
            $id => self.create("{$name}=p", :&callback, :$index)
        );
        return $id;
    }

    #| some method for parser
    method check(::?CLASS::D:) {
        #| check the groups
        for (@!radio, @!multi) -> @groups {
            for @groups -> $group {
                $group.check();
            }
        }
        #| check the options
        .check unless .optional for @!options;
    }

    method check-cmd(::?CLASS::D:) {
        my @front-pos;

        for %!pos {
            @front-pos.push(.value) if .value.match-index(MAXPOSSUPPORT, 0);
        }

        my $found-cmd = [||] %!cmd.values>>.success;

        unless $found-cmd {
            if %!cmd.elems > 0 && (+@front-pos == 0 || !([||] @front-pos>>.success)) {
                Debug::debug("Throw a non-option error");
                &ga-non-option-error("Need cmd { +@front-pos > 0 ?? "or front pos :" !! ":" } [" ~ (
                    %!cmd.values>>.usage.join(" ")
                ) ~ ']');
            }
        }
    }

    method set-parser(::?CLASS::D: Publisher $parser) {
        for (%!main, %!cmd, %!pos) -> %need-parser {
            .value.subscribe($parser) for %need-parser;
        }
        for @!options {
            .subscribe($parser);
        }
        self;
    }

    method reset-owner(::?CLASS::D:) {
        .set-owner(self) for @!options;
        .set-owner(self) for @!radio;
        .set-owner(self) for @!multi;
        .value.set-owner(self) for %!main;
        .value.set-owner(self) for %!pos;
        .value.set-owner(self) for %!cmd;
        .set-owner(self) for $!types;
    }

    method merge(::?CLASS::D: ::?CLASS:D $other --> ::?CLASS) {
        sub merge-no(\current, %new) {
            for %new -> $no {
                current{$!counter++} = $no.value;
            }
        }
        given $other {
            @!options.append(.values);
            @!radio.append(.radio);
            @!multi.append(.multi);
            merge-no(%!main, $other.main);
            merge-no(%!cmd, $other.cmd);
            merge-no(%!pos, $other.pos);
        }
        self;
    }

    method clone() {
        my $obj = callwith(
            options => %_<options> // @!options.clone,
            radio   => %_<radio> // @!radio.clone,
            multi   => %_<multi> // @!multi.clone,
            main    => %_<main> // %!main.clone,
            pos     => %_<pos> // %!pos.clone,
            cmd     => %_<cmd> // %!cmd.clone,
            types   => %_<types> // $!types.clone,
            counter => %_<counter> // $!counter,
            |%_,
        );
        #| need reset the optionset for everything
        $obj.reset-owner();
        $obj;
    }
}
