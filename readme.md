
# Wonder Boy: The Dragon's Trap Mod Launcher
Simple mod launcher for Wonder Boy: The Dragon's Trap

### Overview
This mod launcher works with the Steam or GOG editions of the game. If a data directory is passed through the command line parameter `--data-dir=<folder_name>`, the launcher will switch the game resources folder to the directory specified on the fly before launching the game. Once the game is closed, the original folder names and locations are restored to their previous state. If no data directory is specified, it'll simply launch the game normally

### Building
Compile this script with AutoIt v3 and place a copy of the generated binaries inside the `exe32` and `exe64` folders found in the install location of Wonder Boy: The Dragon's Trap. The original game binaries **must** be renamed to `wb.bkp.exe` (can be changed in source) and the compiled binaries of this script should be renamed to `wb.exe` (so they don't break launching from Steam / GOG Galaxy). 

Pre-compiled binaries are also [available here](https://github.com/mbc07/WBDT_launcher/releases)
