
use Getopt::Advance::Option;
use Getopt::Advance::Argument;
use Getopt::Advance::Exception;


my class OptionValueSetter {
    has $.optref;
    has $.value;

    method set-value() {
        $!optref.set-value($!value, :callback);
    }
}
my regex lprefix { '--' }
my regex dsprefix { '-/' }
my regex dlprefix { '--/' }
my regex sprefix { '-' }
my regex optname { <-[\=]>+ }
my regex optvalue { .* }

# check name
# check value
# then parse over
multi sub ga-parser(@args, $optset, :$strict, :$x-style) is export {
    my $count = +@args;
    my $noa-index = 0;
    my @oav = [];
    my @noa = [];

    loop (my $index = 0;$index < $count;$index++) {
        my $args := @args[$index];
        my ($name, $value, $long);

        given $args {
            when /^ <.&dsprefix> <optname> $/ {
                ($name, $value, $long) = (~$<optname>, False, False);
            }

            when /^ <.&dlprefix> <optname> $/ {
                ($name, $value, $long) = (~$<optname>, False, True);
            }

            when /^ <.&lprefix> <optname> [ '=' <optvalue> ]?/ {
                ($name, $value, $long) = (
                    ~$<optname>,
                    $<optvalue> ?? ~$<optvalue> !! Str,
                    True
                );
            }

            when /^ <.&sprefix> <optname> [ '=' <optvalue> ]?/ {
                ($name, $value, $long) = (
                    ~$<optname>,
                    $<optvalue> ?? ~$<optvalue> !! Str,
                    False
                );
            }

            default {
                @noa.push(Argument.new(index => $noa-index++, value => $args));
            }
        }

        with $name {
            my $ok = False;
            my $can-throw = False;
            my &when-x-style = -> {
                my @options = $name.comb();
                my $last-opt = @options.pop();
                my $check = $optset.has($last-opt);

                if $check {
                    for @options {
                        $check = $check && $optset.has($_)
                            && $optset.get($_).type eq BOOLEAN;
                    }
                    if $check {
                        if $last-opt -> $opt {
                            without $value {
                                if $opt.type eq BOOLEAN {
                                    $value = True;
                                } elsif ($index + 1 < $count) {
                                    unless $strict && (so @args[$index + 1].starts-with('-'|'--'|'--/')) {
                                        $value = @args[++$index];
                                    }
                                }
                            }
                            if $value.defined && $opt.match-value($value) {
                                @oav.push(OptionValueSetter.new(optref => $opt, :$value));
                            } elsif $can-throw {
                                ga-try-next("Option {$opt.usage} need an argument!");
                            }
                        }
                        @oav.push(OptionValueSetter.new(optref => $optset.get($_), :value))
                            for @options;
                        $ok = True;
                    } elsif $can-throw {
                        ga-try-next("Option $args not recongnize!");
                    }
                }  elsif $can-throw {
                    ga-try-next("Option $args not recongnize!");
                }
                $can-throw = True;
            };
            my &when-normal-style = -> {
                if $optset.get($name) -> $opt {
                    if $name eq ($long ?? $opt.long !! $opt.short) {
                        without $value {
                            if $opt.type eq BOOLEAN {
                                $value = True;
                            } elsif ($index + 1 < $count) {
                                unless $strict && (so @args[$index + 1].starts-with('-'|'--'|'--/')) {
                                    $value = @args[++$index];
                                }
                            }
                        }
                        if $value.defined && $opt.match-value($value) {
                            @oav.push(OptionValueSetter.new(optref => $opt, :$value));
                            $ok = True;
                        } elsif $can-throw {
                            ga-try-next("Option {$opt.usage} need an argument!");
                        }
                    } elsif $can-throw {
                        ga-try-next("Option $args not recongnize!");
                    }
                } elsif $can-throw {
                    ga-try-next("Option $args not recongnize!");
                }
                $can-throw = True;
            };

            if $x-style && not $long {
                &when-x-style();
                &when-normal-style() unless $ok;
            } else {
                &when-normal-style();
                if not $long {
                    &when-x-style() unless $ok;
                }
            }
        }
    }

    # non-option
    my %cmd = $optset.get-cmd();
    my %pos = $optset.get-pos();

    if %cmd.elems > 0 {
        if +@noa == 0 {
            ga-try-next("Need command: < {%cmd.values>>.name.join("|")} >.");
        } else {
            my $matched = False;

            for %cmd.values() -> $cmd {
               if $cmd.match-name(@noa[0].value) {
                   $matched ||= $cmd.($optset, @noa);
               }
            }

            unless $matched {
                for %pos.values() -> $pos {
                    if $pos.index ~~ Int {
                        for @noa -> $noa {
                            if $pos.match-index(+@noa, 0) {
                                $matched = True;
                            }
                        }
                    }
                }
            }

            unless $matched {
               ga-try-next("Not recongnize command: {@noa[0].value}.");
            }
        }
    }

    for %pos.values() -> $pos {
        for @noa -> $noa {
            if $pos.match-index(+@noa, $noa.index) {
                $pos.($optset, $noa);
            }
        }
    }

    #option
    .set-value for @oav;

    # non-option
    my %all = $optset.get-main();

    for %all.values() -> $all {
        $all.($optset, @noa);
    }

    $optset.check();

    return @noa;
}


# check name
# check value
# then parse over
multi sub ga-parser(@args, $optset, :$strict, :$x-style, :$bsd-style!) is export {
    my $count = +@args;
    my $noa-index = 0;
    my @oav = [];
    my @noa = [];

    loop (my $index = 0;$index < $count;$index++) {
        my $args := @args[$index];
        my ($name, $value, $long);

        given $args {
            when /^ <.&dsprefix> <optname> $/ {
                ($name, $value, $long) = (~$<optname>, False, False);
            }

            when /^ <.&dlprefix> <optname> $/ {
                ($name, $value, $long) = (~$<optname>, False, True);
            }

            when /^ <.&lprefix> <optname> [ '=' <optvalue> ]?/ {
                ($name, $value, $long) = (
                    ~$<optname>,
                    $<optvalue> ?? ~$<optvalue> !! Str,
                    True
                );
            }

            when /^ <.&sprefix> <optname> [ '=' <optvalue> ]?/ {
                ($name, $value, $long) = (
                    ~$<optname>,
                    $<optvalue> ?? ~$<optvalue> !! Str,
                    False
                );
            }

            default {
                if $bsd-style {
                    my $bsd-ok = False;
                    my $check = True;
                    my @options = $args.comb();

                    for @options {
                        $check = $check && $optset.has($_)
                            && $optset.get($_).type eq BOOLEAN;
                    }
                    if $check {
                        @oav.push(OptionValueSetter.new(optref => $optset.get($_), :value))
                            for @options;
                        next;
                    }
                }
                if not $bsd-style {
                    @noa.push(Argument.new(index => $noa-index++, value => $args));
                }
            }
        }

        with $name {
            my $ok = False;
            my $can-throw = False;
            my &when-x-style = -> {
                my @options = $name.comb();
                my $last-name = @options.pop();
                my $check = $optset.has($last-name);

                if $check {
                    for @options {
                        $check = $check && $optset.has($_)
                            && $optset.get($_).type eq BOOLEAN;
                    }
                    if $check {
                        if $optset.get($last-name) -> $opt {
                            if $opt.type ne BOOLEAN {
                                without $value {
                                    if $opt.type eq BOOLEAN {
                                        $value = True;
                                    } elsif ($index + 1 < $count) {
                                        unless $strict && (so @args[$index + 1].starts-with('-'|'--'|'--/')) {
                                            $value = @args[++$index];
                                        }
                                    }
                                }
                                if $value.defined && $opt.match-value($value) {
                                    @oav.push(OptionValueSetter.new(optref => $opt, :$value));
                                } elsif $can-throw {
                                    ga-try-next("Option {$opt.usage} need an argument!");
                                }
                            } else {
                                @options.push($last-name);
                            }
                        }
                        @oav.push(OptionValueSetter.new(optref => $optset.get($_), :value))
                            for @options;
                    } elsif $can-throw {
                        ga-try-next("Option $args not recongnize!");
                    }
                }  elsif $can-throw {
                    ga-try-next("Option $args not recongnize!");
                }
                $can-throw = True;
            };
            my &when-normal-style = -> {
                if $optset.get($name) -> $opt {
                    if $name eq ($long ?? $opt.long !! $opt.short) {
                        without $value {
                            if $opt.type eq BOOLEAN {
                                $value = True;
                            } elsif ($index + 1 < $count) {
                                unless $strict && (so @args[$index + 1].starts-with('-'|'--'|'--/')) {
                                    $value = @args[++$index];
                                }
                            }
                        }
                        if $value.defined && $opt.match-value($value) {
                            @oav.push(OptionValueSetter.new(optref => $opt, :$value));
                        } elsif $can-throw {
                            ga-try-next("Option {$opt.usage} need an argument!");
                        }
                    } elsif $can-throw {
                        ga-try-next("Option $args not recongnize!");
                    }
                } elsif $can-throw {
                    ga-try-next("Option $args not recongnize!");
                }
                if not $can-throw {
                    $can-throw = True;
                }
            };

            if $x-style {
                &when-x-style();
                &when-normal-style() if $ok;
            } else {
                &when-normal-style();
                &when-x-style() if $ok;
            }
        }
    }

    # non-option
    my %cmd = $optset.get-cmd();
    my %pos = $optset.get-pos();

    if %cmd.elems > 0 {
        if +@noa == 0 {
            ga-try-next("Need command: < {%cmd.values>>.usage.join("|")} >.");
        } else {
            my $matched = False;

            for %cmd.values() -> $cmd {
               if $cmd.match-name(@noa[0].value) {
                   $matched ||= $cmd.($optset, @noa);
               }
            }

            unless $matched {
                for %pos.values() -> $pos {
                    if $pos.index ~~ Int {
                        for @noa -> $noa {
                            if $pos.match-index(+@noa, 0) {
                                $matched = True;
                            }
                        }
                    }
                }
            }

            unless $matched {
               ga-try-next("Not recongnize command: {@noa[0].value}.");
            }
        }
    }

    for %pos.values() -> $pos {
        for @noa -> $noa {
            if $pos.match-index(+@noa, $noa.index) {
                $pos.($optset, $noa);
            }
        }
    }

    #option
    .set-value for @oav;

    # non-option
    my %all = $optset.get-main();

    for %all.values() -> $all {
        $all.($optset, @noa);
    }

    $optset.check();

    return @noa;
}
