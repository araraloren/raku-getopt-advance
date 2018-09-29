
use Getopt::Advance::Utils;

unit module Getopt::Advance::Helper;

constant HELPOPTSUPPORT = 5; #| option number can display in usage
constant HELPPOSSUPPORT = 2;

role Helper is export {
    has Str $.program is rw;    #| program name
    has Str $.main is rw;       #| main usage
    has @.cmd;                  #| all cmd
    has %.pos;                  #| key is position, value is POS
    has %.option;               #| key is usage, value is option
    has @.multi;                #| multi group
    has @.radio;                #| radio group
    has @.usage-cache;
    has @.annotation-cache;
    has @.cmdusage-cache;
    has @.posusage-cache;
    has $.maxopt = HELPOPTSUPPORT;
    has $.maxpos = HELPPOSSUPPORT;
    has $!group-usage-cache;

    method reset-cache() {
        @!usage-cache = [];
        @!annotation-cache = [];
        @!cmdusage-cache = [];
        @!posusage-cache = [];
        $!group-usage-cache = "";
    }

    method merge-group-usage() {
        unless $!group-usage-cache ne "" {
            my ($usage, %optionref) = ("", %!option);
            my @t;

            for @!multi -> $multi {
                @t = [];
                @t.push(.optref.usage()) for $multi.infos;
                $usage ~= ( $multi.optional ?? '[' !! '<' );
                $usage ~= @t.join(",");
                $usage ~= ( $multi.optional ?? ']' !! '>' );
                $usage ~= ' ';
                %optionref{@t}:delete;
            }
            for @!radio -> $radio {
                @t = [];
                @t.push(.optref.usage()) for $radio.infos;
                $usage ~= ( $radio.optional ?? '[' !! '<' );
                $usage ~= @t.join(",");
                $usage ~= ( $radio.optional ?? ']' !! '>' );
                $usage ~= ' ';
                %optionref{@t}:delete;
            }
            for %optionref -> $item {
                $usage ~= ( $item.value.optional ?? '[' !! '<' );
                $usage ~= $item.key;
                $usage ~= ( $item.value.optional ?? ']' !! '>' );
                $usage ~= ' ';
            }
            $!group-usage-cache = $usage;
        }
        $!group-usage-cache;
    }

    method usage(:$merge-group) {
        unless +@!usage-cache > 0 {
            my (@front, @pos);
            my $wide;

            @front.push( .usage() ) for @!cmd;
            if %!pos{0}:exists {
                for @(%!pos{0}) -> $pos {
                    @front.push('[' ~ $pos.usage ~ ']');
                }
            }
            for %!pos.sort(*.key) -> $item {
                given $item.value {
                    @pos.push('[' ~ @($_)>>.usage.join("|") ~ ']');
                }
            }
            $wide = max(@front>>.chars);
            @pos.shift() if %!pos{0}:exists;

            sub concatopt($optcnt, $preusage) {
                my $usage = $preusage;
                if $optcnt > 0 {
                    if $optcnt <= $!maxopt && +@pos <= $!maxpos {
                        if ! $merge-group {
                            for %!option {
                                $usage ~= (.value.optional ?? '[' !! '<');
                                $usage ~= .key;
                                $usage ~= (.value.optional ?? ']' !! '>');
                                $usage ~= ' ';
                            }
                        } else {
                            $usage ~= self.merge-group-usage();
                        }
                    } else {
                        $usage ~= 'OPTIONs ';
                    }
                }

                $usage ~= .Str ~ " " for @pos;
                $usage ~= $!main;
                $usage;
            }

            my $optcnt = %!option.keys.elems;

            if +@front > 0 {
                for @front -> $front {
                    my $usage  = $!program ~ " ";

                    $usage ~= sprintf "%-{$wide}s ", $front;

                    @!usage-cache.push(concatopt($optcnt, $usage));
                }
            } else {
                my $usage  = $!program ~ " ";

                @!usage-cache.push(concatopt($optcnt, $usage));
            }
        }
        @!usage-cache;
    }

    method annotation() {
        unless +@!annotation-cache > 0 {
            my @annotation;

            for %!option -> $item {
                @annotation.push(
                    [
                        $item.key,
                        do given $item.value {
                            .annotation ~ do {
                                if .has-default-value {
                                    "[" ~ .default-value ~ "]";
                                } else {
                                    "";
                                }
                            }
                        }
                    ]
                )
            }

            @!annotation-cache = @annotation;
        }
        @!annotation-cache;
    }

    method cmdusage() {
        unless +@!cmdusage-cache > 0 {
            for @!cmd -> $cmd {
                if $cmd.has-annotation() {
                    @!cmdusage-cache.push(
                        [$cmd.name, $cmd.annotation]
                    );
                }
            }
        }
        @!cmdusage-cache;
    }

    method posusage() {
        unless +@!posusage-cache > 0 {
            for %!pos.sort(*.key) -> $posarray {
                for @($posarray.value) -> $pos {
                    given $pos {
                        if .has-annotation() {
                            @!posusage-cache.push(
                                [.name, .annotation]
                            );
                        }
                    }
                }
            }
        }
        @!posusage-cache;
    }
}

my sub print-annotation(@helpers, $outfh, $newline) {
    require Terminal::Table <&array-to-table>;

    my $section;

    $section = True;
    for @helpers -> $helper {
        my @cmdu = $helper.cmdusage();
        if +@cmdu > 0 {
            if $section {
                $outfh.say("CMDs:");
                $section = False;
            }
            @cmdu = &array-to-table(@cmdu, style => 'none');
            $outfh.say("  " ~ .join(" ") ~ $newline) for @cmdu;
        }
    }
    $section = True;
    for @helpers -> $helper {
        my @posu = $helper.posusage();
        if +@posu > 0 {
            if $section {
                $outfh.say("POSs:");
                $section = False;
            }
            @posu = &array-to-table(@posu, style => 'none');
            $outfh.say("  " ~ .join(" ") ~ $newline) for @posu;
        }
    }
    $section = True;
    for @helpers -> $helper {
        my @annotation = $helper.annotation();
        if @annotation.elems > 0 {
            if $section {
                $outfh.say("OPTIONs:");
                $section = False;
            }
            @annotation = &array-to-table(@annotation, style => 'none');
            $outfh.say("  " ~ .join(" ") ~ $newline) for @annotation;
        }
    }
}

multi sub ga-helper($optset, $outfh, :$compact-help = False, *%args) is export {
    my $helper = &ga-helper-impl($optset);
    my $newline= $compact-help ?? "" !! "\n";

    $outfh.say("Usage:");
    $outfh.say("  " ~ .Str ~ $newline) for $helper.usage(|%args);
    &print-annotation([$helper, ], $outfh, $newline);
}

multi sub ga-helper(@optset, $outfh, :$compact-help = False, *%args) is export {
    if +@optset == 1 {
        &ga-helper(@optset[0], $outfh, |%args);
    } else {
        my @helpers = [ &ga-helper-impl($_) for @optset ];
        my $newline = $compact-help ?? "" !! "\n";

        $outfh.say("Usage:");
        for @helpers -> $helper {
            $outfh.say("  " ~ .Str ~ $newline) for $helper.usage(|%args);
        }

        &print-annotation(@helpers, $outfh, $newline);
    }
}

constant &ga-helper2 is export = &ga-helper;

sub ga-helper-impl($optset) is export {
    my @cmd = $optset.get-cmd().values;
    my %pos;

    Debug::debug("Call ga-helper-impl generate Helper object.");
    for $optset.get-pos().values -> $pos {
        %pos{
            $pos.index ~~ WhateverCode ??
                $pos.index.(MAXPOSSUPPORT) !!
                $pos.index
        }.push($pos);
    }

    my %option;

    for $optset.options -> $opt {
        %option{$opt.usage()} = $opt;
    }

    return Helper.new(
        program => $*PROGRAM-NAME,
        cmd     => @cmd,
        pos     => %pos,
        main    => "",
        option  => %option,
        multi   => $optset.multi,
        radio   => $optset.radio,
    );
}

sub ga-version($version, $outfh) is export {
    $outfh.print($version) if $version ne "";
}
