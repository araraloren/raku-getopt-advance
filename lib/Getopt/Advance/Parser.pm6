
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
                @noa.push(Argument.new(index => $index, value => $args));
            }
        }

        with $name {
            if $optset.get($name) -> $opt {
                if $name eq ($long ?? $opt.long !! $opt.short) {
                    without $value {
                        if $opt.type eq BOOLEAN {
                            $value = True;
                        } elsif ($index + 1 < $count) {
                            unless $strict && @args[$index + 1].start-with('-'|'--'|'--/') {
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
    my %pos = $optset.non-option(:pos);

    for %pos.values() -> $pos {
        for @noa -> $noa {
            if $pos.match-index($count, $noa.index) {
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
