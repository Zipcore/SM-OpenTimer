Handle g_Database;
char g_szError[100];

// Used for all the queries.
static char g_szQuery_Small[128];
static char g_szQuery_Med[200];
static char g_szQuery_Big[300];

// Includes all the threaded SQL callbacks.
#include "opentimer/database_thread.sp"

// Print server times to client. This can be done to console or to a menu.
// Client can also request individual modes.
stock void DB_PrintRecords( int client, bool bInConsole, int iReqStyle = -1, int iRun = 0 )
{
	if ( iReqStyle != -1 )
	{
		FormatEx( g_szQuery_Small, sizeof( g_szQuery_Small ), "SELECT * FROM '%s' WHERE style = %i AND run = %i ORDER BY time LIMIT %i", g_szCurrentMap, iReqStyle, iRun, RECORDS_PRINT_MAX );
	}
	else
	{
		// No requested style.
		FormatEx( g_szQuery_Small, sizeof( g_szQuery_Small ), "SELECT * FROM '%s' WHERE run = %i ORDER BY time LIMIT %i", g_szCurrentMap, iRun, RECORDS_PRINT_MAX );
	}
	
	Handle hData = CreateArray( 2 );
	
	int iData[2];
	iData[0] = GetClientUserId( client );
	iData[1] = bInConsole;
	
	PushArrayArray( hData, iData, 2 );
	
	SQL_TQuery( g_Database, Threaded_PrintRecords, g_szQuery_Small, hData, DBPrio_Low );
}

// We save the record if needed and print a notification to the chat.
stock bool DB_SaveClientRecord( int client, float flNewTime )
{
	char szSteamID[STEAMID_MAXLENGTH];
	
	if ( !GetClientAuthId( client, AuthId_Engine, szSteamID, sizeof( szSteamID ) ) )
	{
		LogError( CONSOLE_PREFIX ... "There was an error at trying to retrieve player's \"%N\" Steam ID! Cannot save record.", client );
		return false;
	}
	
	int run = g_iClientRun[client];
	int style = g_iClientStyle[client];
	
	// First time beating or better time than last time.
	if ( g_flClientBestTime[client][run][style] <= TIME_INVALID || flNewTime < g_flClientBestTime[client][run][style] )
	{
		char szName[MAX_NAME_LENGTH];
		GetClientName( client, szName, sizeof( szName ) );
		
		// I can't believe I forgot about this.
		SQL_EscapeString( g_Database, szName, szName, sizeof( szName ) );
		
		// Insert new if we haven't beaten this one yet. Replace otherwise.
		FormatEx( g_szQuery_Big, sizeof( g_szQuery_Big ), "INSERT OR REPLACE INTO '%s' (steamid, name, time, jumps, run, style, strafes) VALUES ('%s', '%s', %.3f, %i, %i, %i, %i)", g_szCurrentMap, szSteamID, szName, flNewTime, g_nClientJumpCount[client], run, style, g_nClientStrafeCount[client] );
		
		SQL_TQuery( g_Database, Threaded_Empty, g_szQuery_Big, _, DBPrio_High );
	}
	
	
	////////////////////////////////////////////////////////////////////////////////
	// Print record in chat. Only here because my eyes are dying from repetition. //
	////////////////////////////////////////////////////////////////////////////////
	float flLeftSeconds;
	
	// This is to format the time correctly.
	if ( flNewTime > g_flMapBestTime[run][style] )
	{
		// Show them how many seconds it was off of from the record. E.g +00:01:33.70
		flLeftSeconds = flNewTime - g_flMapBestTime[run][style];
	}
	else
	{
		// We got a better time than the best record! E.g -00:00:01.00
		flLeftSeconds = g_flMapBestTime[run][style] - flNewTime;
	}
	
	static char		szTxt[192];
	bool			bIsBest;
	char			szFormTime[SIZE_TIME_CHAT];
	FormatSeconds( flNewTime, szFormTime, sizeof( szFormTime ), FORMAT_COLORED );
	
	// New time if under or equal to 0
	if ( g_flClientBestTime[client][run][style] <= TIME_INVALID ) 
	{
		if ( flNewTime > g_flMapBestTime[run][style] )
		{
			FormatEx( szTxt, sizeof( szTxt ), CHAT_PREFIX ... "\x03%N"...CLR_TEXT..." finished \x03%s"...CLR_TEXT..." for the first time ["...CLR_STYLE..."%s"...CLR_TEXT..."]!\n\x06(%s\x06)", client, g_szRunName[NAME_LONG][run], g_szStyleName[NAME_SHORT][style], szFormTime );
			
			if ( g_flMapBestTime[run][style] <= TIME_INVALID )
			{
				bIsBest = true;
			}
		}
		else
		{
			FormatEx( szTxt, sizeof( szTxt ), CHAT_PREFIX ... "\x03%N"...CLR_TEXT..." broke \x03%s"...CLR_TEXT..." record ["...CLR_STYLE..."%s"...CLR_TEXT..."]!\n\x06(%s\x06) Improving \x03%.2f\x06sec!", client, g_szRunName[NAME_LONG][run], g_szStyleName[NAME_SHORT][style], szFormTime, flLeftSeconds );
			bIsBest = true;
		}
	}
	else
	{
		if ( flNewTime >= g_flMapBestTime[run][style] )
		{
			if ( flNewTime > g_flClientBestTime[client][run][style] )
			{
				FormatEx( szTxt, sizeof( szTxt ), CHAT_PREFIX ... "\x03%N"...CLR_TEXT..." finished \x03%s"...CLR_TEXT..." ["...CLR_STYLE..."%s"...CLR_TEXT..."]!\n\x06(%s\x06)", client, g_szRunName[NAME_LONG][run], g_szStyleName[NAME_SHORT][style], szFormTime );
			}
			else
			{
				FormatEx( szTxt, sizeof( szTxt ), CHAT_PREFIX ... "\x03%N"...CLR_TEXT..." finished \x03%s"...CLR_TEXT..." ["...CLR_STYLE..."%s"...CLR_TEXT..."]!\n\x06(%s\x06) Improving \x03%.2f\x06sec!", client, g_szRunName[NAME_LONG][run], g_szStyleName[NAME_SHORT][style], szFormTime, g_flClientBestTime[client][run][style] - flNewTime );
			}
		}
		else
		{
			FormatEx( szTxt, sizeof( szTxt ), CHAT_PREFIX ... "\x03%N"...CLR_TEXT..." broke \x03%s"...CLR_TEXT..." record ["...CLR_STYLE..."%s"...CLR_TEXT..."]!\n\x06(%s\x06) Improving \x03%.2f\x06sec!", client, g_szRunName[NAME_LONG][run], g_szStyleName[NAME_SHORT][style], szFormTime, flLeftSeconds );
			bIsBest = true;
		}
	}
	
	PRINTCHATALL( client, false, szTxt );
	
	
	// Play sound.
	if ( bIsBest )
	{
		// [BOT CHEER]
		int sound = GetRandomInt( 1, /*7*/sizeof( g_szWinningSounds ) - 1 );
		
		if ( !IsSoundPrecached( g_szWinningSounds[sound] ) )
			PrecacheSound( g_szWinningSounds[sound] );
		
		EmitSoundToAll( g_szWinningSounds[sound] );
	}
	else
	{
		// Beep!
		if ( !IsSoundPrecached( g_szWinningSounds[0] ) )
			PrecacheSound( g_szWinningSounds[0] );
			
		EmitSoundToAll( g_szWinningSounds[0] );
	}
	
	
	// Update client's best time if better or if the time doesn't exist.
	if ( g_flClientBestTime[client][run][style] <= TIME_INVALID || flNewTime < g_flClientBestTime[client][run][style] )
	{
		g_flClientBestTime[client][run][style] = flNewTime;
	}
	
	
	// Save if best time and save the recording on disk. :)
	if ( g_flMapBestTime[run][style] <= TIME_INVALID || flNewTime < g_flMapBestTime[run][style] )
	{
		g_flMapBestTime[run][style] = flNewTime;
		
#if defined RECORD
		if ( g_bClientRecording[client] && g_hClientRecording[client] != null )
		{
			// Save the recording to disk.
			if ( !SaveRecording( client, flNewTime ) ) return false;
			
			
			// We did it, hurray! Now let's copy the record for playback.
			CopyRecordToPlayback( client );
		}
#endif
	}
	
	UpdateScoreboard( client );
	
	return true;
}

stock bool DB_SaveClientData( int client )
{
	if ( g_Database == null ) return false;
	
	char szSteamID[STEAMID_MAXLENGTH];
	
	if ( !GetClientAuthId( client, AuthId_Engine, szSteamID, sizeof( szSteamID ) ) )
	{
		LogError( CONSOLE_PREFIX ... "There was an error while trying to retrieve player's \"%N\" Steam ID! Cannot save data.", client );
		return false;
	}
	
	
	FormatEx( g_szQuery_Small, sizeof( g_szQuery_Small ), "UPDATE player_data SET fov = %i, hideflags = %i WHERE steamid = '%s'", g_iClientFOV[client], g_fClientHideFlags[client], szSteamID );
	
	SQL_TQuery( g_Database, Threaded_Empty, g_szQuery_Small, _, DBPrio_Normal );
	
	return true;
}

// Get client options (fov and hideflags) and time it took him/her to beat the map in all modes.
stock void DB_RetrieveClientData( int client )
{
	char szSteamID[STEAMID_MAXLENGTH];
	
	if ( !GetClientAuthId( client, AuthId_Engine, szSteamID, sizeof( szSteamID ) ) )
	{
		LogError( CONSOLE_PREFIX ... "There was an error while trying to retrieve player's \"%N\" Steam ID! Cannot retrieve data.", client );
		return;
	}
	
	
	FormatEx( g_szQuery_Small, sizeof( g_szQuery_Small ), "SELECT * FROM player_data WHERE steamid = '%s'", szSteamID );
	
	SQL_TQuery( g_Database, Threaded_RetrieveClientData, g_szQuery_Small, GetClientUserId( client ), DBPrio_Normal );
}

// Initialize sounds so important. I'm so cool.
// Create connection with database!
stock void DB_InitializeDatabase()
{
	// Creates opentimer.sq3 in the data folder.
	Handle kv = CreateKeyValues( "" );
	KvSetString( kv, "driver", "sqlite" );
	KvSetString( kv, "database", "opentimer" );
	
	g_Database = SQL_ConnectCustom( kv, g_szError, sizeof( g_szError ), false );
	
	delete kv;
	
	if ( g_Database == null )
	{
		SetFailState( CONSOLE_PREFIX ... "Unable to establish connection to the database! Error: %s", g_szError );
		return;
	}
	
	
	SQL_LockDatabase( g_Database );
	
	if ( !SQL_FastQuery( g_Database, "CREATE TABLE IF NOT EXISTS player_data (steamid VARCHAR(32) PRIMARY KEY, fov INTEGER, hideflags INTEGER)" ) )
	{
		SQL_UnlockDatabase( g_Database );
		
		SQL_GetError( g_Database, g_szError, sizeof( g_szError ) );
		SetFailState( CONSOLE_PREFIX ... "Plugin was unable to create table for player profiles! Error: %s", g_szError );
		
		return;
	}
	
	SQL_UnlockDatabase( g_Database );
	
	
	PrintToServer( CONSOLE_PREFIX ... "Established connection with database!" );
}

// Get map zones, mimics and vote-able maps
stock void DB_InitializeMapZones()
{
	if ( g_Database == null )
		SetFailState( CONSOLE_PREFIX ... "No connection to database. Unable to retrieve map data!" );
	
	
	SQL_LockDatabase( g_Database );
	
	if ( !SQL_FastQuery( g_Database, "CREATE TABLE IF NOT EXISTS _mapbounds (map VARCHAR(32) PRIMARY KEY, smin0 REAL, smin1 REAL, smin2 REAL, smax0 REAL, smax1 REAL, smax2 REAL, emin0 REAL, emin1 REAL, emin2 REAL, emax0 REAL, emax1 REAL, emax2 REAL, bl1min0 REAL, bl1min1 REAL, bl1min2 REAL, bl1max0 REAL, bl1max1 REAL, bl1max2 REAL, bl2min0 REAL, bl2min1 REAL, bl2min2 REAL, bl2max0 REAL, bl2max1 REAL, bl2max2 REAL, bl3min0 REAL, bl3min1 REAL, bl3min2 REAL, bl3max0 REAL, bl3max1 REAL, bl3max2 REAL, b1_smin0 REAL, b1_smin1 REAL, b1_smin2 REAL, b1_smax0 REAL, b1_smax1 REAL, b1_smax2 REAL, b1_emin0 REAL, b1_emin1 REAL, b1_emin2 REAL, b1_emax0 REAL, b1_emax1 REAL, b1_emax2 REAL, b2_smin0 REAL, b2_smin1 REAL, b2_smin2 REAL, b2_smax0 REAL, b2_smax1 REAL, b2_smax2 REAL, b2_emin0 REAL, b2_emin1 REAL, b2_emin2 REAL, b2_emax0 REAL, b2_emax1 REAL, b2_emax2 REAL, fs1min0 REAL, fs1min1 REAL, fs1min2 REAL, fs1max0 REAL, fs1max1 REAL, fs1max2 REAL, fs2min0 REAL, fs2min1 REAL, fs2min2 REAL, fs2max0 REAL, fs2max1 REAL, fs2max2 REAL, fs3min0 REAL, fs3min1 REAL, fs3min2 REAL, fs3max0 REAL, fs3max1 REAL, fs3max2 REAL)" ) )
	{
		SQL_UnlockDatabase( g_Database );
		
		SQL_GetError( g_Database, g_szError, sizeof( g_szError ) );
		SetFailState( CONSOLE_PREFIX ... "Couldn't create map zone table! Error: %s", g_szError );
		return;
	}
	
	
	FormatEx( g_szQuery_Big, sizeof( g_szQuery_Big ), "CREATE TABLE IF NOT EXISTS '%s' (steamid VARCHAR(32) NOT NULL, run INTEGER NOT NULL, style INTEGER NOT NULL, name VARCHAR(64), time REAL, jumps INTEGER , strafes INTEGER, PRIMARY KEY (steamid, run, style))", g_szCurrentMap );
	
	if ( !SQL_FastQuery( g_Database, g_szQuery_Big ) )
	{
		SQL_UnlockDatabase( g_Database );
		
		SQL_GetError( g_Database, g_szError, sizeof( g_szError ) );
		SetFailState( CONSOLE_PREFIX ... "Couldn't create map record table! Error: %s", g_szError );
		return;
	}
	
	
	FormatEx( g_szQuery_Small, sizeof( g_szQuery_Small ), "SELECT * FROM _mapbounds WHERE map = '%s'", g_szCurrentMap );
	Handle hQuery = SQL_Query( g_Database, g_szQuery_Small );
	
	if ( hQuery == null )
	{
		SQL_UnlockDatabase( g_Database );
		
		SQL_GetError( g_Database, g_szError, sizeof( g_szError ) );
		SetFailState( CONSOLE_PREFIX ... "Unable to retrieve map zones! Error: %s", g_szError );
		return;
	}
	
	
	int field;
	
	if ( SQL_GetRowCount( hQuery ) == 0 )
	{
		FormatEx( g_szQuery_Small, sizeof( g_szQuery_Small ), "INSERT INTO _mapbounds (map) VALUES ('%s')", g_szCurrentMap );
		
		if ( !SQL_FastQuery( g_Database, g_szQuery_Small ) )
		{
			delete hQuery;
			
			SQL_UnlockDatabase( g_Database );
			
			SQL_GetError( g_Database, g_szError, sizeof( g_szError ) );
			SetFailState( CONSOLE_PREFIX ... "Couldn't create map zones table! Error: %s", g_szError );
			return;
		}
		
		delete hQuery;
		
		SQL_UnlockDatabase( g_Database );
		return;
	}
	else
	{
		while ( SQL_FetchRow( hQuery ) )
		{
			// START ZONE
			SQL_FieldNameToNum( hQuery, "smin0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				g_vecZoneMins[ZONE_START][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "smin1", field );
				g_vecZoneMins[ZONE_START][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "smin2", field );
				g_vecZoneMins[ZONE_START][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "smax0", field );
				g_vecZoneMaxs[ZONE_START][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "smax1", field );
				g_vecZoneMaxs[ZONE_START][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "smax2", field );
				g_vecZoneMaxs[ZONE_START][2] = SQL_FetchFloat( hQuery, field );
				
				g_bZoneExists[ZONE_START] = true;
			}
			else g_bZoneExists[ZONE_START] = false;
			
			// END ZONE
			SQL_FieldNameToNum( hQuery, "emin0", field );

			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				g_vecZoneMins[ZONE_END][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "emin1", field );
				g_vecZoneMins[ZONE_END][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "emin2", field );
				g_vecZoneMins[ZONE_END][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "emax0", field );
				g_vecZoneMaxs[ZONE_END][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "emax1", field );
				g_vecZoneMaxs[ZONE_END][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "emax2", field );
				g_vecZoneMaxs[ZONE_END][2] = SQL_FetchFloat( hQuery, field );
				
				g_bZoneExists[ZONE_END] = true;
			}
			else g_bZoneExists[ZONE_END] = false;
	
			// BLOCK ZONE
			// BLOCK #1
			SQL_FieldNameToNum( hQuery, "bl1min0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				g_vecZoneMins[ZONE_BLOCK_1][0] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "bl1min1", field );
				g_vecZoneMins[ZONE_BLOCK_1][1] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "bl1min2", field );
				g_vecZoneMins[ZONE_BLOCK_1][2] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "bl1max0", field );
				g_vecZoneMaxs[ZONE_BLOCK_1][0] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "bl1max1", field );
				g_vecZoneMaxs[ZONE_BLOCK_1][1] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "bl1max2", field );
				g_vecZoneMaxs[ZONE_BLOCK_1][2] = SQL_FetchFloat( hQuery, field );
				
				g_bZoneExists[ZONE_BLOCK_1] = true;
			}
			else g_bZoneExists[ZONE_BLOCK_1] = false;
			
			// BLOCK #2
			SQL_FieldNameToNum( hQuery, "bl2min0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				g_vecZoneMins[ZONE_BLOCK_2][0] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "bl2min1", field );
				g_vecZoneMins[ZONE_BLOCK_2][1] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "bl2min2", field );
				g_vecZoneMins[ZONE_BLOCK_2][2] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "bl2max0", field );
				g_vecZoneMaxs[ZONE_BLOCK_2][0] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "bl2max1", field );
				g_vecZoneMaxs[ZONE_BLOCK_2][1] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "bl2max2", field );
				g_vecZoneMaxs[ZONE_BLOCK_2][2] = SQL_FetchFloat( hQuery, field );
				
				g_bZoneExists[ZONE_BLOCK_2] = true;
			}
			else g_bZoneExists[ZONE_BLOCK_2] = false;
			
			
			// BLOCK #3
			SQL_FieldNameToNum( hQuery, "bl3min0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				g_vecZoneMins[ZONE_BLOCK_3][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "bl3min1", field );
				g_vecZoneMins[ZONE_BLOCK_3][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "bl3min2", field );
				g_vecZoneMins[ZONE_BLOCK_3][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "bl3max0", field );
				g_vecZoneMaxs[ZONE_BLOCK_3][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "bl3max1", field );
				g_vecZoneMaxs[ZONE_BLOCK_3][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "bl3max2", field );
				g_vecZoneMaxs[ZONE_BLOCK_3][2] = SQL_FetchFloat( hQuery, field );
				
				g_bZoneExists[ZONE_BLOCK_3] = true;
			}
			else g_bZoneExists[ZONE_BLOCK_3] = false;
			
			
			// BONUS #1 START
			SQL_FieldNameToNum( hQuery, "b1_smin0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				g_vecZoneMins[ZONE_BONUS_1_START][0] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "b1_smin1", field );
				g_vecZoneMins[ZONE_BONUS_1_START][1] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "b1_smin2", field );
				g_vecZoneMins[ZONE_BONUS_1_START][2] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "b1_smax0", field );
				g_vecZoneMaxs[ZONE_BONUS_1_START][0] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "b1_smax1", field );
				g_vecZoneMaxs[ZONE_BONUS_1_START][1] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "b1_smax2", field );
				g_vecZoneMaxs[ZONE_BONUS_1_START][2] = SQL_FetchFloat( hQuery, field );
				
				g_bZoneExists[ZONE_BONUS_1_START] = true;
			}
			else g_bZoneExists[ZONE_BONUS_1_START] = false;
			
			// BONUS #1 END
			SQL_FieldNameToNum( hQuery, "b1_emin0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				g_vecZoneMins[ZONE_BONUS_1_END][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "b1_emin1", field );
				g_vecZoneMins[ZONE_BONUS_1_END][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b1_emin2", field );
				g_vecZoneMins[ZONE_BONUS_1_END][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b1_emax0", field );
				g_vecZoneMaxs[ZONE_BONUS_1_END][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b1_emax1", field );
				g_vecZoneMaxs[ZONE_BONUS_1_END][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b1_emax2", field );
				g_vecZoneMaxs[ZONE_BONUS_1_END][2] = SQL_FetchFloat( hQuery, field );
				
				g_bZoneExists[ZONE_BONUS_1_END] = true;
			}
			else g_bZoneExists[ZONE_BONUS_1_END] = false;
			
			// BONUS #2 START
			SQL_FieldNameToNum( hQuery, "b2_smin0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				g_vecZoneMins[ZONE_BONUS_2_START][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "b2_smin1", field );
				g_vecZoneMins[ZONE_BONUS_2_START][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b2_smin2", field );
				g_vecZoneMins[ZONE_BONUS_2_START][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b2_smax0", field );
				g_vecZoneMaxs[ZONE_BONUS_2_START][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b2_smax1", field );
				g_vecZoneMaxs[ZONE_BONUS_2_START][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b2_smax2", field );
				g_vecZoneMaxs[ZONE_BONUS_2_START][2] = SQL_FetchFloat( hQuery, field );

				g_bZoneExists[ZONE_BONUS_2_START] = true;
			}
			else g_bZoneExists[ZONE_BONUS_2_START] = false;
			
			// BONUS #2 END
			SQL_FieldNameToNum( hQuery, "b2_emin0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				g_vecZoneMins[ZONE_BONUS_2_END][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "b2_emin1", field );
				g_vecZoneMins[ZONE_BONUS_2_END][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b2_emin2", field );
				g_vecZoneMins[ZONE_BONUS_2_END][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b2_emax0", field );
				g_vecZoneMaxs[ZONE_BONUS_2_END][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b2_emax1", field );
				g_vecZoneMaxs[ZONE_BONUS_2_END][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b2_emax2", field );
				g_vecZoneMaxs[ZONE_BONUS_2_END][2] = SQL_FetchFloat( hQuery, field );
				
				g_bZoneExists[ZONE_BONUS_2_END] = true;
			}
			else g_bZoneExists[ZONE_BONUS_2_END] = false;
			
			
			// FREESTYLE #1
			// ROCK THE MICROPHONE WITH A FREESTYLER
			SQL_FieldNameToNum( hQuery, "fs1min0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				g_vecZoneMins[ZONE_FREESTYLE_1][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "fs1min1", field );
				g_vecZoneMins[ZONE_FREESTYLE_1][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs1min2", field );
				g_vecZoneMins[ZONE_FREESTYLE_1][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs1max0", field );
				g_vecZoneMaxs[ZONE_FREESTYLE_1][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs1max1", field );
				g_vecZoneMaxs[ZONE_FREESTYLE_1][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs1max2", field );
				g_vecZoneMaxs[ZONE_FREESTYLE_1][2] = SQL_FetchFloat( hQuery, field );
				
				g_bZoneExists[ZONE_FREESTYLE_1] = true;
			}
			else g_bZoneExists[ZONE_FREESTYLE_1] = false;
			
			// FREESTYLE #2
			SQL_FieldNameToNum( hQuery, "fs2min0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				g_vecZoneMins[ZONE_FREESTYLE_2][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "fs2min1", field );
				g_vecZoneMins[ZONE_FREESTYLE_2][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs2min2", field );
				g_vecZoneMins[ZONE_FREESTYLE_2][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs2max0", field );
				g_vecZoneMaxs[ZONE_FREESTYLE_2][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs2max1", field );
				g_vecZoneMaxs[ZONE_FREESTYLE_2][1] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "fs2max2", field );
				g_vecZoneMaxs[ZONE_FREESTYLE_2][2] = SQL_FetchFloat( hQuery, field );
				
				g_bZoneExists[ZONE_FREESTYLE_2] = true;
			}
			else g_bZoneExists[ZONE_FREESTYLE_2] = false;
			
			// FREESTYLE #3
			SQL_FieldNameToNum( hQuery, "fs3min0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				g_vecZoneMins[ZONE_FREESTYLE_3][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "fs3min1", field );
				g_vecZoneMins[ZONE_FREESTYLE_3][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs3min2", field );
				g_vecZoneMins[ZONE_FREESTYLE_3][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs3max0", field );
				g_vecZoneMaxs[ZONE_FREESTYLE_3][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs3max1", field );
				g_vecZoneMaxs[ZONE_FREESTYLE_3][1] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "fs3max2", field );
				g_vecZoneMaxs[ZONE_FREESTYLE_3][2] = SQL_FetchFloat( hQuery, field );
				
				g_bZoneExists[ZONE_FREESTYLE_3] = true;
			}
			else g_bZoneExists[ZONE_FREESTYLE_3] = false;
		}
	}
	
	for ( int i; i < NUM_ZONES; i++ )
	{
		if ( !g_bZoneExists[i] ) continue;
		
		CorrectMinsMaxs( g_vecZoneMins[i], g_vecZoneMaxs[i] );
		SetupZonePoints( i );
	}

	if ( !g_bZoneExists[ZONE_START] || !g_bZoneExists[ZONE_END] )
	{
		PrintToServer( CONSOLE_PREFIX ... "Map is lacking zones..." );
		g_bIsLoaded[RUN_MAIN] = false;
	}
	else g_bIsLoaded[RUN_MAIN] = true;
	
	
	g_bIsLoaded[RUN_BONUS_1] = ( !g_bZoneExists[ZONE_BONUS_1_START] || !g_bZoneExists[ZONE_BONUS_1_END] ) ? false : true;
	
	g_bIsLoaded[RUN_BONUS_2] = ( !g_bZoneExists[ZONE_BONUS_2_START] || !g_bZoneExists[ZONE_BONUS_2_END] ) ? false : true;
	
	
	// Get map data for records and votes!
#if defined RECORD
	FormatEx( g_szQuery_Big, sizeof( g_szQuery_Big ), "SELECT run, style, MIN(time), steamid, name FROM '%s' GROUP BY run, style ORDER BY run", g_szCurrentMap );
#else
	FormatEx( g_szQuery_Big, sizeof( g_szQuery_Big ), "SELECT run, style, MIN(time) FROM '%s' GROUP BY run, style ORDER BY run", g_szCurrentMap );
#endif
	
	hQuery = SQL_Query( g_Database, g_szQuery_Big );
	
	if ( hQuery == null )
	{
		SQL_UnlockDatabase( g_Database );
		
		SQL_GetError( g_Database, g_szError, sizeof( g_szError ) );
		SetFailState( CONSOLE_PREFIX ... "Unable to retrieve map best times! Error: %s", g_szError );
		return;
	}
	
	int		iStyle;
	int		iRun;
#if defined RECORD
	char	szSteamID[STEAMID_MAXLENGTH];
	char	szName[MAX_NAME_LENGTH];
	
	bool	bNormalOnly = GetConVarBool( g_ConVar_Bonus_NormalOnlyRec );
#endif

	while ( SQL_FetchRow( hQuery ) )
	{
		// Using SQL_FieldNameToNum seems to break everything for some reason.
		// Might be invalid syntax...
		
		iRun = SQL_FetchInt( hQuery, 0 );
	
		iStyle = SQL_FetchInt( hQuery, 1 ); 
		g_flMapBestTime[iRun][iStyle] = SQL_FetchFloat( hQuery, 2 );
		
#if defined RECORD
		// Load records from disk.
		// Assigning the records to bots are done in OnClientPutInServer()
		if ( !g_bIsLoaded[iRun] ) continue;
		
		if ( iRun != RUN_MAIN && iStyle != STYLE_NORMAL && bNormalOnly ) continue;
		
		
		SQL_FetchString( hQuery, 3, szSteamID, sizeof( szSteamID ) );
		SQL_FetchString( hQuery, 4, szName, sizeof( szName ) );
		
		if ( LoadRecording( szSteamID, iRun, iStyle ) )
		{
			strcopy( g_szRecName[iRun][iStyle], sizeof( g_szRecName[][] ), szName );
			g_iNumRec++;
		}
#endif
	}
	
	delete hQuery;
	SQL_UnlockDatabase( g_Database );
	
#if defined RECORD
	ServerCommand( "bot_quota %i", g_iNumRec );
	PrintToServer( CONSOLE_PREFIX ... "Spawning %i record bots...", g_iNumRec );
#endif
	
	DoMapStuff();
}

// Get maps from database that have start and end zones and start with bhop_ or kz_.
#if defined VOTING
	stock void DB_FindMaps()
	{
		SQL_LockDatabase( g_Database );
		
		Handle hQuery = SQL_Query( g_Database, "SELECT map FROM _mapbounds WHERE smin0 IS NOT NULL AND emin0 IS NOT NULL AND (map LIKE 'bhop_%' OR map LIKE 'kz_%') ORDER BY map" );

		if ( hQuery == null )
		{
			SQL_UnlockDatabase( g_Database );
			
			SQL_GetError( g_Database, g_szError, sizeof( g_szError ) );
			SetFailState( CONSOLE_PREFIX ... "Plugin was unable to receive tables (map names) from database! Error: %s", g_szError );
		}
		
		
		char szMapName[MAX_MAP_NAME_LENGTH];
		g_hMapList = CreateArray( MAX_MAP_NAME_LENGTH );
		
		while( SQL_FetchRow( hQuery ) )
		{
			SQL_FetchString( hQuery, 0, szMapName, sizeof( szMapName ) );
			
			int iMap[MAX_MAP_NAME_LENGTH];
			strcopy( iMap[MAP_NAME], sizeof( iMap[MAP_NAME] ), szMapName );
			
			PushArrayArray( g_hMapList, iMap, view_as<int>MapInfo );
		}
		
		delete hQuery;
		SQL_UnlockDatabase( g_Database );
	}
#endif

stock bool DB_SaveMapZone( int zone )
{
	switch ( zone )
	{
		case ZONE_START :
		{
			FormatEx( g_szQuery_Big, sizeof( g_szQuery_Big ), "UPDATE _mapbounds SET smin0 = %.0f, smin1 = %.0f, smin2 = %.0f, smax0 = %.0f, smax1 = %.0f, smax2 = %.0f WHERE map = '%s'",
				g_vecZoneMins[ZONE_START][0], g_vecZoneMins[ZONE_START][1], g_vecZoneMins[ZONE_START][2],
				g_vecZoneMaxs[ZONE_START][0], g_vecZoneMaxs[ZONE_START][1], g_vecZoneMaxs[ZONE_START][2], g_szCurrentMap );
		}
		case ZONE_END :
		{
			FormatEx( g_szQuery_Big, sizeof( g_szQuery_Big ), "UPDATE _mapbounds SET emin0 = %.0f, emin1 = %.0f, emin2 = %.0f, emax0 = %.0f, emax1 = %.0f, emax2 = %.0f WHERE map = '%s'",
				g_vecZoneMins[ZONE_END][0], g_vecZoneMins[ZONE_END][1], g_vecZoneMins[ZONE_END][2],
				g_vecZoneMaxs[ZONE_END][0], g_vecZoneMaxs[ZONE_END][1], g_vecZoneMaxs[ZONE_END][2], g_szCurrentMap );
		}
		case ZONE_BLOCK_1 :
		{
			FormatEx( g_szQuery_Big, sizeof( g_szQuery_Big ), "UPDATE _mapbounds SET bl1min0 = %.0f, bl1min1 = %.0f, bl1min2 = %.0f, bl1max0 = %.0f, bl1max1 = %.0f, bl1max2 = %.0f WHERE map = '%s'",
				g_vecZoneMins[ZONE_BLOCK_1][0], g_vecZoneMins[ZONE_BLOCK_1][1], g_vecZoneMins[ZONE_BLOCK_1][2],
				g_vecZoneMaxs[ZONE_BLOCK_1][0], g_vecZoneMaxs[ZONE_BLOCK_1][1], g_vecZoneMaxs[ZONE_BLOCK_1][2], g_szCurrentMap );
		}
		case ZONE_BLOCK_2 :
		{
			FormatEx( g_szQuery_Big, sizeof( g_szQuery_Big ), "UPDATE _mapbounds SET bl2min0 = %.0f, bl2min1 = %.0f, bl2min2 = %.0f, bl2max0 = %.0f, bl2max1 = %.0f, bl2max2 = %.0f WHERE map = '%s'",
				g_vecZoneMins[ZONE_BLOCK_2][0], g_vecZoneMins[ZONE_BLOCK_2][1], g_vecZoneMins[ZONE_BLOCK_2][2],
				g_vecZoneMaxs[ZONE_BLOCK_2][0], g_vecZoneMaxs[ZONE_BLOCK_2][1], g_vecZoneMaxs[ZONE_BLOCK_2][2], g_szCurrentMap );
		}
		case ZONE_BLOCK_3 :
		{
			FormatEx( g_szQuery_Big, sizeof( g_szQuery_Big ), "UPDATE _mapbounds SET bl3min0 = %.0f, bl3min1 = %.0f, bl3min2 = %.0f, bl3max0 = %.0f, bl3max1 = %.0f, bl3max2 = %.0f WHERE map = '%s'",
				g_vecZoneMins[ZONE_BLOCK_3][0], g_vecZoneMins[ZONE_BLOCK_3][1], g_vecZoneMins[ZONE_BLOCK_3][2],
				g_vecZoneMaxs[ZONE_BLOCK_3][0], g_vecZoneMaxs[ZONE_BLOCK_3][1], g_vecZoneMaxs[ZONE_BLOCK_3][2], g_szCurrentMap );
		}
		case ZONE_BONUS_1_START :
		{
			FormatEx( g_szQuery_Big, sizeof( g_szQuery_Big ), "UPDATE _mapbounds SET b1_smin0 = %.0f, b1_smin1 = %.0f, b1_smin2 = %.0f, b1_smax0 = %.0f, b1_smax1 = %.0f, b1_smax2 = %.0f WHERE map = '%s'",
				g_vecZoneMins[ZONE_BONUS_1_START][0], g_vecZoneMins[ZONE_BONUS_1_START][1], g_vecZoneMins[ZONE_BONUS_1_START][2],
				g_vecZoneMaxs[ZONE_BONUS_1_START][0], g_vecZoneMaxs[ZONE_BONUS_1_START][1], g_vecZoneMaxs[ZONE_BONUS_1_START][2], g_szCurrentMap );
		}
		case ZONE_BONUS_1_END :
		{
			FormatEx( g_szQuery_Big, sizeof( g_szQuery_Big ), "UPDATE _mapbounds SET b1_emin0 = %.0f, b1_emin1 = %.0f, b1_emin2 = %.0f, b1_emax0 = %.0f, b1_emax1 = %.0f, b1_emax2 = %.0f WHERE map = '%s'",
				g_vecZoneMins[ZONE_BONUS_1_END][0], g_vecZoneMins[ZONE_BONUS_1_END][1], g_vecZoneMins[ZONE_BONUS_1_END][2],
				g_vecZoneMaxs[ZONE_BONUS_1_END][0], g_vecZoneMaxs[ZONE_BONUS_1_END][1], g_vecZoneMaxs[ZONE_BONUS_1_END][2], g_szCurrentMap );
		}
		case ZONE_BONUS_2_START :
		{
			FormatEx( g_szQuery_Big, sizeof( g_szQuery_Big ), "UPDATE _mapbounds SET b2_smin0 = %.0f, b2_smin1 = %.0f, b2_smin2 = %.0f, b2_smax0 = %.0f, b2_smax1 = %.0f, b2_smax2 = %.0f WHERE map = '%s'",
				g_vecZoneMins[ZONE_BONUS_2_START][0], g_vecZoneMins[ZONE_BONUS_2_START][1], g_vecZoneMins[ZONE_BONUS_2_START][2],
				g_vecZoneMaxs[ZONE_BONUS_2_START][0], g_vecZoneMaxs[ZONE_BONUS_2_START][1], g_vecZoneMaxs[ZONE_BONUS_2_START][2], g_szCurrentMap );
		}
		case ZONE_BONUS_2_END :
		{
			FormatEx( g_szQuery_Big, sizeof( g_szQuery_Big ), "UPDATE _mapbounds SET b2_emin0 = %.0f, b2_emin1 = %.0f, b2_emin2 = %.0f, b2_emax0 = %.0f, b2_emax1 = %.0f, b2_emax2 = %.0f WHERE map = '%s'",
				g_vecZoneMins[ZONE_BONUS_2_END][0], g_vecZoneMins[ZONE_BONUS_2_END][1], g_vecZoneMins[ZONE_BONUS_2_END][2],
				g_vecZoneMaxs[ZONE_BONUS_2_END][0], g_vecZoneMaxs[ZONE_BONUS_2_END][1], g_vecZoneMaxs[ZONE_BONUS_2_END][2], g_szCurrentMap );
		}
		case ZONE_FREESTYLE_1 :
		{
			FormatEx( g_szQuery_Big, sizeof( g_szQuery_Big ), "UPDATE _mapbounds SET fs1min0 = %.0f, fs1min1 = %.0f, fs1min2 = %.0f, fs1max0 = %.0f, fs1max1 = %.0f, fs1max2 = %.0f WHERE map = '%s'",
				g_vecZoneMins[ZONE_FREESTYLE_1][0], g_vecZoneMins[ZONE_FREESTYLE_1][1], g_vecZoneMins[ZONE_FREESTYLE_1][2],
				g_vecZoneMaxs[ZONE_FREESTYLE_1][0], g_vecZoneMaxs[ZONE_FREESTYLE_1][1], g_vecZoneMaxs[ZONE_FREESTYLE_1][2], g_szCurrentMap );
		}
		case ZONE_FREESTYLE_2 :
		{
			FormatEx( g_szQuery_Big, sizeof( g_szQuery_Big ), "UPDATE _mapbounds SET fs2min0 = %.0f, fs2min1 = %.0f, fs2min2 = %.0f, fs2max0 = %.0f, fs2max1 = %.0f, fs2max2 = %.0f WHERE map = '%s'",
				g_vecZoneMins[ZONE_FREESTYLE_2][0], g_vecZoneMins[ZONE_FREESTYLE_2][1], g_vecZoneMins[ZONE_FREESTYLE_2][2],
				g_vecZoneMaxs[ZONE_FREESTYLE_2][0], g_vecZoneMaxs[ZONE_FREESTYLE_2][1], g_vecZoneMaxs[ZONE_FREESTYLE_2][2], g_szCurrentMap );
		}
		case ZONE_FREESTYLE_3 :
		{
			FormatEx( g_szQuery_Big, sizeof( g_szQuery_Big ), "UPDATE _mapbounds SET fs3min0 = %.0f, fs3min1 = %.0f, fs3min2 = %.0f, fs3max0 = %.0f, fs3max1 = %.0f, fs3max2 = %.0f WHERE map = '%s'",
				g_vecZoneMins[ZONE_FREESTYLE_3][0], g_vecZoneMins[ZONE_FREESTYLE_3][1], g_vecZoneMins[ZONE_FREESTYLE_3][2],
				g_vecZoneMaxs[ZONE_FREESTYLE_3][0], g_vecZoneMaxs[ZONE_FREESTYLE_3][1], g_vecZoneMaxs[ZONE_FREESTYLE_3][2], g_szCurrentMap );
		}
		default : return false;
	}
	
	
	SQL_LockDatabase( g_Database );
	
	if ( !SQL_FastQuery( g_Database, g_szQuery_Big ) )
	{
		SQL_GetError( g_Database, g_szError, sizeof( g_szError ) );
		LogError( CONSOLE_PREFIX ... "Couldn't save a zone!\nError: %s", g_szError );
		
		SQL_UnlockDatabase( g_Database );
		return false;
	}
	
	SQL_UnlockDatabase( g_Database );
	
	
	g_bZoneExists[zone] = true;
	return true;
}

stock bool DB_EraseCurMapZone( int zone )
{
	switch ( zone )
	{
		case ZONE_START :
		{
			FormatEx( g_szQuery_Med, sizeof( g_szQuery_Med ), "UPDATE _mapbounds SET smin0 = NULL, smin1 = NULL, smin2 = NULL, smax0 = NULL, smax1 = NULL, smax2 = NULL WHERE map = '%s'", g_szCurrentMap );
			g_bIsLoaded[RUN_MAIN] = false;
		}
		case ZONE_END :
		{
			FormatEx( g_szQuery_Med, sizeof( g_szQuery_Med ), "UPDATE _mapbounds SET emin0 = NULL, emin1 = NULL, emin2 = NULL, emax0 = NULL, emax1 = NULL, emax2 = NULL WHERE map = '%s'", g_szCurrentMap );
			g_bIsLoaded[RUN_MAIN] = false;
		}
		case ZONE_BLOCK_1 :
		{
			FormatEx( g_szQuery_Med, sizeof( g_szQuery_Med ), "UPDATE _mapbounds SET bl1min0 = NULL, bl1min1 = NULL, bl1min2 = NULL, bl1max0 = NULL, bl1max1 = NULL, bl1max2 = NULL WHERE map = '%s'", g_szCurrentMap );
		}
		case ZONE_BLOCK_2 :
		{
			FormatEx( g_szQuery_Med, sizeof( g_szQuery_Med ), "UPDATE _mapbounds SET bl2min0 = NULL, bl2min1 = NULL, bl2min2 = NULL, bl2max0 = NULL, bl2max1 = NULL, bl2max2 = NULL WHERE map = '%s'", g_szCurrentMap );
		}
		case ZONE_BLOCK_3 :
		{
			FormatEx( g_szQuery_Med, sizeof( g_szQuery_Med ), "UPDATE _mapbounds SET bl3min0 = NULL, bl3min1 = NULL, bl3min2 = NULL, bl3max0 = NULL, bl3max1 = NULL, bl3max2 = NULL WHERE map = '%s'", g_szCurrentMap );
		}
		case ZONE_BONUS_1_START :
		{
			FormatEx( g_szQuery_Med, sizeof( g_szQuery_Med ), "UPDATE _mapbounds SET b1_smin0 = NULL, b1_smin1 = NULL, b1_smin2 = NULL, b1_smax0 = NULL, b1_smax1 = NULL, b1_smax2 = NULL WHERE map = '%s'", g_szCurrentMap );
			g_bIsLoaded[RUN_BONUS_1] = false;
		}
		case ZONE_BONUS_1_END :
		{
			FormatEx( g_szQuery_Med, sizeof( g_szQuery_Med ), "UPDATE _mapbounds SET b1_emin0 = NULL, b1_emin1 = NULL, b1_emin2 = NULL, b1_emax0 = NULL, b1_emax1 = NULL, b1_emax2 = NULL WHERE map = '%s'", g_szCurrentMap );
			g_bIsLoaded[RUN_BONUS_1] = false;
		}
		case ZONE_BONUS_2_START :
		{
			FormatEx( g_szQuery_Med, sizeof( g_szQuery_Med ), "UPDATE _mapbounds SET b2_smin0 = NULL, b2_smin1 = NULL, b2_smin2 = NULL, b2_smax0 = NULL, b2_smax1 = NULL, b2_smax2 = NULL WHERE map = '%s'", g_szCurrentMap );
			g_bIsLoaded[RUN_BONUS_2] = false;
		}
		case ZONE_BONUS_2_END :
		{
			FormatEx( g_szQuery_Med, sizeof( g_szQuery_Med ), "UPDATE _mapbounds SET b2_emin0 = NULL, b2_emin1 = NULL, b2_emin2 = NULL, b2_emax0 = NULL, b2_emax1 = NULL, b2_emax2 = NULL WHERE map = '%s'", g_szCurrentMap );
			g_bIsLoaded[RUN_BONUS_2] = false;
		}
		case ZONE_FREESTYLE_1 :
		{
			FormatEx( g_szQuery_Med, sizeof( g_szQuery_Med ), "UPDATE _mapbounds SET fs1min0 = NULL, fs1min1 = NULL, fs1min2 = NULL, fs1max0 = NULL, fs1max1 = NULL, fs1max2 = NULL WHERE map = '%s'", g_szCurrentMap );
		}
		case ZONE_FREESTYLE_2 :
		{
			FormatEx( g_szQuery_Med, sizeof( g_szQuery_Med ), "UPDATE _mapbounds SET fs2min0 = NULL, fs2min1 = NULL, fs2min2 = NULL, fs2max0 = NULL, fs2max1 = NULL, fs2max2 = NULL WHERE map = '%s'", g_szCurrentMap );
		}
		case ZONE_FREESTYLE_3 :
		{
			FormatEx( g_szQuery_Med, sizeof( g_szQuery_Med ), "UPDATE _mapbounds SET fs3min0 = NULL, fs3min1 = NULL, fs3min2 = NULL, fs3max0 = NULL, fs3max1 = NULL, fs3max2 = NULL WHERE map = '%s'", g_szCurrentMap );
		}
		default : return false;
	}
	
	
	SQL_LockDatabase( g_Database );
	
	if ( !SQL_FastQuery( g_Database, g_szQuery_Med ) )
	{
		SQL_GetError( g_Database, g_szError, sizeof( g_szError ) );
		LogError( CONSOLE_PREFIX ... "Couldn't erase a zone!\nError: %s", g_szError );
		
		SQL_UnlockDatabase( g_Database );
		return false;
	}
	
	SQL_UnlockDatabase( g_Database );
	
	
	g_bZoneExists[zone] = false;
	return true;
}