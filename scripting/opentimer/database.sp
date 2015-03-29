Handle g_Database;
char g_szError[100];

// Used for all the queries.
static char g_szQuery_Small[128];
static char g_szQuery_Med[200];
static char g_szQuery_Big[300];

// Includes all the threaded SQL callbacks.
#include "opentimer/database_thread.sp"

// Print server times to client. This can be done to console (max. 15 records) or to MOTD page (max. 5 records)
// Client can also request individual modes.
stock void PrintRecords( int client, bool bInConsole, int iReqStyle = -1, int iRun = 0 )
{
	int amt;
	
	if ( bInConsole ) amt = 16;
	else amt = 5;
	
	if ( iReqStyle != -1 )
	{
		Format( g_szQuery_Small, sizeof( g_szQuery_Small ), "SELECT * FROM '%s' WHERE style = %i AND run = %i ORDER BY time LIMIT %i;", g_szCurrentMap, iReqStyle, iRun, amt );
	}
	else
	{
		// No requested style.
		Format( g_szQuery_Small, sizeof( g_szQuery_Small ), "SELECT * FROM '%s' WHERE run = %i ORDER BY time LIMIT %i;", g_szCurrentMap, iRun, amt );
	}
	
	Handle hData = CreateArray( 2 );
	
	int iData[2];
	iData[0] = GetClientUserId( client );
	iData[1] = bInConsole;
	
	PushArrayArray( hData, iData, 2 );
	
	SQL_TQuery( g_Database, Threaded_PrintRecords, g_szQuery_Small, hData, DBPrio_Low );
}

// We save the record if needed and print a notification to the chat.
stock bool SaveClientRecord( int client, float flNewTime )
{
	char szSteamID[STEAMID_MAXLENGTH];
	
	if ( !GetClientAuthId( client, AuthId_Engine, szSteamID, sizeof( szSteamID ) ) )
	{
		LogError( "%s There was an error at trying to retrieve player's \"%N\" Steam ID! Cannot save record.", CONSOLE_PREFIX, client );
		return false;
	}
	
	// First time beating or better time than last time.
	if ( g_flClientBestTime[client][ g_iClientRun[client] ][ g_iClientStyle[client] ] <= TIME_INVALID || flNewTime < g_flClientBestTime[client][ g_iClientRun[client] ][ g_iClientStyle[client] ] )
	{
		char szName[MAX_NAME_LENGTH];
		Format( szName, sizeof( szName ), "%N", client );
		
		// I can't believe I forgot about this.
		SQL_EscapeString( g_Database, szName, szName, sizeof( szName ) );
		
		// Insert new if we haven't beaten this one yet. Replace otherwise.
		Format( g_szQuery_Med, sizeof( g_szQuery_Med ), "INSERT OR REPLACE INTO '%s' ( steamid, name, time, jumps, style, strafes, run ) VALUES ( '%s', '%s', '%.3f', %i, %i, %i, %i );", g_szCurrentMap, szSteamID, szName, flNewTime, g_iClientJumpCount[client], g_iClientStyle[client], g_iClientStrafeCount[client], g_iClientRun[client] );
		
		SQL_TQuery( g_Database, Threaded_Empty, g_szQuery_Med, _, DBPrio_High );
	}
	////////////////////////////////////////////////////////////////////////////////
	// Print record in chat. Only here because my eyes are dying from repetition. //
	////////////////////////////////////////////////////////////////////////////////
	float flLeftSeconds;
	
	// This is to format the time correctly.
	if ( flNewTime > g_flMapBestTime[ g_iClientRun[client] ][ g_iClientStyle[client] ] )
	{
		// Show them how many seconds it was off of from the record. E.g +00:01:33.70
		flLeftSeconds = flNewTime - g_flMapBestTime[ g_iClientRun[client] ][ g_iClientStyle[client] ];
	}
	else
	{
		// We got a better time than the best record! E.g -00:00:01.00
		flLeftSeconds = g_flMapBestTime[ g_iClientRun[client] ][ g_iClientStyle[client] ] - flNewTime;
	}
	
	char			szFormTime[17];
	FormatSeconds( flNewTime, szFormTime, sizeof( szFormTime ), true, true );
	
	static char		szTxt[192];
	bool			bIsBest;
	
	// New time if under or equal to 0
	if ( g_flClientBestTime[client][ g_iClientRun[client] ][ g_iClientStyle[client] ] <= TIME_INVALID ) 
	{
		if ( flNewTime > g_flMapBestTime[ g_iClientRun[client] ][ g_iClientStyle[client] ] )
		{
			Format( szTxt, sizeof( szTxt ), "%s \x03%N%s finished \x03%s%s for the first time [%s%s%s]!\n\x06(%s\x06)", CHAT_PREFIX, client, COLOR_TEXT, g_szRunName[NAME_LONG][ g_iClientRun[client] ], COLOR_TEXT, COLOR_GRAY, g_szStyleName[NAME_SHORT][ g_iClientStyle[client] ], COLOR_TEXT, szFormTime );
			
			if ( g_flMapBestTime[ g_iClientRun[client] ][ g_iClientStyle[client] ] <= TIME_INVALID )
			{
				bIsBest = true;
			}
		}
		else
		{
			Format( szTxt, sizeof( szTxt ), "%s \x03%N%s broke \x03%s%s record [%s%s%s]!\n\x06(%s\x06) Improving \x03%.2f\x06sec!", CHAT_PREFIX, client, COLOR_TEXT, g_szRunName[NAME_LONG][ g_iClientRun[client] ], COLOR_TEXT, COLOR_GRAY, g_szStyleName[NAME_SHORT][ g_iClientStyle[client] ], COLOR_TEXT, szFormTime, flLeftSeconds );
			bIsBest = true;
		}
	}
	else
	{
		if ( flNewTime >= g_flMapBestTime[ g_iClientRun[client] ][ g_iClientStyle[client] ] )
		{
			if ( flNewTime > g_flClientBestTime[client][ g_iClientRun[client] ][ g_iClientStyle[client] ] )
			{
				Format( szTxt, sizeof( szTxt ), "%s \x03%N%s finished \x03%s%s [%s%s%s]!\n\x06(%s\x06)", CHAT_PREFIX, client, COLOR_TEXT, g_szRunName[NAME_LONG][ g_iClientRun[client] ], COLOR_TEXT, COLOR_GRAY, g_szStyleName[NAME_SHORT][ g_iClientStyle[client] ], COLOR_TEXT, szFormTime );
			}
			else
			{
				Format( szTxt, sizeof( szTxt ), "%s \x03%N%s finished \x03%s%s [%s%s%s]!\n\x06(%s\x06) Improving \x03%.2f\x06sec!", CHAT_PREFIX, client, COLOR_TEXT, g_szRunName[NAME_LONG][ g_iClientRun[client] ], COLOR_TEXT, COLOR_GRAY, g_szStyleName[NAME_SHORT][ g_iClientStyle[client] ], COLOR_TEXT, szFormTime, g_flClientBestTime[client][ g_iClientRun[client] ][ g_iClientStyle[client] ] - flNewTime );
			}
		}
		else
		{
			Format( szTxt, sizeof( szTxt ), "%s \x03%N%s broke \x03%s%s record [%s%s%s]!\n\x06(%s\x06) Improving \x03%.2f\x06sec!", CHAT_PREFIX, client, COLOR_TEXT, g_szRunName[NAME_LONG][ g_iClientRun[client] ], COLOR_TEXT, COLOR_GRAY, g_szStyleName[NAME_SHORT][ g_iClientStyle[client] ], COLOR_TEXT, szFormTime, flLeftSeconds );
			bIsBest = true;
		}
	}
	
	PrintColorChatAll( client, false, szTxt );
	
	
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
	if ( g_flClientBestTime[client][ g_iClientRun[client] ][ g_iClientStyle[client] ] <= TIME_INVALID || flNewTime < g_flClientBestTime[client][ g_iClientRun[client] ][ g_iClientStyle[client] ] )
	{
		g_flClientBestTime[client][ g_iClientRun[client] ][ g_iClientStyle[client] ] = flNewTime;
	}
	
	
	// Save if best time and save the recording on disk. :)
	if ( g_flMapBestTime[ g_iClientRun[client] ][ g_iClientStyle[client] ] <= TIME_INVALID || flNewTime < g_flMapBestTime[ g_iClientRun[client] ][ g_iClientStyle[client] ] )
	{
		g_flMapBestTime[ g_iClientRun[client] ][ g_iClientStyle[client] ] = flNewTime;
		
#if defined RECORD
		if ( g_bIsClientRecording[client] && g_hClientRecording[client] != null )
		{
			int len = GetArraySize( g_hClientRecording[client] );
			
			if ( len > MIN_REC_SIZE )
			{
				if ( !SaveRecording( client, flNewTime, len ) )
					return false;
				
				// We saved. Now let's update the bot!
				
				// Reset stuff just in case we happen to fuck up something.
				g_bIsClientMimicing[ g_iMimic[ g_iClientRun[client] ][ g_iClientStyle[client] ] ] = false;
				g_iClientTick[ g_iMimic[ g_iClientRun[client] ][ g_iClientStyle[client] ] ] = -1;
				
				// Clone client's recording to the mimic.
				g_hMimicRecording[ g_iClientRun[client] ][ g_iClientStyle[client] ] = CloneArray( g_hClientRecording[client] );
				g_iMimicTickMax[ g_iClientRun[client] ][ g_iClientStyle[client] ] = len;
				
				// Then we change mimic's name...
				Format( g_szMimicName[ g_iClientRun[client] ][ g_iClientStyle[client] ], sizeof( g_szMimicName[][] ), "%N", client );
				
				// Copy player's initial position and angles to mimic.
				ArrayCopy( g_vecInitPos[client], g_vecInitMimicPos[ g_iClientRun[client] ][ g_iClientStyle[client] ], 3 );
				ArrayCopy( g_angInitAngles[client], g_angInitMimicAngles[ g_iClientRun[client] ][ g_iClientStyle[client] ], 2 );
				
				if ( g_iMimic[ g_iClientRun[client] ][ g_iClientStyle[client] ] != 0 ) // We already have a bot? Let's use him instead.
				{
					char szName[MAX_NAME_LENGTH];
					Format( szName, sizeof( szName ), "REC* %s [%s|%s]", g_szMimicName[ g_iClientRun[client] ][ g_iClientStyle[client] ], g_szRunName[NAME_SHORT][ g_iClientRun[client] ], g_szStyleName[NAME_SHORT][ g_iClientStyle[client] ] );
					SetClientInfo( g_iMimic[ g_iClientRun[client] ][ g_iClientStyle[client] ], "name", szName );
					
					// Finally set the mimic's time in the scoreboard.
					char szTime[12];
					FormatSeconds( g_flMapBestTime[ g_iClientRun[client] ][ g_iClientStyle[client] ], szTime, sizeof( szTime ), false );
					CS_SetClientClanTag( g_iMimic[ g_iClientRun[client] ][ g_iClientStyle[client] ], szTime );
					
					
					TeleportEntity( g_iMimic[ g_iClientRun[client] ][ g_iClientStyle[client] ], g_vecInitMimicPos[ g_iClientRun[client] ][ g_iClientStyle[client] ], g_angInitMimicAngles[ g_iClientRun[client] ][ g_iClientStyle[client] ], g_vecNull );
					
					CreateTimer( 2.0, Timer_Rec_Start, g_iMimic[ g_iClientRun[client] ][ g_iClientStyle[client] ] );
				}
				else // Create new if one doesn't exist
				{
					g_iNumMimic++;
					ServerCommand( "bot_quota %i", g_iNumMimic );
				}
			}
		}
#endif
	}
	
	UpdateScoreboard( client );
	
	return true;
}

// SAVE EVERYTHINNNNNNNNNNNNNNGGGGGGGGGGGGGGGGGGG
stock bool SaveClientInfo( int client )
{
	if ( g_Database == null ) return false;
	
	char szSteamID[STEAMID_MAXLENGTH];
	
	if ( !GetClientAuthId( client, AuthId_Engine, szSteamID, sizeof( szSteamID ) ) )
	{
		LogError( "%s There was an error at trying to retrieve player's \"%N\" Steam ID! Cannot save record.", CONSOLE_PREFIX, client );
		return false;
	}
	
	
	Format( g_szQuery_Small, sizeof( g_szQuery_Small ), "UPDATE player_data SET fov = %i, hideflags = %i WHERE steamid = '%s';", g_iClientFOV[client], g_iClientHideFlags[client], szSteamID );
	
	SQL_TQuery( g_Database, Threaded_Empty, g_szQuery_Small, _, DBPrio_Low );
	
	return true;
}

// Get client options (fov and hideflags) and time it took him/her to beat the map in all modes.
stock void RetrieveClientInfo( int client )
{
	char szSteamID[STEAMID_MAXLENGTH];
	
	if ( !GetClientAuthId( client, AuthId_Engine, szSteamID, sizeof( szSteamID ) ) )
	{
		LogError( "%s There was an error at trying to retrieve player's \"%N\" Steam ID! Cannot save record.", CONSOLE_PREFIX, client );
		return;
	}
	
	Format( g_szQuery_Small, sizeof( g_szQuery_Small ), "SELECT * FROM player_data WHERE steamid = '%s';", szSteamID );
	
	SQL_TQuery( g_Database, Threaded_RetrieveClientInfo, g_szQuery_Small, GetClientUserId( client ), DBPrio_High );
}

// Initialize sounds so important. I'm so cool.
// Create connection with database!
stock void InitializeDatabase()
{
	// Creates opentimer.sq3 in the data folder.
	Handle kv = CreateKeyValues( "" );
	KvSetString( kv, "driver", "sqlite" );
	KvSetString( kv, "database", "opentimer" );
	
	g_Database = SQL_ConnectCustom( kv, g_szError, sizeof( g_szError ), false );
	
	delete kv;
	
	if ( g_Database == null )
	{
		SetFailState( "%s Unable to establish connection to database!\n g_szError: %s", CONSOLE_PREFIX, g_szError );
		return;
	}
	
	SQL_LockDatabase( g_Database );
	
	if ( !SQL_FastQuery( g_Database, "CREATE TABLE IF NOT EXISTS player_data ( steamid VARCHAR( 32 ) PRIMARY KEY, fov INTEGER, hideflags INTEGER );" ) )
	{
		SQL_UnlockDatabase( g_Database );
		
		SQL_GetError( g_Database, g_szError, sizeof( g_szError ) );
		SetFailState( "%s Plugin was unable to create table for player profiles!\nError: %s", CONSOLE_PREFIX, g_szError );
		
		return;
	}
	
	SQL_UnlockDatabase( g_Database );
	
	PrintToServer( "%s Established connection with database!", CONSOLE_PREFIX );
}

// Get map bounds, mimics and vote-able maps
stock void InitializeMapBounds()
{
	if ( g_Database == null )
		SetFailState( "%s No connection to database. Unable to retrieve map data!", CONSOLE_PREFIX );
	
	SQL_LockDatabase( g_Database );
	
	if ( !SQL_FastQuery( g_Database, "CREATE TABLE IF NOT EXISTS _mapbounds ( map VARCHAR( 32 ) PRIMARY KEY, smin0 REAL, smin1 REAL, smin2 REAL, smax0 REAL, smax1 REAL, smax2 REAL, emin0 REAL, emin1 REAL, emin2 REAL, emax0 REAL, emax1 REAL, emax2 REAL, bl1min0 REAL, bl1min1 REAL, bl1min2 REAL, bl1max0 REAL, bl1max1 REAL, bl1max2 REAL, bl2min0 REAL, bl2min1 REAL, bl2min2 REAL, bl2max0 REAL, bl2max1 REAL, bl2max2 REAL, bl3min0 REAL, bl3min1 REAL, bl3min2 REAL, bl3max0 REAL, bl3max1 REAL, bl3max2 REAL, b1_smin0 REAL, b1_smin1 REAL, b1_smin2 REAL, b1_smax0 REAL, b1_smax1 REAL, b1_smax2 REAL, b1_emin0 REAL, b1_emin1 REAL, b1_emin2 REAL, b1_emax0 REAL, b1_emax1 REAL, b1_emax2 REAL, b2_smin0 REAL, b2_smin1 REAL, b2_smin2 REAL, b2_smax0 REAL, b2_smax1 REAL, b2_smax2 REAL, b2_emin0 REAL, b2_emin1 REAL, b2_emin2 REAL, b2_emax0 REAL, b2_emax1 REAL, b2_emax2 REAL, fs1min0 REAL, fs1min1 REAL, fs1min2 REAL, fs1max0 REAL, fs1max1 REAL, fs1max2 REAL, fs2min0 REAL, fs2min1 REAL, fs2min2 REAL, fs2max0 REAL, fs2max1 REAL, fs2max2 REAL, fs3min0 REAL, fs3min1 REAL, fs3min2 REAL, fs3max0 REAL, fs3max1 REAL, fs3max2 REAL );" ) )
	{
		SQL_UnlockDatabase( g_Database );
		
		SQL_GetError( g_Database, g_szError, sizeof( g_szError ) );
		SetFailState( "%s Couldn't create map bounds table!\nError: %s", CONSOLE_PREFIX, g_szError );
		return;
	}
	
	Format( g_szQuery_Big, sizeof( g_szQuery_Big ), "CREATE TABLE IF NOT EXISTS '%s' ( steamid VARCHAR( 32 ) NOT NULL, run INTEGER NOT NULL, style INTEGER NOT NULL, name VARCHAR( 64 ), time REAL, jumps INTEGER , strafes INTEGER, PRIMARY KEY ( steamid, run, style ) );", g_szCurrentMap );
	
	if ( !SQL_FastQuery( g_Database, g_szQuery_Big ) )
	{
		SQL_UnlockDatabase( g_Database );
		
		SQL_GetError( g_Database, g_szError, sizeof( g_szError ) );
		SetFailState( "%s Couldn't create map record table!\nError: %s", CONSOLE_PREFIX, g_szError );
		return;
	}
	
	Format( g_szQuery_Big, sizeof( g_szQuery_Big ), "SELECT * FROM _mapbounds WHERE map = '%s';", g_szCurrentMap );
	Handle hQuery = SQL_Query( g_Database, g_szQuery_Big );
	
	if ( hQuery == null )
	{
		SQL_UnlockDatabase( g_Database );
		
		SQL_GetError( g_Database, g_szError, sizeof( g_szError ) );
		SetFailState( "%s Unable to retrieve map bounds!\nError: %s", CONSOLE_PREFIX, g_szError );
		return;
	}
	
	int field;
	
	if ( SQL_GetRowCount( hQuery ) == 0 )
	{
		Format( g_szQuery_Big, sizeof( g_szQuery_Big ), "INSERT INTO _mapbounds ( map ) VALUES ( '%s' );", g_szCurrentMap );
		
		if ( !SQL_FastQuery( g_Database, g_szQuery_Big ) )
		{
			delete hQuery;
			
			SQL_UnlockDatabase( g_Database );
			
			SQL_GetError( g_Database, g_szError, sizeof( g_szError ) );
			SetFailState( "%s Couldn't create map bounds table!\nError: %s", CONSOLE_PREFIX, g_szError );
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
			// START BOUNDS
			SQL_FieldNameToNum( hQuery, "smin0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				g_vecBoundsMin[BOUNDS_START][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "smin1", field );
				g_vecBoundsMin[BOUNDS_START][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "smin2", field );
				g_vecBoundsMin[BOUNDS_START][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "smax0", field );
				g_vecBoundsMax[BOUNDS_START][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "smax1", field );
				g_vecBoundsMax[BOUNDS_START][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "smax2", field );
				g_vecBoundsMax[BOUNDS_START][2] = SQL_FetchFloat( hQuery, field );

				g_bZoneExists[BOUNDS_START] = true;
			}
			else g_bZoneExists[BOUNDS_START] = false;
			
			// END BOUNDS
			SQL_FieldNameToNum( hQuery, "emin0", field );

			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				g_vecBoundsMin[BOUNDS_END][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "emin1", field );
				g_vecBoundsMin[BOUNDS_END][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "emin2", field );
				g_vecBoundsMin[BOUNDS_END][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "emax0", field );
				g_vecBoundsMax[BOUNDS_END][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "emax1", field );
				g_vecBoundsMax[BOUNDS_END][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "emax2", field );
				g_vecBoundsMax[BOUNDS_END][2] = SQL_FetchFloat( hQuery, field );

				g_bZoneExists[BOUNDS_END] = true;
			}
			else g_bZoneExists[BOUNDS_END] = false;
	
			// BLOCK BOUNDS
			// BLOCK #1
			SQL_FieldNameToNum( hQuery, "bl1min0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				g_vecBoundsMin[BOUNDS_BLOCK_1][0] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "bl1min1", field );
				g_vecBoundsMin[BOUNDS_BLOCK_1][1] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "bl1min2", field );
				g_vecBoundsMin[BOUNDS_BLOCK_1][2] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "bl1max0", field );
				g_vecBoundsMax[BOUNDS_BLOCK_1][0] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "bl1max1", field );
				g_vecBoundsMax[BOUNDS_BLOCK_1][1] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "bl1max2", field );
				g_vecBoundsMax[BOUNDS_BLOCK_1][2] = SQL_FetchFloat( hQuery, field );
				
				g_bZoneExists[BOUNDS_BLOCK_1] = true;
			}
			else g_bZoneExists[BOUNDS_BLOCK_1] = false;
			
			// BLOCK #2
			SQL_FieldNameToNum( hQuery, "bl2min0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				g_vecBoundsMin[BOUNDS_BLOCK_2][0] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "bl2min1", field );
				g_vecBoundsMin[BOUNDS_BLOCK_2][1] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "bl2min2", field );
				g_vecBoundsMin[BOUNDS_BLOCK_2][2] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "bl2max0", field );
				g_vecBoundsMax[BOUNDS_BLOCK_2][0] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "bl2max1", field );
				g_vecBoundsMax[BOUNDS_BLOCK_2][1] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "bl2max2", field );
				g_vecBoundsMax[BOUNDS_BLOCK_2][2] = SQL_FetchFloat( hQuery, field );
				
				g_bZoneExists[BOUNDS_BLOCK_2] = true;
			}
			else g_bZoneExists[BOUNDS_BLOCK_2] = false;
			
			
			// BLOCK #3
			SQL_FieldNameToNum( hQuery, "bl3min0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				g_vecBoundsMin[BOUNDS_BLOCK_3][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "bl3min1", field );
				g_vecBoundsMin[BOUNDS_BLOCK_3][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "bl3min2", field );
				g_vecBoundsMin[BOUNDS_BLOCK_3][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "bl3max0", field );
				g_vecBoundsMax[BOUNDS_BLOCK_3][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "bl3max1", field );
				g_vecBoundsMax[BOUNDS_BLOCK_3][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "bl3max2", field );
				g_vecBoundsMax[BOUNDS_BLOCK_3][2] = SQL_FetchFloat( hQuery, field );

				g_bZoneExists[BOUNDS_BLOCK_3] = true;
			}
			else g_bZoneExists[BOUNDS_BLOCK_3] = false;
			
			
			// BONUS #1 START
			SQL_FieldNameToNum( hQuery, "b1_smin0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				g_vecBoundsMin[BOUNDS_BONUS_1_START][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "b1_smin1", field );
				g_vecBoundsMin[BOUNDS_BONUS_1_START][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b1_smin2", field );
				g_vecBoundsMin[BOUNDS_BONUS_1_START][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b1_smax0", field );
				g_vecBoundsMax[BOUNDS_BONUS_1_START][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b1_smax1", field );
				g_vecBoundsMax[BOUNDS_BONUS_1_START][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b1_smax2", field );
				g_vecBoundsMax[BOUNDS_BONUS_1_START][2] = SQL_FetchFloat( hQuery, field );

				g_bZoneExists[BOUNDS_BONUS_1_START] = true;
			}
			else g_bZoneExists[BOUNDS_BONUS_1_START] = false;
			
			// BONUS #1 END
			SQL_FieldNameToNum( hQuery, "b1_emin0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				g_vecBoundsMin[BOUNDS_BONUS_1_END][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "b1_emin1", field );
				g_vecBoundsMin[BOUNDS_BONUS_1_END][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b1_emin2", field );
				g_vecBoundsMin[BOUNDS_BONUS_1_END][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b1_emax0", field );
				g_vecBoundsMax[BOUNDS_BONUS_1_END][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b1_emax1", field );
				g_vecBoundsMax[BOUNDS_BONUS_1_END][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b1_emax2", field );
				g_vecBoundsMax[BOUNDS_BONUS_1_END][2] = SQL_FetchFloat( hQuery, field );

				g_bZoneExists[BOUNDS_BONUS_1_END] = true;
			}
			else g_bZoneExists[BOUNDS_BONUS_1_END] = false;
			
			// BONUS #2 START
			SQL_FieldNameToNum( hQuery, "b2_smin0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				g_vecBoundsMin[BOUNDS_BONUS_2_START][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "b2_smin1", field );
				g_vecBoundsMin[BOUNDS_BONUS_2_START][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b2_smin2", field );
				g_vecBoundsMin[BOUNDS_BONUS_2_START][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b2_smax0", field );
				g_vecBoundsMax[BOUNDS_BONUS_2_START][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b2_smax1", field );
				g_vecBoundsMax[BOUNDS_BONUS_2_START][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b2_smax2", field );
				g_vecBoundsMax[BOUNDS_BONUS_2_START][2] = SQL_FetchFloat( hQuery, field );

				g_bZoneExists[BOUNDS_BONUS_2_START] = true;
			}
			else g_bZoneExists[BOUNDS_BONUS_2_START] = false;
			
			// BONUS #2 END
			SQL_FieldNameToNum( hQuery, "b2_emin0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				g_vecBoundsMin[BOUNDS_BONUS_2_END][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "b2_emin1", field );
				g_vecBoundsMin[BOUNDS_BONUS_2_END][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b2_emin2", field );
				g_vecBoundsMin[BOUNDS_BONUS_2_END][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b2_emax0", field );
				g_vecBoundsMax[BOUNDS_BONUS_2_END][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b2_emax1", field );
				g_vecBoundsMax[BOUNDS_BONUS_2_END][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b2_emax2", field );
				g_vecBoundsMax[BOUNDS_BONUS_2_END][2] = SQL_FetchFloat( hQuery, field );

				g_bZoneExists[BOUNDS_BONUS_2_END] = true;
			}
			else g_bZoneExists[BOUNDS_BONUS_2_END] = false;
			
			
			// FREESTYLE #1
			// ROCK THE MICROPHONE WITH A FREESTYLER
			SQL_FieldNameToNum( hQuery, "fs1min0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				g_vecBoundsMin[BOUNDS_FREESTYLE_1][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "fs1min1", field );
				g_vecBoundsMin[BOUNDS_FREESTYLE_1][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs1min2", field );
				g_vecBoundsMin[BOUNDS_FREESTYLE_1][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs1max0", field );
				g_vecBoundsMax[BOUNDS_FREESTYLE_1][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs1max1", field );
				g_vecBoundsMax[BOUNDS_FREESTYLE_1][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs1max2", field );
				g_vecBoundsMax[BOUNDS_FREESTYLE_1][2] = SQL_FetchFloat( hQuery, field );

				g_bZoneExists[BOUNDS_FREESTYLE_1] = true;
			}
			else g_bZoneExists[BOUNDS_FREESTYLE_1] = false;
			
			// FREESTYLE #2
			SQL_FieldNameToNum( hQuery, "fs2min0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				g_vecBoundsMin[BOUNDS_FREESTYLE_2][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "fs2min1", field );
				g_vecBoundsMin[BOUNDS_FREESTYLE_2][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs2min2", field );
				g_vecBoundsMin[BOUNDS_FREESTYLE_2][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs2max0", field );
				g_vecBoundsMax[BOUNDS_FREESTYLE_2][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs2max1", field );
				g_vecBoundsMax[BOUNDS_FREESTYLE_2][1] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "fs2max2", field );
				g_vecBoundsMax[BOUNDS_FREESTYLE_2][2] = SQL_FetchFloat( hQuery, field );

				g_bZoneExists[BOUNDS_FREESTYLE_2] = true;
			}
			else g_bZoneExists[BOUNDS_FREESTYLE_2] = false;
			
			// FREESTYLE #3
			SQL_FieldNameToNum( hQuery, "fs3min0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				g_vecBoundsMin[BOUNDS_FREESTYLE_3][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "fs3min1", field );
				g_vecBoundsMin[BOUNDS_FREESTYLE_3][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs3min2", field );
				g_vecBoundsMin[BOUNDS_FREESTYLE_3][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs3max0", field );
				g_vecBoundsMax[BOUNDS_FREESTYLE_3][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs3max1", field );
				g_vecBoundsMax[BOUNDS_FREESTYLE_3][1] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "fs3max2", field );
				g_vecBoundsMax[BOUNDS_FREESTYLE_3][2] = SQL_FetchFloat( hQuery, field );

				g_bZoneExists[BOUNDS_FREESTYLE_3] = true;
			}
			else g_bZoneExists[BOUNDS_FREESTYLE_3] = false;
		}
	}

	if ( !g_bZoneExists[BOUNDS_START] || !g_bZoneExists[BOUNDS_END] )
	{
		PrintToServer( "%s Map is lacking bounds...", CONSOLE_PREFIX );
		g_bIsLoaded[RUN_MAIN] = false;
	}
	else g_bIsLoaded[RUN_MAIN] = true;
	
	
	g_bIsLoaded[RUN_BONUS_1] = ( !g_bZoneExists[BOUNDS_BONUS_1_START] || !g_bZoneExists[BOUNDS_BONUS_1_END] ) ? false : true;
	
	g_bIsLoaded[RUN_BONUS_2] = ( !g_bZoneExists[BOUNDS_BONUS_2_START] || !g_bZoneExists[BOUNDS_BONUS_2_END] ) ? false : true;
	
	
	
	// Get map info for records and votes!
#if defined RECORD
	Format( g_szQuery_Big, sizeof( g_szQuery_Big ), "SELECT run, style, MIN( time ), steamid, name FROM %s GROUP BY run, style ORDER BY run;", g_szCurrentMap );
#else
	Format( g_szQuery_Big, sizeof( g_szQuery_Big ), "SELECT run, style, MIN( time ) FROM %s GROUP BY run, style ORDER BY run;", g_szCurrentMap );
#endif
	
	hQuery = SQL_Query( g_Database, g_szQuery_Big );
	
	if ( hQuery == null )
	{
		SQL_UnlockDatabase( g_Database );
		
		SQL_GetError( g_Database, g_szError, sizeof( g_szError ) );
		SetFailState( "%s Unable to retrieve map best times!\nError: %s", CONSOLE_PREFIX, g_szError );
		return;
	}
	
	int		iStyle;
	int		iRun;
#if defined RECORD
	char	szSteamID[STEAMID_MAXLENGTH];
	char	szName[MAX_NAME_LENGTH];
	
	g_iNumMimic = 0;
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
		// Assigning the records to bots are done in OnClientPostAdminCheck()
		SQL_FetchString( hQuery, 3, szSteamID, sizeof( szSteamID ) );
		SQL_FetchString( hQuery, 4, szName, sizeof( szName ) );
		
		if ( LoadRecording( szSteamID, iRun, iStyle ) )
		{
			PrintToServer( "%s Recording found! (%s | %s)", CONSOLE_PREFIX, g_szRunName[NAME_SHORT][iRun], g_szStyleName[NAME_SHORT][iStyle] );
			
			strcopy( g_szMimicName[iRun][iStyle], sizeof( g_szMimicName[][] ), szName );
			g_iNumMimic++;
		}
#endif
	}
	
	delete hQuery;
	SQL_UnlockDatabase( g_Database );
	
#if defined RECORD
	ServerCommand( "bot_quota %i", g_iNumMimic );
	PrintToServer( "%s Spawning %i record bots...", CONSOLE_PREFIX, g_iNumMimic );
#endif
	
	DoMapStuff();
}

// Get maps from database that have start and end zones and start with bhop_ or kz_.
#if defined VOTING
	stock void FindMaps()
	{
		SQL_LockDatabase( g_Database );
		
		Handle hQuery = SQL_Query( g_Database, "SELECT map FROM _mapbounds WHERE smin0 IS NOT NULL AND emin0 IS NOT NULL AND ( map LIKE 'bhop_%' OR map LIKE 'kz_%' ) ORDER BY map;" );

		if ( hQuery == null )
		{
			SQL_UnlockDatabase( g_Database );
			
			SQL_GetError( g_Database, g_szError, sizeof( g_szError ) );
			SetFailState( "%s Plugin was unable to recieve tables (map names) from database!!\nError: %s", CONSOLE_PREFIX, g_szError );
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

stock bool SaveMapCoords( int bounds )
{
	switch ( bounds )
	{
		case BOUNDS_START :
		{
			Format( g_szQuery_Big, sizeof( g_szQuery_Big ), "UPDATE _mapbounds SET smin0 = %.0f, smin1 = %.0f, smin2 = %.0f, smax0 = %.0f, smax1 = %.0f, smax2 = %.0f WHERE map = '%s';",
				g_vecBoundsMin[BOUNDS_START][0], g_vecBoundsMin[BOUNDS_START][1], g_vecBoundsMin[BOUNDS_START][2],
				g_vecBoundsMax[BOUNDS_START][0], g_vecBoundsMax[BOUNDS_START][1], g_vecBoundsMax[BOUNDS_START][2], g_szCurrentMap );
		}
		case BOUNDS_END :
		{
			Format( g_szQuery_Big, sizeof( g_szQuery_Big ), "UPDATE _mapbounds SET emin0 = %.0f, emin1 = %.0f, emin2 = %.0f, emax0 = %.0f, emax1 = %.0f, emax2 = %.0f WHERE map = '%s';",
				g_vecBoundsMin[BOUNDS_END][0], g_vecBoundsMin[BOUNDS_END][1], g_vecBoundsMin[BOUNDS_END][2],
				g_vecBoundsMax[BOUNDS_END][0], g_vecBoundsMax[BOUNDS_END][1], g_vecBoundsMax[BOUNDS_END][2], g_szCurrentMap );
		}
		case BOUNDS_BLOCK_1 :
		{
			Format( g_szQuery_Big, sizeof( g_szQuery_Big ), "UPDATE _mapbounds SET bl1min0 = %.0f, bl1min1 = %.0f, bl1min2 = %.0f, bl1max0 = %.0f, bl1max1 = %.0f, bl1max2 = %.0f WHERE map = '%s';",
				g_vecBoundsMin[BOUNDS_BLOCK_1][0], g_vecBoundsMin[BOUNDS_BLOCK_1][1], g_vecBoundsMin[BOUNDS_BLOCK_1][2],
				g_vecBoundsMax[BOUNDS_BLOCK_1][0], g_vecBoundsMax[BOUNDS_BLOCK_1][1], g_vecBoundsMax[BOUNDS_BLOCK_1][2], g_szCurrentMap );
		}
		case BOUNDS_BLOCK_2 :
		{
			Format( g_szQuery_Big, sizeof( g_szQuery_Big ), "UPDATE _mapbounds SET bl2min0 = %.0f, bl2min1 = %.0f, bl2min2 = %.0f, bl2max0 = %.0f, bl2max1 = %.0f, bl2max2 = %.0f WHERE map = '%s';",
				g_vecBoundsMin[BOUNDS_BLOCK_2][0], g_vecBoundsMin[BOUNDS_BLOCK_2][1], g_vecBoundsMin[BOUNDS_BLOCK_2][2],
				g_vecBoundsMax[BOUNDS_BLOCK_2][0], g_vecBoundsMax[BOUNDS_BLOCK_2][1], g_vecBoundsMax[BOUNDS_BLOCK_2][2], g_szCurrentMap );
		}
		case BOUNDS_BLOCK_3 :
		{
			Format( g_szQuery_Big, sizeof( g_szQuery_Big ), "UPDATE _mapbounds SET bl3min0 = %.0f, bl3min1 = %.0f, bl3min2 = %.0f, bl3max0 = %.0f, bl3max1 = %.0f, bl3max2 = %.0f WHERE map = '%s';",
				g_vecBoundsMin[BOUNDS_BLOCK_3][0], g_vecBoundsMin[BOUNDS_BLOCK_3][1], g_vecBoundsMin[BOUNDS_BLOCK_3][2],
				g_vecBoundsMax[BOUNDS_BLOCK_3][0], g_vecBoundsMax[BOUNDS_BLOCK_3][1], g_vecBoundsMax[BOUNDS_BLOCK_3][2], g_szCurrentMap );
		}
		case BOUNDS_BONUS_1_START :
		{
			Format( g_szQuery_Big, sizeof( g_szQuery_Big ), "UPDATE _mapbounds SET b1_smin0 = %.0f, b1_smin1 = %.0f, b1_smin2 = %.0f, b1_smax0 = %.0f, b1_smax1 = %.0f, b1_smax2 = %.0f WHERE map = '%s';",
				g_vecBoundsMin[BOUNDS_BONUS_1_START][0], g_vecBoundsMin[BOUNDS_BONUS_1_START][1], g_vecBoundsMin[BOUNDS_BONUS_1_START][2],
				g_vecBoundsMax[BOUNDS_BONUS_1_START][0], g_vecBoundsMax[BOUNDS_BONUS_1_START][1], g_vecBoundsMax[BOUNDS_BONUS_1_START][2], g_szCurrentMap );
		}
		case BOUNDS_BONUS_1_END :
		{
			Format( g_szQuery_Big, sizeof( g_szQuery_Big ), "UPDATE _mapbounds SET b1_emin0 = %.0f, b1_emin1 = %.0f, b1_emin2 = %.0f, b1_emax0 = %.0f, b1_emax1 = %.0f, b1_emax2 = %.0f WHERE map = '%s';",
				g_vecBoundsMin[BOUNDS_BONUS_1_END][0], g_vecBoundsMin[BOUNDS_BONUS_1_END][1], g_vecBoundsMin[BOUNDS_BONUS_1_END][2],
				g_vecBoundsMax[BOUNDS_BONUS_1_END][0], g_vecBoundsMax[BOUNDS_BONUS_1_END][1], g_vecBoundsMax[BOUNDS_BONUS_1_END][2], g_szCurrentMap );
		}
		case BOUNDS_BONUS_2_START :
		{
			Format( g_szQuery_Big, sizeof( g_szQuery_Big ), "UPDATE _mapbounds SET b2_smin0 = %.0f, b2_smin1 = %.0f, b2_smin2 = %.0f, b2_smax0 = %.0f, b2_smax1 = %.0f, b2_smax2 = %.0f WHERE map = '%s';",
				g_vecBoundsMin[BOUNDS_BONUS_2_START][0], g_vecBoundsMin[BOUNDS_BONUS_2_START][1], g_vecBoundsMin[BOUNDS_BONUS_2_START][2],
				g_vecBoundsMax[BOUNDS_BONUS_2_START][0], g_vecBoundsMax[BOUNDS_BONUS_2_START][1], g_vecBoundsMax[BOUNDS_BONUS_2_START][2], g_szCurrentMap );
		}
		case BOUNDS_BONUS_2_END :
		{
			Format( g_szQuery_Big, sizeof( g_szQuery_Big ), "UPDATE _mapbounds SET b2_emin0 = %.0f, b2_emin1 = %.0f, b2_emin2 = %.0f, b2_emax0 = %.0f, b2_emax1 = %.0f, b2_emax2 = %.0f WHERE map = '%s';",
				g_vecBoundsMin[BOUNDS_BONUS_2_END][0], g_vecBoundsMin[BOUNDS_BONUS_2_END][1], g_vecBoundsMin[BOUNDS_BONUS_2_END][2],
				g_vecBoundsMax[BOUNDS_BONUS_2_END][0], g_vecBoundsMax[BOUNDS_BONUS_2_END][1], g_vecBoundsMax[BOUNDS_BONUS_2_END][2], g_szCurrentMap );
		}
		case BOUNDS_FREESTYLE_1 :
		{
			Format( g_szQuery_Big, sizeof( g_szQuery_Big ), "UPDATE _mapbounds SET fs1min0 = %.0f, fs1min1 = %.0f, fs1min2 = %.0f, fs1max0 = %.0f, fs1max1 = %.0f, fs1max2 = %.0f WHERE map = '%s';",
				g_vecBoundsMin[BOUNDS_FREESTYLE_1][0], g_vecBoundsMin[BOUNDS_FREESTYLE_1][1], g_vecBoundsMin[BOUNDS_FREESTYLE_1][2],
				g_vecBoundsMax[BOUNDS_FREESTYLE_1][0], g_vecBoundsMax[BOUNDS_FREESTYLE_1][1], g_vecBoundsMax[BOUNDS_FREESTYLE_1][2], g_szCurrentMap );
		}
		case BOUNDS_FREESTYLE_2 :
		{
			Format( g_szQuery_Big, sizeof( g_szQuery_Big ), "UPDATE _mapbounds SET fs2min0 = %.0f, fs2min1 = %.0f, fs2min2 = %.0f, fs2max0 = %.0f, fs2max1 = %.0f, fs2max2 = %.0f WHERE map = '%s';",
				g_vecBoundsMin[BOUNDS_FREESTYLE_2][0], g_vecBoundsMin[BOUNDS_FREESTYLE_2][1], g_vecBoundsMin[BOUNDS_FREESTYLE_2][2],
				g_vecBoundsMax[BOUNDS_FREESTYLE_2][0], g_vecBoundsMax[BOUNDS_FREESTYLE_2][1], g_vecBoundsMax[BOUNDS_FREESTYLE_2][2], g_szCurrentMap );
		}
		case BOUNDS_FREESTYLE_3 :
		{
			Format( g_szQuery_Big, sizeof( g_szQuery_Big ), "UPDATE _mapbounds SET fs3min0 = %.0f, fs3min1 = %.0f, fs3min2 = %.0f, fs3max0 = %.0f, fs3max1 = %.0f, fs3max2 = %.0f WHERE map = '%s';",
				g_vecBoundsMin[BOUNDS_FREESTYLE_3][0], g_vecBoundsMin[BOUNDS_FREESTYLE_3][1], g_vecBoundsMin[BOUNDS_FREESTYLE_3][2],
				g_vecBoundsMax[BOUNDS_FREESTYLE_3][0], g_vecBoundsMax[BOUNDS_FREESTYLE_3][1], g_vecBoundsMax[BOUNDS_FREESTYLE_3][2], g_szCurrentMap );
		}
		default : return false;
	}
	
	SQL_LockDatabase( g_Database );
	
	if ( !SQL_FastQuery( g_Database, g_szQuery_Big ) )
	{
		SQL_GetError( g_Database, g_szError, sizeof( g_szError ) );
		LogError( "%s Couldn't save map's ending bounds!\nError: %s", CONSOLE_PREFIX, g_szError );
		
		SQL_UnlockDatabase( g_Database );
		return false;
	}
	
	SQL_UnlockDatabase( g_Database );
	
	g_bZoneExists[bounds] = true;
	return true;
}

stock bool EraseCurMapCoords( int bounds )
{
	switch ( bounds )
	{
		case BOUNDS_START :
		{
			Format( g_szQuery_Med, sizeof( g_szQuery_Med ), "UPDATE _mapbounds SET smin0 = NULL, smin1 = NULL, smin2 = NULL, smax0 = NULL, smax1 = NULL, smax2 = NULL WHERE map = '%s';", g_szCurrentMap );
			g_bIsLoaded[RUN_MAIN] = false;
		}
		case BOUNDS_END :
		{
			Format( g_szQuery_Med, sizeof( g_szQuery_Med ), "UPDATE _mapbounds SET emin0 = NULL, emin1 = NULL, emin2 = NULL, emax0 = NULL, emax1 = NULL, emax2 = NULL WHERE map = '%s';", g_szCurrentMap );
			g_bIsLoaded[RUN_MAIN] = false;
		}
		case BOUNDS_BLOCK_1 :
		{
			Format( g_szQuery_Med, sizeof( g_szQuery_Med ), "UPDATE _mapbounds SET bl1min0 = NULL, bl1min1 = NULL, bl1min2 = NULL, bl1max0 = NULL, bl1max1 = NULL, bl1max2 = NULL WHERE map = '%s';", g_szCurrentMap );
		}
		case BOUNDS_BLOCK_2 :
		{
			Format( g_szQuery_Med, sizeof( g_szQuery_Med ), "UPDATE _mapbounds SET bl2min0 = NULL, bl2min1 = NULL, bl2min2 = NULL, bl2max0 = NULL, bl2max1 = NULL, bl2max2 = NULL WHERE map = '%s';", g_szCurrentMap );
		}
		case BOUNDS_BLOCK_3 :
		{
			Format( g_szQuery_Med, sizeof( g_szQuery_Med ), "UPDATE _mapbounds SET bl3min0 = NULL, bl3min1 = NULL, bl3min2 = NULL, bl3max0 = NULL, bl3max1 = NULL, bl3max2 = NULL WHERE map = '%s';", g_szCurrentMap );
		}
		case BOUNDS_BONUS_1_START :
		{
			Format( g_szQuery_Med, sizeof( g_szQuery_Med ), "UPDATE _mapbounds SET b1_smin0 = NULL, b1_smin1 = NULL, b1_smin2 = NULL, b1_smax0 = NULL, b1_smax1 = NULL, b1_smax2 = NULL WHERE map = '%s';", g_szCurrentMap );
			g_bIsLoaded[RUN_BONUS_1] = false;
		}
		case BOUNDS_BONUS_1_END :
		{
			Format( g_szQuery_Med, sizeof( g_szQuery_Med ), "UPDATE _mapbounds SET b1_emin0 = NULL, b1_emin1 = NULL, b1_emin2 = NULL, b1_emax0 = NULL, b1_emax1 = NULL, b1_emax2 = NULL WHERE map = '%s';", g_szCurrentMap );
			g_bIsLoaded[RUN_BONUS_1] = false;
		}
		case BOUNDS_BONUS_2_START :
		{
			Format( g_szQuery_Med, sizeof( g_szQuery_Med ), "UPDATE _mapbounds SET b2_smin0 = NULL, b2_smin1 = NULL, b2_smin2 = NULL, b2_smax0 = NULL, b2_smax1 = NULL, b2_smax2 = NULL WHERE map = '%s';", g_szCurrentMap );
			g_bIsLoaded[RUN_BONUS_2] = false;
		}
		case BOUNDS_BONUS_2_END :
		{
			Format( g_szQuery_Med, sizeof( g_szQuery_Med ), "UPDATE _mapbounds SET b2_emin0 = NULL, b2_emin1 = NULL, b2_emin2 = NULL, b2_emax0 = NULL, b2_emax1 = NULL, b2_emax2 = NULL WHERE map = '%s';", g_szCurrentMap );
			g_bIsLoaded[RUN_BONUS_2] = false;
		}
		case BOUNDS_FREESTYLE_1 :
		{
			Format( g_szQuery_Med, sizeof( g_szQuery_Med ), "UPDATE _mapbounds SET fs1min0 = NULL, fs1min1 = NULL, fs1min2 = NULL, fs1max0 = NULL, fs1max1 = NULL, fs1max2 = NULL WHERE map = '%s';", g_szCurrentMap );
		}
		case BOUNDS_FREESTYLE_2 :
		{
			Format( g_szQuery_Med, sizeof( g_szQuery_Med ), "UPDATE _mapbounds SET fs2min0 = NULL, fs2min1 = NULL, fs2min2 = NULL, fs2max0 = NULL, fs2max1 = NULL, fs2max2 = NULL WHERE map = '%s';", g_szCurrentMap );
		}
		case BOUNDS_FREESTYLE_3 :
		{
			Format( g_szQuery_Med, sizeof( g_szQuery_Med ), "UPDATE _mapbounds SET fs3min0 = NULL, fs3min1 = NULL, fs3min2 = NULL, fs3max0 = NULL, fs3max1 = NULL, fs3max2 = NULL WHERE map = '%s';", g_szCurrentMap );
		}
		default : return false;
	}
	
	SQL_LockDatabase( g_Database );
	
	if ( !SQL_FastQuery( g_Database, g_szQuery_Med ) )
	{
		SQL_GetError( g_Database, g_szError, sizeof( g_szError ) );
		LogError( "%s Couldn't erase map's ending bounds!\nError: %s", CONSOLE_PREFIX, g_szError );
		
		SQL_UnlockDatabase( g_Database );
		return false;
	}
	
	SQL_UnlockDatabase( g_Database );
	
	g_bZoneExists[bounds] = false;
	return true;
}