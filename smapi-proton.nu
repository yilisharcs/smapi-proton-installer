#!/usr/bin/env nu

# Install SMAPI for Stardew Valley under Proton.
#
# File-copy of the Windows payload per the wiki's manual install:
#   https://stardewvalleywiki.com/Modding:Installing_SMAPI_on_Windows
#   https://stardewvalleywiki.com/Modding:Installing_SMAPI_on_Linux#SMAPI_with_Proton
#
# No installer binary runs, so it works on NixOS.
def main []: nothing -> nothing { help main }

const script = path self
const script_exe = ($script | path basename)
const script_dir = ($script | path dirname)

# bump this when updating
const smapi_url = "https://github.com/Pathoschild/SMAPI/releases/download/4.5.2/SMAPI-4.5.2-installer.zip"

let cache_home = ($env.XDG_CACHE_HOME? | default ([$env.HOME ".cache"] | path join))
let cache_dir = ([$cache_home "SMAPI-proton"] | path join)
let payload_dat = ([$cache_dir "install.dat"] | path join)

let zip_name = ($smapi_url | path split | last)
let zip_path = ([$cache_dir $zip_name] | path join)

def resolve-game-dir []: nothing -> path {
    let candidates = [
        $"($env.HOME)/.local/share/Steam/steamapps/common/Stardew Valley"
        $"($env.HOME)/.steam/steam/steamapps/common/Stardew Valley"
        # flatpak
        $"($env.HOME)/.var/app/com.valvesoftware.Steam/data/Steam/steamapps/common/Stardew Valley"
    ]
    let matches = ($candidates | where {|dir|
        [
            "Stardew Valley.exe"
            "Stardew Valley.deps.json"
        ] | all {|f|
            [$dir $f] | path join | path exists
        }
    })
    if ($matches | is-empty) {
        error make --unspanned {
            msg: "Stardew Valley install directory not found"
            help: ($candidates | each {|dir| $"  - ($dir)"} | str join (char nl))
            code: "smapi-proton::no_game_dir"
        }
    } else {
        $matches | first
    }
}
let game_dir = (resolve-game-dir)

# Unpack the Windows SMAPI into the game folder.
def "main install" [] {
    if (which unzip | is-empty) {
        error make --unspanned {
            msg: "unzip: command not found. cannot unpack install.dat"
            help: $"install unzip \(e.g. `nix shell nixpkgs#unzip --command ./($script_exe)`)"
            code: "smapi-proton::no_unzip"
        }
    }

    mkdir $cache_dir

    let archives = (
        ls $cache_dir
        | where {|r| ($r.name | path basename) =~ '^SMAPI-.*-installer\.zip$'}
        | sort-by modified --reverse
        | get 0?
    )
    let zip = (if $archives == null {
        print $"Downloading ($zip_name)..."
        try {
            http get $smapi_url | save --force $zip_path
            $zip_path
        } catch {
            error make --unspanned {
                msg: "download failed"
                code: "smapi-proton::download_failed"
            }
        }
    } else {
        $archives.name
    })
    let extract = (do { ^unzip -j -o $zip "*internal/windows/install.dat" -d $cache_dir } | complete)
    if $extract.exit_code != 0 {
        error make --unspanned {
            msg: ($extract.stderr | str trim)
            code: "smapi-proton::extract_failed"
        }
    }

    print $"Installing SMAPI-Proton into: ~/($game_dir | path relative-to $env.HOME)"

    # -o  overwrite files WITHOUT prompting
    # -q  quiet mode (-qq => quieter)
    # -d  extract files into exdir
    let result = (do { ^unzip -o -q $payload_dat -d $game_dir } | complete)
    if $result.exit_code != 0 {
        error make --unspanned {
            msg: ($result.stderr | str trim)
            code: "smapi-proton::unzip_failed"
        }
    }

    let game_deps  = ([$game_dir "Stardew Valley.deps.json"] | path join)
    let smapi_deps = ([$game_dir "StardewModdingAPI.deps.json"] | path join)
    cp --force $game_deps $smapi_deps

    print $"
SMAPI installed. Next steps, in the Steam client:

    1. Games -> Add a Non-Steam Game -> Browse -> ~/([$game_dir StardewModdingAPI.exe] | path join | path relative-to $env.HOME)
    2. Right-click the new entry -> Properties -> Compatibility -> force a Proton version.
    3. Launch 'StardewModdingAPI' from your library to play with mods.

To share saves with the vanilla game, first launch 'StardewModdingAPI'
to create its save prefix, then run `./($script_exe) link-saves`. Be
warned that Steam Cloud only watches the vanilla entry's save folder.
With `link-saves`, your modded saves sit there too, but only back up
after you play vanilla again.

SMAPI added its two bundled mods \(SaveBackup, ConsoleCommands) to Mods/.
Your own mods go in the same folder."
}

# Remove SMAPI from the game folder. Mods/ and any mods you added are left alone.
def "main uninstall" [] {
    if ($payload_dat | path exists) == false {
        error make --unspanned {
            msg: "no SMAPI payload found"
            help: $"run ./($script_exe) install first"
            code: "smapi-proton::no_payload"
        }
    }
    let listing = (do { ^unzip -Z1 $payload_dat } | complete)
    if $listing.exit_code != 0 {
        error make --unspanned {
            msg: ($listing.stderr | str trim)
            code: "smapi-proton::unzip_list_failed"
        }
    }

    let removable = ($listing.stdout | lines | each {|e|
        let p = ($e | path parse)
        if ($p.parent | str starts-with "Mods/") {
            $p.parent
        } else if ($p.parent | is-empty) {
            if ($p.extension | is-empty) { $p.stem } else { $e }
        } else {
            $p.parent | path split | first
        }
    } | uniq | where $it != "Mods" | append "StardewModdingAPI.deps.json")

    print $"Removing SMAPI from: ~/($game_dir | path relative-to $env.HOME)"
    let removed = ($removable | each {|entry|
        let target = ([$game_dir $entry] | path join)
        if ($target | path exists) {
            rm --recursive --force $target
            $entry
        }
    } | compact)
    if ($removed | is-empty) {
        print "No SMAPI files found."
    } else {
        $removed | each {|entry| print $"  removed ($entry)"}
        print ""
        print "Done. The Steam non-Steam-game entry (if you added one) is yours to delete."
    }
}

# Link the modded prefix's saves folder to the vanilla one, so both share saves.
def "main link-saves" [] {
    let saves_suffix = "pfx/drive_c/users/steamuser/AppData/Roaming/StardewValley"
    let compatdata_candidates = [
        $"($env.HOME)/.local/share/Steam/steamapps/compatdata"
        $"($env.HOME)/.steam/steam/steamapps/compatdata"
        # flatpak
        $"($env.HOME)/.var/app/com.valvesoftware.Steam/data/Steam/steamapps/compatdata"
    ]
    let vanilla_roots = ($compatdata_candidates | where {|c| [$c "413150"] | path join | path exists})
    if ($vanilla_roots | is-empty) {
        error make --unspanned {
            msg: "compatdata/413150 not found"
            help: "launch Stardew Valley once so Steam creates its prefix"
            code: "smapi-proton::no_vanilla_prefix"
        }
    }
    let compatdata = ($vanilla_roots | first)
    let source = ([$compatdata "413150" $saves_suffix] | path join)

    let prefixes = (
        ls $compatdata
        | where type == dir
        | where {|r| ($r.name | path basename) != "413150"}
        | where {|r| [$r.name $saves_suffix] | path join | path exists}
        | sort-by modified --reverse
    )
    if ($prefixes | is-empty) {
        error make --unspanned {
            msg: "compatdata/<id> not found"
            help: "launch StardewModdingAPI once first, then rerun"
            code: "smapi-proton::no_modded_prefix"
        }
    }

    let chosen = ($prefixes | first)
    let id = ($chosen.name | path basename)
    let target = ([$chosen.name $saves_suffix] | path join)
    print $"Prefix: ($id)"
    if (($prefixes | length) > 1) {
        let older = (
            $prefixes
            | skip 1
            | each {|p| $p.name | path basename}
            | str join ', '
        )
        print $"  also matched \(older, ignored): ($older)"
    }

    if (($target | path expand) == ($source | path expand)) {
        print "Already linked."
    } else {
        rm --recursive --force $target
        ^ln -s $source $target
        print "Linked:"
        print $"  ~/($target | path relative-to $env.HOME)"
        print $"   -> ~/($source | path relative-to $env.HOME)"
    }
}
