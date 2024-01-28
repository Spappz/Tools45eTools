## How2PowerShell

On Windows, right-click this script and select 'Run with PowerShell'. If a script specifies that it requires a version of PowerShell greater than 5, you'll need to [install](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows) it. On Mac OS and Linux, you will probably have to install [PowerShell](https://github.com/powershell/powershell) and run it via command line.

Each script has some comments at the top. Read them before use.

---

### Creature Fluff Tagger

This script adds the `hasFluff` and `hasFluffImages` properties, as appropriate, to creatures with a referenced `_monsterFluff` object.

---

### Creature Imager

This script applies images and tokens to a brew file in bulk by reading from a `.csv` file. Useful for creature-heavy conversions and art updates.

---

### Entries Tagger

This script looks throughout a brew file for `entries`-like properties, and then proceeds to (try to) automatically tag things.

---

### Homebrew Merger

This script stitches 5eTools-style homebrew JSONs together to output a single JSON with all the content included, saving you having to lug around many files at once.

---

### Mask Rescaler

This script resizes all the masks outputted by the PDF Image Extractor to match the preceding image's size.

---

### Tag Checker

This script tests a file or directory of files for any bad `@tag`s.

---

### Tag Checker

This script tests a file or directory of files for any bad `@tag`s.

---

### URL Tester

This script verifies that media URLs aren't dead.

---

Raise an issue if something's broken. ~~Development ongoing.~~ Contributions welcome.
