#!/usr/bin/env raku

use Getopt::Advance;
use Getopt::Advance::Parser;
use Getopt::Advance::Exception;

my @files = [];
my OptionSet $optset .= new;

$optset.insert-pos(
    "directory",
    0,
    sub ($, $dirarg) {
        die "$dirarg: Not a valid directory" if $dirarg.value.IO !~~ :d;
        @files = gather &find($dirarg.value.IO);
    }
);
$optset.append(
    "h|help=b"      => "print this help.",
    "v|version=b"   => "print program version.",
    "?=b"           => "same as -h.",
    :multi
);
$optset.append(
    'd=b' => 'specify file type to directory',
    'l=b' => 'specify file type to symlink',
    'f=b' => 'specify file type to normal file',
    :radio
);
for <d l f> -> $t {
    $optset.set-callback(
        $t,
        -> $, $ { @files = @files.grep({ ."{$t}"(); }); }
    );
}
$optset.push(
    'size=i',
    'the minimum size limit of file.',
    callback => sub ($, $size) {
        @files = @files.grep({ .s() >= $size.Int; });
    }
);
$optset.insert-main(
    sub main($optset, @args) {
        return 0 if $optset<help> || $optset<version>;
        if $optset.get-pos('directory', 0).?success {
            @args.shift;
        } else {
            &ga-want-helper();
        }
        my $regex = +@args > 0 ?? @args.shift.value !! "";

        if $regex eq "" {
            .path.say for @files;
        } else {
            .path.say if .path ~~ /<$regex>/ for @files;
        }
    }
);

&getopt($optset, :autohv, parser => &ga-parser2);

sub find($dir) {
    for $dir.dir() -> $f {
        take $f;
        if $f ~~ :d {
            &find($f);
        }
    }
}
