
use Getopt::Advance::Utils;

unit module Getopt::Advance::Helper;

constant HELPOPTSUPPORT = 5; #| option number can display in usage
constant HELPPOSSUPPORT = 2;

role Helper {
    has Str $.program is rw;    #| program name
    has Str $.main is rw;       #| main usage
    has @.cmd;                  #| cmd usage
    has %.pos;                  #| pos usage
    has %.annotation;           #| key is option usage, value is option annotation
    has %.default-value;        #| option default-value
    has @.multi;                #| multi group
    has @.radio;                #| radio group
    has @.usage-cache;
    has @.annotation-cache;
    has $.maxopt = HELPOPTSUPPORT;
    has $.maxpos = HELPPOSSUPPORT;

    method merge-group-usage() {
        my ($usage, %annotation) = ("", %!annotation);

        for @!multi -> $multi {
            $usage ~= "[" ~ @$multi.join(",") ~ "] ";
            %annotation{@$multi}:delete;
        }
        for @!radio -> $radio {
            $usage ~= "[" ~ @$radio.join("|") ~ "] ";
            %annotation{@$radio}:delete;
        }
        $usage ~= "[" ~ .Str ~ "] " for %annotation.keys;
        $usage;
    }

    method usage(:$merge-group) {
        unless +@!usage-cache > 0 {
            my @command = |@!cmd;
            my @pos;
            my $wide;

            @command.append(%!pos{0}.sort.map({ "<" ~ $_ ~ ">" })) if %!pos{0}:exists;
            @pos.push("<" ~ .value.join("|") ~ ">") for %!pos.sort(*.key);
            $wide = max(@command>>.chars);
            @pos.shift() if %!pos{0}:exists;

            sub concatopt($optcnt, $preusage) {
                my $usage = $preusage;
                if $optcnt > 0 {
                    if $optcnt <= $!maxopt && +@pos <= $!maxpos {
                        if ! $merge-group {
                            $usage ~= "[" ~ .Str ~ "] " for %!annotation.keys;
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

            my $optcnt = %!annotation.keys.elems;
            
            if +@command > 0 {
                for @command -> $command {
                    my $usage  = $!program ~ " ";

                    $usage ~= sprintf "%-{$wide}s ", $command;

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

            for %!annotation {
                @annotation.push(
                    [
                        .key,
                        .value ~ do {
                            if %!default-value{.key}:exists {
                                "[{%!default-value{.key}}]";
                            } else {
                                "";
                            }
                        }
                    ]
                )
            }

            @!annotation-cache = @annotation;
        }
        @!annotation-cache;
    }
}

multi sub ga-helper($optset, $outfh) is export {
    my $helper = &ga-helper-impl($optset);

    $outfh.say("Usage:");
    $outfh.say(.Str ~ "\n") for $helper.usage();
    
    require Terminal::Table <&array-to-table>;

    my @annotation = &array-to-table($helper.annotation(), style => 'none');

    $outfh.say(.join(" ") ~ "\n") for @annotation;
}

multi sub ga-helper(@optset, $outfh) is export {
    if +@optset == 1 {
        &ga-helper(@optset[0], $outfh);
    } else {
        my @helpers = &ga-helper-impl($_) for @optset;

        $outfh.say("Usage:");
        for @helpers -> $helper {
            $outfh.say(.Str ~ "\n") for $helper.usage();
        }

        require Terminal::Table <&array-to-table>;

        for @helpers -> $helper {
            my @annotation = &array-to-table($helper.annotation(), style => 'none');

            $outfh.say(.join(" ") ~ "\n") for @annotation;
        }
    }
}

constant &ga-helper2 is export = &ga-helper;

sub ga-helper-impl($optset) is export {
    my @cmd = $optset.get-cmd().values>>.usage;
    my %pos;

    for $optset.get-pos().values -> $pos {
        %pos{
            $pos.index ~~ WhateverCode ??
                $pos.index.(MAXPOSSUPPORT) !!
                $pos.index
        } = $pos.usage();
    }

    my (%default-value, %annotation);

    for $optset.values -> $opt {
        %annotation{$opt.usage()} = $opt.annotation();
        if $opt.has-default-value {
            %default-value{$opt.usage()} = $opt.default-value;
        }
    }

    my (@multi, @radio);

    for $optset.multi() -> $multi {
        my @t = [];
        @t.push( .optref.usage() ) for $multi.infos;
        @multi.push(@t);
    }

    for $optset.radio() -> $radio {
        my @t = [];
        @t.push( .optref.usage() ) for $radio.infos;
        @radio.push(@t);
    }

    return Helper.new(
        program         => $*PROGRAM-NAME,
        cmd             => @cmd,
        pos             => %pos,
        main            => "",
        annotation      => %annotation,
        default-value   => %default-value,
        multi           => @multi,
        radio           => @radio,
    );
}