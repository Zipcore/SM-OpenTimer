new Handle:Database = INVALID_HANDLE;
new String:Error[100];

#include "opentimer/database_thread.sp"

// Print server times to client. This can be done to console (max. 15 records) or to MOTD page (max. 5 records)
// Client can also request individual modes.
stock PrintRecords( client, bool:bInConsole, iReqStyle=-1, iRun=0 )
{
	decl String:Buffer[128];
	new amt;
	
	if ( bInConsole ) amt = 16;
	else amt = 5;
	
	if ( iReqStyle != -1 )
		Format( Buffer, sizeof( Buffer ), "SELECT * FROM '%s' WHERE style = %i AND run = %i ORDER BY time LIMIT %i;", CurrentMap, iReqStyle, iRun, amt );
	else
		Format( Buffer, sizeof( Buffer ), "SELECT * FROM '%s' WHERE run = %i ORDER BY time LIMIT %i;", CurrentMap, iRun, amt );
	
	new Handle:hData = CreateArray( 2 );
	
	new iData[2];
	iData[0] = GetClientUserId( client );
	iData[1] = bInConsole;
	
	PushArrayArray( hData, iData, 2 );
	
	SQL_TQuery( Database, Threaded_PrintRecords, Buffer, hData, DBPrio_High );
}

// We save the record if needed and print a notification to the chat.
stock bool:SaveClientRecord( client, Float:flNewTime )
{
	decl String:SteamID[32];
	
	if ( !GetClientAuthString( client, SteamID, sizeof( SteamID ) ) )
	{
		LogError( "%s There was an error at trying to retrieve player's \"%N\" Steam ID! Cannot save record.", CONSOLE_PREFIX, client );
		return false;
	}
	
	// Insert new if we haven't beaten this one yet. Replace if it's better.
	if ( flClientBestTime[client][ iClientRun[client] ][ iClientStyle[client] ] <= 0.0 || flNewTime < flClientBestTime[client][ iClientRun[client] ][ iClientStyle[client] ] )
	{
		decl String:Buffer[200];
		
		Format( Buffer, sizeof( Buffer ), "INSERT OR REPLACE INTO '%s' ( steamid, name, time, jumps, style, strafes, run ) VALUES ( '%s', '%N', '%.3f', %i, %i, %i, %i );", CurrentMap, SteamID, client, flNewTime, iClientJumpCount[client], iClientStyle[client], iClientStrafeCount[client], iClientRun[client] );
		
		SQL_LockDatabase( Database );
		
		if ( !SQL_FastQuery( Database, Buffer ) )
		{
			SQL_UnlockDatabase( Database );
			
			LogError( "%s Couldn't save \"%N\" player's record!", CONSOLE_PREFIX, client );
			return false;
		}
		
		SQL_UnlockDatabase( Database );
	}
	////////////////////////////////////////////////////////////////////////////////
	// Print record in chat. Only here because my eyes are dying from repetition. //
	////////////////////////////////////////////////////////////////////////////////
	new Float:flLeftSeconds;
	
	if ( flNewTime > flMapBestTime[ iClientRun[client] ][ iClientStyle[client] ] ) flLeftSeconds = flNewTime - flMapBestTime[ iClientRun[client] ][ iClientStyle[client] ];
	else flLeftSeconds = flMapBestTime[ iClientRun[client] ][ iClientStyle[client] ] - flNewTime;
	
	decl String:FormattedTime[18];
	FormatSeconds( flNewTime, FormattedTime, true, true );
	
	decl String:RecordString[192];
	new bool:bIsBest;
	
	if ( flClientBestTime[client][ iClientRun[client] ][ iClientStyle[client] ] <= 0.0 ) // New time if under or equal to 0.0
	{
		if ( flNewTime > flMapBestTime[ iClientRun[client] ][ iClientStyle[client] ] )
		{
			Format( RecordString, sizeof( RecordString ), "%s \x03%N%s finished \x03%s%s for the first time [%s%s%s]!\n\x06(%s\x06)", CHAT_PREFIX, client, COLOR_TEXT, RunName[NAME_LONG][ iClientRun[client] ], COLOR_TEXT, COLOR_GRAY, StyleName[NAME_SHORT][ iClientStyle[client] ], COLOR_TEXT, FormattedTime );
			
			if ( flMapBestTime[ iClientRun[client] ][ iClientStyle[client] ] <= 0.0 )
				bIsBest = true;
		}
		else
		{
			Format( RecordString, sizeof( RecordString ), "%s \x03%N%s broke \x03%s%s record [%s%s%s]!\n\x06(%s\x06) Improving \x03%.2f\x06sec!", CHAT_PREFIX, client, COLOR_TEXT, RunName[NAME_LONG][ iClientRun[client] ], COLOR_TEXT, COLOR_GRAY, StyleName[NAME_SHORT][ iClientStyle[client] ], COLOR_TEXT, FormattedTime, flLeftSeconds );
			bIsBest = true;
		}
	}
	else
	{
		if ( flNewTime >= flMapBestTime[ iClientRun[client] ][ iClientStyle[client] ] )
		{
			if ( flNewTime > flClientBestTime[client][ iClientRun[client] ][ iClientStyle[client] ] )
				Format( RecordString, sizeof( RecordString ), "%s \x03%N%s finished \x03%s%s [%s%s%s]!\n\x06(%s\x06)", CHAT_PREFIX, client, COLOR_TEXT, RunName[NAME_LONG][ iClientRun[client] ], COLOR_TEXT, COLOR_GRAY, StyleName[NAME_SHORT][ iClientStyle[client] ], COLOR_TEXT, FormattedTime );
			else
				Format( RecordString, sizeof( RecordString ), "%s \x03%N%s finished \x03%s%s [%s%s%s]!\n\x06(%s\x06) Improving \x03%.2f\x06sec!", CHAT_PREFIX, client, COLOR_TEXT, RunName[NAME_LONG][ iClientRun[client] ], COLOR_TEXT, COLOR_GRAY, StyleName[NAME_SHORT][ iClientStyle[client] ], COLOR_TEXT, FormattedTime, flClientBestTime[client][ iClientRun[client] ][ iClientStyle[client] ] - flNewTime );
		}
		else
		{
			Format( RecordString, sizeof( RecordString ), "%s \x03%N%s broke \x03%s%s record [%s%s%s]!\n\x06(%s\x06) Improving \x03%.2f\x06sec!", CHAT_PREFIX, client, COLOR_TEXT, RunName[NAME_LONG][ iClientRun[client] ], COLOR_TEXT, COLOR_GRAY, StyleName[NAME_SHORT][ iClientStyle[client] ], COLOR_TEXT, FormattedTime, flLeftSeconds );
			bIsBest = true;
		}
	}
	
	PrintColorChatAll( client, false, RecordString );
	
	// Play sound.
	if ( bIsBest )
	{
		new sound = GetRandomInt( 1, sizeof( WinningSounds ) - 1 );
		
		if ( !IsSoundPrecached( WinningSounds[sound] ) )
			PrecacheSound( WinningSounds[sound] );
		
		EmitSoundToAll( WinningSounds[sound] );
	}
	else
	{
		if ( !IsSoundPrecached( WinningSounds[0] ) )
			PrecacheSound( WinningSounds[0] );
			
		EmitSoundToAll( WinningSounds[0] );
	}
	
	// Update best time if better or if best time doesn't exist.
	if ( flClientBestTime[client][ iClientRun[client] ][ iClientStyle[client] ] <= 0.0 || flNewTime < flClientBestTime[client][ iClientRun[client] ][ iClientStyle[client] ] )	
		flClientBestTime[client][ iClientRun[client] ][ iClientStyle[client] ] = flNewTime;
	
	// Save if best time and save the recording on disk. :)
	if ( flMapBestTime[ iClientRun[client] ][ iClientStyle[client] ] <= 0.0 || flNewTime < flMapBestTime[ iClientRun[client] ][ iClientStyle[client] ] )
	{
		flMapBestTime[ iClientRun[client] ][ iClientStyle[client] ] = flNewTime;
		
#if defined RECORD
		if ( bIsClientRecording[client] && hClientRecording[client] != INVALID_HANDLE )
		{
			new len = GetArraySize( hClientRecording[client] );
			
			if ( len > MIN_REC_SIZE )
			{
				if ( !SaveRecording( client, len ) )
					return false;
				
				// We saved. Now let's update the bot!
				
				// Reset stuff just in case we happen to fuck up something.
				bIsClientMimicing[ iMimic[ iClientRun[client] ][ iClientStyle[client] ] ] = false;
				iClientTick[ iMimic[ iClientRun[client] ][ iClientStyle[client] ] ] = -1;
				
				hMimicRecording[ iClientRun[client] ][ iClientStyle[client] ] = CloneArray( hClientRecording[client] );
				iMimicTickMax[ iClientRun[client] ][ iClientStyle[client] ] = len;
				
				Format( MimicName[ iClientRun[client] ][ iClientStyle[client] ], sizeof( MimicName[][] ), "%N", client );
				
				ArrayCopy( vecInitPos[client], vecInitMimicPos[ iClientRun[client] ][ iClientStyle[client] ], 3 );
				ArrayCopy( angInitAngles[client], angInitMimicAngles[ iClientRun[client] ][ iClientStyle[client] ], 2 );
				
				if ( iMimic[ iClientRun[client] ][ iClientStyle[client] ] != 0 ) // We already have a bot? Let's use him instead.
				{
					decl String:Name[32];
					Format( Name, sizeof( Name ), "REC* %s [%s|%s]", MimicName[ iClientRun[client] ][ iClientStyle[client] ], RunName[NAME_SHORT][ iClientRun[client] ], StyleName[NAME_SHORT][ iClientStyle[client] ] );
					SetClientInfo( iMimic[ iClientRun[client] ][ iClientStyle[client] ], "name", Name );
					
					decl String:MimicTime[13];
					FormatSeconds( flMapBestTime[ iClientRun[client] ][ iClientStyle[client] ], MimicTime, false );
					CS_SetClientClanTag( iMimic[ iClientRun[client] ][ iClientStyle[client] ], MimicTime );
					
					
					TeleportEntity( iMimic[ iClientRun[client] ][ iClientStyle[client] ], vecInitMimicPos[ iClientRun[client] ][ iClientStyle[client] ], angInitMimicAngles[ iClientRun[client] ][ iClientStyle[client] ], vecNull );
					
					CreateTimer( 2.0, Timer_Rec_Start, iMimic[ iClientRun[client] ][ iClientStyle[client] ] );
				}
				else // Create new if one doesn't exist
				{
					iNumMimic++;
					ServerCommand( "bot_quota %i", iNumMimic );
				}
			}
		}
#endif
	}
	
	UpdateScoreboard( client );
	
	return true;
}

// SAVE EVERYTHINNNNNNNNNNNNNNGGGGGGGGGGGGGGGGGGG
stock bool:SaveClientInfo( client )
{
	if ( Database == INVALID_HANDLE ) return false;
	
	decl String:SteamID[32];
	
	if ( !GetClientAuthString( client, SteamID, sizeof( SteamID ) ) )
	{
		LogError( "%s There was an error at trying to retrieve player's \"%N\" Steam ID! Cannot save record.", CONSOLE_PREFIX, client );
		return false;
	}
	
	decl String:Buffer[256];
	
	Format( Buffer, sizeof( Buffer ), "UPDATE player_data SET fov = %i, hideflags = %i WHERE steamid = '%s';", iClientFOV[client], iClientHideFlags[client], SteamID );
	
	SQL_LockDatabase( Database );
	
	if ( !SQL_FastQuery( Database, Buffer ) )
	{
		SQL_UnlockDatabase( Database );
		
		SQL_GetError( Database, Error, sizeof( Error ) );
		LogError( "%s Couldn't save player's \"%N\" profile!\nError: %s", CONSOLE_PREFIX, client, Error );
	
		return false;
	}
	
	SQL_UnlockDatabase( Database );
	
	return true;
}

// Get client options (fov and hideflags) and time it took him/her to beat the map in all modes.
stock RetrieveClientInfo( client )
{
	decl String:SteamID[32];
	
	if ( !GetClientAuthString( client, SteamID, sizeof( SteamID ) ) )
	{
		LogError( "%s There was an error at trying to retrieve player's \"%N\" Steam ID! Cannot save record.", CONSOLE_PREFIX, client );
		return;
	}
	
	decl String:Buffer[128];
	Format( Buffer, sizeof( Buffer ), "SELECT * FROM player_data WHERE steamid = '%s';", SteamID );
	
	SQL_TQuery( Database, Threaded_RetrieveClientInfo, Buffer, GetClientUserId( client ), DBPrio_High );
}

// Initialize sounds so important. I'm so cool.
// Create connection with database and get all valid run-able maps so we can vote for them.
stock InitializeDatabase()
{
	Database = SQLite_UseDatabase( "opentimer", Error, sizeof( Error ) );
	
	if ( Database == INVALID_HANDLE )
		SetFailState( "%s Unable to establish connection to database!\n Error: %s", CONSOLE_PREFIX, Error );
	
	SQL_LockDatabase( Database );
	
	if ( !SQL_FastQuery( Database, "CREATE TABLE IF NOT EXISTS player_data ( steamid VARCHAR( 32 ) PRIMARY KEY, fov INTEGER, hideflags INTEGER );" ) )
	{
		SQL_UnlockDatabase( Database );
		
		SQL_GetError( Database, Error, sizeof( Error ) );
		SetFailState( "%s Plugin was unable to create table for player profiles!\nError: %s", CONSOLE_PREFIX, Error );
		return;
	}
	
	SQL_UnlockDatabase( Database );
	
	PrintToServer( "%s Established connection with database!", CONSOLE_PREFIX );
}

// Get map bounds, mimics and voteable maps
stock InitializeMapBounds()
{
	if ( Database == INVALID_HANDLE )
		SetFailState( "%s No connection to database. Unable to retrieve map data!", CONSOLE_PREFIX );
	
	// Fuq me
	// Now, we COULD store all different bounds in separate tables with a key assigning it to specific bound, but IN THE END IT DOESN'T EVEN MATTER.
	// You see, we are going to have to limit the amount of bounds we have in the first place. Having a static array just makes things a lot easier.
	// I wouldn't trust dynamic arrays in this case. Especially when we do calculations on bounds every frame.
	SQL_LockDatabase( Database );
	
	if ( !SQL_FastQuery( Database, "CREATE TABLE IF NOT EXISTS _mapbounds ( map VARCHAR( 32 ) PRIMARY KEY, smin0 REAL, smin1 REAL, smin2 REAL, smax0 REAL, smax1 REAL, smax2 REAL, emin0 REAL, emin1 REAL, emin2 REAL, emax0 REAL, emax1 REAL, emax2 REAL, bl1min0 REAL, bl1min1 REAL, bl1min2 REAL, bl1max0 REAL, bl1max1 REAL, bl1max2 REAL, bl2min0 REAL, bl2min1 REAL, bl2min2 REAL, bl2max0 REAL, bl2max1 REAL, bl2max2 REAL, bl3min0 REAL, bl3min1 REAL, bl3min2 REAL, bl3max0 REAL, bl3max1 REAL, bl3max2 REAL, b1_smin0 REAL, b1_smin1 REAL, b1_smin2 REAL, b1_smax0 REAL, b1_smax1 REAL, b1_smax2 REAL, b1_emin0 REAL, b1_emin1 REAL, b1_emin2 REAL, b1_emax0 REAL, b1_emax1 REAL, b1_emax2 REAL, b2_smin0 REAL, b2_smin1 REAL, b2_smin2 REAL, b2_smax0 REAL, b2_smax1 REAL, b2_smax2 REAL, b2_emin0 REAL, b2_emin1 REAL, b2_emin2 REAL, b2_emax0 REAL, b2_emax1 REAL, b2_emax2 REAL, fs1min0 REAL, fs1min1 REAL, fs1min2 REAL, fs1max0 REAL, fs1max1 REAL, fs1max2 REAL, fs2min0 REAL, fs2min1 REAL, fs2min2 REAL, fs2max0 REAL, fs2max1 REAL, fs2max2 REAL, fs3min0 REAL, fs3min1 REAL, fs3min2 REAL, fs3max0 REAL, fs3max1 REAL, fs3max2 REAL );" ) )
	{
		SQL_UnlockDatabase( Database );
		
		SQL_GetError( Database, Error, sizeof( Error ) );
		SetFailState( "%s Couldn't create map bounds table!\nError: %s", CONSOLE_PREFIX, Error );
		return;
	}
	
	decl String:Buffer[256];

/*
CREATE TABLE temp_map ( steamid VARCHAR( 32 ), run INTEGER, mode INTEGER, name VARCHAR( 64 ), time REAL, jumps INTEGER , strafes INTEGER );

INSERT INTO temp_map ( steamid, run, mode, name, time, jumps, strafes ) SELECT steamid, run, mode, name, time, jumps, strafes FROM bhop_ytt_dust;

DROP TABLE bhop_ytt_dust;

CREATE TABLE bhop_ytt_dust ( steamid VARCHAR( 32 ) NOT NULL, run INTEGER NOT NULL, style INTEGER NOT NULL, name VARCHAR( 64 ), time REAL, jumps INTEGER , strafes INTEGER, PRIMARY KEY ( steamid, run, style ) );

INSERT INTO bhop_ytt_dust ( steamid, run, style, name, time, jumps, strafes ) SELECT steamid, run, mode, name, time, jumps, strafes FROM temp_map;

DROP TABLE temp_map;
*/
	Format( Buffer, sizeof( Buffer ), "CREATE TABLE IF NOT EXISTS '%s' ( steamid VARCHAR( 32 ) NOT NULL, run INTEGER NOT NULL, style INTEGER NOT NULL, name VARCHAR( 64 ), time REAL, jumps INTEGER , strafes INTEGER, PRIMARY KEY ( steamid, run, style ) );", CurrentMap );
	
	if ( !SQL_FastQuery( Database, Buffer ) )
	{
		SQL_UnlockDatabase( Database );
		
		SQL_GetError( Database, Error, sizeof( Error ) );
		SetFailState( "%s Couldn't create map record table!\nError: %s", CONSOLE_PREFIX, Error );
		return;
	}
	
	Format( Buffer, sizeof( Buffer ), "SELECT * FROM _mapbounds WHERE map = '%s';", CurrentMap );
	new Handle:hQuery = SQL_Query( Database, Buffer );
	
	if ( hQuery == INVALID_HANDLE )
	{
		SQL_UnlockDatabase( Database );
		
		SQL_GetError( Database, Error, sizeof( Error ) );
		SetFailState( "%s Unable to retrieve map bounds!\nError: %s", CONSOLE_PREFIX, Error );
		return;
	}
	
	new field;
	
	if ( SQL_GetRowCount( hQuery ) == 0 )
	{
		Format( Buffer, sizeof( Buffer ), "INSERT INTO _mapbounds ( map ) VALUES ( '%s' );", CurrentMap );
		
		if ( !SQL_FastQuery( Database, Buffer ) )
		{
			CloseHandle( hQuery );
			SQL_UnlockDatabase( Database );
			
			SQL_GetError( Database, Error, sizeof( Error ) );
			SetFailState( "%s Couldn't create map bounds table!\nError: %s", CONSOLE_PREFIX, Error );
			return;
		}
		
		CloseHandle( hQuery );
		SQL_UnlockDatabase( Database );
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
				vecBoundsMin[BOUNDS_START][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "smin1", field );
				vecBoundsMin[BOUNDS_START][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "smin2", field );
				vecBoundsMin[BOUNDS_START][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "smax0", field );
				vecBoundsMax[BOUNDS_START][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "smax1", field );
				vecBoundsMax[BOUNDS_START][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "smax2", field );
				vecBoundsMax[BOUNDS_START][2] = SQL_FetchFloat( hQuery, field );

				bZoneExists[BOUNDS_START] = true;
			}
			else bZoneExists[BOUNDS_START] = false;
			
			// END BOUNDS
			SQL_FieldNameToNum( hQuery, "emin0", field );

			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				vecBoundsMin[BOUNDS_END][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "emin1", field );
				vecBoundsMin[BOUNDS_END][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "emin2", field );
				vecBoundsMin[BOUNDS_END][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "emax0", field );
				vecBoundsMax[BOUNDS_END][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "emax1", field );
				vecBoundsMax[BOUNDS_END][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "emax2", field );
				vecBoundsMax[BOUNDS_END][2] = SQL_FetchFloat( hQuery, field );

				bZoneExists[BOUNDS_END] = true;
			}
			else bZoneExists[BOUNDS_END] = false;
	
			// BLOCK BOUNDS
			// BLOCK #1
			SQL_FieldNameToNum( hQuery, "bl1min0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				vecBoundsMin[BOUNDS_BLOCK_1][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "bl1min1", field );
				vecBoundsMin[BOUNDS_BLOCK_1][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "bl1min2", field );
				vecBoundsMin[BOUNDS_BLOCK_1][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "bl1max0", field );
				vecBoundsMax[BOUNDS_BLOCK_1][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "bl1max1", field );
				vecBoundsMax[BOUNDS_BLOCK_1][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "bl1max2", field );
				vecBoundsMax[BOUNDS_BLOCK_1][2] = SQL_FetchFloat( hQuery, field );
				
				bZoneExists[BOUNDS_BLOCK_1] = true;
			}
			else bZoneExists[BOUNDS_BLOCK_1] = false;
			
			// BLOCK #2
			SQL_FieldNameToNum( hQuery, "bl2min0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				vecBoundsMin[BOUNDS_BLOCK_2][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "bl2min1", field );
				vecBoundsMin[BOUNDS_BLOCK_2][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "bl2min2", field );
				vecBoundsMin[BOUNDS_BLOCK_2][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "bl2max0", field );
				vecBoundsMax[BOUNDS_BLOCK_2][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "bl2max1", field );
				vecBoundsMax[BOUNDS_BLOCK_2][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "bl2max2", field );
				vecBoundsMax[BOUNDS_BLOCK_2][2] = SQL_FetchFloat( hQuery, field );

				bZoneExists[BOUNDS_BLOCK_2] = true;
			}
			else bZoneExists[BOUNDS_BLOCK_2] = false;
			
			
			// BLOCK #3
			SQL_FieldNameToNum( hQuery, "bl3min0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				vecBoundsMin[BOUNDS_BLOCK_3][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "bl3min1", field );
				vecBoundsMin[BOUNDS_BLOCK_3][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "bl3min2", field );
				vecBoundsMin[BOUNDS_BLOCK_3][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "bl3max0", field );
				vecBoundsMax[BOUNDS_BLOCK_3][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "bl3max1", field );
				vecBoundsMax[BOUNDS_BLOCK_3][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "bl3max2", field );
				vecBoundsMax[BOUNDS_BLOCK_3][2] = SQL_FetchFloat( hQuery, field );

				bZoneExists[BOUNDS_BLOCK_3] = true;
			}
			else bZoneExists[BOUNDS_BLOCK_3] = false;
			
			
			// BONUS #1 START
			SQL_FieldNameToNum( hQuery, "b1_smin0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				vecBoundsMin[BOUNDS_BONUS_1_START][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "b1_smin1", field );
				vecBoundsMin[BOUNDS_BONUS_1_START][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b1_smin2", field );
				vecBoundsMin[BOUNDS_BONUS_1_START][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b1_smax0", field );
				vecBoundsMax[BOUNDS_BONUS_1_START][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b1_smax1", field );
				vecBoundsMax[BOUNDS_BONUS_1_START][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b1_smax2", field );
				vecBoundsMax[BOUNDS_BONUS_1_START][2] = SQL_FetchFloat( hQuery, field );

				bZoneExists[BOUNDS_BONUS_1_START] = true;
			}
			else bZoneExists[BOUNDS_BONUS_1_START] = false;
			
			// BONUS #1 END
			SQL_FieldNameToNum( hQuery, "b1_emin0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				vecBoundsMin[BOUNDS_BONUS_1_END][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "b1_emin1", field );
				vecBoundsMin[BOUNDS_BONUS_1_END][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b1_emin2", field );
				vecBoundsMin[BOUNDS_BONUS_1_END][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b1_emax0", field );
				vecBoundsMax[BOUNDS_BONUS_1_END][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b1_emax1", field );
				vecBoundsMax[BOUNDS_BONUS_1_END][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b1_emax2", field );
				vecBoundsMax[BOUNDS_BONUS_1_END][2] = SQL_FetchFloat( hQuery, field );

				bZoneExists[BOUNDS_BONUS_1_END] = true;
			}
			else bZoneExists[BOUNDS_BONUS_1_END] = false;
			
			// BONUS #2 START
			SQL_FieldNameToNum( hQuery, "b2_smin0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				vecBoundsMin[BOUNDS_BONUS_2_START][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "b2_smin1", field );
				vecBoundsMin[BOUNDS_BONUS_2_START][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b2_smin2", field );
				vecBoundsMin[BOUNDS_BONUS_2_START][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b2_smax0", field );
				vecBoundsMax[BOUNDS_BONUS_2_START][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b2_smax1", field );
				vecBoundsMax[BOUNDS_BONUS_2_START][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b2_smax2", field );
				vecBoundsMax[BOUNDS_BONUS_2_START][2] = SQL_FetchFloat( hQuery, field );

				bZoneExists[BOUNDS_BONUS_2_START] = true;
			}
			else bZoneExists[BOUNDS_BONUS_2_START] = false;
			
			// BONUS #2 END
			SQL_FieldNameToNum( hQuery, "b2_emin0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				vecBoundsMin[BOUNDS_BONUS_2_END][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "b2_emin1", field );
				vecBoundsMin[BOUNDS_BONUS_2_END][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b2_emin2", field );
				vecBoundsMin[BOUNDS_BONUS_2_END][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b2_emax0", field );
				vecBoundsMax[BOUNDS_BONUS_2_END][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b2_emax1", field );
				vecBoundsMax[BOUNDS_BONUS_2_END][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "b2_emax2", field );
				vecBoundsMax[BOUNDS_BONUS_2_END][2] = SQL_FetchFloat( hQuery, field );

				bZoneExists[BOUNDS_BONUS_2_END] = true;
			}
			else bZoneExists[BOUNDS_BONUS_2_END] = false;
			
			
			// FREESTYLE #1
			// ROCK THE MICROPHONE WITH A FREESTYLER
			SQL_FieldNameToNum( hQuery, "fs1min0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				vecBoundsMin[BOUNDS_FREESTYLE_1][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "fs1min1", field );
				vecBoundsMin[BOUNDS_FREESTYLE_1][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs1min2", field );
				vecBoundsMin[BOUNDS_FREESTYLE_1][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs1max0", field );
				vecBoundsMax[BOUNDS_FREESTYLE_1][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs1max1", field );
				vecBoundsMax[BOUNDS_FREESTYLE_1][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs1max2", field );
				vecBoundsMax[BOUNDS_FREESTYLE_1][2] = SQL_FetchFloat( hQuery, field );

				bZoneExists[BOUNDS_FREESTYLE_1] = true;
			}
			else bZoneExists[BOUNDS_FREESTYLE_1] = false;
			
			// FREESTYLE #2
			SQL_FieldNameToNum( hQuery, "fs2min0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				vecBoundsMin[BOUNDS_FREESTYLE_2][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "fs2min1", field );
				vecBoundsMin[BOUNDS_FREESTYLE_2][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs2min2", field );
				vecBoundsMin[BOUNDS_FREESTYLE_2][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs2max0", field );
				vecBoundsMax[BOUNDS_FREESTYLE_2][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs2max1", field );
				vecBoundsMax[BOUNDS_FREESTYLE_2][1] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "fs2max2", field );
				vecBoundsMax[BOUNDS_FREESTYLE_2][2] = SQL_FetchFloat( hQuery, field );

				bZoneExists[BOUNDS_FREESTYLE_2] = true;
			}
			else bZoneExists[BOUNDS_FREESTYLE_2] = false;
			
			// FREESTYLE #3
			SQL_FieldNameToNum( hQuery, "fs3min0", field );
			
			if ( !SQL_IsFieldNull( hQuery, field ) )
			{
				vecBoundsMin[BOUNDS_FREESTYLE_3][0] = SQL_FetchFloat( hQuery, field );

				SQL_FieldNameToNum( hQuery, "fs3min1", field );
				vecBoundsMin[BOUNDS_FREESTYLE_3][1] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs3min2", field );
				vecBoundsMin[BOUNDS_FREESTYLE_3][2] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs3max0", field );
				vecBoundsMax[BOUNDS_FREESTYLE_3][0] = SQL_FetchFloat( hQuery, field );
			
				SQL_FieldNameToNum( hQuery, "fs3max1", field );
				vecBoundsMax[BOUNDS_FREESTYLE_3][1] = SQL_FetchFloat( hQuery, field );
				
				SQL_FieldNameToNum( hQuery, "fs3max2", field );
				vecBoundsMax[BOUNDS_FREESTYLE_3][2] = SQL_FetchFloat( hQuery, field );

				bZoneExists[BOUNDS_FREESTYLE_3] = true;
			}
			else bZoneExists[BOUNDS_FREESTYLE_3] = false;
		}
	}

	if ( !bZoneExists[BOUNDS_START] || !bZoneExists[BOUNDS_END] )
	{
		PrintToServer( "%s Map is lacking bounds...", CONSOLE_PREFIX );
		bIsLoaded[RUN_MAIN] = false;
	}
	else bIsLoaded[RUN_MAIN] = true;
	
	if ( !bZoneExists[BOUNDS_BONUS_1_START] || !bZoneExists[BOUNDS_BONUS_1_END] )
		bIsLoaded[RUN_BONUS_1] = false;
	else
		bIsLoaded[RUN_BONUS_1] = true;
	
	if ( !bZoneExists[BOUNDS_BONUS_2_START] || !bZoneExists[BOUNDS_BONUS_2_END] )
		bIsLoaded[RUN_BONUS_2] = false;
	else
		bIsLoaded[RUN_BONUS_2] = true;
	
	Format( Buffer, sizeof( Buffer ), "SELECT run, style, MIN( time ), steamid, name FROM %s GROUP BY run, style ORDER BY run;", CurrentMap );
	hQuery = SQL_Query( Database, Buffer );
	
	if ( hQuery == INVALID_HANDLE )
	{
		SQL_UnlockDatabase( Database );
		
		SQL_GetError( Database, Error, sizeof( Error ) );
		SetFailState( "%s Unable to retrieve map best times!\nError: %s", CONSOLE_PREFIX, Error );
		return;
	}
	
	new iStyle, iRun;
	
#if defined RECORD
	decl String:SteamID[32], String:Name[MAX_NAME_LENGTH];
	
	iNumMimic = 0;
#endif

	while ( SQL_FetchRow( hQuery ) )
	{
		iRun = SQL_FetchInt( hQuery, 0 );
	
		iStyle = SQL_FetchInt( hQuery, 1 ); // Using SQL_FieldNameToNum seems to break everything for some reason.
		flMapBestTime[iRun][iStyle] = SQL_FetchFloat( hQuery, 2 );
		
#if defined RECORD
		// Load records from disk.
		// Assigning the records to bots are done in OnClientPostAdminCheck()
		SQL_FetchString( hQuery, 3, SteamID, sizeof( SteamID ) );
		SQL_FetchString( hQuery, 4, Name, sizeof( Name ) );
		
		if ( LoadRecording( SteamID, iRun, iStyle ) )
		{
			PrintToServer( "%s Recording found! (%s | %s)", CONSOLE_PREFIX, RunName[NAME_SHORT][iRun], StyleName[NAME_SHORT][iStyle] );
			
			strcopy( MimicName[iRun][iStyle], sizeof( MimicName[][] ), Name );
			iNumMimic++;
		}
#endif
	}
	
	CloseHandle( hQuery );
	SQL_UnlockDatabase( Database );
	
#if defined RECORD
	ServerCommand( "bot_quota %i", iNumMimic );
	PrintToServer( "%s Spawning %i record bots...", CONSOLE_PREFIX, iNumMimic );
#endif
	
	DoMapStuff();
}

// Get maps from database that have start and end zones and start with bhop_ or kz_.
#if defined VOTING
stock FindMaps()
{
	SQL_LockDatabase( Database );
	
	new Handle:hQuery = SQL_Query( Database, "SELECT map FROM _mapbounds WHERE smin0 IS NOT NULL AND emin0 IS NOT NULL AND ( map LIKE 'bhop_%' OR map LIKE 'kz_%' ) ORDER BY map;" );

	if ( hQuery == INVALID_HANDLE )
	{
		SQL_UnlockDatabase( Database );
		
		SQL_GetError( Database, Error, sizeof( Error ) );
		SetFailState( "%s Plugin was unable to recieve tables (map names) from database!!\nError: %s", CONSOLE_PREFIX, Error );
	}

	decl String:MapName[32];
	hMapList = CreateArray( MAX_MAP_NAME_LENGTH );
	
	while( SQL_FetchRow( hQuery ) )
	{
		SQL_FetchString( hQuery, 0, MapName, sizeof( MapName ) );
		
		new iMap[MAX_MAP_NAME_LENGTH];
		strcopy( iMap[MAP_NAME], sizeof( iMap[MAP_NAME] ), MapName );
		
		PushArrayArray( hMapList, iMap, _:MapInfo );
	}
	
	CloseHandle( hQuery );
	SQL_UnlockDatabase( Database );
}
#endif

stock bool:SaveMapCoords( bounds )
{
	decl String:Buffer[300];
	
	if ( bounds == BOUNDS_START )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET smin0 = %.0f, smin1 = %.0f, smin2 = %.0f, smax0 = %.0f, smax1 = %.0f, smax2 = %.0f WHERE map = '%s';", vecBoundsMin[BOUNDS_START][0], vecBoundsMin[BOUNDS_START][1], vecBoundsMin[BOUNDS_START][2], vecBoundsMax[BOUNDS_START][0], vecBoundsMax[BOUNDS_START][1], vecBoundsMax[BOUNDS_START][2], CurrentMap );
	else if ( bounds == BOUNDS_END )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET emin0 = %.0f, emin1 = %.0f, emin2 = %.0f, emax0 = %.0f, emax1 = %.0f, emax2 = %.0f WHERE map = '%s';", vecBoundsMin[BOUNDS_END][0], vecBoundsMin[BOUNDS_END][1], vecBoundsMin[BOUNDS_END][2], vecBoundsMax[BOUNDS_END][0], vecBoundsMax[BOUNDS_END][1], vecBoundsMax[BOUNDS_END][2], CurrentMap );
	else if ( bounds == BOUNDS_BLOCK_1 )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET bl1min0 = %.0f, bl1min1 = %.0f, bl1min2 = %.0f, bl1max0 = %.0f, bl1max1 = %.0f, bl1max2 = %.0f WHERE map = '%s';", vecBoundsMin[BOUNDS_BLOCK_1][0], vecBoundsMin[BOUNDS_BLOCK_1][1], vecBoundsMin[BOUNDS_BLOCK_1][2], vecBoundsMax[BOUNDS_BLOCK_1][0], vecBoundsMax[BOUNDS_BLOCK_1][1], vecBoundsMax[BOUNDS_BLOCK_1][2], CurrentMap );
	else if ( bounds == BOUNDS_BLOCK_2 )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET bl2min0 = %.0f, bl2min1 = %.0f, bl2min2 = %.0f, bl2max0 = %.0f, bl2max1 = %.0f, bl2max2 = %.0f WHERE map = '%s';", vecBoundsMin[BOUNDS_BLOCK_2][0], vecBoundsMin[BOUNDS_BLOCK_2][1], vecBoundsMin[BOUNDS_BLOCK_2][2], vecBoundsMax[BOUNDS_BLOCK_2][0], vecBoundsMax[BOUNDS_BLOCK_2][1], vecBoundsMax[BOUNDS_BLOCK_2][2], CurrentMap );
	else if ( bounds == BOUNDS_BLOCK_3 )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET bl3min0 = %.0f, bl3min1 = %.0f, bl3min2 = %.0f, bl3max0 = %.0f, bl3max1 = %.0f, bl3max2 = %.0f WHERE map = '%s';", vecBoundsMin[BOUNDS_BLOCK_3][0], vecBoundsMin[BOUNDS_BLOCK_3][1], vecBoundsMin[BOUNDS_BLOCK_3][2], vecBoundsMax[BOUNDS_BLOCK_3][0], vecBoundsMax[BOUNDS_BLOCK_3][1], vecBoundsMax[BOUNDS_BLOCK_3][2], CurrentMap );
	else if ( bounds == BOUNDS_BONUS_1_START )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET b1_smin0 = %.0f, b1_smin1 = %.0f, b1_smin2 = %.0f, b1_smax0 = %.0f, b1_smax1 = %.0f, b1_smax2 = %.0f WHERE map = '%s';", vecBoundsMin[BOUNDS_BONUS_1_START][0], vecBoundsMin[BOUNDS_BONUS_1_START][1], vecBoundsMin[BOUNDS_BONUS_1_START][2], vecBoundsMax[BOUNDS_BONUS_1_START][0], vecBoundsMax[BOUNDS_BONUS_1_START][1], vecBoundsMax[BOUNDS_BONUS_1_START][2], CurrentMap );
	else if ( bounds == BOUNDS_BONUS_1_END )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET b1_emin0 = %.0f, b1_emin1 = %.0f, b1_emin2 = %.0f, b1_emax0 = %.0f, b1_emax1 = %.0f, b1_emax2 = %.0f WHERE map = '%s';", vecBoundsMin[BOUNDS_BONUS_1_END][0], vecBoundsMin[BOUNDS_BONUS_1_END][1], vecBoundsMin[BOUNDS_BONUS_1_END][2], vecBoundsMax[BOUNDS_BONUS_1_END][0], vecBoundsMax[BOUNDS_BONUS_1_END][1], vecBoundsMax[BOUNDS_BONUS_1_END][2], CurrentMap );
	else if ( bounds == BOUNDS_BONUS_2_START )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET b2_smin0 = %.0f, b2_smin1 = %.0f, b2_smin2 = %.0f, b2_smax0 = %.0f, b2_smax1 = %.0f, b2_smax2 = %.0f WHERE map = '%s';", vecBoundsMin[BOUNDS_BONUS_2_START][0], vecBoundsMin[BOUNDS_BONUS_2_START][1], vecBoundsMin[BOUNDS_BONUS_2_START][2], vecBoundsMax[BOUNDS_BONUS_2_START][0], vecBoundsMax[BOUNDS_BONUS_2_START][1], vecBoundsMax[BOUNDS_BONUS_2_START][2], CurrentMap );
	else if ( bounds == BOUNDS_BONUS_2_END )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET b2_emin0 = %.0f, b2_emin1 = %.0f, b2_emin2 = %.0f, b2_emax0 = %.0f, b2_emax1 = %.0f, b2_emax2 = %.0f WHERE map = '%s';", vecBoundsMin[BOUNDS_BONUS_2_END][0], vecBoundsMin[BOUNDS_BONUS_2_END][1], vecBoundsMin[BOUNDS_BONUS_2_END][2], vecBoundsMax[BOUNDS_BONUS_2_END][0], vecBoundsMax[BOUNDS_BONUS_2_END][1], vecBoundsMax[BOUNDS_BONUS_2_END][2], CurrentMap );
	else if ( bounds == BOUNDS_FREESTYLE_1 )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET fs1min0 = %.0f, fs1min1 = %.0f, fs1min2 = %.0f, fs1max0 = %.0f, fs1max1 = %.0f, fs1max2 = %.0f WHERE map = '%s';", vecBoundsMin[BOUNDS_FREESTYLE_1][0], vecBoundsMin[BOUNDS_FREESTYLE_1][1], vecBoundsMin[BOUNDS_FREESTYLE_1][2], vecBoundsMax[BOUNDS_FREESTYLE_1][0], vecBoundsMax[BOUNDS_FREESTYLE_1][1], vecBoundsMax[BOUNDS_FREESTYLE_1][2], CurrentMap );
	else if ( bounds == BOUNDS_FREESTYLE_2 )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET fs2min0 = %.0f, fs2min1 = %.0f, fs2min2 = %.0f, fs2max0 = %.0f, fs2max1 = %.0f, fs2max2 = %.0f WHERE map = '%s';", vecBoundsMin[BOUNDS_FREESTYLE_2][0], vecBoundsMin[BOUNDS_FREESTYLE_2][1], vecBoundsMin[BOUNDS_FREESTYLE_2][2], vecBoundsMax[BOUNDS_FREESTYLE_2][0], vecBoundsMax[BOUNDS_FREESTYLE_2][1], vecBoundsMax[BOUNDS_FREESTYLE_2][2], CurrentMap );
	else if ( bounds == BOUNDS_FREESTYLE_3 )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET fs3min0 = %.0f, fs3min1 = %.0f, fs3min2 = %.0f, fs3max0 = %.0f, fs3max1 = %.0f, fs3max2 = %.0f WHERE map = '%s';", vecBoundsMin[BOUNDS_FREESTYLE_3][0], vecBoundsMin[BOUNDS_FREESTYLE_3][1], vecBoundsMin[BOUNDS_FREESTYLE_3][2], vecBoundsMax[BOUNDS_FREESTYLE_3][0], vecBoundsMax[BOUNDS_FREESTYLE_3][1], vecBoundsMax[BOUNDS_FREESTYLE_3][2], CurrentMap );
	else return false;
	
	SQL_LockDatabase( Database );
	
	if ( !SQL_FastQuery( Database, Buffer ) )
	{
		SQL_GetError( Database, Error, sizeof( Error ) );
		LogError( "%s Couldn't save map's ending bounds!\nError: %s", CONSOLE_PREFIX, Error );
		
		SQL_UnlockDatabase( Database );
		return false;
	}
	
	SQL_UnlockDatabase( Database );
	
	bZoneExists[bounds] = true;
	return true;
}

stock bool:EraseCurMapCoords( bounds )
{
	decl String:Buffer[200];
	
	if ( bounds == BOUNDS_START )
	{
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET smin0 = NULL, smin1 = NULL, smin2 = NULL, smax0 = NULL, smax1 = NULL, smax2 = NULL WHERE map = '%s';", CurrentMap );
		
		bIsLoaded[RUN_MAIN] = false;
	}
	else if ( bounds == BOUNDS_END )
	{
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET emin0 = NULL, emin1 = NULL, emin2 = NULL, emax0 = NULL, emax1 = NULL, emax2 = NULL WHERE map = '%s';", CurrentMap );
		
		bIsLoaded[RUN_MAIN] = false;
	}
	else if ( bounds == BOUNDS_BLOCK_1 )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET bl1min0 = NULL, bl1min1 = NULL, bl1min2 = NULL, bl1max0 = NULL, bl1max1 = NULL, bl1max2 = NULL WHERE map = '%s';", CurrentMap );
	else if ( bounds == BOUNDS_BLOCK_2 )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET bl2min0 = NULL, bl2min1 = NULL, bl2min2 = NULL, bl2max0 = NULL, bl2max1 = NULL, bl2max2 = NULL WHERE map = '%s';", CurrentMap );
	else if ( bounds == BOUNDS_BLOCK_3 )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET bl3min0 = NULL, bl3min1 = NULL, bl3min2 = NULL, bl3max0 = NULL, bl3max1 = NULL, bl3max2 = NULL WHERE map = '%s';", CurrentMap );
	else if ( bounds == BOUNDS_BONUS_1_START )
	{
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET b1_smin0 = NULL, b1_smin1 = NULL, b1_smin2 = NULL, b1_smax0 = NULL, b1_smax1 = NULL, b1_smax2 = NULL WHERE map = '%s';", CurrentMap );
		
		bIsLoaded[RUN_BONUS_1] = false;
	}
	else if ( bounds == BOUNDS_BONUS_1_END )
	{
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET b1_emin0 = NULL, b1_emin1 = NULL, b1_emin2 = NULL, b1_emax0 = NULL, b1_emax1 = NULL, b1_emax2 = NULL WHERE map = '%s';", CurrentMap );
		
		bIsLoaded[RUN_BONUS_1] = false;
	}
	else if ( bounds == BOUNDS_BONUS_2_START )
	{
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET b2_smin0 = NULL, b2_smin1 = NULL, b2_smin2 = NULL, b2_smax0 = NULL, b2_smax1 = NULL, b2_smax2 = NULL WHERE map = '%s';", CurrentMap );
		
		bIsLoaded[RUN_BONUS_2] = false;
	}
	else if ( bounds == BOUNDS_BONUS_2_END )
	{
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET b2_emin0 = NULL, b2_emin1 = NULL, b2_emin2 = NULL, b2_emax0 = NULL, b2_emax1 = NULL, b2_emax2 = NULL WHERE map = '%s';", CurrentMap );
		
		bIsLoaded[RUN_BONUS_2] = false;
	}
	else if ( bounds == BOUNDS_FREESTYLE_1 )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET fs1min0 = NULL, fs1min1 = NULL, fs1min2 = NULL, fs1max0 = NULL, fs1max1 = NULL, fs1max2 = NULL WHERE map = '%s';", CurrentMap );
	else if ( bounds == BOUNDS_FREESTYLE_2 )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET fs2min0 = NULL, fs2min1 = NULL, fs2min2 = NULL, fs2max0 = NULL, fs2max1 = NULL, fs2max2 = NULL WHERE map = '%s';", CurrentMap );
	else if ( bounds == BOUNDS_FREESTYLE_3 )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET fs3min0 = NULL, fs3min1 = NULL, fs3min2 = NULL, fs3max0 = NULL, fs3max1 = NULL, fs3max2 = NULL WHERE map = '%s';", CurrentMap );
	else return false;
	
	SQL_LockDatabase( Database );
	
	if ( !SQL_FastQuery( Database, Buffer ) )
	{
		SQL_GetError( Database, Error, sizeof( Error ) );
		LogError( "%s Couldn't erase map's ending bounds!\nError: %s", CONSOLE_PREFIX, Error );
		
		SQL_UnlockDatabase( Database );
		return false;
	}
	
	SQL_UnlockDatabase( Database );
	
	bZoneExists[bounds] = false;
	return true;
}