#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <basecomm> // To check if client is gagged.


#define PLUGIN_VERSION	"1.4.5"
#define PLUGIN_AUTHOR	"Mehis"
#define PLUGIN_NAME		"OpenTimer"
#define PLUGIN_URL		"https://github.com/TotallyMehis/SM-OpenTimer"
#define PLUGIN_DESC		"Timer plugin"

//	OPTIONS: Uncomment/comment things to change the plugin to your liking! Simply adding '//' (without quotation marks) in front of the line.
// ------------------------------------------------------------------------------------------------------------------------------------------
#define CSGO // Comment out for CSS.

#define	RECORD // Comment out for no recording and record playback.


// These are not tested with CS:GO!

//#define VOTING // Comment out for no voting. NOTE: This overrides commands rtv and nominate.
// Disabled by default because it overrides default commands. (rtv/nominate)

//#define CHAT // Comment out for no chat processing. Custom colors on player messages.
// Disabled by default because it is not really necessary for this plugin.

//#define ANTI_DOUBLESTEP // Let people fix their non-perfect jumps. Used for autobhop.
// Disabled by default because not necessary.

//#define DELETE_ENTS // Comment out to keep some entities. (func_doors, func_movelinears, etc.)
// This was originally used for surf maps. If you want old bhop maps with platforms don't uncomment.
// ------------------------------------------------------------------------------------------------------------------------------------------

#define ZONE_EDIT_ADMFLAG ADMFLAG_ROOT // Admin level that allows zone editing.
// E.g ADMFLAG_KICK, ADMFLAG_BAN, ADMFLAG_CHANGELEVEL

#if defined RECORD

	// 60 * minutes * tickrate
	// E.g: 60 * 45 * 100 = 270 000
	#define	RECORDING_MAX_LENGTH 270000 // Maximum recording length (def. 45 minutes with 100tick)

#endif

#define MAXPLAYERS_BHOP 64 + 1 // Change according to your player count. As long as it's not lower than (slots + 1) count it's fine... Def. 64
// I really don't know what I was thinking when I started to use this instead of the default MAXPLAYERS which is 65.
// I guess I was really paranoid about optimization. Keep in mind, I didn't really intend to share this plugin with anybody else.

#define RECORDS_PRINT_MAX 15 // Maximum records to print in the console. Def. 15


// HEX color codes (NOT SUPPORTED IN CSGO!!!)
//
//
// You have to put \x07{HEX COLOR}
// E.g \x07FFFFFF for white
//
// You can then put your own text after it:
// \x07FFFFFFThis text is white!
#if defined CSGO
	// CS:GO colors.
	#define CLR_SPEC		"\x01"
	#define CLR_SETTINGS	"\x02"
	#define CLR_STYLE		"\x03"
	
	#define CLR_TEXT		"\x06"

	#define CHAT_PREFIX		"\x01[\x07" ... PLUGIN_NAME ... "\x01] " ... CLR_TEXT
#else
	// CSS colors.
	#define CLR_SPEC		"\x07E71470" // Purple
	#define CLR_SETTINGS	"\x0766CCCC" // Teal
	#define CLR_STYLE		"\x07434343" // Gray

	#define CLR_TEXT		"\x07FFFFFF" // Default text color. (White)

	#define CHAT_PREFIX		"\x072F2F2F[\x07D01265" ... PLUGIN_NAME ... "\x072F2F2F] " ... CLR_TEXT
#endif

#define CONSOLE_PREFIX	"[" ... PLUGIN_NAME ... "] " // Used only for console/server.

// Don't change things under this unless you know what you are doing!!
// -------------------------------------------------------------------

// Variadic preprocessor function doesn't actually require anything significant, it seems.
#if defined CSGO
	// V postfix means variadic (formatting).
	#define PRINTCHATV(%0,%1,%2,%3) ( PrintToChat( %0, %2, %3 ) )
	#define PRINTCHAT(%0,%1,%2) ( PrintToChat( %0, %2 ) )
	
	#define PRINTCHATALL(%0,%1,%2) ( PrintToChatAll( %2 ) )
	#define PRINTCHATALLV(%0,%1,%2,%3) ( PrintToChatAll( %2, %3 ) )
#else
	#define PRINTCHATV(%0,%1,%2,%3) ( PrintColorChat( %0, %1, %2, %3 ) )
	#define PRINTCHAT(%0,%1,%2) ( PrintColorChat( %0, %1, %2 ) )
	
	#define PRINTCHATALL(%0,%1,%2) ( PrintColorChatAll( %0, %1, %2 )  )
	#define PRINTCHATALLV(%0,%1,%2,%3) ( PrintColorChatAll( %0, %1, %2, %3 ) )
#endif

#if defined CSGO
	#define PREF_SECONDARY "weapon_hkp2000"
#else
	#define PREF_SECONDARY "weapon_usp"
#endif

// This has to be AFTER include files because not all natives are translated to 1.7!!!
#pragma semicolon 1
#pragma newdecls required


// -----------------
// All globals here.
// -----------------

///////////////
// RECORDING //
///////////////
#if defined RECORD
	enum FrameInfo
	{
		Float:FRAME_ANGLES[2],
		Float:FRAME_POS[3],
		
		FRAME_FLAGS // Combined FRAME_BUTTONS and FRAME_FLAGS. See FRAMEFLAG_*
	};
	
	enum HeaderInfo
	{
		HEADER_BINARYFORMAT = 0,
		
		HEADER_TICKCOUNT,
		Float:HEADER_TIME, // Just in case our database loses the record information!!
		
		
		Float:HEADER_INITPOS[3],
		Float:HEADER_INITANGLES[2]
	};
	
	#define FRAME_SIZE			6
	#define HEADER_SIZE			8
	
	#define MAGIC_NUMBER		0x4B1B
	// Old: 0x4B1D
	// 1.3: 0x4B1F
	// PRE-1.4: 0x4B1C
	
	#define BINARY_FORMAT		0x01
	
	#define TICK_PRE_PLAYBLACK	-1
	
	#define FRAMEFLAG_CROUCH	( 1 << 0 )
	#define FRAMEFLAG_PRIMARY	( 1 << 1 ) // When switching to specific slot.
	#define FRAMEFLAG_SECONDARY	( 1 << 2 )
	#define FRAMEFLAG_MELEE		( 1 << 3 )
	#define FRAMEFLAG_ATTACK	( 1 << 4 )
	#define FRAMEFLAG_ATTACK2	( 1 << 5 )
	
	#define MIN_REC_SIZE		100
	
	#define MAX_RECNAME_LENGTH	13
#endif

///////////////////
// MISC. DEFINES //
///////////////////
#define HIDEHUD_HUD				( 1 << 0 )
#define HIDEHUD_VM				( 1 << 1 )
#define HIDEHUD_PLAYERS			( 1 << 2 )
#define HIDEHUD_TIMER			( 1 << 3 )
#define HIDEHUD_SIDEINFO		( 1 << 4 )
#define HIDEHUD_CHAT			( 1 << 5 )
#define HIDEHUD_BOTS			( 1 << 6 )

// HUD flags to hide specific objects.
#define HIDE_FLAGS				3946

#define OBS_MODE_IN_EYE			4

// How do we format time to hud/scoreboard/text.
#define FORMAT_DESISECONDS		( 1 << 0 )
#define FORMAT_COLORED			( 1 << 1 )
#define FORMAT_NOHOURS			( 1 << 2 )

#define SIZE_TIME_SCOREBOARD	9
#define SIZE_TIME_HINT			11
#define SIZE_TIME_RECORDS		12
#define SIZE_TIME_CHAT			17

#define TIME_INVALID			0.0

#define TIMER_UPDATE_INTERVAL	0.1 // HUD Timer.
#define ZONE_UPDATE_INTERVAL	0.5
#define ZONE_BUILD_INTERVAL		0.1
#define ZONE_WIDTH				1.0
#define ZONE_DEF_HEIGHT			128.0

// Anti-spam and warning interval
#define WARNING_INTERVAL		1.0

// How many checkpoints can a player have?
#define PRAC_MAX_SAVES			5

#define MAX_PRESPEED			300.0

// Default "grid size" for editing zones.
#define BUILDER_DEF_GRIDSIZE	8

#define STEAMID_MAXLENGTH		32
#define MAX_MAP_NAME_LENGTH		32

#define INVALID_INDEX			0
#define INVALID_ZONE_INDEX		-1
#define INVALID_CP				-1

#define MATH_PI					3.14159

// Used for the block zone.
// Entities are required to have some kind of model. Of course, we don't render the vending machine, lol.
#define BLOCK_BRUSH_MODEL		"models/props/cs_office/vending_machine.mdl"

////////////
// VOTING //
////////////
#if defined VOTING
	
	enum MapInfo { String:MAP_NAME[MAX_MAP_NAME_LENGTH] };
	
#endif
//////////////////////
// ZONE/MODES ENUMS //
//////////////////////
enum
{
	ZONE_START = 0,
	ZONE_END,
	ZONE_BONUS_1_START,
	ZONE_BONUS_1_END,
	ZONE_BONUS_2_START,
	ZONE_BONUS_2_END,
	ZONE_FREESTYLE_1,
	ZONE_FREESTYLE_2,
	ZONE_FREESTYLE_3,
	ZONE_BLOCK_1,
	ZONE_BLOCK_2,
	ZONE_BLOCK_3,
	
	NUM_ZONES
};
// Number of block zones available. TO-DO: Make a block zones be stored in a dynamic array for limitless block zones.
#define NUM_BLOCKZONES 3

enum { STATE_START = 0, STATE_RUNNING, STATE_END };

enum
{
	RUN_MAIN = 0,
	RUN_BONUS_1,
	RUN_BONUS_2,
	
	NUM_RUNS
};

enum { NAME_LONG = 0, NAME_SHORT, NUM_NAMES };

enum
{
	STYLE_NORMAL = 0,
	STYLE_SIDEWAYS,
	STYLE_W,
	STYLE_REAL_HSW,
	STYLE_HSW,
	STYLE_VEL,
	
	NUM_STYLES
};

enum
{
	STRAFE_INVALID = -1,
	STRAFE_LEFT,
	STRAFE_RIGHT,
	
	NUM_STRAFES
};

enum
{
	SLOT_PRIMARY = 0,
	SLOT_SECONDARY,
	SLOT_MELEE,
	SLOT_GRENADE,
	SLOT_BOMB,
	
	NUM_SLOTS // 6
};

//#define NUM_SLOTS_SAVED 3


// Zones
bool g_bIsLoaded[NUM_RUNS]; // Do we have start and end zone for main/bonus at least?
bool g_bZoneExists[NUM_ZONES]; // Are we going to check if the player is inside the zones in the first place?
float g_vecZoneMins[NUM_ZONES][3];
float g_vecZoneMaxs[NUM_ZONES][3];
int g_iBlockZoneIndex[NUM_BLOCKZONES];


// Building
int g_iBuilderIndex;
int g_iBuilderZone = INVALID_ZONE_INDEX;
int g_iBuilderGridSize = BUILDER_DEF_GRIDSIZE;


// Running
int g_iClientState[MAXPLAYERS_BHOP]; // Player's previous position (in start/end/running?)
int g_iClientStyle[MAXPLAYERS_BHOP]; // Styles W-ONLY/HSW/RHSW etc.
int g_iClientRun[MAXPLAYERS_BHOP]; // Which run client is doing (main/bonus)?
float g_flClientStartTime[MAXPLAYERS_BHOP]; // When we started our run? Engine time.
float g_flClientFinishTime[MAXPLAYERS_BHOP]; // This is to tell the client's finish time in the end. Engine time.
float g_flClientBestTime[MAXPLAYERS_BHOP][NUM_RUNS][NUM_STYLES];


// Player stats
int g_nClientJumpCount[MAXPLAYERS_BHOP];
int g_nClientStrafeCount[MAXPLAYERS_BHOP];
float g_flClientSync[MAXPLAYERS_BHOP][NUM_STRAFES];


// Misc player stuff.
float g_flClientWarning[MAXPLAYERS_BHOP]; // Used for anti-spam.
#if defined ANTI_DOUBLESTEP
	bool g_bClientHoldingJump[MAXPLAYERS_BHOP]; // Used for anti-doublestep.
#endif


// Practice
bool g_bIsClientPractising[MAXPLAYERS_BHOP];
float g_vecClientSavePos[MAXPLAYERS_BHOP][PRAC_MAX_SAVES][3];
float g_vecClientSaveAng[MAXPLAYERS_BHOP][PRAC_MAX_SAVES][3];
float g_vecClientSaveVel[MAXPLAYERS_BHOP][PRAC_MAX_SAVES][3];
float g_flClientSaveDif[MAXPLAYERS_BHOP][PRAC_MAX_SAVES]; // The time between save and start time.
int g_iClientCurSave[MAXPLAYERS_BHOP] = { INVALID_CP, ... };


// Recording
#if defined RECORD
	Handle g_hClientRecording[MAXPLAYERS_BHOP];
	bool g_bClientRecording[MAXPLAYERS_BHOP];
	bool g_bClientMimicing[MAXPLAYERS_BHOP];
	int g_nClientTick[MAXPLAYERS_BHOP];
	
	float g_vecInitPos[MAXPLAYERS_BHOP][3];
	float g_vecInitAng[MAXPLAYERS_BHOP][3];
	
	// Record playback
	float g_vecInitRecPos[NUM_RUNS][NUM_STYLES][3];
	float g_vecInitRecAng[NUM_RUNS][NUM_STYLES][3];
	int g_iRec[NUM_RUNS][NUM_STYLES];
	int g_iNumRec;
	int g_iRecTickMax[NUM_RUNS][NUM_STYLES];
	Handle g_hRec[NUM_RUNS][NUM_STYLES];
	char g_szRecName[NUM_RUNS][NUM_STYLES][MAX_NAME_LENGTH];
	
	// Max tick count for player's recording.
	// Usually couple ticks higher than bot's tick count for safety reasons.
	int g_iRecMaxLength[NUM_RUNS][NUM_STYLES];
	
	// Do playback or not?
	bool g_bPlayback;
#endif


// Client settings (bonus stuff)
int g_iClientFOV[MAXPLAYERS_BHOP] = { 90, ... };
int g_fClientHideFlags[MAXPLAYERS_BHOP];


// Other
char g_szCurrentMap[MAX_MAP_NAME_LENGTH];
float g_vecSpawnPos[NUM_RUNS][3];
float g_vecSpawnAngles[NUM_RUNS][3];
float g_flMapBestTime[NUM_RUNS][NUM_STYLES];
int g_iBeam;
int g_iPreferredTeam = CS_TEAM_T;


// Voting stuff
#if defined VOTING
	ArrayList g_hMapList;
	char g_szNextMap[MAX_MAP_NAME_LENGTH];
	
	int g_iClientVote[MAXPLAYERS_BHOP] = { -1, ... };
#endif


// Constants
char g_szZoneNames[NUM_ZONES][15] =
{
	"Start", "End",
	"Bonus #1 Start", "Bonus #1 End",
	"Bonus #2 Start", "Bonus #2 End",
	"Freestyle #1", "Freestyle #2", "Freestyle #3",
	"Block #1", "Block #2", "Block #3"
};
// The short versions are also used for directories. Do not use special characters!
char g_szRunName[NUM_NAMES][NUM_RUNS][9] =
{
	{ "Main", "Bonus #1", "Bonus #2" },
	{ "M", "B1", "B2" }
};
char g_szStyleName[NUM_NAMES][NUM_STYLES][14] =
{
	{ "Normal", "Sideways", "W-Only", "Real HSW", "Half-Sideways", "Vel-Cap" }, // "A/D-Only"
	{ "N", "SW", "W", "RHSW", "HSW", "VEL" } // "A_D"
};
// First one is always the normal ending sound!
#if defined CSGO
	char g_szWinningSounds[][38] =
	{
		"buttons/button16.wav",
		"player/vo/sas/onarollbrag13.wav",
		"player/vo/sas/onarollbrag03.wav",
		"player/vo/phoenix/onarollbrag11.wav",
		"player/vo/anarchist/onarollbrag13.wav",
		"player/vo/separatist/onarollbrag01.wav",
		"player/vo/seal/onarollbrag08.wav"
	};
#else
	char g_szWinningSounds[][25] =
	{
		"buttons/button16.wav", "bot/i_am_on_fire.wav",
		"bot/its_a_party.wav", "bot/made_him_cry.wav",
		"bot/this_is_my_house.wav", "bot/yea_baby.wav",
		"bot/yesss.wav", "bot/yesss2.wav"
	};
#endif
float g_vecNull[3] = { 0.0, 0.0, 0.0 };


// ConVars
ConVar g_ConVar_AirAccelerate; // To tell the client what aa we have.
static ConVar g_ConVar_PreSpeed;
ConVar g_ConVar_AutoHop;
ConVar g_ConVar_EZHop;
ConVar g_ConVar_LeftRight;
ConVar g_ConVar_AntiCheat_StrafeVel;
#if defined RECORD
	ConVar g_ConVar_SmoothPlayback;
	ConVar g_ConVar_Bonus_NormalOnlyRec;
#endif

ConVar g_ConVar_Allow_SW;
ConVar g_ConVar_Allow_W;
ConVar g_ConVar_Allow_HSW;
ConVar g_ConVar_Allow_RHSW;
ConVar g_ConVar_Allow_Vel;

ConVar g_ConVar_VelCap;

// Settings (Convars)
bool g_bPreSpeed = false;
bool g_bAllowLeftRight = true;
bool g_bAutoHop = true;
bool g_bEZHop = true;
bool g_bAntiCheat_StrafeVel = true;
#if defined RECORD
	bool g_bSmoothPlayback = true;
#endif
float g_flVelCap = 400.0;
float g_flVelCapSquared = 160000.0;

// ------------------------
// End of globals.
// ------------------------

#include "opentimer/stocks.sp"
#if defined RECORD
	#include "opentimer/file.sp"
#endif
#include "opentimer/cmd.sp"
#include "opentimer/usermsg.sp"
#include "opentimer/database.sp"
#include "opentimer/events.sp"
#include "opentimer/commands.sp"
#include "opentimer/commands_admin.sp"
#include "opentimer/timers.sp"
#include "opentimer/menus.sp"
#include "opentimer/menus_admin.sp"

public Plugin OpenTimerInfo = {
	author = PLUGIN_AUTHOR,
	name = PLUGIN_NAME,
	description = PLUGIN_DESC,
	url = PLUGIN_URL,
	version = PLUGIN_VERSION
};

public void OnPluginStart()
{
	// HOOKS
	HookEvent( "player_spawn", Event_ClientSpawn );
#if !defined CSGO
	HookEvent( "player_jump", Event_ClientJump );
#endif
	HookEvent( "player_team", Event_ClientTeam );
	//HookEvent( "player_hurt", Event_ClientHurt );
	HookEvent( "player_death", Event_ClientDeath );
	
	
	// LISTENERS
	AddCommandListener( Listener_Say, "say" );
	AddCommandListener( Listener_Say, "say_team" );
	
#if defined ANTI_DOUBLESTEP
	AddCommandListener( Listener_AntiDoublestep_On, "+ds" );
	AddCommandListener( Listener_AntiDoublestep_Off, "-ds" );
#endif

	
	// SPAWNING
	RegConsoleCmd( "sm_respawn", Command_Spawn );
	RegConsoleCmd( "sm_spawn", Command_Spawn );
	RegConsoleCmd( "sm_restart", Command_Spawn );
	RegConsoleCmd( "sm_r", Command_Spawn );
	RegConsoleCmd( "sm_re", Command_Spawn );
	RegConsoleCmd( "sm_start", Command_Spawn );
	RegConsoleCmd( "sm_teleport", Command_Spawn );
	RegConsoleCmd( "sm_tele", Command_Spawn );
	
	
	// SPEC
	RegConsoleCmd( "sm_spectate", Command_Spectate );
	RegConsoleCmd( "sm_spec", Command_Spectate );
	RegConsoleCmd( "sm_s", Command_Spectate );
	
	
	// FOV
	RegConsoleCmd( "sm_fov", Command_FieldOfView );
	RegConsoleCmd( "sm_fieldofview", Command_FieldOfView );
	
	
	// CLIENT SETTINGS
	RegConsoleCmd( "sm_hud", Command_ToggleHUD ); // Menu
	RegConsoleCmd( "sm_showhud", Command_ToggleHUD );
	RegConsoleCmd( "sm_hidehud", Command_ToggleHUD );
	RegConsoleCmd( "sm_h", Command_ToggleHUD );
	
	RegConsoleCmd( "sm_viewmodel", Command_ToggleHUD );
	RegConsoleCmd( "sm_vm", Command_ToggleHUD );
	RegConsoleCmd( "sm_hideweapons", Command_ToggleHUD );
	RegConsoleCmd( "sm_remove", Command_ToggleHUD );
	RegConsoleCmd( "sm_showweapons", Command_ToggleHUD );
	RegConsoleCmd( "sm_weapons", Command_ToggleHUD );
	
	RegConsoleCmd( "sm_timer", Command_ToggleHUD );
	
	RegConsoleCmd( "sm_hide", Command_ToggleHUD );
	RegConsoleCmd( "sm_hideplayers", Command_ToggleHUD );
	RegConsoleCmd( "sm_players", Command_ToggleHUD );
	
	
	// RECORDS
	RegConsoleCmd( "sm_wr", Command_RecordsMenu );
	RegConsoleCmd( "sm_records", Command_RecordsMenu );
	RegConsoleCmd( "sm_times", Command_RecordsMenu );
	
	RegConsoleCmd( "sm_printrecords", Command_RecordsPrint );
	
	
	// MODES
	RegConsoleCmd( "sm_mode", Command_Style ); // Menu
	RegConsoleCmd( "sm_modes", Command_Style );
	RegConsoleCmd( "sm_style", Command_Style );
	RegConsoleCmd( "sm_styles", Command_Style );
	
	RegConsoleCmd( "sm_normal", Command_Style_Normal );
	RegConsoleCmd( "sm_n", Command_Style_Normal );
	
	RegConsoleCmd( "sm_sideways", Command_Style_Sideways );
	RegConsoleCmd( "sm_sw", Command_Style_Sideways );
	
	RegConsoleCmd( "sm_w", Command_Style_W );
	RegConsoleCmd( "sm_w-only", Command_Style_W );
	
	RegConsoleCmd( "sm_rhsw", Command_Style_RealHSW );
	RegConsoleCmd( "sm_realhsw", Command_Style_RealHSW );
	
	RegConsoleCmd( "sm_hsw", Command_Style_HSW );
	RegConsoleCmd( "sm_halfsideways", Command_Style_HSW );
	RegConsoleCmd( "sm_half-sideways", Command_Style_HSW );
	
	RegConsoleCmd( "sm_400", Command_Style_VelCap );
	RegConsoleCmd( "sm_400vel", Command_Style_VelCap );
	RegConsoleCmd( "sm_vel", Command_Style_VelCap );
	RegConsoleCmd( "sm_velcap", Command_Style_VelCap );
	RegConsoleCmd( "sm_vel-cap", Command_Style_VelCap );
	RegConsoleCmd( "sm_v", Command_Style_VelCap );
	
	
	// RUNS
	RegConsoleCmd( "sm_main", Command_Run_Main );
	RegConsoleCmd( "sm_m", Command_Run_Main );
	
	RegConsoleCmd( "sm_bonus", Command_Run_Bonus );
	RegConsoleCmd( "sm_b", Command_Run_Bonus );
	
	RegConsoleCmd( "sm_bonus1", Command_Run_Bonus_1 );
	RegConsoleCmd( "sm_b1", Command_Run_Bonus_1 );
	
	RegConsoleCmd( "sm_bonus2", Command_Run_Bonus_2 );
	RegConsoleCmd( "sm_b2", Command_Run_Bonus_2 );
	
	
	// PRACTICE
	RegConsoleCmd( "sm_practise", Command_Practise );
	RegConsoleCmd( "sm_practice", Command_Practise );
	RegConsoleCmd( "sm_prac", Command_Practise );
	RegConsoleCmd( "sm_p", Command_Practise );
	
	RegConsoleCmd( "sm_saveloc", Command_Practise_SavePoint );
	RegConsoleCmd( "sm_save", Command_Practise_SavePoint );
	
	RegConsoleCmd( "sm_cp", Command_Practise_GotoPoint );
	RegConsoleCmd( "sm_checkpoint", Command_Practise_GotoPoint );
	RegConsoleCmd( "sm_gotocp", Command_Practise_GotoPoint );
	
	RegConsoleCmd( "sm_lastcp", Command_Practise_GotoLastPoint );
	RegConsoleCmd( "sm_last", Command_Practise_GotoLastPoint );
	
	RegConsoleCmd( "sm_no-clip", Command_Practise_Noclip );
	RegConsoleCmd( "sm_fly", Command_Practise_Noclip );
	
	
	// HELP AND MISC.
	RegConsoleCmd( "sm_commands", Command_Help );
	
	RegConsoleCmd( "sm_version", Command_Version );
	
	RegConsoleCmd( "sm_credits", Command_Credits );
	
#if defined ANTI_DOUBLESTEP
	RegConsoleCmd( "sm_ds", Command_Doublestep );
	RegConsoleCmd( "sm_doublestep", Command_Doublestep );
	RegConsoleCmd( "sm_doublestepping", Command_Doublestep );
#endif
	
	
	// VOTING
#if defined VOTING
	RegConsoleCmd( "sm_choosemap", Command_VoteMap ); // Menu
	RegConsoleCmd( "sm_rtv", Command_VoteMap );
	RegConsoleCmd( "sm_rockthevote", Command_VoteMap );
	RegConsoleCmd( "sm_nominate", Command_VoteMap );
#endif
	
	
	// ADMIN STUFF
	// ZONES
	RegAdminCmd( "sm_zone", Command_Admin_ZoneMenu, ZONE_EDIT_ADMFLAG, "Zone menu." ); // Menu
	RegAdminCmd( "sm_zones", Command_Admin_ZoneMenu, ZONE_EDIT_ADMFLAG, "Zone menu." );
	RegAdminCmd( "sm_zonemenu", Command_Admin_ZoneMenu, ZONE_EDIT_ADMFLAG, "Zone menu." );
	
	RegAdminCmd( "sm_startzone", Command_Admin_ZoneStart, ZONE_EDIT_ADMFLAG, "Begin to make a zone." ); // Menu
	RegAdminCmd( "sm_endzone", Command_Admin_ZoneEnd, ZONE_EDIT_ADMFLAG, "Finish the zone." ); // Menu
	RegAdminCmd( "sm_deletezone", Command_Admin_ZoneDelete, ZONE_EDIT_ADMFLAG, "Delete a zone." ); // Menu
	
	
	// CONVARS
	g_ConVar_AirAccelerate = FindConVar( "sv_airaccelerate" );
	
	g_ConVar_AutoHop = CreateConVar( "sm_autobhop", "1", "Is autobunnyhopping allowed? (hold space)", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	
	g_ConVar_EZHop = CreateConVar( "sm_ezhop", "1", "Is ezhop enabled?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	
	g_ConVar_PreSpeed = CreateConVar( "sm_prespeed", "0", "Is prespeeding allowed in the starting zone?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	
	g_ConVar_LeftRight = CreateConVar( "sm_allow_leftright", "1", "Is +left and +right allowed?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	
	g_ConVar_AntiCheat_StrafeVel = CreateConVar( "sm_ac_strafevel", "1", "Does server check for inconsistencies in player's strafes? (anti-cheat)", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	
#if defined RECORD
	g_ConVar_SmoothPlayback = CreateConVar( "sm_smoothplayback", "1", "If false, playback movement will appear more responsive but choppy and teleporting will not be affected by ping.", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	
	g_ConVar_Bonus_NormalOnlyRec = CreateConVar( "sm_bonus_normalonlyrec", "1", "Do we allow only normal style to be recorded in bonuses? (Prevents mass bots.)", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
#endif
	
	// STYLE CONVARS
	g_ConVar_Allow_SW = CreateConVar( "sm_allow_sw", "1", "Is Sideways-style allowed?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVar_Allow_W = CreateConVar( "sm_allow_w", "1", "Is W-Only-style allowed?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVar_Allow_HSW = CreateConVar( "sm_allow_hsw", "1", "Is Half-Sideways-style allowed?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVar_Allow_RHSW = CreateConVar( "sm_allow_rhsw", "1", "Is Real Half-Sideways-style allowed?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	g_ConVar_Allow_Vel = CreateConVar( "sm_allow_vel", "1", "Is XXXvel-style allowed?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	
	g_ConVar_VelCap = CreateConVar( "sm_vel_limit", "400", "What is the cap for XXXvel-style?", FCVAR_NOTIFY, true, 250.0, true, 3500.0 );
	
	
	HookConVarChange( g_ConVar_AutoHop, Event_ConVar_AutoHop );
#if !defined CSGO
	HookConVarChange( g_ConVar_EZHop, Event_ConVar_EZHop );
#endif
	HookConVarChange( g_ConVar_PreSpeed, Event_ConVar_PreSpeed );
	HookConVarChange( g_ConVar_LeftRight, Event_ConVar_LeftRight );
	HookConVarChange( g_ConVar_AntiCheat_StrafeVel, Event_ConVar_AntiCheat_StrafeVel );
#if defined RECORD
	HookConVarChange( g_ConVar_SmoothPlayback, Event_ConVar_SmoothPlayback );
#endif
	
	HookConVarChange( g_ConVar_VelCap, Event_ConVar_VelCap );
	
	LoadTranslations( "common.phrases" ); // So FindTarget() can work.
	
	DB_InitializeDatabase();
}

public void Event_ConVar_AutoHop( Handle hConVar, const char[] szOldValue, const char[] szNewValue )
{
	g_bAutoHop = StringToInt( szNewValue ) ? true : false;
}

public void Event_ConVar_EZHop( Handle hConVar, const char[] szOldValue, const char[] szNewValue )
{
	g_bEZHop = StringToInt( szNewValue ) ? true : false;
}

public void Event_ConVar_PreSpeed( Handle hConVar, const char[] szOldValue, const char[] szNewValue )
{
	g_bPreSpeed = StringToInt( szNewValue ) ? true : false;
}

public void Event_ConVar_LeftRight( Handle hConVar, const char[] szOldValue, const char[] szNewValue )
{
	g_bAllowLeftRight = StringToInt( szNewValue ) ? true : false;
}

public void Event_ConVar_AntiCheat_StrafeVel( Handle hConVar, const char[] szOldValue, const char[] szNewValue )
{
	g_bAntiCheat_StrafeVel = StringToInt( szNewValue ) ? true : false;
}

#if defined RECORD
	public void Event_ConVar_SmoothPlayback( Handle hConVar, const char[] szOldValue, const char[] szNewValue )
	{
		g_bSmoothPlayback = StringToInt( szNewValue ) ? true : false;
	}
#endif

public void Event_ConVar_VelCap( Handle hConVar, const char[] szOldValue, const char[] szNewValue )
{
	g_flVelCap = StringToFloat( szNewValue );
	g_flVelCapSquared = g_flVelCap * g_flVelCap;
}


public void OnMapStart()
{
#if defined RECORD
	// No bots until we have records.
	ServerCommand( "bot_quota 0" );
	g_iNumRec = 0;
#endif
	
	
	// Just in case there are maps that use uppercase letters.
	GetCurrentMap( g_szCurrentMap, sizeof( g_szCurrentMap ) );
	
	int len = strlen( g_szCurrentMap );
	
	for ( int i; i < len; i++ )
		if ( IsCharUpper( g_szCurrentMap[i] ) ) CharToLower( g_szCurrentMap[i] );
	
	
	// Resetting/precaching stuff.
	g_iBuilderIndex =		INVALID_INDEX;
	g_iBuilderZone =		INVALID_ZONE_INDEX;
	g_iBuilderGridSize =	BUILDER_DEF_GRIDSIZE;
	
	
	for ( int run; run < NUM_RUNS; run++ )
		for ( int style; style < NUM_STYLES; style++ )
		{
			g_flMapBestTime[run][style] = TIME_INVALID;
			
#if defined RECORD
			// Reset all recordings.
			g_iRec[run][style] = INVALID_INDEX;
			g_iRecTickMax[run][style] = 0;
			g_iRecMaxLength[run][style] = RECORDING_MAX_LENGTH;
			
			if ( g_hRec[run][style] != null )
			{
				delete g_hRec[run][style];
				g_hRec[run][style] = null;
			}
#endif
		}
	
	// In case we don't try to fetch the zones.
	for ( int i; i < NUM_ZONES; i++ ) g_bZoneExists[i] = false;
	ArrayFill( g_iBlockZoneIndex, 0, NUM_BLOCKZONES );
	
	
	PrecacheModel( BLOCK_BRUSH_MODEL );
	// materials/sprites/plasma.vmt, Original
	// materials/vgui/white.vmt
	g_iBeam = PrecacheModel( "materials/sprites/laserbeam.vmt" );
	
	for ( int i; i < sizeof( g_szWinningSounds ); i++ )
	{
		PrecacheSound( g_szWinningSounds[i] );
	}
	
	g_iPreferredTeam = 0;
	
	
	// Get map zones from database.
	DB_InitializeMapZones();
	
#if defined VOTING
	// Find maps to vote for from database.
	DB_FindMaps();
#endif
	
	// Solves the pesky convar reset on map changes.
	g_bAutoHop = GetConVarBool( g_ConVar_AutoHop );
	g_bEZHop = GetConVarBool( g_ConVar_EZHop );
	g_bPreSpeed = GetConVarBool( g_ConVar_PreSpeed );
	g_bAllowLeftRight = GetConVarBool( g_ConVar_LeftRight );
	g_bAntiCheat_StrafeVel = GetConVarBool( g_ConVar_AntiCheat_StrafeVel );
#if defined RECORD
	g_bSmoothPlayback = GetConVarBool( g_ConVar_SmoothPlayback );
#endif

	g_flVelCap = GetConVarFloat( g_ConVar_VelCap );
	g_flVelCapSquared = g_flVelCap * g_flVelCap;
	
	// Repeating timer that sends the zones to the client every X seconds.
	CreateTimer( ZONE_UPDATE_INTERVAL, Timer_DrawZoneBeams, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
	
	// Show timer to players.
	CreateTimer( TIMER_UPDATE_INTERVAL, Timer_HudTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
	
	// We want to restart the map if it has been going on for too long without any players.
	// This prevents performance issues.
	CreateTimer( 3600.0, Timer_RestartMap, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
}

public void OnClientDisconnect( int client )
{
	//SDKUnhook( client, SDKHook_OnTakeDamage, Event_ClientHurt );
	//SDKUnhook( client, SDKHook_SetTransmit, Event_ClientTransmit );
	//SDKUnhook( client, SDKHook_WeaponDropPost, Event_WeaponDropPost );
	
	PrintToServer( "Team num: %i", GetEntProp( client, Prop_Send, "m_iTeamNum" ) );
	// Changing player's team with m_iTeamNum apparently causes crashes. (Something to do with player counts?)
	// This will prevent it.
	if ( GetEntProp( client, Prop_Send, "m_iTeamNum" ) == 0 )
	{
		SetEntProp( client, Prop_Send, "m_iTeamNum", CS_TEAM_CT );
		SetEntProp( client, Prop_Send, "m_lifeState", 0 );
		SetEntityMoveType( client, MOVETYPE_ISOMETRIC );
	}
		
	
#if defined RECORD
	if ( IsFakeClient( client ) )
	{
		if ( g_iRec[ g_iClientRun[client] ][ g_iClientStyle[client] ] == client )
		{
			g_iRec[ g_iClientRun[client] ][ g_iClientStyle[client] ] = INVALID_INDEX;
			g_bClientMimicing[client] = false;
		}
		
		return;
	}
	
	if ( GetActivePlayers( client ) < 1 )
	{
		g_bPlayback = false;
		PrintToServer( CONSOLE_PREFIX ... "No players, disabling playback." );
	}
#endif
	
	//SDKUnhook( client, SDKHook_PostThinkPost, Event_PostThinkPost );
	//SDKUnhook( client, SDKHook_WeaponSwitchPost, Event_WeaponSwitchPost );
	
#if defined VOTING
	g_iClientVote[client] = -1;
	CalcVotes();
#endif
}

public void OnClientPutInServer( int client )
{
	// Reset stuff, assign records and hook necessary events.
	
	
	g_flClientStartTime[client] = TIME_INVALID;
	
	
	SDKHook( client, SDKHook_OnTakeDamage, Event_OnTakeDamage );
	SDKHook( client, SDKHook_WeaponDropPost, Event_WeaponDropPost ); // No more weapon dropping.
	SDKHook( client, SDKHook_SetTransmit, Event_ClientTransmit ); // Has to be hooked to everybody(?)
	
#if defined RECORD
	// Recording
	g_bClientRecording[client] = false;
	g_bClientMimicing[client] = false;
	g_nClientTick[client] = 0;
	
	
	if ( IsFakeClient( client ) )
	{
		// -----------------------------------------------
		// Assign records for bots and make them mimic it.
		// -----------------------------------------------
		for ( int run; run < NUM_RUNS; run++ )
			for ( int style; style < NUM_STYLES; style++ )
			{
				// We already have a mimic in this slot? Continue to the next.
				if ( g_iRec[run][style] != INVALID_INDEX ) continue;
				
				// Does the playback even exist?
				if ( g_hRec[run][style] == null || g_iRecTickMax[run][style] < 1 ) continue;
				
				CS_SetClientClanTag( client, "REC*" );
				
				AssignRecordToBot( client, run, style );
				
				SetEntProp( client, Prop_Data, "m_iFrags", 1337 );
				SetEntProp( client, Prop_Data, "m_iDeaths", 1337 );
				
				return;
			}
		
		return;
	}
	
	// Allow playback if there are players.
	g_bPlayback = true;
#endif
	
	// States
	g_iClientState[client] = STATE_RUNNING;
	g_iClientStyle[client] = STYLE_NORMAL;
	g_iClientRun[client] = RUN_MAIN;
	
	
	// Times
	g_flClientFinishTime[client] = TIME_INVALID;
	
	for ( int i; i < NUM_RUNS; i++ )
		ArrayFill( g_flClientBestTime[client][i], TIME_INVALID, NUM_STYLES );
	
	
	// Stats
	g_nClientJumpCount[client] = 0;
	g_nClientStrafeCount[client] = 0;
	
	g_flClientSync[client][STRAFE_LEFT] = 1.0;
	g_flClientSync[client][STRAFE_RIGHT] = 1.0;
	
	
	// Practicing
	g_bIsClientPractising[client] = false;
	
	for ( int i; i < PRAC_MAX_SAVES; i++ )
	{
		// Reset all checkpoints.
		g_flClientSaveDif[client][i] = TIME_INVALID;
	}
	
	g_iClientCurSave[client] = INVALID_CP;
	
	
	// Misc.
	g_iClientFOV[client] = 90;
	g_fClientHideFlags[client] = 0;
	
	g_flClientWarning[client] = TIME_INVALID;
	
	
	// Welcome message for players.
	CreateTimer( 5.0, Timer_Connected, GetClientUserId( client ), TIMER_FLAG_NO_MAPCHANGE );
	
	SDKHook( client, SDKHook_WeaponSwitchPost, Event_WeaponSwitchPost ); // FOV reset.
	SDKHook( client, SDKHook_PostThinkPost, Event_PostThinkPost );
	
	// Get their desired FOV and other settings from DB.
	DB_RetrieveClientData( client );
}

// Used just here.
enum { INSIDE_START = 0, INSIDE_END, NUM_INSIDE };

public void Event_PostThinkPost( int client )
{
	// ---------------------------------------------------------
	// Main component of the timer. Does everything, basically.
	// ---------------------------------------------------------
	if ( !g_bIsLoaded[ g_iClientRun[client] ] || !IsPlayerAlive( client ) ) return;
	
	
	static bool bInsideZone[MAXPLAYERS_BHOP][NUM_INSIDE];
	
	// First we find out if our player is in his/her current zone areas.
	switch ( g_iClientRun[client] )
	{
		case RUN_BONUS_1 :
		{
			bInsideZone[client][INSIDE_START] = IsInsideZone( client, ZONE_BONUS_1_START );
			bInsideZone[client][INSIDE_END] = IsInsideZone( client, ZONE_BONUS_1_END );
		}
		case RUN_BONUS_2 :
		{
			bInsideZone[client][INSIDE_START] = IsInsideZone( client, ZONE_BONUS_2_START );
			bInsideZone[client][INSIDE_END] = IsInsideZone( client, ZONE_BONUS_2_END );
		}
		default :
		{
			bInsideZone[client][INSIDE_START] = IsInsideZone( client, ZONE_START );
			bInsideZone[client][INSIDE_END] = IsInsideZone( client, ZONE_END );
		}
	}
	
	
	// We then compare that:
	if ( g_iClientState[client] == STATE_START && !bInsideZone[client][INSIDE_START] )
	{
		// We were previously in start but we're not anymore.
		// Start to run!
		
		
		// Don't allow admins to cheat by noclipping around FROM THE START...
		// I intentionally allow admins to use the sm_noclip command during the run.
		// This is basically just to remind admins that you can accidentally get a record.
		if ( !g_bIsClientPractising[client] && GetEntityMoveType( client ) == MOVETYPE_NOCLIP )
		{
			PRINTCHAT( client, client, CHAT_PREFIX ... "You are now in \x03practice"...CLR_TEXT..." mode! Type \x03!prac"...CLR_TEXT..." again to toggle." );
			g_bIsClientPractising[client] = true;
		}
		// No prespeeding.
		else if ( !g_bPreSpeed && GetClientSpeed( client ) > MAX_PRESPEED && GetEntityMoveType( client ) != MOVETYPE_NOCLIP )
		{
			if ( !IsSpamming( client ) )
			{
				PRINTCHATV( client, client, CHAT_PREFIX ... "No prespeeding allowed! (\x03%.0fspd"...CLR_TEXT...")", MAX_PRESPEED );
			}
			
			
			TeleportEntity( client, NULL_VECTOR, NULL_VECTOR, g_vecNull );
			
			return;
		}
		
		g_flClientStartTime[client] = GetEngineTime();
		
		
		g_flClientSync[client][STRAFE_LEFT] = 1.0;
		g_flClientSync[client][STRAFE_RIGHT] = 1.0;
		
		
#if defined RECORD
		// Start to record!
		if ( !g_bIsClientPractising[client] &&
			!( g_iClientRun[client] != RUN_MAIN && g_iClientStyle[client] != STYLE_NORMAL && GetConVarBool( g_ConVar_Bonus_NormalOnlyRec ) ) )
		{
			PrintToServer( "Started to record!" );
			
			g_nClientTick[client] = 0;
			g_bClientRecording[client] = true;
			
			g_hClientRecording[client] = CreateArray( view_as<int>FrameInfo );
			
			GetClientEyeAngles( client, g_vecInitAng[client] );
			GetClientAbsOrigin( client, g_vecInitPos[client] );
		}
		else
		{
			// Reset just in case.
			g_bClientRecording[client] = false;
			
			delete g_hClientRecording[client];
			g_hClientRecording[client] = null;
		}
#endif
		g_iClientState[client] = STATE_RUNNING;
	}
	else if ( g_iClientState[client] == STATE_RUNNING && bInsideZone[client][INSIDE_END] )
	{
		// Inside the end zone from running!
		
		
		// We haven't even started to run or we already came in to the end!!
		if ( g_flClientStartTime[client] == TIME_INVALID ) return;
		
		if ( GetEntityMoveType( client ) == MOVETYPE_NOCLIP ) return;
		
		
		g_iClientState[client] = STATE_END;
		
		// Save the time if we're not practising.
		if ( !g_bIsClientPractising[client] )
		{
			// So there is no way of them deleting the recording.
			// E.i. going back to start while we're about to save the recording to disk.
			g_flClientWarning[client] = GetEngineTime() + WARNING_INTERVAL;
			
			float flNewTime = GetEngineTime() - g_flClientStartTime[client];
			
			g_flClientFinishTime[client] = flNewTime;
			
			if ( !DB_SaveClientRecord( client, flNewTime ) )
			{
				PRINTCHAT( client, client, CHAT_PREFIX ... "Couldn't save your record and/or recording!" );
			}
			
#if defined RECORD
			if ( g_bClientRecording[client] && g_hClientRecording[client] != null )
			{
				g_nClientTick[client] = 0;
				g_bClientRecording[client] = false;
				
				delete g_hClientRecording[client];
				g_hClientRecording[client] = null;
			}
#endif
		}

		g_flClientStartTime[client] = TIME_INVALID;
	}
	else if ( bInsideZone[client][INSIDE_START] )
	{
		// We're not doing anything important, so just reset stuff.
		
		
		// Did we come in just now.
		// Or...
		// Did we not jump when we were on the ground?
		if ( g_iClientState[client] != STATE_START || ( GetEntityFlags( client ) & FL_ONGROUND && !( GetClientButtons( client ) & IN_JUMP ) ) )
		{
			g_nClientJumpCount[client] = 0;
		}
		
		g_iClientState[client] = STATE_START;
		
		ArrayFill( g_flClientSaveDif[client], TIME_INVALID, PRAC_MAX_SAVES );
		
		g_nClientStrafeCount[client] = 0;
	}
#if defined RECORD
	else if ( !g_bIsClientPractising[client] && g_bClientRecording[client] )
	{
		// We're running and recording!
		// Have we been running for too long?
		
		// Is our recording longer than max length.
		if ( g_nClientTick[client] > g_iRecMaxLength[ g_iClientRun[client] ][ g_iClientStyle[client] ] )
		{
			g_nClientTick[client] = 0;
			g_bClientRecording[client] = false;
			
			if ( g_hClientRecording[client] != null )
			{
				delete g_hClientRecording[client];
				g_hClientRecording[client] = null;
			}
			
			if ( g_nClientTick[client] >= RECORDING_MAX_LENGTH )
			{
				PRINTCHAT( client, client, CHAT_PREFIX ... "Your time was too long to be recorded!" );
			}
		}
	}
#endif
}


stock void CheckFreestyle( int client )
{
	// Player pressed a forbidden key.
	// Check whether we're in freestyle zone or not.
	
	if ( g_iClientState[client] != STATE_RUNNING
		|| IsInsideZone( client, ZONE_FREESTYLE_1 )
		|| IsInsideZone( client, ZONE_FREESTYLE_2 )
		|| IsInsideZone( client, ZONE_FREESTYLE_3 ) )
		return;
	
	
	if ( !IsSpamming( client ) )
	{
		PRINTCHATV( client, client, CHAT_PREFIX ... "That key (combo) is not allowed in \x03%s"...CLR_TEXT..."!", g_szStyleName[NAME_LONG][ g_iClientStyle[client] ] );
	}
	
	
	// We can't go back? Just kill them.
	if ( !g_bIsLoaded[ g_iClientRun[client] ] )
	{
		ForcePlayerSuicide( client );
		return;
	}
	
	TeleportPlayerToStart( client );
}

stock void TeleportPlayerToStart( int client )
{
	g_flClientStartTime[client] = TIME_INVALID;
	g_iClientState[client] = STATE_START;
	
	if ( g_bIsLoaded[ g_iClientRun[client] ] )
		TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_vecSpawnAngles[ g_iClientRun[client] ], g_vecNull );
}

stock void DoMapStuff()
{
	// Find a destination where we are suppose to go to when teleporting back to a zone.
	// Find an angle for the starting zones.
	// Find suitable team for players.
	// Spawn block zones.
	
	
	bool	bFoundAng[NUM_RUNS];
	float	angAngle[3];
	int		ent;
	
	while ( ( ent = FindEntityByClassname( ent, "info_teleport_destination" ) ) != -1 )
	{
		if ( g_bZoneExists[ZONE_START] && IsInsideZone( ent, ZONE_START ) )
		{
			GetEntPropVector( ent, Prop_Data, "m_angRotation", angAngle );
			
			ArrayCopy( angAngle, g_vecSpawnAngles[RUN_MAIN], 2 );
			g_vecSpawnAngles[RUN_MAIN][2] = 0.0; // Reset roll in case the mappers are dumbasses.
			
			bFoundAng[RUN_MAIN] = true;
		}
		else if ( g_bZoneExists[ZONE_BONUS_1_START] && IsInsideZone( ent, ZONE_BONUS_1_START ) )
		{
			GetEntPropVector( ent, Prop_Data, "m_angRotation", angAngle );
			
			ArrayCopy( angAngle, g_vecSpawnAngles[RUN_BONUS_1], 2 );
			g_vecSpawnAngles[RUN_BONUS_1][2] = 0.0;
			
			bFoundAng[RUN_BONUS_1] = true;
		}
		else if ( g_bZoneExists[ZONE_BONUS_2_START] && IsInsideZone( ent, ZONE_BONUS_2_START ) )
		{
			GetEntPropVector( ent, Prop_Data, "m_angRotation", angAngle );
			
			ArrayCopy( angAngle, g_vecSpawnAngles[RUN_BONUS_2], 2 );
			g_vecSpawnAngles[RUN_BONUS_2][2] = 0.0;
			
			bFoundAng[RUN_BONUS_2] = true;
		}
	}
	
	
	// Give each starting zone a spawn position.
	// If no angle was previous found, we make it face the ending trigger.
	if ( g_bZoneExists[ZONE_START] )
	{
		if ( g_vecZoneMins[ZONE_START][0] < g_vecZoneMaxs[ZONE_START][0] )
		{
			g_vecSpawnPos[RUN_MAIN][0] = g_vecZoneMins[ZONE_START][0] + ( g_vecZoneMaxs[ZONE_START][0] - g_vecZoneMins[ZONE_START][0] ) / 2;
		}
		else
		{
			g_vecSpawnPos[RUN_MAIN][0] = g_vecZoneMaxs[ZONE_START][0] + ( g_vecZoneMins[ZONE_START][0] - g_vecZoneMaxs[ZONE_START][0] ) / 2;
		}
		
		if ( g_vecZoneMins[ZONE_START][1] < g_vecZoneMaxs[ZONE_START][1] )
		{
			g_vecSpawnPos[RUN_MAIN][1] = g_vecZoneMins[ZONE_START][1] + ( g_vecZoneMaxs[ZONE_START][1] - g_vecZoneMins[ZONE_START][1] ) / 2;
		}
		else
		{
			g_vecSpawnPos[RUN_MAIN][1] = g_vecZoneMaxs[ZONE_START][1] + ( g_vecZoneMins[ZONE_START][1] - g_vecZoneMaxs[ZONE_START][1] ) / 2;
		}
		
		g_vecSpawnPos[RUN_MAIN][2] = g_vecZoneMins[ZONE_START][2] + 16.0;
		
		
		// Direction of the end!
		if ( !bFoundAng[RUN_MAIN] )
			g_vecSpawnAngles[RUN_MAIN][1] = ArcTangent2( g_vecZoneMins[ZONE_END][1] - g_vecZoneMins[ZONE_START][1], g_vecZoneMins[ZONE_END][0] - g_vecZoneMins[ZONE_START][0] ) * 180 / MATH_PI;
	}
	
	if ( g_bZoneExists[ZONE_BONUS_1_START] )
	{
		if ( g_vecZoneMins[ZONE_BONUS_1_START][0] < g_vecZoneMaxs[ZONE_BONUS_1_START][0] )
		{
			g_vecSpawnPos[RUN_BONUS_1][0] = g_vecZoneMins[ZONE_BONUS_1_START][0] + ( g_vecZoneMaxs[ZONE_BONUS_1_START][0] - g_vecZoneMins[ZONE_BONUS_1_START][0] ) / 2;
		}
		else
		{
			g_vecSpawnPos[RUN_BONUS_1][0] = g_vecZoneMaxs[ZONE_BONUS_1_START][0] + ( g_vecZoneMins[ZONE_BONUS_1_START][0] - g_vecZoneMaxs[ZONE_BONUS_1_START][0] ) / 2;
		}
		
		if ( g_vecZoneMins[ZONE_BONUS_1_START][1] < g_vecZoneMaxs[ZONE_BONUS_1_START][1] )
		{
			g_vecSpawnPos[RUN_BONUS_1][1] = g_vecZoneMins[ZONE_BONUS_1_START][1] + ( g_vecZoneMaxs[ZONE_BONUS_1_START][1] - g_vecZoneMins[ZONE_BONUS_1_START][1] ) / 2;
		}
		else
		{
			g_vecSpawnPos[RUN_BONUS_1][1] = g_vecZoneMaxs[ZONE_BONUS_1_START][1] + ( g_vecZoneMins[ZONE_BONUS_1_START][1] - g_vecZoneMaxs[ZONE_BONUS_1_START][1] ) / 2;
		}
		
		g_vecSpawnPos[RUN_BONUS_1][2] = g_vecZoneMins[ZONE_BONUS_1_START][2] + 16.0;
		
		
		if ( !bFoundAng[RUN_BONUS_1] )
			g_vecSpawnAngles[RUN_BONUS_1][1] = ArcTangent2( g_vecZoneMins[ZONE_BONUS_1_END][1] - g_vecZoneMins[ZONE_BONUS_1_START][1], g_vecZoneMins[ZONE_BONUS_1_END][0] - g_vecZoneMins[ZONE_BONUS_1_START][0] ) * 180 / MATH_PI;
	}
	
	if ( g_bZoneExists[ZONE_BONUS_2_START] )
	{
		if ( g_vecZoneMins[ZONE_BONUS_2_START][0] < g_vecZoneMaxs[ZONE_BONUS_2_START][0] )
		{
			g_vecSpawnPos[RUN_BONUS_2][0] = g_vecZoneMins[ZONE_BONUS_2_START][0] + ( g_vecZoneMaxs[ZONE_BONUS_2_START][0] - g_vecZoneMins[ZONE_BONUS_2_START][0] ) / 2;
		}
		else
		{
			g_vecSpawnPos[RUN_BONUS_2][0] = g_vecZoneMaxs[ZONE_BONUS_2_START][0] + ( g_vecZoneMins[ZONE_BONUS_2_START][0] - g_vecZoneMaxs[ZONE_BONUS_2_START][0] ) / 2;
		}
		
		if ( g_vecZoneMins[ZONE_BONUS_2_START][1] < g_vecZoneMaxs[ZONE_BONUS_2_START][1] )
		{
			g_vecSpawnPos[RUN_BONUS_2][1] = g_vecZoneMins[ZONE_BONUS_2_START][1] + ( g_vecZoneMaxs[ZONE_BONUS_2_START][1] - g_vecZoneMins[ZONE_BONUS_2_START][1] ) / 2;
		}
		else
		{
			g_vecSpawnPos[RUN_BONUS_2][1] = g_vecZoneMaxs[ZONE_BONUS_2_START][1] + ( g_vecZoneMins[ZONE_BONUS_2_START][1] - g_vecZoneMaxs[ZONE_BONUS_2_START][1] ) / 2;
		}
		
		g_vecSpawnPos[RUN_BONUS_2][2] = g_vecZoneMins[ZONE_BONUS_2_START][2] + 16.0;
		
		
		if ( !bFoundAng[RUN_BONUS_2] )
			g_vecSpawnAngles[RUN_BONUS_2][1] = ArcTangent2( g_vecZoneMins[ZONE_BONUS_2_END][1] - g_vecZoneMins[ZONE_BONUS_2_START][1], g_vecZoneMins[ZONE_BONUS_2_END][0] - g_vecZoneMins[ZONE_BONUS_2_START][0] ) * 180 / MATH_PI;
	}
	
	// Determine what team we should put the runners in when map starts.
	// Bots go to the other team.
	if ( !g_iPreferredTeam )
	{
		if ( FindEntityByClassname( -1, "info_player_counterterrorist" ) != -1 )
		{
			g_iPreferredTeam = CS_TEAM_CT;
			ServerCommand( "mp_humanteam ct" );
			
#if defined RECORD
			ServerCommand( "bot_join_team t" );
#endif
		}
		else
		{
			g_iPreferredTeam = CS_TEAM_T;
			ServerCommand( "mp_humanteam t" );
			
#if defined RECORD
			ServerCommand( "bot_join_team ct" );
#endif
		}
	}
	
	
#if defined RECORD
	char szSpawn[29];
	
	if ( g_iPreferredTeam == CS_TEAM_CT )
	{
		strcopy( szSpawn, sizeof( szSpawn ), "info_player_terrorist" );
	}
	else
	{
		strcopy( szSpawn, sizeof( szSpawn ), "info_player_counterterrorist" );
	}
	// Spawn bot spawnpoints if none exist.
	if ( g_bIsLoaded[RUN_MAIN] && ( ent = FindEntityByClassname( -1, szSpawn ) ) == -1 )
	{
		for ( int i; i < 24; i++ )
		{
			ent = CreateEntityByName( szSpawn );
			
			if ( ent != -1 )
			{
				DispatchKeyValueVector( ent, "origin", g_vecSpawnPos[RUN_MAIN] );
				DispatchSpawn( ent );
			}
		}
	}
#endif
	
	
	// Spawn block zones and clean up map (if DELETE_ENTS is defined).
	CreateTimer( 3.0, Timer_DoMapStuff, TIMER_FLAG_NO_MAPCHANGE );
}

stock bool CreateBlockZoneEntity( int zone )
{
	if ( !g_bZoneExists[zone] ) return false;
	
	
	int ent = CreateEntityByName( "trigger_multiple" );
	
	if ( ent < 1 )
	{
		LogError( CONSOLE_PREFIX ... "Couldn't create block entity!" );
		return false;
	}
	
	DispatchKeyValue( ent, "wait", "0" );
	DispatchKeyValue( ent, "StartDisabled", "0" );
	DispatchKeyValue( ent, "spawnflags", "1" ); // Clients only!
	
	if ( !DispatchSpawn( ent ) )
	{
		LogError( CONSOLE_PREFIX ... "Couldn't spawn block entity!" );
		return false;
	}
	
	ActivateEntity( ent );

	
	if ( !IsModelPrecached( BLOCK_BRUSH_MODEL ) ) PrecacheModel( BLOCK_BRUSH_MODEL );
	
	SetEntityModel( ent, BLOCK_BRUSH_MODEL );
	
	SetEntProp( ent, Prop_Send, "m_fEffects", 32 ); // NODRAW
	
	
	/////////////////////////////////////////////
	// Create the bounding box for the entity: //
	/////////////////////////////////////////////
	
	// Determine the entity's origin. It is the center of the zone in this case.
	float vecPos[3];
	float vecLength[3];
	
	

	vecLength[0] = ( g_vecZoneMaxs[zone][0] - g_vecZoneMins[zone][0] ) / 2;
	vecPos[0] = g_vecZoneMins[zone][0] + vecLength[0];

	vecLength[1] = ( g_vecZoneMaxs[zone][1] - g_vecZoneMins[zone][1] ) / 2;
	vecPos[1] = g_vecZoneMins[zone][1] + vecLength[1];

	vecLength[2] = ( g_vecZoneMaxs[zone][2] - g_vecZoneMins[zone][2] ) / 2;
	vecPos[2] = g_vecZoneMins[zone][2] + vecLength[2];
	
	
	TeleportEntity( ent, vecPos, NULL_VECTOR, NULL_VECTOR );
	
	
	// We then set the mins and maxs of the zone.
	float vecMins[3];
	float vecMaxs[3];
	
	vecMins[0] = -1 * vecLength[0];
	vecMins[1] = -1 * vecLength[1];
	vecMins[2] = -1 * vecLength[2];
	
	vecMaxs[0] = vecLength[0];
	vecMaxs[1] = vecLength[1];
	vecMaxs[2] = vecLength[2];
	
	SetEntPropVector( ent, Prop_Send, "m_vecMins", vecMins );
	SetEntPropVector( ent, Prop_Send, "m_vecMaxs", vecMaxs );
	SetEntProp( ent, Prop_Send, "m_nSolidType", 2 ); // Essential! Use bounding box instead of model's bsp(?) for input.
	
	
	// Done! Hook it!
	SDKHook( ent, SDKHook_StartTouchPost, Event_TouchBlock );
	
	// Make sure we know which entity we hooked.
	switch ( zone )
	{
		case ZONE_BLOCK_1 : g_iBlockZoneIndex[0] = ent;
		case ZONE_BLOCK_2 : g_iBlockZoneIndex[1] = ent;
		case ZONE_BLOCK_3 : g_iBlockZoneIndex[2] = ent;
	}
	
	return true;
}

stock void SetPlayerStyle( int client, int style )
{
	if ( !IsPlayerAlive( client ) )
	{
		PRINTCHAT( client, client, CHAT_PREFIX ... "You must be alive to change your style!" );
		return;
	}
	
	if ( !IsStyleAllowed( style ) )
	{
		PRINTCHAT( client, client, CHAT_PREFIX ... "That style is not allowed!" );
		return;
	}

	if ( IsSpamming( client ) )
	{
		PRINTCHAT( client, client, CHAT_PREFIX ... "Please wait before using this command again, thanks." );
		return;
	}
	
	
	if ( g_bIsLoaded[ g_iClientRun[client] ] )
	{
		TeleportPlayerToStart( client );
	}
	
	g_iClientStyle[client] = style;
	
	if ( style == STYLE_VEL )
	{
		PRINTCHATV( client, client, CHAT_PREFIX ... "Your style is now \x03%.0fvel"...CLR_TEXT..."!", g_flVelCap );
	}
	else
	{
		PRINTCHATV( client, client, CHAT_PREFIX ... "Your style is now \x03%s"...CLR_TEXT..."!", g_szStyleName[NAME_LONG][style] );
	}
	
	UpdateScoreboard( client );
}

stock void SetPlayerRun( int client, int run )
{
	if ( !IsPlayerAlive( client ) )
	{
		PRINTCHAT( client, client, CHAT_PREFIX ... "You must be alive to change your run!" );
		return;
	}
	
	if ( !g_bIsLoaded[run] )
	{
		PRINTCHAT( client, client, CHAT_PREFIX ... "That run is not available!" );
		return;
	}
	
	if ( IsSpamming( client ) )
	{
		PRINTCHAT( client, client, CHAT_PREFIX ... "Please wait before using this command again, thanks." );
		return;
	}
	
	
	g_iClientRun[client] = run;
	
	TeleportPlayerToStart( client );
}

stock bool IsSpamming( int client )
{
	if ( g_flClientWarning[client] > GetEngineTime() )
	{
		return true;
	}
	
	g_flClientWarning[client] = GetEngineTime() + WARNING_INTERVAL;
	
	return false;
}

stock bool IsStyleAllowed( int style )
{
	switch( style )
	{
		case STYLE_HSW : if ( !GetConVarBool( g_ConVar_Allow_HSW ) ) return false;
		case STYLE_REAL_HSW : if ( !GetConVarBool( g_ConVar_Allow_RHSW ) ) return false;
		case STYLE_SIDEWAYS : if ( !GetConVarBool( g_ConVar_Allow_SW ) ) return false;
		case STYLE_W : if ( !GetConVarBool( g_ConVar_Allow_W ) ) return false;
		case STYLE_VEL : if ( !GetConVarBool( g_ConVar_Allow_Vel ) ) return false;
	}
	
	return true;
}

// Used for players and other entities.
stock bool IsInsideZone( int ent, int zone )
{
	if ( !g_bZoneExists[zone] ) return false;
	
	
	static float vecPos[3];
	GetEntPropVector( ent, Prop_Data, "m_vecOrigin", vecPos );
	
	// As of 1.4.4, we correct zone mins and maxs.
	return (
		( g_vecZoneMins[zone][0] <= vecPos[0] <= g_vecZoneMaxs[zone][0] )
		&&
		( g_vecZoneMins[zone][1] <= vecPos[1] <= g_vecZoneMaxs[zone][1] )
		&&
		( g_vecZoneMins[zone][2] <= vecPos[2] <= g_vecZoneMaxs[zone][2] ) );
}

stock void CopyRecordToPlayback( int client )
{
	int run = g_iClientRun[client];
	int style = g_iClientStyle[client];
	// If that bot already exists, we must stop it from mimicing.
	g_bClientMimicing[ g_iRec[run][style] ] = false;
	
	
	// Clone client's recording to the playback slot.
	g_hRec[run][style] = CloneArray( g_hClientRecording[client] );
	g_iRecTickMax[run][style] = GetArraySize( g_hClientRecording[client] );
	
	// Re-calc max length.
	g_iRecMaxLength[run][style] = RoundFloat( g_iRecTickMax[run][style] * 1.2 );
	
	
	delete g_hClientRecording[client];
	g_hClientRecording[client] = null;
	g_bClientRecording[client] = false;
	
	GetClientName( client, g_szRecName[run][style], sizeof( g_szRecName[][] ) );
	
	ArrayCopy( g_vecInitPos[client], g_vecInitRecPos[run][style], 3 );
	ArrayCopy( g_vecInitAng[client], g_vecInitRecAng[run][style], 2 );
	
	if ( g_iRec[run][style] != INVALID_INDEX )
	{
		// We already have a bot? Let's use it instead.
		AssignRecordToBot( g_iRec[run][style], run, style );
	}
	else
	{
		// Create new if one doesn't exist.
		// Check OnClientPutInServer() for that.
		g_iNumRec++;
		ServerCommand( "bot_quota %i", g_iNumRec );
	}
}

stock void AssignRecordToBot( int mimic, int run, int style )
{
	g_iClientRun[mimic] = run;
	g_iClientStyle[mimic] = style;
	
	g_iRec[run][style] = mimic;
	
	// We'll have to limit the player's name in order to show everything.
	char szName[MAX_RECNAME_LENGTH];
	strcopy( szName, sizeof( szName ), g_szRecName[run][style] );
	
	char szTime[SIZE_TIME_SCOREBOARD];
	FormatSeconds( g_flMapBestTime[run][style], szTime, sizeof( szTime ), FORMAT_NOHOURS );
	
	// "XXXXXXXXXXXX [B1|RHSW] 00:00.00"
	char szFullName[MAX_NAME_LENGTH];
	FormatEx( szFullName, sizeof( szFullName ), "%s [%s|%s] %s", szName, g_szRunName[NAME_SHORT][run], g_szStyleName[NAME_SHORT][style], szTime );
	SetClientInfo( mimic, "name", szFullName );
	
	// Teleport 'em to the starting position and start the countdown!
	g_bClientMimicing[mimic] = false;
	g_nClientTick[mimic] = TICK_PRE_PLAYBLACK;
	
	CreateTimer( 2.0, Timer_Rec_Start, g_iRec[run][style] );
}