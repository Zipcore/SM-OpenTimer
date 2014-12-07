SM-OpenTimer
============

SourceMod timer plugin for bunnyhop servers. **Currently only supports multihop maps!** (Deletes all func_doors because I'm an idiot.)

Use these commands, please:
- bot_quota 3
- bot_quota_mode normal
- sv_hudhint_sound 0 (lol)

Creating a .nav file for maps (Required for record bots. Tell Valve how much you hate it.)
- Local server and the map you want to generate the .nav file for.
- *sv_cheats 1; nav_mark_walkable* and aim at the floor. This should generate .nav file in your maps folder.
- Move that into your server's maps folder. Potentially put it in your fast-dl. ;)

TO-DO LIST:
- Use DHOOKS to teleport the bots.
- Use better sync, lol. The current one is shitty.
- More tweaks.
- More everything.
- Fix shit.
