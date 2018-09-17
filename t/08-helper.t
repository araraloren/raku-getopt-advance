
use Test;
use Getopt::Advance;
use Getopt::Advance::Exception;

plan 1;

{
    my OptionSet $optset .= new;

    $optset.insert-cmd("plus");
    $optset.insert-cmd("multi");
    $optset.insert-pos("other", :front, sub ($arg) {
        &ga-try-next("want try next optionset");
    });
    $optset.insert-pos("type", 1, sub ($arg) {
        say $arg;
    });
    $optset.insert-pos("control", * - 2, sub ($arg) {
        say $arg;
    });
    $optset.push("h|help=b", "print this help message.");
    $optset.push("c|count=i!", "set count.");
    $optset.push("w|=s!", "wide string.");
    $optset.push("quite=b/", "quite mode.");

    dies-ok {
        getopt(["addx", ], $optset);
    }, "auto helper";
}
