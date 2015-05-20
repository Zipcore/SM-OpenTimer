OpenTimer (Read this!)
============

SourceMod timer plugin for *CSS* and *CS:GO* bunnyhop servers. Yes, it is free as in freedom.
Test it out @ 98.166.119.99:27016 (CSS)

The plugin is written in new syntax which requires **SourceMod version 1.7**!

**Read opentimer_log.txt if you want to know what changes have been made!**

**Dependencies (Optional) (CSS):**
- For 260vel weapons: https://forums.alliedmods.net/showthread.php?t=166468
- For multihop (Maps with func_door platforms.): https://forums.alliedmods.net/showthread.php?t=90467

**Download links:**

https://dl.dropboxusercontent.com/u/142067828/download/opentimer.zip - CSS
https://dl.dropboxusercontent.com/u/142067828/download/opentimer_csgo.zip - CS:GO

**How to install:**

    1. You can download the sourcecode and the plugin by pressing the 'Download ZIP'-button on the right-side. If you do not wish to do that, you can use the links above to only download the plugin.
    2. Unzip files opentimer_csgo.smx OR opentimer.smx (Depending which game you're hosting) and place it in your <gamefolder>/addons/sourcemod/plugins directory. You're done!

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
- sv_hudhint_sound 0 (lol, CSS)
- mp_ignore_round_win_conditions 1
- mp_autoteambalance 0
- mp_limitteams 0

**Other commands you might find useful:**
- sv_allow_wait_command 0

**Plugin commands:**
- sm_autobhop 0/1 (Def. enabled)
- sm_ezhop 0/1 (Def. enabled)
- sm_allow_leftright 0/1 (+left/+right allowed? Def. enabled)
- sm_ac_strafevel 0/1 (Do we check for strafe inconsistencies? **Experimental anti-cheat** Def. enabled)
- sm_prespeed 0/1 (Can go over 300vel when leaving starting zone? Def. disabled.)
- sm_smoothplayback 0/1 (If false, show more accurate but not as smooth playback. Def. enabled)
- sm_allow_sw 0/1 (Allow Sideways-style? Def. enabled)
- sm_allow_w 0/1 (Allow W-Only-style? Def. enabled)
- sm_allow_hsw 0/1 (Allow HSW-style? Def. enabled)
- sm_allow_rhsw 0/1 (Allow Real HSW-style? Def. enabled)
- sm_allow_vel 0/1 (Allow Vel-Cap-style? Def. enabled)
- sm_allow_ad 0/1 (Allow A/D-Only-style? Def. enabled)
- sm_vel_limit 250/3500 (Vel-Cap-style's limit. Def. 400)
- sm_bonus_normalonlyrec 0/1 (Do we allow only normal style to be recorded in bonuses? Prevents mass bots. Def. enabled)

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
