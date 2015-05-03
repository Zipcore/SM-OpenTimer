OpenTimer (Read this!)
============

SourceMod timer plugin for *CSS* bunnyhop servers. Yes, it is free as in freedom.
Test it out @ 98.166.119.99:27016

The plugin is written in new syntax which requires **SourceMod version 1.7**!

**Read opentimer_log.txt if you want to know what changes have been made!**

**Dependencies (Optional):**
- For 260vel weapons: https://forums.alliedmods.net/showthread.php?t=166468
- For multihop (Maps with func_door platforms.): https://forums.alliedmods.net/showthread.php?t=90467

**Things to remember:**

    - Make sure your admin status is root to create/delete zones. (configs/admins.cfg)
    - Use the chat command !zone to configure zones.
    - You can add/remove some functions such as recording or fancy chat by commenting out first few lines in the opentimer.sp file and then recompiling it.
    - !r, !respawn can be used to respawn.
    - Rest of the commands can be found with !commands.
    - This plugin will automatically create a new database called 'opentimer'. You are no longer required to change databases.cfg.
    - By default, max recording length is 45 minutes. Times can be however long.

**Required server commands for bunnyhop-gamemode to work:**
- bot_quota_mode normal
- sv_hudhint_sound 0 (lol)
- mp_ignore_round_win_conditions 1
- mp_autoteambalance 0

**Other commands you might find useful:**
- sv_allow_wait_command 0

**Plugin commands:**
- sm_autobhop 0/1
- sm_ezhop 0/1
- sm_forbidden_commands 0/1 (+left/+right allowed?)
- sm_prespeed 0/1 (Can go over 300vel when leaving starting zone?)
- sm_smoothplayback 0/1 (If false, show more accurate but not as smooth playback.)
- sm_allow_sw (Allow Sideways-style?)
- sm_allow_w (Allow W-Only-style?)
- sm_allow_hsw (Allow HSW-style?)
- sm_allow_rhsw (Allow Real HSW-style?)
- sm_allow_vel (Allow Vel-Cap-style?)
- sm_vel_limit (Vel-Cap-style's limit. Def. 400)

**Creating a .nav file for maps:** (Required for record bots. Tell Valve how much you hate it.)
- Local server and the map you want to generate the .nav file for.
- Aim at the floor and type this in your console: *sv_cheats 1; nav_edit 1; nav_mark_walkable*. This should generate .nav file in your maps folder. If it doesn't, type *nav_generate*.
- Move that into your server's maps folder. Potentially put it in your fast-dl. ;)

**Features:**
- Timer with records and playback.
- Times saved with SQLite and recordings saved in binary.
- Toggle HUD elements, change FOV, etc.
- Zone building (Starting-Ending/Block/Freestyle/Bonus1-2 Zones)
- Practising with multiple checkpoints.
- Anti-doublestepping Technology(TM)
- Simple map voting. **(Optional)**
- Chat processing. (Custom colors for chat.) **(Optional)**

**TO-DO LIST:**
- More admin tools to remove/modify records.
- Better database structure.
- Fix everything.
