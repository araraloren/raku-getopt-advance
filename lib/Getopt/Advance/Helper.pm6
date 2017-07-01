
sub ga-helper($optset, $outfh) is export {
    $outfh.say($optset.usage());
    $outfh.say("");
    $outfh.say(.join("  ")) for @($optset.annotation());
    $outfh.say("");
}
