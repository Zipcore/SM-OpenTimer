SM-OpenTimer (Read this!)
============

SourceMod timer plugin for *CSS* bunnyhop servers.

**Read opentimer_log.txt if you want to know what changes have been made!**

**Dependencies (Optional):**
- For 260vel weapons: https://forums.alliedmods.net/showthread.php?t=166468
- For multihop (Maps with func_door platforms.): https://forums.alliedmods.net/showthread.php?t=90467
- For smoother mimic teleporting **(Strongly recommended)**: https://forums.alliedmods.net/showthread.php?t=180114 (Download v2.0 for SM 1.7)

**Things to remember:**

    - Make sure your admin status is root to create/delete zones. (configs/admins.cfg)
    - Use !zone to configure zones.
    - You can remove some functions such as recording or fancy chat by commenting out first few lines in the opentimer.sp file and then recompiling it.
    - !r, !respawn can be used to respawn.
    - Rest of the commands can be found with !commands.
    - This plugin will automatically create a new database called 'opentimer'. You are no longer required to change databases.cfg.
    - By default, max recording length is 45 minutes. Times can be however long.

**Use these commands, please:**
- bot_quota_mode normal
- sv_hudhint_sound 0 (lol)
- mp_ignore_round_win_conditions 1
- mp_autoteambalance 0

**Optional commands:**
- sv_allow_wait_command 0

**Plugin commands:**
- sm_autobhop 0/1
- sm_ezhop 0/1
- sm_forbidden_commands 0/1 (+left/+right allowed?)
- sm_prespeed 0/1 (Can go over 300vel when leaving starting zone?)

**Creating a .nav file for maps:** (Required for record bots. Tell Valve how much you hate it.)
- Local server and the map you want to generate the .nav file for.
- *sv_cheats 1; nav_edit 1; nav_mark_walkable* and aim at the floor. This should generate .nav file in your maps folder.
- Move that into your server's maps folder. Potentially put it in your fast-dl. ;)

**Features:**
- Timer with records and playback.
- Times saved with SQLite.
- Toggle HUD elements, change FOV, etc.
- Zone building (Starting-Ending/Block/Freestyle/Bonus1-2 Zones)
- Practising (not fully implemented.)
- Simple map voting. **(Optional)**
- Chat processing. (Custom colors for chat.) **(Optional)**

**TO-DO LIST:**
- Use better sync, lol. The current one is shitty.
- Fix menus.
- More tweaks.
- More everything.
- Fix everything.
