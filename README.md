SM-OpenTimer (Read this!)
============

SourceMod timer plugin for *CSS* bunnyhop servers.

I was kind of in the middle of working on the plugin when suddenly I was contacted about it. I decided to release it in a hacky-state. However, everything should be stable right now. **The compiled version will always be stable.**

**Dependencies (Optional):**
- For 260vel weapons: https://forums.alliedmods.net/showthread.php?t=166468
- For multihop (Maps with func_door platforms.): https://forums.alliedmods.net/showthread.php?t=90467

**SQLite Required (Put this in your sourcemod/configs/databases.cfg)**

    "default"
    {
    	"driver"	"sqlite"
    	"database"	"database_name"
    	"host"		"localhost"
    }

**Use these commands, please:**
- bot_quota_mode normal
- sv_hudhint_sound 0 (lol)
- mp_ignore_round_win_conditions 1
- mp_autoteambalance 0

**Optional commands:**
- sv_allow_wait_command 0

**Plugin commands:**
- sm_autohopping 0/1 (Allow EZHOP and AUTO?)
- sm_forbidden_commands 0/1 (+left/+right allowed?)
- sm_prespeed 0/1 (Can go over 300vel when leaving starting zone?)

**Creating a .nav file for maps:** (Required for record bots. Tell Valve how much you hate it.)
- Local server and the map you want to generate the .nav file for.
- *sv_cheats 1; nav_mark_walkable* and aim at the floor. This should generate .nav file in your maps folder.
- Move that into your server's maps folder. Potentially put it in your fast-dl. ;)

**Features:**
- Timer with records and semi-working playback (not fully implemented.). 
- Times saved with SQLite.
- Toggle HUD elements, change FOV, etc.
- Zone building (Starting-Ending/Block/Freestyle/Bonus1-2 Zones)
- Practising (not fully implemented.)
- Simple map voting.
- Chat processing. (Custom colors for chat.)

**TO-DO LIST:**
- Use DHOOKS to teleport the bots.
- Use better sync, lol. The current one is shitty.
- Fix menus.
- More tweaks.
- More everything.
- Fix everything.
