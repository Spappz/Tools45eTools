# Tools45eTools

A collection of PowerShell scripts to make a few niche things in the 5eTools project easier.

- [How2PowerShell](#how2powershell)
- [The scripts](#the-scripts)
  - [Creature Imager](#creature-imager)
  - [Entries Tagger](#entries-tagger)
  - [Fluff Tagger](#fluff-tagger)
  - [Homebrew Merger](#homebrew-merger)
  - [Mask Rescaler](#mask-rescaler)
  - [Tag Checker](#tag-checker)
  - [URL Tester](#url-tester)
- [Contributing](#contributing)

## How2PowerShell

Each script has some comments at the top. Read them before use.

If you're on Windows, the script doesn't specify that it requires a PowerShell version above 5, _and_ no command arguments are listed, you can right-click the script and select 'Run with PowerShell'.

Otherwise, you'll need to [install](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows) the latest version (macOS/Linux [here](https://github.com/powershell/powershell)) and run the script via the command line.

## The scripts

### Creature Imager

This script applies images and tokens to a brew file in bulk by reading from a `.csv` file. Useful for creature-heavy conversions and art updates.

### Entries Tagger

This script looks throughout a brew file for `entries`-like properties, and then proceeds to (try to) automatically tag things.

### Fluff Tagger

This script adds the `hasFluff` and `hasFluffImages` properties, as appropriate, to (most) datatypes with a referenced `_<datatype>Fluff` object.

### Homebrew Merger

This script stitches 5eTools-style homebrew JSONs together to output a single JSON with all the content included, saving you having to lug around many files at once.

### Mask Rescaler

This script resizes all the masks outputted by the PDF Image Extractor to match the preceding image's size.

### Tag Checker

This script tests a file or directory of files for any bad `@tag`s.

### URL Tester

This script verifies that media URLs aren't dead.

## Contributing

Raise an issue if something's broken. ~~Development ongoing.~~ Additions welcome (in any language; I just use PowerShell because I'm lazy).
