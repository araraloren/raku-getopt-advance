
use Test;
use Getopt::Advance;
use Getopt::Advance::Option;

plan 28;

my OptionSet $optset .= new;

$optset.push("h|help=b");
$optset.push("v|version=b", 'print the program version.');
$optset.push("c|compiler=s", 'set the compiler.', value => 'g++');
$optset.push(
    "m|main=s",
    'set the main function header.',
    value => 'int main(void)',
    callback => sub ($opt, $v) {
        ok $opt === $optset.get("main"), "pass the option to the callback.";
        is $v, "int main(int argc, char* argv[])", "set the option value ok.";
    }
);
$optset.push("f|flag=a");
$optset.push("ex|=h", value => %(win32 => 'exe'));
$optset.push("q|quite=b/");
$optset.push("?=b");

$optset.append("p|print-code=b;d|debug=b;t|temp=a");
$optset.append(
    'i|include=a' => 'set the include file.', 'I=a' => 'set the include search path.'
);
$optset.append(
    'S=b' => 'pass -S to compiler.', 'E=b' => 'pass -E to compiler.',
    :radio
);
$optset.append('e=a;r=b', :radio, :!optional);
$optset.append('l|link=a;L|=a;D|DEFINE=a', :multi);

$optset.set-value('f', 'Wall');
$optset.set-annotation('h', 'b', 'print the help message.');
$optset.set-callback('c', 's', sub ($opt, $v) {
    ok True == True , 'the callback called.';
    is $v, 'clang++', 'set the compiler to clang++.';
});

my $thr;

supply {
    whenever $optset.Supply('h') {
        my ($os, $opt, $v) = @$_;

        $thr = start {
            sleep 1;
            ok True, 'sleep 1 in another thread.';
        };

        is $os, $optset, "get the optset from supply block";
    }
}.tap;

&getopt(
    [
        '-h',
        '--compiler',   'clang++',
        '-m',           'int main(int argc, char* argv[])',
        '-ex',          ':linux(a)',
        '-S',
        '--/quite',
        '-l',           'm',
        '-L',           './',
        '-i',           'math.h',
        '-e',           'printf("Hello World!");',
        '--debug',
        '-?',
    ],
    $optset
);

$optset.set-value('e', 'a', 'return 0;');

is      $optset.values.elems, 20, 'we add 20 options.';
isa-ok  $optset.get('h'), Option::Boolean, 'the **help** is a boolean option.';
isa-ok  $optset.get('c', 's'), Option::String, 'the **compiler** is a String option.';
isa-ok  $optset.get('w'), Any, 'we have not a **w** option.';
nok     $optset.has('o'), 'we have not a **o** option.';
ok      $optset.has('t'), 'we have a **t** option.';
ok      $optset.{'t'}:exists, 'we have a **t** option.';
ok      $optset.remove('t'), 'remove the **t|temp** option.';
nok     $optset.has('t'), 'we have not a **t** option.';
nok     $optset.{'t'}:exists, 'we have not a **t** option.';
ok      $optset.{'S'}, '**S** option is True.';
        $optset.reset('S');
nok     $optset.{'S'}, 'reset **S** option ok.';
ok      $optset.<h d>, 'has set the **debug** and **help** option.';
is      $optset.get('h', 'b').value, True, 'set the **help** option value to True.';
is      $optset.get('v').annotation, 'print the program version.', 'get the annotation message ok';
ok      "Wall" (elem) $optset<f>, 'set value Wall to **f** option ok';
is      $optset<e>, [ 'printf("Hello World!");', "return 0;", ], 'append to option value ok';
is      $optset<ex>, { linux => 'a', win32 => 'exe' }, "set hash value ok";
nok     $optset<q>, 'disable **quite** option ok';
is      $optset<c>, 'clang++', 'set the **compiler** option ok';
is      $optset<u>, Any, 'get any when option not exists';
ok      $optset<?>, 'set the ? option ok';

await $thr;
