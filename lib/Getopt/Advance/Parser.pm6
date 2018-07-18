
use Getopt::Advance::Option:api<2>;
use Getopt::Advance::Exception;
use Getopt::Advance::Argument:api<2>;

unit module Getopt::Advance::Parser:api<2>;

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
		<-[\=]>+
	}

	token optvalue {
		.+
	}
}

class Option::Actions {
	has $.name;
	has $.value;
	has $.prefix;

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
}

sub make-type-info(Option::Actions:D $actions, &popValue) {
    if $actions.prefix == Prefix::LONG {
        emit $actions.name;
    } elsif $actions.prefix == Prefix::SHORT {
        emit $actions.name;
    } elsif $actions.prefix == Prefix::NULL {
        emit $actions.name;
    } else {
        emit $actions.name;
    }
}

sub ga-parser(Supplier::Preserving $noa, @args, :$strict, :$xStyle, :$bsdStyle, :$autohv --> Supply) is export {
    supply {
        my ($count, $noaIndex) = (+@args, 0);

        loop (my $index = 0; $index < $count; $index += 1) {
            sub pop-value() {
                if ($index + 1 < $count) {
                    given @args[$index + 1] {
                        unless $strict && (
                            .starts-with('-')  || .starts-with('--') || .starts-with('-/') || .starts-with('--/')
                        ) {
                            return @args[++$index];
                        }
                    }
                }
                ga-invalid-option(" need an argument! ");
            }

            my ($arg, $actions) := ( @args[$index], Option::Actions.new );

            if Option::Grammar.parse($arg, :$actions) {
                make-type-info($actions, &pop-value);
            } else {
                $noa.emit(Argument.new(index => $noaIndex++, value => $arg));
            }
        }
    }
}
