
use Getopt::Advance::Utils:api<2>;
use Getopt::Advance::Option:api<2>;
use Getopt::Advance::Exception:api<2>;
use Getopt::Advance::Argument:api<2>;

unit module Getopt::Advance::Parser:api<2>;

my constant ParserRT = sub { True };
my constant ParserRF = sub { False };

grammar Option::Grammar {
	token TOP { ^ <option> $ }

	proto token option {*}

	token option:sym<s> { '-'  <optname> }

	token option:sym<l> { '--' <optname> }

	token option:sym<ds>{ '-/' <optname> }

	token option:sym<dl>{ '--/'<optname> }

	token option:sym<sv>{ '-'  <optname> '=' <optvalue> }

	token option:sym<lv>{ '--' <optname> '=' <optvalue>	}

	token optname {
		<-[\=\-]>+
	}

	token optvalue {
		.+
	}
}

role ResultHandler { ... }

class Option::Actions {
	has $.name;
	has $.value;
	has $.prefix;
    has $.handler;

    method setHandler(ResultHandler $handler) {
        $!handler = $handler;
    }

	method option:sym<s>($/) {
		$!name = ~$<optname>;
		$!prefix = Prefix::SHORT;
	}

	method option:sym<l>($/) {
		$!name = ~$<optname>;
		$!prefix = Prefix::LONG;
	}

	method option:sym<ds>($/) {
		$!name  = ~$<optname>;
		$!value = False;
		$!prefix = Prefix::SHORT;
	}

	method option:sym<dl>($/) {
		$!name  = ~$<optname>;
		$!value = False;
		$!prefix = Prefix::LONG;
	}

	method option:sym<lv>($/) {
		$!name  = ~$<optname>;
		$!value = ~$<optvalue>;
		$!prefix = Prefix::LONG;
	}

	method option:sym<sv>($/) {
		$!name  = ~$<optname>;
		$!value = ~$<optvalue>;
		$!prefix = Prefix::SHORT;
	}

    method !guess-option(&getarg) {
        my @guess;

        if $!value.defined {
            @guess.push([ $!value === False ?? False !! True, sub { $!value } ]);
        } elsif &getarg.defined {
            @guess.push([ True,  &getarg ]);
            @guess.push([ False, ParserRT ]);
        } else {
            @guess.push([ False, ParserRT ]);
        }
        @guess;
    }

    # generate option like '--foo', aka long style
    multi method broadcastOption(&getarg, :$long!) {
        # skip option like '-f'
        if $!prefix == Prefix::LONG  {
            for self!guess-option(&getarg) -> $g {
                emit MatchContext.new(
                    handler => $!handler,
                    style => Style::LONG,
                    contexts => [
                        MatchContext::Option.new(
                            prefix => $!prefix,
                            name   => $!name,
                            hasarg => $g.[0],
                            getarg  => $g.[1],
                        )
                    ],
                );
            }
        }
    }

    # generate option like '-foo', but not '-f', aka x-style
    multi method broadcastOption(&getarg, :$xopt!) {
        # skip option like '-f'
        if $!prefix == Prefix::SHORT && $!name.chars > 1  {
            for self!guess-option(&getarg) -> $g {
                emit MatchContext.new(
                    handler => $!handler,
                    style => Style::XOPT,
                    contexts => [
                        MatchContext::Option.new(
                            prefix => $!prefix,
                            name   => $!name,
                            hasarg => $g.[0],
                            getarg  => $g.[1],
                        )
                    ]
                );
            }
        }
    }

    # generate option like '-a', aka short style
    multi method broadcastOption(&getarg, :$short!) {
        if $!prefix == Prefix::SHORT && $!name.chars == 1 {
            for self!guess-option(&getarg) -> $g {
                emit MatchContext.new(
                    handler => $!handler,
                    style => Style::SHORT,
                    contexts => [
                        MatchContext::Option.new(
                            prefix => $!prefix,
                            name   => $!name,
                            hasarg => $g.[0],
                            getarg  => $g.[1],
                        )
                    ]
                );
            }
        }
    }

    # generate option like '[-|--]ab' ==> '[-|--]a b, that mean b is argument of option a
    multi method broadcastOption(&getarg, :$ziparg!) {
        if $!name.chars > 1 && !$!value.defined {
            emit MatchContext.new(
                handler => $!handler,
                style => Style::ZIPARG,
                contexts => [
                    MatchContext::Option.new(
                        prefix => $!prefix,
                        name   => $!name.substr(0, 1),
                        hasarg => True,
                        getarg  => sub { $!name.substr(1); },
                    )
                ]
            );
        }
    }

    # generate option like '[-|--][/]ab' ==> '[-|--][/]a [-|--][/]b, that mean multi option
    multi method broadcastOption(&getarg, :$comb!) {
        if $!name.chars > 1 {
            my @opts = $!name.comb;
            my @contexts;

            for @opts[0..*-2] -> $opt {
                @contexts.push(
                    MatchContext::Option.new(
                            prefix => $!prefix,
                            name   => $opt,
                            hasarg => False,
                            getarg  => do {
                                ($!value === False) ?? (ParserRF) !! (ParserRT);
                            },
                        )
                );
            }
            for self!guess-option(&getarg) -> $g {
                my @t = @contexts;
                @t.push(
                    MatchContext::Option.new(
                        prefix => $!prefix,
                        name   => @opts[*-1],
                        hasarg => $g.[0],
                        getarg  => $g.[1],
                    )
                );
                emit MatchContext.new(
                    handler => $!handler,
                    style => Style::COMB,
                    contexts => @t
                );
            }
        }
    }
}

sub broadcastOption(Option::Actions:D $actions, &getarg, %styles) {
    if %styles<long> {
        $actions.broadcastOption(&getarg, :long);
    }
    if %styles<xopt> {
        $actions.broadcastOption(&getarg, :xopt);
    }
    if %styles<short> {
        $actions.broadcastOption(&getarg, :short);
    }
    if %styles<ziparg> {
        $actions.broadcastOption(&getarg, :ziparg);
    }
    if %styles<comb> {
        $actions.broadcastOption(&getarg, :comb);
    }
    $actions.handler.handle($actions);
}

sub broadcastNonOption($a, ResultHandler $handler) {
    if $a.index == 0 {
        emit MatchContext.new(
            handler  => $handler,
            style    => Style::CMD,
            contexts => [
                MatchContext::NonOption.new( argument => $a ),
            ]
        );
    }
    emit MatchContext.new(
        handler  => $handler,
        style    => Style::POS,
        contexts => [
            MatchContext::NonOption.new( argument => $a ),
        ]
    );
    $handler.handle($a);
}

role ResultHandler {
    has $.success = False;

    method setSuccess() {
        $!success = True;
    }

    method reset() {
        $!success = False;
    }

    method handle($data) { }

    method shiftArgs() {}
}

sub ga-parser(@args, :$strict, :$bsd-style, :$autohv , *%styles --> Supply) is export {
    supply {
        my ($count, $noaIndex) = (+@args, 0);
        my @noa;
        my $nrh = ResultHandler.new;

        loop (my $index = 0; $index < $count; $index += 1) {
            sub isNextAnArgument( --> False ) {
                if ($index + 1 < $count) {
                    given @args[$index + 1] {
                        unless $strict && (
                            .starts-with('-')  || .starts-with('--') || .starts-with('-/') || .starts-with('--/')
                        ) {
                            return True;
                        }
                    }
                }
            }

            # getarg not add the index, so that we can verify the argument
            sub getarg() {
                return @args[$index + 1];
            }

            my class OptionResultHanlder does ResultHandler {
                method handle($data) {
                    Debug::debug("Call handler for option [{@args[$index]}]");
                    unless self.success {
                        &ga-try-next("Can not find the option: {@args[$index]}");
                    }
                }

                #| when option want skip the argument, call this method
                method shiftArgs() {
                    $index += 1;
                }
            }

            my class NonOptionResultHandler does ResultHandler {

            }

            state $prh = OptionResultHanlder.new;
            state $nrh = NonOptionResultHandler.new;

            my ($arg, $actions) := ( @args[$index], Option::Actions.new );

            .reset() for $nrh, $prh;
            if Option::Grammar.parse($arg, :$actions) {
                $actions.setHandler($prh);
                broadcastOption($actions, &isNextAnArgument() ?? &getarg !! Callable, %styles);
            } else {
                my $bsd;
                if $bsd-style {
                    $bsd = MatchContext.new(
                        handler => $nrh,
                        style => Style::BSD,
                        contexts => [
                            MatchContext::Option.new(
                                prefix  => Prefix::NULL,
                                name    => $_,
                                hasarg  => False,
                                getarg  => ParserRT,
                            ) for $arg.comb();
                        ]
                    );
                    emit $bsd;
                    Debug::debug("Bsd match result of [{$arg}]: {$bsd.matched}");
                }

                if !$bsd-style || !$bsd.matched {
                    my $a = Argument.new( index => $noaIndex, value => $arg, );
                    @noa.push($a);
                    Debug::debug("Emit NOA [{$arg}\@{$noaIndex}]");
                    broadcastNonOption($a, $nrh);
                }
            }
        }
        emit MatchContext.new(
            handler  => $nrh,
            style    => Style::MAIN,
            contexts => [
                MatchContext::Main.new( argument => @noa ),
            ]
        );
    }
}
