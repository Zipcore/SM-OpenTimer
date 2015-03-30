#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <basecomm> // To check if client is gagged.

#define PLUGIN_VERSION	"1.4.1"
#define PLUGIN_AUTHOR	"Mehis"


//	OPTIONS: Uncomment/comment things to change the plugin to your liking! Simply adding '//' (without quotation marks) in front of the line.
// ------------------------------------------------------------------------------------------------------------------------------------------
#define	RECORD // Comment out for no recording and record playback.


//#define VOTING // Comment out for no voting. NOTE: This overrides commands rtv and nominate.
// Disabled by default because it overrides default commands. (rtv/nominate)


//#define CHAT // Comment out for no chat processing. Custom colors on player messages.
// Disabled by default because it is not really necessary for this plugin.

//#define DELETE_ENTS // Comment out to keep some entities. (func_doors, func_movelinears, etc.)
// This was originally used for surf maps. If you want old bhop maps with platforms don't uncomment.


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

#define RECORDS_PRINT_MAXPLAYERS 16 // Maximum records to print in the console. Def. 16


// HEX color codes
//
// You have to put \x07{HEX COLOR}
// E.g \x07FFFFFF for white
//
// You can then put your own text after it:
// \x07FFFFFFThis text is white!
#define COLOR_PURPLE	"\x07E71470"
#define COLOR_TEAL		"\x0766CCCC"
#define COLOR_GRAY		"\x07434343"

#define COLOR_TEXT		"\x07FFFFFF" // Default text color.

#define CHAT_PREFIX		"\x072F2F2F[\x07D01265OpenTimer\x072F2F2F]" ... COLOR_TEXT

#define CONSOLE_PREFIX	"[OpenTimer]" // Used only for console/server.

// Don't change things under this unless you know what you are doing!!
// -------------------------------------------------------------------



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
	/*
		Huge thanks to Peace-Maker. A lot was learned from his movement recorder plugin.
		Another huge thanks to george for giving me a tip about the correct way of recording ;)
	*/
	enum FrameInfo {
		float:FRAME_ANGLES[2],
		float:FRAME_POS[3],
		
		FRAME_FLAGS // Combined FRAME_BUTTONS and FRAME_FLAGS. See FRAMEFLAG_*
	};
	
	enum HeaderInfo {
		HEADER_BINARYFORMAT = 0,
		
		HEADER_TICKCOUNT,
		float:HEADER_TIME, // Just in case our database loses the record information!!
		
		
		float:HEADER_INITPOS[3],
		float:HEADER_INITANGLES[2]
	};
	
	#define FRAME_SIZE			6
	#define HEADER_SIZE			8
	
	#define MAGIC_NUMBER		0x4B1B
	// Old: 0x4B1D
	// 1.3: 0x4B1F
	// PRE-1.4: 0x4B1C
	
	#define BINARY_FORMAT		0x01
	
	#define TICK_PRE_PLAYBLACK	-1
	
	//#define FRAMEFLAG_TELEPORT	( 1 << 0 )
	#define FRAMEFLAG_CROUCH	( 1 << 0 )
	
	// Honestly, shooting isn't even needed since we don't record weapons in the first place.
	//#define FRAMEFLAG_ATTACK1	( 1 << 1 )
	//#define FRAMEFLAG_ATTACK2	( 1 << 2 )
	
	#define MIN_REC_SIZE		100
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

#define HIDE_FLAGS				3946

#define STRAFE_INVALID			0
#define STRAFE_LEFT				1
#define STRAFE_RIGHT			2

#define TIME_INVALID			0.0

#define TIMER_UPDATE_INTERVAL	0.1 // HUD Timer.
#define ZONE_UPDATE_INTERVAL	3.0
#define ZONE_BUILD_INTERVAL		0.1
#define ZONE_WIDTH				1.0
#define ZONE_DEF_HEIGHT			128.0

#define WARNING_INTERVAL		3.0

// How many samples we take to determine our sync.
//#define SYNC_MAX_SAMPLES		1000

// How many checkpoints can a player have?
#define PRAC_MAX_SAVES			5

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
enum {
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
	
	MAX_ZONES
};
// Number of block zones available.
#define NUM_BLOCKZONES 3

enum { STATE_START = 0, STATE_RUNNING, STATE_END };

enum {
	RUN_MAIN = 0,
	RUN_BONUS_1,
	RUN_BONUS_2,
	
	MAX_RUNS
};

enum { NAME_LONG = 0, NAME_SHORT, MAX_NAMES };

enum {
	STYLE_NORMAL = 0,
	STYLE_SIDEWAYS,
	STYLE_W,
	STYLE_REAL_HSW,
	STYLE_HSW,
	
	MAX_STYLES // 5
};


// Zones
bool	g_bIsLoaded[MAX_RUNS]; // Do we have start and end zone for main/bonus at least?
bool	g_bZoneExists[MAX_ZONES]; // Are we going to check if the player is inside the zones in the first place?
float	g_vecZoneMins[MAX_ZONES][3];
float	g_vecZoneMaxs[MAX_ZONES][3];
int		g_iBlockZoneIndex[NUM_BLOCKZONES];


// Building
int g_iBuilderIndex;
int g_iBuilderZone = INVALID_ZONE_INDEX;
int g_iBuilderGridSize = BUILDER_DEF_GRIDSIZE;


// Running
int		g_iClientState[MAXPLAYERS_BHOP]; // Player's previous position (in start/end/running?)
int		g_iClientStyle[MAXPLAYERS_BHOP]; // Styles W-ONLY/HSW/RHSW etc.
int		g_iClientRun[MAXPLAYERS_BHOP]; // Which run client is doing (main/bonus)?
float	g_flClientStartTime[MAXPLAYERS_BHOP]; // When we started our run? Engine time.
float	g_flClientFinishTime[MAXPLAYERS_BHOP]; // This is to tell the client's finish time in the end. Engine time.
float	g_flClientBestTime[MAXPLAYERS_BHOP][MAX_RUNS][MAX_STYLES];


// Player stats
int g_iClientJumpCount[MAXPLAYERS_BHOP];
int g_iClientStrafeCount[MAXPLAYERS_BHOP];
// New sync
int g_iClientSync[MAXPLAYERS_BHOP] = { 1, ... };
int g_iClientSync_Max[MAXPLAYERS_BHOP] = { 1, ... };

int g_iClientLastStrafe[MAXPLAYERS_BHOP]; // Which direction did the client strafe to last time?


// Misc player stuff.
float	g_flClientWarning[MAXPLAYERS_BHOP]; // Used for anti-spam.
bool	g_bClientHoldingJump[MAXPLAYERS_BHOP]; // Used for anti-doublestep.


// Practice
bool	g_bIsClientPractising[MAXPLAYERS_BHOP];
float	g_vecClientSavePos[MAXPLAYERS_BHOP][PRAC_MAX_SAVES][3];
float	g_vecClientSaveAng[MAXPLAYERS_BHOP][PRAC_MAX_SAVES][3];
float	g_vecClientSaveVel[MAXPLAYERS_BHOP][PRAC_MAX_SAVES][3];
float	g_flClientSaveDif[MAXPLAYERS_BHOP][PRAC_MAX_SAVES]; // The time between save and start time.
int		g_iClientCurSave[MAXPLAYERS_BHOP] = { INVALID_CP, ... };


// Recording
#if defined RECORD
	Handle	g_hClientRecording[MAXPLAYERS_BHOP];
	bool	g_bIsClientRecording[MAXPLAYERS_BHOP];
	bool	g_bIsClientMimicing[MAXPLAYERS_BHOP];
	int		g_iClientSnapshot[MAXPLAYERS_BHOP];
	int		g_iClientTick[MAXPLAYERS_BHOP];
	
	float	g_vecInitPos[MAXPLAYERS_BHOP][3];
	float	g_angInitAngles[MAXPLAYERS_BHOP][3];
	
	// Mimic stuff
	float	g_vecInitMimicPos[MAX_RUNS][MAX_STYLES][3];
	float	g_angInitMimicAngles[MAX_RUNS][MAX_STYLES][3];
	int		g_iMimic[MAX_RUNS][MAX_STYLES];
	int		g_iNumMimic;
	int		g_iMimicTickMax[MAX_RUNS][MAX_STYLES];
	Handle	g_hMimicRecording[MAX_RUNS][MAX_STYLES];
	char	g_szMimicName[MAX_RUNS][MAX_STYLES][MAX_NAME_LENGTH];
#endif


// Client settings (bonus stuff)
int g_iClientFOV[MAXPLAYERS_BHOP] = { 90, ... };
int g_iClientHideFlags[MAXPLAYERS_BHOP];


// Other
char	g_szCurrentMap[MAX_MAP_NAME_LENGTH];
float	g_vecSpawnPos[MAX_RUNS][3];
float	g_angSpawnAngles[MAX_RUNS][3];
float	g_flMapBestTime[MAX_RUNS][MAX_STYLES];
int		g_iBeam;
int		g_iPreferedTeam = CS_TEAM_T;


// Voting stuff
#if defined VOTING
	ArrayList	g_hMapList;
	char		g_szNextMap[MAX_MAP_NAME_LENGTH];
	
	int			g_iClientVote[MAXPLAYERS_BHOP] = { -1, ... };
#endif


// Constants
char	g_szZoneNames[MAX_ZONES][15] = {
	"Start", "End",
	"Bonus #1 Start", "Bonus #1 End",
	"Bonus #2 Start", "Bonus #2 End",
	"Freestyle #1", "Freestyle #2", "Freestyle #3",
	"Block #1", "Block #2", "Block #3"
};
char	g_szRunName[MAX_NAMES][MAX_RUNS][9] = {
	{ "Main", "Bonus #1", "Bonus #2" },
	{ "M", "B1", "B2" }
};
char	g_szStyleName[MAX_NAMES][MAX_STYLES][14] = {
	{ "Normal", "Sideways", "W-Only", "Real HSW", "Half-Sideways" },
	{ "N", "SW", "W", "RHSW", "HSW" }
};
char	g_szWinningSounds[][25] = {
	"buttons/button16.wav", "bot/i_am_on_fire.wav",
	"bot/its_a_party.wav", "bot/made_him_cry.wav",
	"bot/this_is_my_house.wav", "bot/yea_baby.wav",
	"bot/yesss.wav", "bot/yesss2.wav"
};
float	g_vecNull[3] = { 0.0, 0.0, 0.0 };


// ConVars
ConVar			g_ConVar_AirAccelerate; // To tell the client what aa we have.
static ConVar	g_ConVar_PreSpeed;
ConVar			g_ConVar_AutoHop;
ConVar			g_ConVar_EZHop;
ConVar			g_ConVar_LeftRight;
ConVar			g_ConVar_SmoothPlayback;


// Settings (Convars)
// WARNING: Must be initialized as the default value or it will not register when executing it(?)!!
bool g_bPreSpeed = false;
bool g_bForbiddenCommands = true;
bool g_bAutoHop = true;
bool g_bEZHop = true;
bool g_bSmoothPlayback = true;
//bool g_bClientAutoHop[MAXPLAYERS_BHOP] = { true, ... };

// ------------------------
// End of globals.
// ------------------------

#if defined RECORD
	#include "opentimer/file.sp"
#endif

#include "opentimer/recording.sp"
#include "opentimer/usermsg.sp"
#include "opentimer/stocks.sp"
#include "opentimer/database.sp"
#include "opentimer/events.sp"
#include "opentimer/commands.sp"
#include "opentimer/commands_admin.sp"
#include "opentimer/timers.sp"
#include "opentimer/menus.sp"
#include "opentimer/menus_admin.sp"

public Plugin OpenTimerInfo = {
	author = PLUGIN_AUTHOR,
	name = "OpenTimer",
	description = "Open source timer plugin",
	url = "http://steamcommunity.com/profiles/76561198021256769",
	version = PLUGIN_VERSION
};

public void OnPluginStart()
{
	// HOOKS
	HookEvent( "player_spawn", Event_ClientSpawn );
	HookEvent( "player_jump", Event_ClientJump );
	HookEvent( "player_death", Event_ClientDeath );
	//HookEvent( "player_team", Event_ClientChangeTeam );
	//HookEvent( "player_changename", Event_ClientName, EventHookMode_Pre );
	//HookEvent( "teamplay_round_start", Event_RoundStart, EventHookMode_PostNoCopy );
	
	
	// LISTENERS
	AddCommandListener( Listener_Say, "say" );
	AddCommandListener( Listener_Say, "say_team" );
	
	AddCommandListener( Listener_AntiDoublestep_On, "+ds" );
	AddCommandListener( Listener_AntiDoublestep_Off, "-ds" );
	
	
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
	RegConsoleCmd( "sm_wr", Command_RecordsMOTD );
	RegConsoleCmd( "sm_records", Command_RecordsMOTD );
	RegConsoleCmd( "sm_times", Command_RecordsMOTD );
	
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
	RegConsoleCmd( "sm_v", Command_Version );
	
	RegConsoleCmd( "sm_ds", Command_Doublestep );
	RegConsoleCmd( "sm_doublestep", Command_Doublestep );
	RegConsoleCmd( "sm_doublestepping", Command_Doublestep );
	
	
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
	
	g_ConVar_LeftRight = CreateConVar( "sm_forbidden_commands", "1", "Is +left and +right allowed?", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	
	g_ConVar_SmoothPlayback = CreateConVar( "sm_smoothplayback", "1", "If false, playback movement will appear more responsive but choppy and teleporting will not be affected by ping.", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	
	
	HookConVarChange( g_ConVar_AutoHop, Event_ConVar_AutoHop );
	HookConVarChange( g_ConVar_EZHop, Event_ConVar_EZHop );
	HookConVarChange( g_ConVar_PreSpeed, Event_ConVar_PreSpeed );
	HookConVarChange( g_ConVar_LeftRight, Event_ConVar_LeftRight );
	HookConVarChange( g_ConVar_SmoothPlayback, Event_ConVar_SmoothPlayback );
	
	
	InitializeDatabase();
	
/*
#if defined RECORD
	// Doesn't work.
	HookEvent( "base_player_teleported", Event_ClientTeleport );
	
	// Unreliable. Would fire even when not teleported.
	HookEntityOutput( "trigger_teleport", "OnEndTouch", Event_Teleport );
#endif
*/

	LoadTranslations( "common.phrases" ); // So FindTarget() can work.
}

public void Event_ConVar_AutoHop( Handle hConVar, const char[] szOldValue, const char[] szNewValue )
{
	g_bAutoHop = GetConVarBool( hConVar );
}

public void Event_ConVar_EZHop( Handle hConVar, const char[] szOldValue, const char[] szNewValue )
{
	g_bEZHop = GetConVarBool( hConVar );
}

public void Event_ConVar_PreSpeed( Handle hConVar, const char[] szOldValue, const char[] szNewValue )
{
	g_bPreSpeed = GetConVarBool( hConVar );
}

public void Event_ConVar_LeftRight( Handle hConVar, const char[] szOldValue, const char[] szNewValue )
{
	g_bForbiddenCommands = GetConVarBool( hConVar );
}

public void Event_ConVar_SmoothPlayback( Handle hConVar, const char[] szOldValue, const char[] szNewValue )
{
	g_bSmoothPlayback = GetConVarBool( hConVar );
}

public void OnMapStart()
{
#if defined RECORD
	// No bots until we have records.
	ServerCommand( "bot_quota 0" );
	g_iNumMimic = 0;
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
	
	
	for ( int run; run < MAX_RUNS; run++ )
		for ( int style; style < MAX_STYLES; style++ )
		{
			g_flMapBestTime[run][style] = TIME_INVALID;
			
#if defined RECORD
			// Remove all mimic recordings.
			g_iMimic[run][style] = INVALID_INDEX;
			g_iMimicTickMax[run][style] = 0;
			
			if ( g_hMimicRecording[run][style] != null )
			{
				delete g_hMimicRecording[run][style];
				g_hMimicRecording[run][style] = null;
				//ClearArray( g_hMimicRecording[run][style] );
			}
#endif
		}

	// Block zone resets...
	ArrayFill( g_iBlockZoneIndex, 0, NUM_BLOCKZONES );
	PrecacheModel( BLOCK_BRUSH_MODEL );
	
	
	// materials/sprites/plasma.vmt, Original
	// materials/vgui/white.vmt
	g_iBeam = PrecacheModel( "materials/sprites/laserbeam.vmt" );
	
	
	for ( int i; i < sizeof( g_szWinningSounds ); i++ )
	{
		PrecacheSound( g_szWinningSounds[i] );
	}

	
	// Get map zones from database.
	InitializeMapZones();
	
#if defined VOTING
	// Find maps to vote for from database.
	FindMaps();
#endif
	
	
	// Repeating timer that sends the zones to the client every X seconds.
	CreateTimer( ZONE_UPDATE_INTERVAL, Timer_DrawZoneBeams, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
	
	
	// We want to restart the map if it has been going on for too long without any players.
	// This prevents performance issues.
	CreateTimer( 3600.0, Timer_RestartMap, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
}

public void OnClientDisconnect( int client )
{
	// Release client's vote or bot's record.
	
	
#if defined RECORD
	if ( IsFakeClient( client ) && g_iMimic[ g_iClientRun[client] ][ g_iClientStyle[client] ] == client )
	{
		g_iMimic[ g_iClientRun[client] ][ g_iClientStyle[client] ] = INVALID_INDEX;
		return;
	}
#endif

#if defined VOTING
	g_iClientVote[client] = -1;
	CalcVotes();
#endif
}

public void OnClientPutInServer( int client )
{
	// Reset stuff, assign records and hook necessary events.
	
	
	// States
	g_iClientState[client] = STATE_RUNNING;
	g_iClientStyle[client] = STYLE_NORMAL;
	g_iClientRun[client] = RUN_MAIN;
	
	
	// Times
	g_flClientStartTime[client] = TIME_INVALID;
	g_flClientFinishTime[client] = TIME_INVALID;
	
	for ( int i; i < MAX_RUNS; i++ )
		ArrayFill( g_flClientBestTime[client][i], TIME_INVALID, MAX_STYLES );
	
	
	// Stats
	g_iClientJumpCount[client] = 0;
	g_iClientStrafeCount[client] = 0;
	
	g_iClientSync[client] = 1;
	g_iClientSync_Max[client] = 1;
	
	
	// Practicing
	g_bIsClientPractising[client] = false;
	
	for ( int i; i < PRAC_MAX_SAVES; i++ )
	{
		// Reset all checkpoints.
		g_flClientSaveDif[client][i] = TIME_INVALID;
	}
	
	g_iClientCurSave[client] = INVALID_CP;

	
#if defined RECORD
	// Recording
	g_bIsClientRecording[client] = false;
	g_bIsClientMimicing[client] = false;
	g_iClientSnapshot[client] = 0;
	g_iClientTick[client] = 0;
	
	if ( g_hClientRecording[client] != null )
	{
		delete g_hClientRecording[client];
		g_hClientRecording[client] = null;
	}
#endif
	
	// Misc.
	g_iClientFOV[client] = 90;
	g_iClientHideFlags[client] = 0;
	
	g_flClientWarning[client] = TIME_INVALID;
	
	
	// --------------------------------------------------------------------------------
	// Reset is done, now we assign stuff. Fetch client data from DB and hook stuff...
	// --------------------------------------------------------------------------------
#if defined RECORD
	if ( IsFakeClient( client ) )
	{
		// -----------------------------------------------
		// Assign records for bots and make them mimic it.
		// -----------------------------------------------
		for ( int run; run < MAX_RUNS; run++ )
			for ( int style; style < MAX_STYLES; style++ )
			{
				// We already have a mimic in this slot? Continue to the next.
				if ( g_iMimic[run][style] != INVALID_INDEX || g_iMimicTickMax[run][style] < 1 ) continue;
				
				char szName[MAX_NAME_LENGTH];
				Format( szName, sizeof( szName ), "REC* %s [%s|%s]", g_szMimicName[run][style], g_szRunName[NAME_SHORT][run], g_szStyleName[NAME_SHORT][style] );
				SetClientInfo( client, "name", szName );
				
				char szFormTime[12];
				FormatSeconds( g_flMapBestTime[run][style], szFormTime, sizeof( szFormTime ), false );
				CS_SetClientClanTag( client, szFormTime );
				
				// Get the bot ready for playback.
				g_iClientTick[client] = TICK_PRE_PLAYBLACK;
				
				TeleportEntity( client, g_vecInitMimicPos[run][style], g_angInitMimicAngles[run][style], g_vecNull );
				CreateTimer( 2.0, Timer_Rec_Start, client, TIMER_FLAG_NO_MAPCHANGE );
				
				g_iClientStyle[client] = style;
				g_iClientRun[client] = run;
				
				g_iMimic[run][style] = client;
				
				return;
			}
		
		return;
	}
#endif
	
	
	// Get their desired FOV and other settings from DB.
	RetrieveClientData( client );
	
	// Welcome message for players.
	CreateTimer( 5.0, Timer_Connected, GetClientUserId( client ), TIMER_FLAG_NO_MAPCHANGE );
	
	// Timer's timer function :^)
	CreateTimer( TIMER_UPDATE_INTERVAL, Timer_ShowClientInfo, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
	
	SDKHook( client, SDKHook_OnTakeDamage, Event_ClientDamage );
	SDKHook( client, SDKHook_WeaponDropPost, Event_WeaponDrop ); // No more weapon dropping.
	SDKHook( client, SDKHook_WeaponSwitchPost, Event_WeaponSwitchPost ); // FOV reset.
	SDKHook( client, SDKHook_PreThinkPost, Event_ClientThink );
}

public void Event_WeaponSwitchPost( int client )
{
	// The higher the ping, the longer the transition period will be.
	SetClientFOV( client, g_iClientFOV[client] );
}

public void Event_WeaponDrop( int client, int weapon )
{
	// This doesn't delete all the weapons.
	// In fact, this doesn't get called when player suicides.
	if ( IsValidEntity( weapon ) )
		AcceptEntityInput( weapon, "Kill" );
}


// Used just here.
enum { INSIDE_START = 0, INSIDE_END, INSIDE_MAX };

public void Event_ClientThink( int client )
{
	// ---------------------------------------------------------
	// Main component of the timer. Does everything, basically.
	// ---------------------------------------------------------
	if ( !g_bIsLoaded[ g_iClientRun[client] ] || !IsPlayerAlive( client ) ) return;
	
	
	static bool bInsideZone[MAXPLAYERS_BHOP][INSIDE_MAX];
	
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
		if ( GetEntityMoveType( client ) == MOVETYPE_NOCLIP && !g_bIsClientPractising[client] )
		{
			PrintColorChat( client, client, "%s You are now in \x03practice%s mode! Type \x03!prac%s again to toggle.", CHAT_PREFIX, COLOR_TEXT, COLOR_TEXT );
			g_bIsClientPractising[client] = true;
		}
		// No prespeeding.
		else if ( !g_bPreSpeed && GetClientVelocity( client ) > 300.0 && GetEntityMoveType( client ) != MOVETYPE_NOCLIP )
		{
			if ( g_flClientWarning[client] < GetEngineTime() )
			{
				PrintColorChat( client, client, "%s No prespeeding allowed! (\x03300spd%s)", CHAT_PREFIX, COLOR_TEXT );
				
				g_flClientWarning[client] = GetEngineTime() + WARNING_INTERVAL;
			}
			
			
			TeleportEntity( client, NULL_VECTOR, NULL_VECTOR, g_vecNull );
			
			return;
		}
		
		g_flClientStartTime[client] = GetEngineTime();
		
		
		g_iClientSync[client] = 1;
		g_iClientSync_Max[client] = 1;
		
#if defined RECORD
		// Start to record if we're not practising...
		if ( !g_bIsClientPractising[client] )
		{
			g_iClientTick[client] = 0;
			g_bIsClientRecording[client] = true;
			
			g_hClientRecording[client] = CreateArray( view_as<int>FrameInfo );
			
			GetClientEyeAngles( client, g_angInitAngles[client] );
			GetClientAbsOrigin( client, g_vecInitPos[client] );
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
			float flNewTime = GetEngineTime() - g_flClientStartTime[client];
			
			g_flClientFinishTime[client] = flNewTime;
			
			if ( !SaveClientRecord( client, flNewTime ) )
			{
				PrintColorChat( client, client, "%s Couldn't save your record and/or recording!", CHAT_PREFIX );
			}
			
#if defined RECORD
			if ( g_bIsClientRecording[client] && g_hClientRecording[client] != null )
			{
				g_iClientTick[client] = 0;
				g_bIsClientRecording[client] = false;
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
			g_iClientJumpCount[client] = 0;
		}
		
		g_iClientState[client] = STATE_START;
		
		ArrayFill( g_flClientSaveDif[client], TIME_INVALID, PRAC_MAX_SAVES );
		
		g_iClientStrafeCount[client] = 0;
		g_iClientLastStrafe[client] = STRAFE_INVALID;
		
/*#if defined VOTING
		static float flClientKick[MAXPLAYERS_BHOP];
		
		if ( GetEntProp( client, Prop_Data, "m_nButtons" ) == 0 && flClientKick[client] == 0.0 )
			flClientKick[client] = GetEngineTime() + 120.0;
		
		if ( GetEngineTime() > flClientLastAway[client] )
		{
			flClientKick[client] = 0.0;
			ChangeClientTeam( client, CS_TEAM_SPECTATOR );
		}
#endif*/
	}
#if defined RECORD
	else if ( !g_bIsClientPractising[client] && g_bIsClientRecording[client] )
	{
		// We're running and recording!
		// Have we been running for too long?
		
		
		// Is our recording longer than max length.
		// Or...
		// Does the mimic's recording even exist?
		// Is our tick count bigger than mimics? This doesn't consider if the mimic doesn't exist but best time does.
		if ( g_iClientTick[client] > RECORDING_MAX_LENGTH || ( g_iMimicTickMax[ g_iClientRun[client] ][ g_iClientStyle[client] ] > 0 && g_iClientTick[client] > g_iMimicTickMax[ g_iClientRun[client] ][ g_iClientStyle[client] ] ) )
		{
			g_iClientTick[client] = 0;
			g_bIsClientRecording[client] = false;
			
			if ( g_hClientRecording[client] != null )
			{
				delete g_hClientRecording[client];
				g_hClientRecording[client] = null;
			}
			
			if ( g_iClientTick[client] > RECORDING_MAX_LENGTH )
			{
				PrintColorChat( client, client, "%s Your time was too long to be recorded!", CHAT_PREFIX );
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
	
	
	if ( g_flClientWarning[client] < GetEngineTime() )
	{
		PrintColorChat( client, client, "%s That key (combo) is not allowed in \x03%s%s!", CHAT_PREFIX, g_szStyleName[NAME_LONG][ g_iClientStyle[client] ], COLOR_TEXT );
		
		g_flClientWarning[client] = GetEngineTime() + WARNING_INTERVAL;
	}
	
	
	// We can't go back? Just kill them.
	if ( !g_bIsLoaded[ g_iClientRun[client] ] )
	{
		ForcePlayerSuicide( client );
		return;
	}
	
	TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_angSpawnAngles[ g_iClientRun[client] ], g_vecNull );
}

stock void DoMapStuff()
{
	// Find a destination where we are suppose to go to when teleporting back to a zone.
	// Find an angle for the starting zones.
	// Find suitable team for players.
	// Spawn block zones.
	
	
	bool	bFoundAng[MAX_RUNS];
	float	angAngle[3];
	int		ent;
	
	while ( ( ent = FindEntityByClassname( ent, "info_teleport_destination" ) ) != -1 )
	{
		if ( IsInsideZone( ent, ZONE_START ) )
		{
			GetEntPropVector( ent, Prop_Data, "m_angRotation", angAngle );
			
			ArrayCopy( angAngle, g_angSpawnAngles[RUN_MAIN], 2 );
			bFoundAng[RUN_MAIN] = true;
		}
		else if ( IsInsideZone( ent, ZONE_BONUS_1_START ) )
		{
			GetEntPropVector( ent, Prop_Data, "m_angRotation", angAngle );
			
			ArrayCopy( angAngle, g_angSpawnAngles[RUN_BONUS_1], 2 );
			bFoundAng[RUN_BONUS_1] = true;
		}
		else if ( IsInsideZone( ent, ZONE_BONUS_2_START ) )
		{
			GetEntPropVector( ent, Prop_Data, "m_angRotation", angAngle );
			
			ArrayCopy( angAngle, g_angSpawnAngles[RUN_BONUS_2], 2 );
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
			g_angSpawnAngles[RUN_MAIN][1] = ArcTangent2( g_vecZoneMins[ZONE_END][1] - g_vecZoneMins[ZONE_START][1], g_vecZoneMins[ZONE_END][0] - g_vecZoneMins[ZONE_START][0] ) * 180 / MATH_PI;
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
			g_angSpawnAngles[RUN_BONUS_1][1] = ArcTangent2( g_vecZoneMins[ZONE_BONUS_1_END][1] - g_vecZoneMins[ZONE_BONUS_1_START][1], g_vecZoneMins[ZONE_BONUS_1_END][0] - g_vecZoneMins[ZONE_BONUS_1_START][0] ) * 180 / MATH_PI;
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
			g_angSpawnAngles[RUN_BONUS_2][1] = ArcTangent2( g_vecZoneMins[ZONE_BONUS_2_END][1] - g_vecZoneMins[ZONE_BONUS_2_START][1], g_vecZoneMins[ZONE_BONUS_2_END][0] - g_vecZoneMins[ZONE_BONUS_2_START][0] ) * 180 / MATH_PI;
	}
	
	
	// Determine what team we should put the runners in.
	if ( FindEntityByClassname( ent, "info_player_counterterrorist" ) != -1 )
	{
		g_iPreferedTeam = CS_TEAM_CT;
		
#if defined RECORD
		ServerCommand( "bot_join_team ct" );
#endif
	}
	else
	{
		g_iPreferedTeam = CS_TEAM_T;
		
#if defined RECORD
		ServerCommand( "bot_join_team t" );
#endif
	}
	
	
	// Spawn block zones and clean up map (if DELETE_ENTS is defined).
	CreateTimer( 3.0, Timer_DoMapStuff, TIMER_FLAG_NO_MAPCHANGE );
}

stock bool CreateBlockZoneEntity( int zone )
{
	if ( !g_bZoneExists[zone] ) return false;
	
	
	int ent = CreateEntityByName( "trigger_multiple" );
	
	if ( ent < 1 )
	{
		PrintToServer( "%s Couldn't create block entity!", CONSOLE_PREFIX );
		return false;
	}
	
	DispatchKeyValue( ent, "wait", "0" );
	DispatchKeyValue( ent, "StartDisabled", "0" );
	DispatchKeyValue( ent, "spawnflags", "1" ); // Clients only!
	
	if ( !DispatchSpawn( ent ) )
	{
		PrintToServer( "%s Couldn't spawn block entity!", CONSOLE_PREFIX );
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
	
	
	if ( g_vecZoneMins[zone][0] < g_vecZoneMaxs[zone][0] )
	{
		vecLength[0] = g_vecZoneMaxs[zone][0] - g_vecZoneMins[zone][0];
		vecPos[0] = g_vecZoneMins[zone][0] + vecLength[0] / 2;
	}
	else
	{
		vecLength[0] = g_vecZoneMins[zone][0] - g_vecZoneMaxs[zone][0];
		vecPos[0] = g_vecZoneMaxs[zone][0] + vecLength[0] / 2;
	}
	
	
	if ( g_vecZoneMins[zone][1] < g_vecZoneMaxs[zone][1] )
	{
		vecLength[1] = g_vecZoneMaxs[zone][1] - g_vecZoneMins[zone][1];
		vecPos[1] = g_vecZoneMins[zone][1] + vecLength[1] / 2;
	}
	else
	{
		vecLength[1] = g_vecZoneMins[zone][1] - g_vecZoneMaxs[zone][1];
		vecPos[1] = g_vecZoneMaxs[zone][1] + vecLength[1] / 2;
	}
	
	
	if ( g_vecZoneMins[zone][2] < g_vecZoneMaxs[zone][2] )
	{
		vecLength[2] = g_vecZoneMaxs[zone][2] - g_vecZoneMins[zone][2];
		vecPos[2] = g_vecZoneMins[zone][2] + vecLength[2] / 2;
	}
	else
	{
		vecLength[2] = g_vecZoneMins[zone][2] - g_vecZoneMaxs[zone][2];
		vecPos[2] = g_vecZoneMaxs[zone][2] + vecLength[2] / 2;
	}
	
	TeleportEntity( ent, vecPos, NULL_VECTOR, NULL_VECTOR );
	
	
	// We then set the mins and maxs of the zone.
	float vecMins[3];
	float vecMaxs[3];
	
	vecLength[0] /= 2;
	vecLength[1] /= 2;
	vecLength[2] /= 2;
	
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