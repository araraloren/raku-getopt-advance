
sub ga-helper($optset, $outfh) is export {
    $outfh.say($optset.usage());
    $outfh.say("");
    $outfh.say(.join("  "), "\n") for @($optset.annotation());
    $outfh.say("");
}

sub ga-helper2($optset, $outfh, :$table-format) is export {
    my %no-cmd = $optset.get-cmd();
    my %no-pos = $optset.get-pos();
    my @main = $optset.values();
    my (@command, @pos, @wepos, @opts) := ([], [], [], []);

    if %no-cmd.elems > 0 {
        @command.push($_) for %no-cmd.values>>.usage;
    }

    if %no-pos.elems > 0 {
        my $fake = 4096;
        my %kind = classify {
            $_.index ~~ Int ?? ($_.index == 0 ?? 0 !! 'index' ) !! '-1'
        }, %no-pos.values;

        if %kind{0}:exists && %kind<0>.elems > 0 {
            @command.push("<{$_}>") for @(%kind<0>)>>.usage;
        }

        if %kind<index>:exists && %kind<index>.elems > 0 {
            my %pos = classify { $_.index }, @(%kind<index>);

            for %pos.sort(*.key)>>.value -> $value {
                @pos.push("<{join("|", @($value)>>.usage)}>");
            }
        }

        if %kind{-1}:exists && %kind{-1}.elems > 0 {
            my %pos = classify { $_.index.($fake) }, @(%kind{-1});

            for %pos.sort(*.key)>>.value -> $value {
                @wepos.push("<{join("|", @($value)>>.usage)}>");
            }
        }
    }
    for @main -> $opt {
        @opts.push($opt.optional ?? "[{$opt.usage}]" !! "<{$opt.usage}>");
    }

    if not $table-format {
        my $usage = "Usage:\n";

        for @command -> $cmd {
            $usage ~= "{$*PROGRAM-NAME} {$cmd} {join(" ", @pos)} ";
            $usage ~= "{join(" ", @opts)} {join(" ", @wepos)} ";
            $usage ~= $optset.get-main().elems > 0 ?? "*\@args\n" !! "\n";
        }

        $outfh.say("{$usage}");
        $outfh.say(.join("  "), "\n") for @($optset.annotation());
        $outfh.say("");
    } else {
        my @usage = [];

        for @command -> $cmd {
            my @inner-usage = [];

            @inner-usage.push($*PROGRAM-NAME);
            @inner-usage.push($cmd);
            @inner-usage.append(@pos);
            @inner-usage.append(@opts);
            @inner-usage.append(@wepos);
            @inner-usage.append($optset.get-main().elems > 0 ?? "*\@args" !! "");
            @usage.push(@inner-usage);
        }

        require Terminal::Table <&array-to-table>;

        $outfh.say(.join(" ")) for &array-to-table(@usage, style => 'none');
        $outfh.say("");
        $outfh.say(.join(" "), "\n") for @($optset.annotation());
        $outfh.say("");
    }
}

sub ga-versioner(Str $version, $outfh) is export {
    $outfh.say($version) if $version;
}
