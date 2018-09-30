
use Test;
use Getopt::Advance;
use Getopt::Advance::Exception;

plan 3;

{
    my OptionSet $optset .= new;

    $optset.insert-cmd("plus", "Using plus feature");
    $optset.insert-cmd("multi", "Using multi feature");
    $optset.insert-pos("other", "Using other feature", :front, sub ($arg) {
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

{
    my OptionSet $optset .= new;

    $optset.insert-cmd("plus");
    $optset.insert-cmd("multi");
    $optset.insert-pos("type", 1, sub ($arg) {
        say $arg;
    });
    $optset.insert-pos("control", * - 2, sub ($arg) {
        say $arg;
    });
    $optset.push("h|help=b", "print this help message.");
    $optset.push("v|version=b", "print the version message.");
    $optset.push("c|count=i!", "set count.");
    $optset.push("w|=s!", "wide string.");
    $optset.push("quite=b/", "quite mode.");

    lives-ok {
        getopt(["plus", "-c", 2, "-w", "string", "-h"], $optset, :autohv);
    }, "auto helper";

    lives-ok {
        getopt(["plus", "-c", 2, "-w", "string", "-v"], $optset, :autohv, version => "v0.0.1 create by araraloren.\n");
    }, "auto helper";
}
