
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

grammar Option::Grammar {
	token TOP { ^ <option> $ }

	proto token option {*}

	token option:sym<s> { '-'  <optname> }

	token option:sym<l> { '--' <optname> }

	token option:sym<ds>{ '-/' <optname> }

	token option:sym<dl>{ '--/'<optname> }

	token option:sym<lv>{ '-'  <optname> '=' <optvalue> }

	token option:sym<sv>{ '--' <optname> '=' <optvalue>	}

	token optname {
		<-[\=]>+
	}

	token optvalue {
		.+
	}
}

class Option::Actions {
	has $.name;
	has $.value;
	has $.long;
    has $!can-throw = False;

	method option:sym<s>($/) {
		$!name = ~$<optname>;
		$!long = False;
	}

	method option:sym<l>($/) {
		$!name = ~$<optname>;
		$!long = True;
	}

	method option:sym<ds>($/) {
		$!name  = ~$<optname>;
		$!value = False;
		$!long  = False;
	}

	method option:sym<dl>($/) {
		$!name  = ~$<optname>;
		$!value = False;
		$!long  = True;
	}

	method option:sym<lv>($/) {
		$!name  = ~$<optname>;
		$!value = ~$<optvalue>;
		$!long  = True;
	}

	method option:sym<sv>($/) {
		$!name  = ~$<optname>;
		$!value = ~$<optvalue>;
		$!long  = False;
	}

	# this check include unix style i.e. '-x'
	method guess-option($optset, &get-value, $can-throw) {
        if $optset.get($!name) -> $opt {
            if $!name eq ($!long ?? $opt.long !! $opt.short) {
                without $!value {
        			if not $opt.need-argument {
        				$!value = True;
        			} else {
        				$!value = &get-value();
        			}
        		}
                if $!value.defined && $opt.match-value($!value) {
                    return ($opt, $!value);
                } elsif $can-throw {
                    &ga-try-next("{$opt.usage}: {$!value} not correct!");
                }
            }
        }
        &ga-try-next("Option {$!name} not recongnized!") if $can-throw;
	}

	# this assume first char is an option, and left is argument
	method guess-with-argument($optset, $can-throw) {
		unless $!name.chars < 2 || $!value.defined {
			my ($optname, $value) = ($!name.substr(0, 1), $!name.substr(1));

			if $optset.get($optname) -> $opt {
				if $optname eq $opt.short {
					return ($opt, $value);
				}
			}
		}
        &ga-try-next("Option {$!name} not recongnized!")
            if $can-throw;
	}

	method guess-component-option($optset, &get-value, $can-throw) {
        my @opts = $!name.comb;

        if +@opts > 1 {
            if $optset.get(@opts[* - 1]) -> $opt {
                if $opt.need-argument and $!value == False {
                    &ga-try-next("Option {$opt.usage}: not support deactivate style!")
                        if $can-throw;
                    return ();
                }
                for @opts {
                    if $optset.get($_).need-argument {
                        &ga-try-next("Option {$optset.get($_).usage}: need argument!")
                            if $can-throw;
                        return ();
                    }
                }
                without $!value {
        			if not $opt.need-argument {
        				$!value = True;
        			} else {
        				$!value = &get-value();
        			}
        		}
                if $!value.defined && $opt.match-value($!value) {
                    return ($opt, $!value);
                } elsif $can-throw {
                    &ga-try-next("{$opt.usage}: {$!value} not correct!");
                }
                @opts.pop();
                return ($opt, $!value, @opts);
            }
        }
        &ga-try-next("Option {$!name} not recongnized!")
            if $can-throw;
	}
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
        my $actions = Option::Actions.new;
        my &get-value = sub () {
            if ($index + 1 < $count) {
                unless $strict && (so @args[$index + 1].starts-with('-'|'--'|'--/')) {
                    return @args[++$index];
                }
            }
        };

        if Option::Grammar.parse($args, :$actions) {
            my @ret;

            if $actions.long {
                @ret = $actions.guess-option($optset, &get-value, True);
                @oav.push(OptionValueSetter.new(
                    optref => @ret[0],
                    value  => @ret[1],
                ));
            } else {
                my &guess-x-style = -> $bool {
                    @ret = $actions.guess-option($optset, &get-value, $bool);
                    if +@ret > 0 {
                        @oav.push(OptionValueSetter.new(
                            optref => @ret[0],
                            value  => @ret[1],
                        ));
                    }
                    +@ret > 0;
                };
                my &guess-other-style = -> $bool {
                    @ret = $actions.guess-with-argument($optset, False);
                    if +@ret > 0 {
                        @oav.push(OptionValueSetter.new(
                            optref => @ret[0],
                            value  => @ret[1],
                        ));
                        +@ret > 0;
                    } else {
                        my ($opt, $value, @bopts) = $actions.guess-component-option($optset, &get-value, $bool);

                        with $opt {
                            @oav.push(OptionValueSetter.new(
                                optref => $opt,
                                value  => $value,
                            ));
                            @oav.push(OptionValueSetter.new(optref => $optset.get($_), :value))
                                for @bopts;
                        }
                        $opt.defined;
                    }
                }
                if $x-style {
                    unless &guess-x-style(False) {
                        &guess-other-style(True);
                    }
                } else {
                    unless &guess-other-style(False) {
                        &guess-x-style(True);
                    }
                }
            }
        } else {
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
