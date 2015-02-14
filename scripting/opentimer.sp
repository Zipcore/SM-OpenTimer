#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "1.3"


//	OPTIONS: Uncomment/comment things to change the plugin to your liking! Simply adding '//' (without quotation marks) in front of the line.
// ------------------------------------------------------------------------------------------------------------------------------------------
#define RECORD // Comment out for no recording.


//#define VOTING // Comment out for no voting. NOTE: This overrides commands rtv and nominate.
// Disabled by default because it overrides default commands. (rtv/nominate)


//#define CHAT // Comment out for no chat processing. Custom colors on player messages.
// Disabled by default because it is not really necessary for this plugin.

//#define DELETE_ENTS // Comment out to keep some entities. (func_doors, func_movelinears, etc.)
// This was originally used for surf maps. If you want old bhop maps with platforms don't uncomment.


#define ZONE_EDIT_ADMFLAG ADMFLAG_ROOT // Admin flag that allows zone editing.
// E.g ADMFLAG_KICK, ADMFLAG_BAN, ADMFLAG_CHANGELEVEL


#if defined RECORD

// 60 * minutes * tickrate
// E.g: 60 * 45 * 100 = 270 000
#define RECORDING_MAX_LENGTH 270000 // Maximum recording length (def. 45 minutes with 100tick)

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
#define COLOR_PURPLE "\x07E71470"
#define COLOR_TEAL "\x0766CCCC"
#define COLOR_GRAY "\x07434343"

#define COLOR_TEXT "\x07FFFFFF" // Default text color.

#define CHAT_PREFIX "\x072F2F2F[\x07D01265OpenTimer\x072F2F2F]\x07FFFFFF" // Remember to edit this one too if you want to change the text color!
// God damn compiler won't let me add 2 preprocessed strings together... :/
// It would make things much more easier...

#define CONSOLE_PREFIX "[OpenTimer]" // Used only for console/server.

// Don't change things under this unless you know what you are doing!!
// -------------------------------------------------------------------
#if defined CHAT
	#include <basecomm> // To check if client is gagged.
#endif

#if defined RECORD
	// ------------------------------------------------------------------------------------------------------------------------------------------------
	// DHOOKS is required to compile this plugin! However, it is not required while running this plugin or if you don't want to compile with recording!
	// ------------------------------------------------------------------------------------------------------------------------------------------------
	#undef REQUIRE_EXTENSIONS
	#include <dhooks>

#endif

// This has to be AFTER include files because not all natives are translated to 1.7!!!
#pragma semicolon 1
#pragma newdecls required

// --------------------------
// All shared variables here.
// --------------------------
///////////////
// RECORDING //
///////////////
#if defined RECORD
	/*
		Huge thanks to Peace-Maker. A lot was learned from his movement recorder plugin.
	*/
	enum FrameInfo {
		float:FRAME_ANGLES[2],
		float:FRAME_ABSVELOCITY[3],
		float:FRAME_POS[3],
		
		FRAME_FLAGS // Combined FRAME_BUTTONS and FRAME_FLAGS. See FRAMEFLAG_*
	};
	#define FRAME_SIZE 9
	
	#define FRAMEFLAG_TELEPORT	( 1 << 0 )
	#define FRAMEFLAG_CROUCH	( 1 << 1 )
	
	#define MIN_REC_SIZE 10
	
	enum HeaderInfo {
		HEADER_BINARYFORMAT = 0,
		
		HEADER_TICKCOUNT,
		float:HEADER_TIME, // Just in case our database loses the record information!!
		
		
		float:HEADER_INITPOS[3],
		float:HEADER_INITANGLES[2]
	};
	#define HEADER_SIZE 8
	
	#define MAGIC_NUMBER 0x4B1F // Old: 0x4B1D
	
	#define BINARY_FORMAT 0x01
	
	#define TICK_PRE_PLAYBLACK -1
#endif

///////////////////
// MISC. DEFINES //
///////////////////
#define HIDEHUD_HUD			( 1 << 0 )
#define HIDEHUD_VM			( 1 << 1 )
#define HIDEHUD_PLAYERS		( 1 << 2 )
#define HIDEHUD_TIMER		( 1 << 3 )
#define HIDEHUD_SIDEINFO	( 1 << 4 )
#define HIDEHUD_CHAT		( 1 << 5 )

#define HIDE_FLAGS 3946

#define STRAFE_INVALID 0
#define STRAFE_LEFT 1
#define STRAFE_RIGHT 2

#define TIME_INVALID 0.0

#define TIMER_UPDATE_INTERVAL 0.1
#define BOUNDS_UPDATE_INTERVAL 3.0

// How many samples we take to determine our sync.
#define SYNC_MAX_SAMPLES 100

// Default "grid size" for editing zones.
#define BUILDER_DEF_GRIDSIZE 8

#define STEAMID_MAXLENGTH 32

#define MAX_MAP_NAME_LENGTH 32

////////////
// VOTING //
////////////
#if defined VOTING
	
	enum MapInfo { String:MAP_NAME[MAX_MAP_NAME_LENGTH] };
	
#endif
////////////////////////
// BOUNDS/MODES ENUMS //
////////////////////////
enum {
	BOUNDS_START = 0,
	BOUNDS_END,
	BOUNDS_BONUS_1_START,
	BOUNDS_BONUS_1_END,
	BOUNDS_BONUS_2_START,
	BOUNDS_BONUS_2_END,
	BOUNDS_FREESTYLE_1,
	BOUNDS_FREESTYLE_2,
	BOUNDS_FREESTYLE_3,
	BOUNDS_BLOCK_1,
	BOUNDS_BLOCK_2,
	BOUNDS_BLOCK_3,
	
	MAX_BOUNDS
};

enum { STATE_START, STATE_END, STATE_RUNNING };

enum {
	RUN_MAIN = 0,
	RUN_BONUS_1,
	RUN_BONUS_2,
	
	MAX_RUNS
};

enum { INSIDE_START = 0, INSIDE_END, INSIDE_MAX };

enum { NAME_LONG = 0, NAME_SHORT };

enum {
	STYLE_NORMAL = 0,
	STYLE_SIDEWAYS,
	STYLE_W,
	STYLE_REAL_HSW,
	STYLE_HSW,
	
	MAX_STYLES // 5
};

// Zones
bool g_bIsLoaded[MAX_RUNS]; // Do we have start and end bounds for main/bonus at least?
bool g_bZoneExists[MAX_BOUNDS]; // Are we going to check if the player is inside these bounds in the first place?
float g_vecBoundsMin[MAX_BOUNDS][3];
float g_vecBoundsMax[MAX_BOUNDS][3];

char g_szZoneNames[MAX_BOUNDS][15] = {
	"Start", "End",
	"Bonus #1 Start", "Bonus #1 End",
	"Bonus #2 Start", "Bonus #2 End",
	"Freestyle #1", "Freestyle #2", "Freestyle #3",
	"Block #1", "Block #2", "Block #3"
};

// Building
int g_iBuilderIndex;
int g_iBuilderZone = -1;
int g_iBuilderGridSize = BUILDER_DEF_GRIDSIZE;

// Running
int g_iClientState[MAXPLAYERS_BHOP];
int g_iClientStyle[MAXPLAYERS_BHOP];
int g_iClientRun[MAXPLAYERS_BHOP]; // Which run client is doing (main/bonus)?
float g_flClientStartTime[MAXPLAYERS_BHOP];
float g_flClientFinishTime[MAXPLAYERS_BHOP];
float g_flClientBestTime[MAXPLAYERS_BHOP][MAX_RUNS][MAX_STYLES];
//bool g_bIsClientSaving[MAXPLAYERS_BHOP];

// Player stats
int g_iClientJumpCount[MAXPLAYERS_BHOP];
int g_iClientStrafeCount[MAXPLAYERS_BHOP];
int g_iClientGoodSync[MAXPLAYERS_BHOP][SYNC_MAX_SAMPLES];
int g_iClientLastStrafe[MAXPLAYERS_BHOP]; // Which direction did the client strafe to last time?

// Practice
// TODO: Add multiple save points.
bool g_bIsClientPractising[MAXPLAYERS_BHOP];
float g_vecClientSavePos[MAXPLAYERS_BHOP][3];
float g_vecClientSaveAng[MAXPLAYERS_BHOP][3];
float g_vecClientSaveVel[MAXPLAYERS_BHOP][3];
float g_flClientSaveTime[MAXPLAYERS_BHOP];

// Recording
#if defined RECORD
	Handle g_hClientRecording[MAXPLAYERS_BHOP];
	bool g_bIsClientRecording[MAXPLAYERS_BHOP];
	bool g_bIsClientMimicing[MAXPLAYERS_BHOP];
	int g_iClientSnapshot[MAXPLAYERS_BHOP];
	int g_iClientTick[MAXPLAYERS_BHOP];

	float g_vecInitPos[MAXPLAYERS_BHOP][3];
	float g_angInitAngles[MAXPLAYERS_BHOP][3];

	// Mimic stuff
	float g_vecInitMimicPos[MAX_RUNS][MAX_STYLES][3];
	float g_angInitMimicAngles[MAX_RUNS][MAX_STYLES][3];
	int g_iMimic[MAX_RUNS][MAX_STYLES];
	int g_iNumMimic;
	int g_iMimicTickMax[MAX_RUNS][MAX_STYLES];
	Handle g_hMimicRecording[MAX_RUNS][MAX_STYLES];
	char g_szMimicName[MAX_RUNS][MAX_STYLES][MAX_NAME_LENGTH];

	Handle g_hHookTele; // DHOOKS
	bool g_b_DHOOKS_Exists;
#endif

// Client settings (bonus stuff)
int g_iClientFOV[MAXPLAYERS_BHOP] = { 90, ... };
int g_iClientHideFlags[MAXPLAYERS_BHOP];

// Other
char g_szCurrentMap[MAX_MAP_NAME_LENGTH];
float g_vecSpawnPos[MAX_RUNS][3];
float g_angSpawnAngles[MAX_RUNS][3];
float g_flMapBestTime[MAX_RUNS][MAX_STYLES];
int g_iBeam;
int g_iPreferedTeam = CS_TEAM_T;

// Voting stuff
#if defined VOTING
	ArrayList g_hMapList;
	char g_szNextMap[MAX_MAP_NAME_LENGTH];

	int g_iClientVote[MAXPLAYERS_BHOP] = { -1, ... };
#endif

// Constants
char g_szStyleName[][][14] = {
	{ "Normal", "Sideways", "W-Only", "Real HSW", "Half-Sideways" },
	{ "N", "SW", "W", "RHSW", "HSW" }
};
char g_szRunName[][][8] = {
	{ "Main", "Bonus 1", "Bonus 2" },
	{ "M", "B1", "B2" }
};
char g_szWinningSounds[][25] = {
	"buttons/button16.wav", "bot/i_am_on_fire.wav",
	"bot/its_a_party.wav", "bot/made_him_cry.wav",
	"bot/this_is_my_house.wav", "bot/yea_baby.wav",
	"bot/yesss.wav", "bot/yesss2.wav"
};

float g_vecNull[3] = { 0.0, 0.0, 0.0 };

// ConVars
ConVar g_ConVar_AirAccelerate; // To tell the client what aa we have.
static ConVar g_ConVar_PreSpeed;
ConVar g_ConVar_AutoHop;
ConVar g_ConVar_EZHop;
ConVar g_ConVar_LeftRight;

// Settings (Convars)
// WARNING: Must be initialized as the default value or it will not register when executing it!!
bool g_bPreSpeed = false;
bool g_bForbiddenCommands = true;
bool g_bAutoHop = true;
bool g_bEZHop = true;
//bool g_bClientAutoHop[MAXPLAYERS_BHOP] = { true, ... };

// ---------------------------------------------
// End of shared variables.
// ---------------------------------------------

#include "opentimer/stocks.sp"
#include "opentimer/database.sp"
#include "opentimer/events.sp"
#include "opentimer/commands.sp"
#include "opentimer/timers.sp"
#include "opentimer/menus.sp"

public Plugin OpenTimerInfo = {
	author = "Mehis",
	name = "OpenTimer",
	description = "For servers that want to go the fastest.",
	url = "http://steamcommunity.com/profiles/76561198021256769",
	version = PLUGIN_VERSION
};

public void OnPluginStart()
{
	// HOOKS
	HookEvent( "player_spawn", Event_ClientSpawn );
	HookEvent( "player_jump", Event_ClientJump );
	HookEvent( "player_hurt", Event_ClientHurt );
	HookEvent( "player_death", Event_ClientDeath );
	//HookEvent( "player_team", Event_ClientChangeTeam );
	//HookEvent( "player_changename", Event_ClientName, EventHookMode_Pre );
	//HookEvent( "teamplay_round_start", Event_RoundStart, EventHookMode_PostNoCopy );
	
	// LISTENERS
#if defined CHAT
	AddCommandListener( Listener_Say, "say" );
	AddCommandListener( Listener_Say, "say_team" );
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
	//RegConsoleCmd( "sm_s", Command_Practise_SavePoint );
	
	RegConsoleCmd( "sm_cp", Command_Practise_GotoPoint );
	RegConsoleCmd( "sm_checkpoint", Command_Practise_GotoPoint );
	RegConsoleCmd( "sm_gotocp", Command_Practise_GotoPoint );
	
	// HELP
	RegConsoleCmd( "sm_commands", Command_Help );
	//RegConsoleCmd( "sm_help", Command_Help );
	
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
	
	g_ConVar_AutoHop = CreateConVar( "sm_autobhop", "1", "Is autobunnyhopping allowed? (hold space)", FCVAR_PLUGIN | FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	
	g_ConVar_EZHop = CreateConVar( "sm_ezhop", "1", "Is ezhop enabled?", FCVAR_PLUGIN | FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	
	g_ConVar_PreSpeed = CreateConVar( "sm_prespeed", "0", "Is prespeeding allowed in the starting area?", FCVAR_PLUGIN | FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	
	g_ConVar_LeftRight = CreateConVar( "sm_forbidden_commands", "1", "Is +left and +right allowed?", FCVAR_PLUGIN | FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	
	HookConVarChange( g_ConVar_AutoHop, Event_ConVar_AutoHop );
	HookConVarChange( g_ConVar_EZHop, Event_ConVar_EZHop );
	HookConVarChange( g_ConVar_PreSpeed, Event_ConVar_PreSpeed );
	HookConVarChange( g_ConVar_LeftRight, Event_ConVar_LeftRight );
	
	InitializeDatabase();
	
#if defined RECORD
	//HookEvent( "base_player_teleported", Event_ClientTeleport ); // Doesn't work.
	//HookEntityOutput( "trigger_teleport", "OnEndTouch", Event_Teleport ); // Unreliable. Would fire even when not teleported.

	if( LibraryExists( "dhooks" ) )
	{
		g_b_DHOOKS_Exists = true;
		
		Handle hGameConfig = LoadGameConfigFile( "sdktools.games" );
		if ( hGameConfig == null ) return;
		
		int iOffset = GameConfGetOffset( hGameConfig, "Teleport" );
		
		delete hGameConfig;
		
		if ( iOffset == -1 ) return;
		
		g_hHookTele = DHookCreate( iOffset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, Event_OnTeleport );
		if ( g_hHookTele == null ) return;
		
		DHookAddParam( g_hHookTele, HookParamType_VectorPtr ); // Can't take any of these away or it will crash.
		DHookAddParam( g_hHookTele, HookParamType_ObjectPtr );
		DHookAddParam( g_hHookTele, HookParamType_VectorPtr );
	}
	else
	{
		g_b_DHOOKS_Exists = false;
		
		if ( g_hHookTele != null )
		{
			delete g_hHookTele;
			g_hHookTele = null;
		}
		
		PrintToServer( "%s DHOOKS extension not found!", CONSOLE_PREFIX );
	}
#endif
	
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

public void OnMapStart()
{
	ServerCommand( "bot_quota 0" ); // No bots until we have records.
	
	// Just incase there are maps that use uppercase letters.
	GetCurrentMap( g_szCurrentMap, sizeof( g_szCurrentMap ) );
	
	int len = strlen( g_szCurrentMap );
	
	for ( int i; i < len; i++ )
		if ( IsCharUpper( g_szCurrentMap[i] ) )
		{
			CharToLower( g_szCurrentMap[i] );
		}
	
	// Rest is just resetting/precaching stuff.
	g_iBuilderIndex = 0;
	g_iBuilderZone = -1;
	g_iBuilderGridSize = BUILDER_DEF_GRIDSIZE;

#if defined RECORD
	g_iNumMimic = 0;
	
	for ( int run; run < MAX_RUNS; run++ )
	{
		ArrayFill( g_flMapBestTime[run], TIME_INVALID, MAX_STYLES );
		
		for ( int style; style < MAX_STYLES; style++ )
		{
			g_iMimic[run][style] = 0;
			g_iMimicTickMax[run][style] = 0;
			
			if ( g_hMimicRecording[run][style] != null )
			{
				delete g_hMimicRecording[run][style];
				g_hMimicRecording[run][style] = null;
				//ClearArray( g_hMimicRecording[run][style] );
			}
		}
	}
#endif
	
	InitializeMapBounds();
	
#if defined VOTING
	FindMaps();
#endif
	
	g_iBeam = PrecacheModel( "materials/sprites/plasma.vmt" );
	
	
	for ( int i; i < sizeof( g_szWinningSounds ); i++ )
	{
		PrecacheSound( g_szWinningSounds[i] );
	}
	
	CreateTimer( BOUNDS_UPDATE_INTERVAL, Timer_DrawZoneBeams, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
	
	// We want to restart the map if it has been going on for too long without any players.
	// This prevents performance issues.
	CreateTimer( 3600.0, Timer_RestartMap, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
}

// Release client's vote or bot's record.
public void OnClientDisconnect( int client )
{
#if defined RECORD
	if ( IsFakeClient( client ) && g_iMimic[ g_iClientRun[client] ][ g_iClientStyle[client] ] == client )
	{
		g_iMimic[ g_iClientRun[client] ][ g_iClientStyle[client] ] = 0;
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
	// -----------------
	// Reset everything!
	// -----------------
	
	// States
	g_iClientState[client] = STATE_RUNNING;
	g_iClientStyle[client] = STYLE_NORMAL;
	g_iClientRun[client] = RUN_MAIN;
	
	// Times
	g_flClientStartTime[client] = TIME_INVALID;
	g_flClientFinishTime[client] = TIME_INVALID;
	
	for ( int i; i < MAX_RUNS; i++ )
		ArrayFill( g_flClientBestTime[client][i], TIME_INVALID, MAX_STYLES );
	
	// Other data
	g_iClientJumpCount[client] = 0;
	g_iClientStrafeCount[client] = 0;	
	
	// Practicing
	g_bIsClientPractising[client] = false;
	ArrayFill( g_vecClientSavePos[client], TIME_INVALID, 3 );
	ArrayFill( g_vecClientSaveAng[client], TIME_INVALID, 3 );
	ArrayFill( g_vecClientSaveVel[client], TIME_INVALID, 3 );
	
	g_flClientSaveTime[client] = TIME_INVALID;
	
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
	
	// Misc. settings
	g_iClientFOV[client] = 90;
	g_iClientHideFlags[client] = 0;
	
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
				// We already have a mimic in this slot? Continue.
				if ( g_iMimic[run][style] != 0 || g_iMimicTickMax[run][style] < 1 ) continue;
				
				char szName[MAX_NAME_LENGTH];
				Format( szName, sizeof( szName ), "REC* %s [%s|%s]", g_szMimicName[run][style], g_szRunName[NAME_SHORT][run], g_szStyleName[NAME_SHORT][style] );
				SetClientInfo( client, "name", szName );
				
				char szFormTime[12];
				FormatSeconds( g_flMapBestTime[run][style], szFormTime, sizeof( szFormTime ), false );
				CS_SetClientClanTag( client, szFormTime );
				
				// Get the bot ready for playback.
				g_iClientTick[client] = -1;
				
				TeleportEntity( client, g_vecInitMimicPos[run][style], g_angInitMimicAngles[run][style], g_vecNull );
				CreateTimer( 2.0, Timer_Rec_Start, client );
				
				g_iClientStyle[client] = style;
				g_iClientRun[client] = run;
				
				g_iMimic[run][style] = client;
				
				return;
			}
		
		return;
	}
#endif
	
	RetrieveClientInfo( client );
	
	
	// Welcome message
	CreateTimer( 5.0, Timer_Connected, GetClientUserId( client ) );
	
	// Timer's timer function :^)
	CreateTimer( TIMER_UPDATE_INTERVAL, Timer_ShowClientInfo, client, TIMER_REPEAT );
	
	// Hooks
	if ( g_iClientHideFlags[client] & HIDEHUD_PLAYERS )
		SDKHook( client, SDKHook_SetTransmit, Event_ClientTransmit );
	
	SDKHook( client, SDKHook_WeaponDropPost, Event_WeaponDrop ); // No more weapon dropping.
	SDKHook( client, SDKHook_WeaponSwitchPost, Event_WeaponSwitchPost );
	SDKHook( client, SDKHook_PreThinkPost, Event_ClientThink );
	
#if defined RECORD
	if ( g_b_DHOOKS_Exists && g_hHookTele != null ) // DHOOKS hooked only on real players.
		DHookEntity( g_hHookTele, false, client );
#endif
}

// People don't necessarily want this.
/*public void OnClientPostAdminCheck( int client )
{
	// Join sound
	if ( !IsSoundPrecached( g_szWinningSounds[0] ) )
		PrecacheSound( g_szWinningSounds[0] );
	
	EmitSoundToClient( client, g_szWinningSounds[0] );
}*/

public void Event_WeaponSwitchPost( int client )
{
	SetEntProp( client, Prop_Data, "m_iFOV", g_iClientFOV[client] );
	SetEntProp( client, Prop_Data, "m_iDefaultFOV", g_iClientFOV[client] );
}

public void Event_WeaponDrop( int client, int weapon ) // REMOVE THOSE WEAPONS GOD DAMN IT!
{
	// This doesn't delete all the weapons.
	// In fact, this doesn't get called when player suicides.
	if ( IsValidEntity( weapon ) )
		AcceptEntityInput( weapon, "Kill" );
}
// ---------------------------------------------------------
// Main component of the zones. Does everything, basically.
// ---------------------------------------------------------
public void Event_ClientThink( int client )
{
	if ( !g_bIsLoaded[ g_iClientRun[client] ] || !IsPlayerAlive( client ) ) return;
	
	static bool bInsideBounds[MAXPLAYERS_BHOP][INSIDE_MAX];
	
	// First we find out if our client is in his own zone areas.
	switch ( g_iClientRun[client] )
	{
		case RUN_BONUS_1 :
		{
			bInsideBounds[client][INSIDE_START] = IsInsideBounds( client, BOUNDS_BONUS_1_START );
			bInsideBounds[client][INSIDE_END] = IsInsideBounds( client, BOUNDS_BONUS_1_END );
		}
		case RUN_BONUS_2 :
		{
			bInsideBounds[client][INSIDE_START] = IsInsideBounds( client, BOUNDS_BONUS_2_START );
			bInsideBounds[client][INSIDE_END] = IsInsideBounds( client, BOUNDS_BONUS_2_END );
		}
		default :
		{
			bInsideBounds[client][INSIDE_START] = IsInsideBounds( client, BOUNDS_START );
			bInsideBounds[client][INSIDE_END] = IsInsideBounds( client, BOUNDS_END );
		}
	}
	
	// We then compare that:
	if ( g_iClientState[client] == STATE_START && !bInsideBounds[client][INSIDE_START] )
	{
		// We were in start but we're not anymore.
		// Start to run!
		
		// Don't allow players to cheat by noclipping around...
		if ( GetEntityMoveType( client ) == MOVETYPE_NOCLIP && !g_bIsClientPractising[client] )
		{
			PrintColorChat( client, client, "%s You are now in practice mode! Type \x03!prac%s again to toggle.", CHAT_PREFIX, COLOR_TEXT );
			g_bIsClientPractising[client] = true;
		}
		// No prespeeding or multiple jumps in the starting zone!
		else if ( !g_bPreSpeed && ( GetClientVelocity( client ) > 300.0 || g_iClientJumpCount[client] > 1 ) )
		{
			PrintColorChat( client, client, "%s No prespeeding allowed! (\x03300vel/2 jump cap%s)", CHAT_PREFIX, COLOR_TEXT );
			
			TeleportEntity( client, NULL_VECTOR, NULL_VECTOR, g_vecNull );
			
			// Not setting this would cause people to float, lol
			// Basically, the function keeps resetting their speed but not their jump count.
			// It would then keep on looping forever until players got inside the starting zone again.
			g_iClientJumpCount[client] = 0;
			
			return;
		}
		
		g_flClientStartTime[client] = GetEngineTime();
		
		ArrayFill( g_iClientGoodSync[client], 1, 100 );
		
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
	else if ( g_iClientState[client] == STATE_RUNNING && bInsideBounds[client][INSIDE_END] )
	{
		// Inside the end bounds from running! :D
		
		// We haven't even started to run or we already came in to the start!!
		if ( g_flClientStartTime[client] == TIME_INVALID ) return;
		
		g_iClientState[client] = STATE_END;
		
		// Save the time if we're not practising.
		if ( !g_bIsClientPractising[client] )
		{
			float flNewTime = GetEngineTime() - g_flClientStartTime[client];
			
			g_flClientFinishTime[client] = flNewTime;
			
			if ( !SaveClientRecord( client, flNewTime ) )
			{
				PrintColorChat( client, client, "%s Couldn't save your record to the database!", CHAT_PREFIX );
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
	else if ( bInsideBounds[client][INSIDE_START] )
	{
		// We have been in the starting zone for a while...
		// Reset everything if we're inside the starting zone.
		
		
		// Did we come in just now or did we not jump when we were on the ground?
		if ( g_iClientState[client] != STATE_START || ( GetEntityFlags( client ) & FL_ONGROUND && !( GetClientButtons( client ) & IN_JUMP ) ) )
		{
			g_iClientJumpCount[client] = 0;
		}
		
		g_iClientState[client] = STATE_START;
		g_flClientSaveTime[client] = TIME_INVALID;
		
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
	else if ( !g_bIsClientPractising[client] )
	{
		// We're running!
		
		// Have we been running for too long?
#if defined RECORD
		if ( g_iClientTick[client] > RECORDING_MAX_LENGTH && g_bIsClientRecording[client] )
		{
			g_iClientTick[client] = 0;
			g_bIsClientRecording[client] = false;
			
			if ( g_hClientRecording[client] != null )
			{
				delete g_hClientRecording[client];
				g_hClientRecording[client] = null;
			}
			
			PrintColorChat( client, client, "%s Your time was too long to be recorded!", CHAT_PREFIX );
		}
#endif
		// Let's check for potential block zones and stuff.
		for ( int i = BOUNDS_BLOCK_1; i <= BOUNDS_BLOCK_3; i++ )
		{
			if ( !g_bZoneExists[i] ) continue;
			
			if ( IsInsideBounds( client, i ) )
			{
				PrintColorChat( client, client, "%s You are not allowed to go there!", CHAT_PREFIX );
				TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_angSpawnAngles[ g_iClientRun[client] ], g_vecNull );
				
				return;
			}
		}
	}
}