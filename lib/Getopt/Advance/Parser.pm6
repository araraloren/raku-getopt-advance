
use Getopt::Advance::Option;
use Getopt::Advance::Argument;
use Getopt::Advance::Exception;


my class OptionAndValue {
    has $.optref;
    has $.value;

    method set-value() {
        say "\tSET VALUE |{$!optref.usage}| +{$!value}+ ";
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
sub ga-parser(@args, $optset, :$strict) is export {
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
                        @oav.push(OptionAndValue.new(optref => $opt, :$value));
                        next;
                    } else {
                        try-next("Option {$opt.usage} need an argument!");
                    }
                } else {
                    try-next("Option {$opt.usage} not correct!");
                }
            } else {
                try-next("Option {$name} not recongnize!");
            }
        }
    }

    # non-option
    my %front = $optset.non-option(:front);

    if %front.elems > 0 && +@noa == 0 {
        try-next("Need front command: < {%front.values>>.name.join("|")} >.");
    } else {
        my $matched = False;

        for %front.values() -> $front {
            $matched ||= $front.($optset, @noa[0]);
        }

        unless $matched {
            try-next("Not recongnize front command: {@noa[0].value}.");
        }
    }

    my %pos = $optset.non-option(:pos);

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
    my %all = $optset.non-option(:all);

    for %all.values() -> $all {
        $all.($optset, @noa);
    }

    return @noa;
}
