<?php

exec("cd node-src && git diff  --name-only",$o);

$pending = [];
passthru("cd node-src && git stash push");

foreach($o as $file) {
    if(empty($file)) continue;
    $patch_name = strtr($file, "/", "_");
    if(!file_exists("patches/node-src/$patch_name.diff")) {
        echo "Adding $patch_name\n";
        $pending[] = "$patch_name.diff";
        passthru("QUILT_PATCHES=patches/node-src quilt new ".escapeshellarg("$patch_name.diff"));
        passthru("QUILT_PATCHES=patches/node-src quilt add ".escapeshellarg("node-src/$file"));
    } else {

    }
}

passthru("cd node-src && git stash pop");

foreach(array_merge(glob("patches/node-src/*.diff"), $pending) as $f) {
    $name = basename($f);
    passthru("QUILT_PATCHES=patches/node-src quilt refresh -f " . escapeshellarg($name));
}
