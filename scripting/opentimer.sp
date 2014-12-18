#pragma semicolon 1

#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>

#define RECORD // Comment out for no recording.
#define VOTING // Comment out for no voting. NOTE: This overrides commands rtv, nominate, etc.
#define CHAT // Comment out for no chat processing.
//#define DELETE_ENTS // Comment out to keep some entities. (func_doors, func_movelinears, etc.)
// This was originally used for surf maps. If you want old bhop maps with platforms don't uncomment.

#if defined CHAT
#include <basecomm> // To check if client is gagged.
#endif

#if defined RECORD
#undef REQUIRE_EXTENSIONS
#include <dhooks>
#endif

#define MAXPLAYERS_BHOP 24 + 1 // Change according to your player count. ( slots + 1 )
#define ZONE_EDIT_ADMFLAG ADMFLAG_ROOT // Admin flag that allows zone editing.

// HEX color codes
//
// You have to put \x07{HEX COLOR}
// E.g \x07FFFFFF for white
//
// You can then put your own text after it:
// \x07FFFFFFThis text is white!
#define CHAT_PREFIX "\x072F2F2F[\x07D01265OpenTimer\x072F2F2F]\x07FFFFFF" // Used only for chat
#define CONSOLE_PREFIX "[OpenTimer]" // Used only for console/server.

#define PLUGIN_NAME "OpenTimer" // Name of the plugin. Please don't change this.
#define PLUGIN_VERSION "1.2"

#define COLOR_PURPLE "\x07E71470"
#define COLOR_TEAL "\x0766CCCC"
#define COLOR_GRAY "\x07434343"
#define COLOR_TEXT "\x07FFFFFF" // Default text color. Must be changed in CHAT_PREFIX too!!

////////////////////////////////
// All shared variables here. //
////////////////////////////////
///////////////
// RECORDING //
///////////////
#if defined RECORD
/*
	Huge thanks to Peace-Maker. A lot was learned from his movement recorder plugin.
*/
enum FrameInfo {
	FRAME_BUTTONS = 0,
	//FRAME_IMPULSE,
	//FRAME_SEED,
	
	Float:FRAME_ANGLES[2],
	Float:FRAME_VELOCITY[3],
	Float:FRAME_ABSVELOCITY[3],
	
	Float:FRAME_POS[3],
	FRAME_FLAGS
};
#define FRAME_SIZE 13

#define FRAMEFLAG_SNAPSHOT	( 1 << 0 ) // Doesn't break backwards compatibility :D
#define FRAMEFLAG_TELEPORT	( 1 << 1 )

#define SNAPSHOT_INTERVAL 100
#define MIN_REC_SIZE 10

enum HeaderInfo {
	HEADER_BINARYFORMAT = 0,
	HEADER_TICKCOUNT,
	
	Float:HEADER_INITPOS[3],
	Float:HEADER_INITANGLES[2]
};
#define HEADER_SIZE 7

#define MAGIC_NUMBER 0x4B1D
#define BINARY_FORMAT 0x01
#endif

////////////
// VOTING //
////////////
#if defined VOTING
#define MAX_MAP_NAME_LENGTH 32
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

enum {
	INSIDE_START = 0,
	INSIDE_END,
	
	INSIDE_MAX
}

enum { NAME_LONG = 0, NAME_SHORT };

enum {
	STYLE_NORMAL = 0,
	STYLE_SIDEWAYS,
	STYLE_W,
	STYLE_REAL_HSW,
	STYLE_HSW,
	
	MAX_STYLES // 5
};

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

#define TIMER_UPDATE_INTERVAL 0.1
#define BOUNDS_UPDATE_INTERVAL 3.0

#define SYNC_MAX_SAMPLES 100

#define BUILDER_DEF_GRIDSIZE 8

// Zones
new bool:bIsLoaded[MAX_RUNS]; // Do we have start and end bounds for main/bonus at least?
new bool:bZoneExists[MAX_BOUNDS]; // Are we going to check if the player is inside these bounds in the first place?
new Float:vecBoundsMin[MAX_BOUNDS][3];
new Float:vecBoundsMax[MAX_BOUNDS][3];

new const String:ZoneNames[MAX_BOUNDS][] = {
	"Start",
	"End",
	"Bonus #1 Start",
	"Bonus #1 End",
	"Bonus #2 Start",
	"Bonus #2 End",
	"Freestyle #1",
	"Freestyle #2",
	"Freestyle #3",
	"Block #1",
	"Block #2",
	"Block #3"
};

// Building
new iBuilderIndex;
new iBuilderZone = -1;
new iBuilderGridSize = BUILDER_DEF_GRIDSIZE;

// Settings (Convars)
new bool:bPreSpeed;
new bool:bForbiddenCommands;
//new bool:bClientAutoHop[MAXPLAYERS_BHOP] = { true, ... };
new bool:bAutoHop = true;

// Running
new iClientState[MAXPLAYERS_BHOP];
new iClientStyle[MAXPLAYERS_BHOP];
new iClientRun[MAXPLAYERS_BHOP]; // Which run client is doing (main/bonus)?
new Float:flClientStartTime[MAXPLAYERS_BHOP];
new Float:flClientFinishTime[MAXPLAYERS_BHOP];
new Float:flClientBestTime[MAXPLAYERS_BHOP][MAX_RUNS][MAX_STYLES];
//new bool:bIsClientSaving[MAXPLAYERS_BHOP];

// Player stats
new iClientJumpCount[MAXPLAYERS_BHOP];
new iClientStrafeCount[MAXPLAYERS_BHOP];
new iClientGoodSync[MAXPLAYERS_BHOP][SYNC_MAX_SAMPLES];
new iClientLastStrafe[MAXPLAYERS_BHOP]; // Which direction did the client strafe to last time?

// Practice
// To-Do: Add multiple save points.
new bool:bIsClientPractising[MAXPLAYERS_BHOP];
new Float:vecClientSavePos[MAXPLAYERS_BHOP][3];
new Float:vecClientSaveAng[MAXPLAYERS_BHOP][3];
new Float:vecClientSaveVel[MAXPLAYERS_BHOP][3];
new Float:flClientSaveTime[MAXPLAYERS_BHOP];

// Recording
#if defined RECORD
new Handle:hClientRecording[MAXPLAYERS_BHOP];
new bool:bIsClientRecording[MAXPLAYERS_BHOP];
new bool:bIsClientMimicing[MAXPLAYERS_BHOP];
new iClientSnapshot[MAXPLAYERS_BHOP];
new iClientTick[MAXPLAYERS_BHOP];

new Float:vecInitPos[MAXPLAYERS_BHOP][3];
new Float:angInitAngles[MAXPLAYERS_BHOP][3];

// Mimic stuff
new Float:vecInitMimicPos[MAX_RUNS][MAX_STYLES][3];
new Float:angInitMimicAngles[MAX_RUNS][MAX_STYLES][3];
new iMimic[MAX_RUNS][MAX_STYLES];
new iNumMimic;
new iMimicTickMax[MAX_RUNS][MAX_STYLES];
new Handle:hMimicRecording[MAX_RUNS][MAX_STYLES];
new String:MimicName[MAX_RUNS][MAX_STYLES][MAX_NAME_LENGTH];

new Handle:hHookTele; // DHOOKS
new bool:b_DHOOKS_Exists;
#endif

// Client settings (bonus stuff)
new iClientFOV[MAXPLAYERS_BHOP] = { 90, ... };
new iClientHideFlags[MAXPLAYERS_BHOP];

// Other
new String:CurrentMap[32];
new Float:vecSpawnPos[MAX_RUNS][3], Float:angSpawnAngles[MAX_RUNS][3];
new Float:flMapBestTime[MAX_RUNS][MAX_STYLES];
new iBeam;
new iPreferedTeam = CS_TEAM_T;

#if defined VOTING
new Handle:hMapList;
new String:NextMap[MAX_MAP_NAME_LENGTH];
new iClientVote[MAXPLAYERS_BHOP] = { -1, ... };
#endif

new const String:StyleName[][][] = { { "Normal", "Sideways", "W-Only", "Real HSW", "Half-Sideways" } , { "N", "SW", "W", "RHSW", "HSW" } };
new const String:RunName[][][8] = { { "Main", "Bonus 1", "Bonus 2" }, { "M", "B1", "B2" } };
new const Float:vecNull[] = { 0.0, 0.0, 0.0 };
new const String:WinningSounds[][] = {
	"buttons/button16.wav",
	"bot/i_am_on_fire.wav",
	"bot/its_a_party.wav",
	"bot/made_him_cry.wav",
	"bot/this_is_my_house.wav",
	"bot/yea_baby.wav",
	"bot/yesss.wav",
	"bot/yesss2.wav"
};

// ConVars
new Handle:ConVar_AirAccelerate; // To tell the client what aa we have.
static Handle:ConVar_PreSpeed;
new Handle:ConVar_AutoHop;
new Handle:ConVar_LeftRight;

//////////////////////////////
// End of shared variables. //
//////////////////////////////

#include "opentimer/stocks.sp"
#include "opentimer/database.sp"
#include "opentimer/events.sp"
#include "opentimer/commands.sp"
#include "opentimer/timers.sp"
#include "opentimer/menus.sp"

public Plugin:Info = {
	author = "Mehis",
	name = PLUGIN_NAME,
	description = "For servers that want to go the fastest.",
	url = "http://steamcommunity.com/id/mehis/",
	version = PLUGIN_VERSION
};

public OnPluginStart()
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
	RegConsoleCmd( "sm_gotocp", Command_Practise_GotoPoint );
	
	// HELP
	RegConsoleCmd( "sm_commands", Command_Help );
	RegConsoleCmd( "sm_help", Command_Help );
	
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
	ConVar_AirAccelerate = FindConVar( "sv_airaccelerate" );
	
	ConVar_AutoHop = CreateConVar( "sm_autohopping", "1", "Is autobunnyhopping allowed? (hold space)", FCVAR_PLUGIN | FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	
	ConVar_PreSpeed = CreateConVar( "sm_prespeed", "0", "Is prespeeding allowed in the starting area?", FCVAR_PLUGIN | FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	
	ConVar_LeftRight = CreateConVar( "sm_forbidden_commands", "1", "Is +left and +right allowed?", FCVAR_PLUGIN | FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	
	HookConVarChange( ConVar_AutoHop, Event_ConVar_AutoHop );
	HookConVarChange( ConVar_PreSpeed, Event_ConVar_PreSpeed );
	HookConVarChange( ConVar_LeftRight, Event_ConVar_LeftRight );
	
	InitializeDatabase();
	
	
#if defined RECORD
	//HookEvent( "base_player_teleported", Event_ClientTeleport ); // Doesn't work.
	//HookEntityOutput( "trigger_teleport", "OnEndTouch", Event_Teleport ); // Unreliable. Would fire even when not teleported.

	if( LibraryExists( "dhooks" ) )
	{
		b_DHOOKS_Exists = true;
		
		new Handle:hGameConfig = LoadGameConfigFile( "sdktools.games" );
		if ( hGameConfig == INVALID_HANDLE ) return;
		
		new iOffset = GameConfGetOffset( hGameConfig, "Teleport" );
		if ( iOffset == -1 ) return;
		
		hHookTele = DHookCreate( iOffset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, Event_OnTeleport );
		if ( hHookTele == INVALID_HANDLE ) return;
		
		DHookAddParam( hHookTele, HookParamType_VectorPtr ); // Can't take any of these away or it will crash.
		DHookAddParam( hHookTele, HookParamType_ObjectPtr );
		DHookAddParam( hHookTele, HookParamType_VectorPtr );
	}
	else
	{
		b_DHOOKS_Exists = false;
		PrintToServer( "%s DHOOKS extension not found!", CONSOLE_PREFIX );
	}
#endif
}

public Event_ConVar_AutoHop( Handle:hConVar, const String:oldValue[], const String:newValue[] )
	bAutoHop = GetConVarBool( hConVar );
	
public Event_ConVar_PreSpeed( Handle:hConVar, const String:oldValue[], const String:newValue[] )
	bPreSpeed = GetConVarBool( hConVar );

public Event_ConVar_LeftRight( Handle:hConVar, const String:oldValue[], const String:newValue[] )
	bForbiddenCommands = GetConVarBool( hConVar );

public OnMapStart()
{
	ServerCommand( "bot_quota 0" ); // No bots until we have records.
	
	// Just incase there are maps that use uppercase letters.
	GetCurrentMap( CurrentMap, sizeof( CurrentMap ) );
	
	new len = strlen( CurrentMap );
	for ( new i; i < len; i++ )
		if ( IsCharUpper( CurrentMap[i] ) )
			CharToLower( CurrentMap[i] );
	
	// Rest is just resetting/precaching stuff.
	iBuilderIndex = 0;
	iBuilderZone = -1;
	iBuilderGridSize = BUILDER_DEF_GRIDSIZE;

#if defined RECORD
	iNumMimic = 0;
	
	for ( new run; run < MAX_RUNS; run++ )
	{
		ArrayFill( flMapBestTime[run], 0.0, MAX_STYLES );
		
		for ( new i; i < MAX_STYLES; i++ )
		{
			iMimic[run][i] = 0;
			iMimicTickMax[run][i] = 0;
			
			if ( hMimicRecording[run][i] != INVALID_HANDLE )
				ClearArray( hMimicRecording[run][i] );
		}
	}
#endif
	
	InitializeMapBounds();
	
#if defined VOTING
	FindMaps();
#endif
	
	iBeam = PrecacheModel( "materials/sprites/plasma.vmt" );
	
	PrecacheSound( WinningSounds[0] );
	PrecacheSound( WinningSounds[1] );
	PrecacheSound( WinningSounds[2] );
	PrecacheSound( WinningSounds[3] );
	PrecacheSound( WinningSounds[4] );
	PrecacheSound( WinningSounds[5] );
	PrecacheSound( WinningSounds[6] );
	PrecacheSound( WinningSounds[7] );
	
	CreateTimer( BOUNDS_UPDATE_INTERVAL, Timer_DrawZoneBeams, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
	
	// We want to restart the map if it has been going on for too long without any players.
	// This prevents performance issues.
	CreateTimer( 3600.0, Timer_RestartMap, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
}

// Release client's vote or bot's record.
public OnClientDisconnect( client )
{
#if defined RECORD
	if ( IsFakeClient( client ) && iMimic[ iClientRun[client] ][ iClientStyle[client] ] == client )
	{
		iMimic[ iClientRun[client] ][ iClientStyle[client] ] = 0;
		return;
	}
#endif

#if defined VOTING
	iClientVote[client] = -1;
	CalcVotes();
#endif
}

public OnClientConnected( client )
{
	// Reset per client is done while connecting.
	iClientState[client] = STATE_RUNNING;
	iClientStyle[client] = STYLE_NORMAL;
	iClientRun[client] = RUN_MAIN;
	flClientStartTime[client] = 0.0;
	
	//bClientAutoHop[client] = true;
	
	flClientFinishTime[client] = 0.0;
	
	for ( new i; i < MAX_RUNS; i++ )
		ArrayFill( flClientBestTime[client][i], 0.0, MAX_STYLES );
	
	iClientJumpCount[client] = 0;
	iClientStrafeCount[client] = 0;	
	
	bIsClientPractising[client] = false;
	ArrayFill( vecClientSavePos[client], 0.0, 3 );
	ArrayFill( vecClientSaveAng[client], 0.0, 3 );
	ArrayFill( vecClientSaveVel[client], 0.0, 3 );
	
	flClientSaveTime[client] = 0.0;
	
#if defined RECORD
	bIsClientRecording[client] = false;
	bIsClientMimicing[client] = false;
	iClientSnapshot[client] = 0;
	iClientTick[client] = 0;
#endif
	
	iClientFOV[client] = 90;
	iClientHideFlags[client] = 0;
}

public OnClientPostAdminCheck( client )
{
// Assign records to bots, fetch client info from DB and hook stuff.
#if defined RECORD
	if ( IsFakeClient( client ) )
	{
		iClientState[client] = STATE_START;
		
		for ( new run; run < MAX_RUNS; run++ )
			for ( new i; i < MAX_STYLES; i++ )
			{
				if ( iMimic[run][i] != 0 || iMimicTickMax[run][i] < 1 ) continue;
				
				decl String:Name[MAX_NAME_LENGTH];
				Format( Name, sizeof( Name ), "REC* %s [%s|%s]", MimicName[run][i], RunName[NAME_SHORT][run], StyleName[NAME_SHORT][i] );
				SetClientInfo( client, "name", Name );
				
				decl String:FormattedTime[13];
				FormatSeconds( flMapBestTime[run][i], FormattedTime, false );
				CS_SetClientClanTag( client, FormattedTime );
				
				iClientTick[client] = -1;
				
				TeleportEntity( client, vecInitMimicPos[run][i], angInitMimicAngles[run][i], vecNull );
				CreateTimer( 2.0, Timer_Rec_Start, client );
				
				iClientStyle[client] = i;
				iClientRun[client] = run;
				
				iMimic[run][i] = client;
				
				return;
			}
		
		return;
	}
#endif
	
	RetrieveClientInfo( client );
	
	// Timer and welcome msg
	CreateTimer( 5.0, Timer_Connected, client );
	CreateTimer( TIMER_UPDATE_INTERVAL, Timer_ShowClientInfo, client, TIMER_REPEAT );
	
	// Hooks
	if ( iClientHideFlags[client] & HIDEHUD_PLAYERS )
		SDKHook( client, SDKHook_SetTransmit, Event_ClientTransmit );
	
	SDKHook( client, SDKHook_WeaponDropPost, Event_WeaponDrop ); // No more weapon dropping.
	SDKHook( client, SDKHook_WeaponSwitchPost, Event_WeaponSwitchPost );
	SDKHook( client, SDKHook_PreThinkPost, Event_ClientThink );
	
#if defined RECORD
	if ( b_DHOOKS_Exists && hHookTele != INVALID_HANDLE ) // DHOOKS only on real players.
		DHookEntity( hHookTele, false, client );
#endif
	
	// Join sound
	if ( !IsSoundPrecached( WinningSounds[0] ) )
		PrecacheSound( WinningSounds[0] );
	
	EmitSoundToClient( client, WinningSounds[0] );
}

public Event_WeaponSwitchPost( client )
{
	SetEntProp( client, Prop_Data, "m_iFOV", iClientFOV[client] );
	SetEntProp( client, Prop_Data, "m_iDefaultFOV", iClientFOV[client] );
}

public Event_WeaponDrop( client, weapon ) // REMOVE THOSE WEAPONS GOD DAMN IT!
	if ( IsValidEntity( weapon ) ) AcceptEntityInput( weapon, "Kill" );

//////////////////////////////////////////////////////////////
// Main component of the zones. Does everything, basically. //
//////////////////////////////////////////////////////////////
public Event_ClientThink( client )
{
	if ( !bIsLoaded[ iClientRun[client] ] || !IsPlayerAlive( client ) ) return;
	
	static bool:bInsideBounds[MAXPLAYERS_BHOP][INSIDE_MAX];
	
	if ( iClientRun[client] == RUN_MAIN )
	{
		bInsideBounds[client][INSIDE_START] = IsInsideBounds( client, BOUNDS_START );
		bInsideBounds[client][INSIDE_END] = IsInsideBounds( client, BOUNDS_END );
	}
	else if ( iClientRun[client] == RUN_BONUS_1 )
	{
		bInsideBounds[client][INSIDE_START] = IsInsideBounds( client, BOUNDS_BONUS_1_START );
		bInsideBounds[client][INSIDE_END] = IsInsideBounds( client, BOUNDS_BONUS_1_END );
	}
	else if ( iClientRun[client] == RUN_BONUS_2 )
	{
		bInsideBounds[client][INSIDE_START] = IsInsideBounds( client, BOUNDS_BONUS_2_START );
		bInsideBounds[client][INSIDE_END] = IsInsideBounds( client, BOUNDS_BONUS_2_END );
	}
	
	if ( iClientState[client] == STATE_START && !bInsideBounds[client][INSIDE_START] )
	{
		if ( GetEntityMoveType( client ) == MOVETYPE_NOCLIP )
		{
			PrintColorChat( client, client, "%s You're now in practice mode! Type \x03!prac%s again to toggle.", CHAT_PREFIX, COLOR_TEXT );
			bIsClientPractising[client] = true;
		}
		else if ( !bPreSpeed && ( GetClientVelocity( client ) > 300.0 || iClientJumpCount[client] > 1 ) )
		{
			PrintColorChat( client, client, "%s No prespeeding allowed! (\x03300vel/2 jump cap%s)", CHAT_PREFIX, COLOR_TEXT );
			TeleportEntity( client, NULL_VECTOR, NULL_VECTOR, vecNull );
			
			return;
		}
		
		flClientStartTime[client] = GetEngineTime();
		
		ArrayFill( iClientGoodSync[client], 1, 100 );
		
#if defined RECORD
		if ( !bIsClientPractising[client] )
		{
			iClientTick[client] = 0;
			bIsClientRecording[client] = true;
			
			hClientRecording[client] = CreateArray( _:FrameInfo );
			
			GetClientEyeAngles( client, angInitAngles[client] );
			GetClientAbsOrigin( client, vecInitPos[client] );
		}
#endif
		iClientState[client] = STATE_RUNNING;
	}
	else if ( iClientState[client] == STATE_RUNNING && bInsideBounds[client][INSIDE_END] )
	{
		// Inside the end bounds from running! :D
		if ( flClientStartTime[client] == 0.0 )
			return;
		
		iClientState[client] = STATE_END;
		
		new Float:flNewTime = GetEngineTime() - flClientStartTime[client];
		
		flClientStartTime[client] = 0.0;
		
		if ( bIsClientPractising[client] )
			return;
		
		flClientFinishTime[client] = flNewTime;
		
		if ( !SaveClientRecord( client, flNewTime ) )
			PrintColorChat( client, client, "%s Couldn't save your record to the database!", CHAT_PREFIX );
		
#if defined RECORD
		if ( bIsClientRecording[client] && hClientRecording[client] != INVALID_HANDLE )
		{
			iClientTick[client] = 0;
			bIsClientRecording[client] = false;
		}
#endif
	}
	else if ( bInsideBounds[client][INSIDE_START] )
	{
		// Reset everything if we're inside the starting zone.
		// Did we come in just now or did we not jump when we were on the ground?
		if ( iClientState[client] != STATE_START || ( GetEntityFlags( client ) & FL_ONGROUND && !( GetClientButtons( client ) & IN_JUMP ) ) )
			iClientJumpCount[client] = 0;
		
		iClientState[client] = STATE_START;
		flClientSaveTime[client] = 0.0;
		
		iClientStrafeCount[client] = 0;
		iClientLastStrafe[client] = STRAFE_INVALID;
	}
	else if ( !bIsClientPractising[client] )
	{
		// We're running, so let's check for potential block zones.
		for ( new i = BOUNDS_BLOCK_1; i < MAX_BOUNDS; i++ )
		{
			if ( !bZoneExists[i] ) continue;
			
			if ( IsInsideBounds( client, i ) )
			{
				PrintColorChat( client, client, "%s You are not allowed to go there!", CHAT_PREFIX );
				TeleportEntity( client, vecSpawnPos[ iClientRun[client] ], angSpawnAngles[ iClientRun[client] ], vecNull );
				
				return;
			}
		}
	}
}