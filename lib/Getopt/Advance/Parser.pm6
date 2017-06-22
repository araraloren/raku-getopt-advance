
use Getopt::Advance::Argument;

# check name
# check value
# then parse over
sub parser($optset, @args) is export {
    my Argument @noa = [];

    loop (my $index = 0;$index < +@args;$index++) {
        my $args := @args[$index];

        given $args {
            # treat -- and - as NonOption argument
            when '-' | '--' {
                @noa.push(Argument.new(index => $index, value => $args));
            }

            # --[multi letter]<gun-style>
            # --[single letter]<custom style>
            when .starts-with('--') {

            }

            # -[single letter]<unix-style>
            # -[multi letter]<unix-style x-style>
            when .starts-with('-') {

            }

            # NonOption argument
            default {

            }
        }
    }
}
