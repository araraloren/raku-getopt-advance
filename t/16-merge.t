
use Test;
use Getopt::Advance;

plan 10;

my OptionSet $common .= new;

$common.push("h|help=b");
$common.insert-main(sub main($, @) {
    ok $common.has("v"), "merge ok";
    ok $common.has("z"), "merge ok";
});
$common.insert-cmd("merge");
$common.insert-pos(
    "common",
    1,
    sub () {
        ok True, "call pos okay";
    }
);

my OptionSet $os1 .= new;

$os1.push("v|version=b");
$os1.append("a=s;b=b;c=f", :radio);
$os1.push("z|zsd=h");
$os1.insert-main(sub main1() {
    ok True, "merge ok";
});



getopt(["merge", 1, "-a", "your", "-z", "a => 88"], $common.merge($os1));

ok $common.has('h'), "merge ok";
ok $common.has("a"), "merge ok";
ok $common.has('b'), "merge ok";
ok $common.has("c"), "merge ok";
ok $common.get('z').value.<a> == 88, "merge ok";
ok $common.get('a').value eq "your", "merge ok";
