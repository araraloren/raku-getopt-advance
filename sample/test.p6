#!/usr/bin/env perl6

use Getopt::Advance;
use Getopt::Advance::SubInfo;
use Getopt::Advance::Exception;

class Calculator{
    method double(:$number) {
        2 * $number;
    }

    method pow($number, $pow where * > 0) {
        $number ** $pow;
    }
}

sub classBridge(::T) {
    my @methods = T.^methods(:local);
    my @oss;
    my $pos;

    for @methods -> $method {
        my (@named, @pos);
        @oss.push(my $os := OptionSet.new);
        $os.insert-cmd($method.name);
        $pos = -1;
        for @($method.signature.params) -> $param {
            next if $pos++ == -1;
            next if $param.slurpy;
            if $param.named {
                my $type = do given $param.type {
                    when Int { "i" }
                    when Array { "a" }
                    default { "s" }
                };
                $os.push("{$param.named_names.[0]}={$type}");
                @named.push($param.named_names.[0]);
            } else {
                if $param.sigil eq '$' {
                    my $id = $os.insert-pos($param.name.substr(1), $pos, sub ($arg) {
                        if not so $param.constraints.($arg.value) {
                            &ga-try-next-pos("pos matched failed: {$param.name}")
                        }
                    });
                    @pos.push($id);
                }
            }
        }
        $os.insert-main(sub ($os, @) {
            my @args;
            @args.push($os.get-pos($_).value) for @pos;
            my %args;
            for @named {
                if $os.get($_).has-value {
                    %args{$_} = $os.get($_).value;
                }
            }
            say $method.(T, | @args, | %args);
        });

    }
    @oss;
}

sub f(:$a) {

}

my $os = OptionSet.new;

say mixin-option($os, &f);
