

use Test;
use Getopt::Advance;

plan 4;

my OptionSet $optset .= new;

$optset.push("h|help=b");
$optset.push("v|version=b", "print program version.");
$optset.push("c|count=i");
$optset.push("?=b");

getopt(
    ["-hvc", "42", "-?"],
    $optset,
    :x-style
);

ok $optset<h>, "bsd-style set help";
ok $optset<v>, "bsd-style set version";
ok $optset<?>, "bsd-style set ?";
is $optset<c>, 42;
