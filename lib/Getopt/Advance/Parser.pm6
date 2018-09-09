
use Getopt::Advance::Utils:api<2>;
use Getopt::Advance::Context:api<2>;
use Getopt::Advance::Option:api<2>;
use Getopt::Advance::Exception:api<2>;
use Getopt::Advance::Argument:api<2>;

unit module Getopt::Advance::Parser:api<2>;

my constant ParserRT = sub { True };
my constant ParserRF = sub { False };
my Int $messageid = 0;

role Parser { ... }
role ResultHandler { ... }

grammar OptionGrammar is export {
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

class OptionActions is export {
	has $.name;
	has $.value;
	has $.prefix;
    has $.handler;
    has $.publisher handles < publish >;

    method set-handler(ResultHandler $handler) {
        $!handler = $handler;
    }

    method set-publisher(Publisher $publisher) {
        $!publisher = $publisher;
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
    multi method broadcast-option(&getarg, :$long!) {
        # skip option like '-f'
        if $!prefix == Prefix::LONG  {
            for self!guess-option(&getarg) -> $g {
                self.publish: ContextProcesser.new(
                    id => $messageid++,
                    handler => $!handler,
                    style => Style::LONG,
                    contexts => [
                        TheContext::Option.new(
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
    multi method broadcast-option(&getarg, :$xopt!) {
        # skip option like '-f'
        if $!prefix == Prefix::SHORT && $!name.chars > 1  {
            for self!guess-option(&getarg) -> $g {
                self.publish: ContextProcesser.new(
                    id => $messageid++,
                    handler => $!handler,
                    style => Style::XOPT,
                    contexts => [
                        TheContext::Option.new(
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
    multi method broadcast-option(&getarg, :$short!) {
        if $!prefix == Prefix::SHORT && $!name.chars == 1 {
            for self!guess-option(&getarg) -> $g {
                self.publish: ContextProcesser.new(
                    id => $messageid++,
                    handler => $!handler,
                    style => Style::SHORT,
                    contexts => [
                        TheContext::Option.new(
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
    multi method broadcast-option(&getarg, :$ziparg!) {
        if $!name.chars > 1 && !$!value.defined {
            self.publish: ContextProcesser.new(
                id => $messageid++,
                handler => $!handler,
                style => Style::ZIPARG,
                contexts => [
                    TheContext::Option.new(
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
    multi method broadcast-option(&getarg, :$comb!) {
        if $!name.chars > 1 {
            my @opts = $!name.comb;
            my @contexts;

            for @opts[0..*-2] -> $opt {
                @contexts.push(
                    TheContext::Option.new(
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
                    TheContext::Option.new(
                        prefix => $!prefix,
                        name   => @opts[*-1],
                        hasarg => $g.[0],
                        getarg  => $g.[1],
                    )
                );
                self.publish: ContextProcesser.new(
                    id => $messageid++,
                    handler => $!handler,
                    style => Style::COMB,
                    contexts => @t
                );
            }
        }
    }
}

role ResultHandler is export {
    has $.success = False;
    has $.skiparg = False;

    #| set we match success
    method set-success() {
        $!success = True;
        self;
    }

    #| reset the status, so we can use the handler next time
    method reset() {
        $!success = $!skiparg = False;
        self;
    }

    #| will called after the ContextProcesser process the thing
    method handle($parser) { self; }

    #| when option want skip the argument, call this method, default do nothing
    method skip-next-arg() { self; }
}

role Parser does Getopt::Advance::Utils::Publisher is export {
    has Bool $.strict;
    has Bool $.autohv;
    has Bool $.bsd-style;
    has $.optgrammar;
    has $.optactions;
    has Int  $.index;
    has Int  $.count;
    has Int  $!noaIndex;
    has $.arg;
    has @.noa;
	has $.owner;
    has &.is-next-arg-available;
    has ResultHandler $.nrh; #| for NonOption
    has ResultHandler $.brh; #| for BSD Option
    has ResultHandler $.orh; #| for Option
	has ResultHandler $.mrh; #| for Main    
    has @.styles;
    has @.args;

    method init(@!args,  :@order) {
        $!noaIndex = $!index = 0;
        $!count = +@!args;
        unless &!is-next-arg-available.defined {
            &!is-next-arg-available = sub ( Parser $parser --> False ) {
                given $parser {
                    if (.index + 1 < .count) {
                        given .args[.index + 1] {
                            unless $parser.strict && (
                                .starts-with('-')  || .starts-with('--') || .starts-with('-/') || .starts-with('--/')
                            ) {
                                return True;
                            }
                        }
                    }
                }
            }
        }
        unless $!orh.defined {
            $!orh = class :: does ResultHandler {
                method handle($parser) {
                    Debug::debug("Call handler for option [{$parser.arg}]");
                    unless self.success {
                        &ga-parse-error("Can not find the option: {$parser.arg}");
                    }
                    #| skip next argument if the option has consume an argument
                    Debug::debug("Will skip the next arguments");
                    $parser.skip() if self.skiparg();
                    self;
                }
            }.new;
        }
        unless $!nrh.defined {
            $!nrh = ResultHandler.new;
        }
        if $!bsd-style {
            unless $!brh.defined {
                $!brh = ResultHandler.new;
            }
        }
		unless $!mrh.defined {
			$!mrh = class :: does ResultHandler {
				method set-success() { } # skip the set-success, we need call all the MAINs
			}.new;
		}
        if +@order > 0 {
            my (%order, @sorted);
            %order{ @order } = 0 ...^ +@order;
            Debug::debug("Sort the styles with >> {@order.join(" - ")}");
            for @!styles -> $style {
                @sorted[%order{$style.key.Str}] = $style;
            }
            @!styles = @sorted;   
        } elsif +@order == 0 && +@!styles == 0 {
            &ga-raise-error('Set the :@order, styles for parser!');
        }
        self;
    }

    #| skip current argument
    method skip() {
        $!index += 1;
    }

    method CALL-ME( $!owner ) {
        my @delaypos;

        Debug::debug("Got arguments '{@!args.join(" ")}' from input");
        while $!index < $!count {
            ($!arg, my $actions) = ( @!args[$!index], self.optactions.new );

            sub get-option-arg() { @!args[$!index + 1]; }

            Debug::debug("Process the argument '{$!arg}'\@{$!index}");

            if self.optgrammar.parse($!arg, :$actions) {
                #| the action need handler pass it to ContextProcesser
                $actions.set-handler($!orh.reset());
                $actions.set-publisher(self);
                for @!styles -> $style {
                    if $style.defined {
                        Debug::debug("** Start broadcast {$style.key.Str} style option");
                        $actions.broadcast-option(&!is-next-arg-available(self) ?? &get-option-arg !! Callable, |$style);
                        Debug::debug("** End broadcast {$style.key.Str} style option");
                    }
                }
                $!orh.handle(self);
            } else {
                my $bsdmc;

                #| if we need suppot bsd style
                if $!bsd-style {
                    #| reset the bsd style handler
                    $bsdmc = ContextProcesser.new( handler => $!brh.reset(), style => Style::BSD,
                        id => $messageid++,
                        contexts => [
                            TheContext::Option.new(
                                prefix  => Prefix::NULL,
                                name    => $_,
                                hasarg  => False,
                                getarg  => ParserRT,
                            ) for $!arg.comb();
                        ]
                    );
                    Debug::debug("** Broadcast a bsd style option [{$!arg.comb.join("|")}]");
                    self.publish: $bsdmc;
                    $!brh.handle(self);
                    Debug::debug("** End bsd style");
                }

                #| if not bsd style or it matched failed
                if !$!bsd-style || !$bsdmc.matched {
                    my $a = Argument.new( index => $!noaIndex++, value => $!arg, );

                    #| push the arg to @!noa
                    @!noa.push($a);

                    Debug::debug("** Begin POS NonOption");

                    #| maybe a POS
                    self.publish: ContextProcesser.new( handler => $!nrh.reset(), style => Style::POS,
                        id => $messageid++, 
                        contexts => [
                            TheContext::Pos.new( argument => @!noa, index => $a.index ),
                        ]
                    );
                    $!nrh.handle(self);

                    Debug::debug("** End POS NonOption");
                }
            }

            #| increment the index
            self.skip();
        }

        Debug::debug(" + Check the option and group");
        $!owner.check();

        #| last, we should emit the CMD and MAIN
        if +@!noa > 0 {
            Debug::debug("** Broadcast the CMD and WHATEVERPOS NonOption");
            self.publish: ContextProcesser.new( handler => $!nrh.reset(), style => Style::CMD,
                id => $messageid++,
                contexts => [
                    TheContext::NonOption.new( argument => @!noa, index => 0),
                ]
            );
            $!nrh.handle(self);
            for @!noa -> $noa {
                self.publish: ContextProcesser.new( handler => $!nrh.reset(), style => Style::WHATEVERPOS,
                    id => $messageid++,
                    contexts => [
                        TheContext::Pos.new( argument => @!noa, index => $noa.index ),
                    ]
                );
                $!nrh.handle(self);
            }
            Debug::debug("** End the CMD and WHATEVERPOS NonOption");
        }
        #`[check the cmd and pos@0]
        Debug::debug(" + Check the cmd and pos@0");
        $!owner.check-cmd();
        Debug::debug("** Broadcast the MAIN NonOption");
        #| we don't want skip any other MAINs, so we using $!mrh skip the set-success method
        self.publish: ContextProcesser.new( handler => $!mrh.reset(), style => Style::MAIN,
            id => $messageid++,
            contexts => [
                TheContext::NonOption.new( argument => @!noa, index => -1 ),
            ]
        );
        $!mrh.handle(self);
        self;
    }
}
