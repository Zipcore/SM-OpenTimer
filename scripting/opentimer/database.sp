static Handle:Database = INVALID_HANDLE;
static String:Error[150];

// Print server times to client. This can be done to console (max. 15 records) or to MOTD page (max. 5 records)
// Client can also request individual modes.
stock PrintRecords( client, bool:bInConsole, iReqMode=-1, iRun=0 )
{
	decl String:Buffer[128];
	new amt;
	
	if ( bInConsole ) amt = 16;
	else amt = 5;
	
	if ( iReqMode != -1 )
		Format( Buffer, sizeof( Buffer ), "SELECT * FROM '%s' WHERE mode = %i AND run = %i ORDER BY time LIMIT %i;", CurrentMap, iReqMode, iRun, amt );
	else
		Format( Buffer, sizeof( Buffer ), "SELECT * FROM '%s' WHERE run = %i ORDER BY time LIMIT %i;", CurrentMap, iRun, amt );
	
	new Handle:TimeQuery = SQL_Query( Database, Buffer );
	
	if ( TimeQuery == INVALID_HANDLE )
	{
		SQL_GetError( Database, Error, sizeof( Error ) );
		LogError( "%s Error occured when trying to print times to client.\nError: %s", CONSOLE_PREFIX, Error );
	
		PrintColorChat( client, client, "%s Sorry, something went wrong.", CHAT_PREFIX );
		return;
	}
	
	new field, ply, iJumps[17], iMode[17];
	decl Float:flSeconds[17], String:SteamId[17][32], String:Name[17][MAX_NAME_LENGTH], String:FormattedTime[17][13];
	
	while ( SQL_FetchRow( TimeQuery ) )
	{
		if ( bInConsole )
		{
			SQL_FieldNameToNum( TimeQuery, "steamid", field );
			SQL_FetchString( TimeQuery, field, SteamId[ply], sizeof( SteamId[] ) );
		
			SQL_FieldNameToNum( TimeQuery, "jumps", field );
			iJumps[ply] = SQL_FetchInt( TimeQuery, field );
		}
		
		SQL_FieldNameToNum( TimeQuery, "name", field );
		SQL_FetchString( TimeQuery, field, Name[ply], sizeof( Name[] ) );
		
		SQL_FieldNameToNum( TimeQuery, "time", field );
		flSeconds[ply] = SQL_FetchFloat( TimeQuery, field );
		//flSeconds[ply] += 0.0001; // Just to make sure...
		
		SQL_FieldNameToNum( TimeQuery, "mode", field );
		iMode[ply] = SQL_FetchInt( TimeQuery, field );
		
		FormatSeconds( flSeconds[ply], FormattedTime[ply], true );
		
		ply++;
	}
	
	CloseHandle( TimeQuery );
	
	new index = 1;
	if ( !bInConsole )
	{
		decl String:Text[200];
		
		if ( ply > 0 )
		{
			Format( Text, sizeof( Text ), "!printrecords for detailed version." );
			
			for ( new i; i < ply; i++ )
			{
				Format( Text, sizeof( Text ), "%s\n%i. %s - %s - %s", Text, index, Name[i], FormattedTime[i], ModeName[MODENAME_SHORT][ iMode[i] ] );
				index++;
			}
		}
		else Format( Text, sizeof( Text ), "No one has beaten the map yet... :(" );
		
		ShowMOTDPanel( client, "Top 5 (All modes)", Text, MOTDPANEL_TYPE_TEXT );
	}
	else
	{
		PrintToConsole( client, "\nRecords (Max. 16):\n!printrecord <mode> for specific modes. (\"normal\", \"sideways\", \"w\")----------------" );
		
		if ( ply > 0 )
		{
			for ( new i; i < ply; i++ )
			{
				PrintToConsole( client, "%i. %s - %s - %s - %s - %i jumps", index, SteamId[i], Name[i], FormattedTime[i], ModeName[MODENAME_LONG][ iMode[i] ], iJumps[i] );
				index++;
			}
		}
		else PrintToConsole( client, "No one has beaten the map yet... :(" );
		
		PrintToConsole( client, "----------------" );
		
		PrintColorChat( client, client, "%s Printed all (%i) records in your console.", CHAT_PREFIX, ply );
	}
}

// We save the record if needed and print a notification to the chat.
stock bool:SaveClientRecord( client, Float:flNewTime )
{
	// iClientRun[client], flNewTime, iClientMode[client], iClientJumpCount[client], iClientStrafeCount[client]
	decl String:SteamId[32];
	
	if ( !GetClientAuthString( client, SteamId, sizeof( SteamId ) ) )
	{
		LogError( "%s There was an error at trying to retrieve player's \"%N\" Steam ID! Cannot save record.", CONSOLE_PREFIX, client );
		
		return false;
	}
	
	decl String:Buffer[300];
	
	Format( Buffer, sizeof( Buffer ), "SELECT time FROM '%s' WHERE mode = %i AND run = %i AND steamid = '%s';", CurrentMap, iClientMode[client], iClientRun[client], SteamId );
	new Handle:TimeBuffer = SQL_Query( Database, Buffer );
	
	if ( TimeBuffer == INVALID_HANDLE )
	{
		SQL_GetError( Database, Error, sizeof( Error ) );
		LogError( "%s Couldn't retrieve player's old time when saving record!\nError: %s", CONSOLE_PREFIX, Error );
		
		return false;
	}
	
	new bool:bNewTime;
	if ( SQL_GetRowCount( TimeBuffer ) == 0 ) // Beat it for the first time!
	{
		Format( Buffer, sizeof( Buffer ), "INSERT INTO '%s' ( steamid, name, time, jumps, mode, strafes, run ) VALUES ( '%s', '%N', '%.3f', %i, %i, %i, %i );", CurrentMap, SteamId, client, flNewTime, iClientJumpCount[client], iClientMode[client], iClientStrafeCount[client], iClientRun[client] );
		
		if ( !SQL_FastQuery( Database, Buffer ) )
			return false;
		
		flClientBestTime[client][ iClientRun[client] ][ iClientMode[client] ] = flNewTime;
		bNewTime = true;
	}
	
	CloseHandle( TimeBuffer );
	////////////////////////////////////////////////////////////////////////////////
	// Print record in chat. Only here because my eyes are dying from repetition. //
	////////////////////////////////////////////////////////////////////////////////
	new Float:flLeftSeconds;
	
	if ( flNewTime > flMapBestTime[ iClientRun[client] ][ iClientMode[client] ] ) flLeftSeconds = flNewTime - flMapBestTime[ iClientRun[client] ][ iClientMode[client] ];
	else flLeftSeconds = flMapBestTime[ iClientRun[client] ][ iClientMode[client] ] - flNewTime;
	
	decl String:FormattedTime[18];
	FormatSeconds( flNewTime, FormattedTime, true, true );
	
	decl String:RecordString[192];
	new bool:bIsBest;
	
	if ( bNewTime )
	{
		if ( flNewTime > flMapBestTime[ iClientRun[client] ][ iClientMode[client] ] )
		{
			Format( RecordString, sizeof( RecordString ), "%s \x03%N%s finished \x03%s%s for the first time [%s%s%s]!\n\x06(%s\x06)", CHAT_PREFIX, client, COLOR_TEXT, RunName[ iClientRun[client] ], COLOR_TEXT, COLOR_GRAY, ModeName[MODENAME_SHORT][ iClientMode[client] ], COLOR_TEXT, FormattedTime );
			
			if ( flMapBestTime[ iClientRun[client] ][ iClientMode[client] ] <= 0.0 )
				bIsBest = true;
		}
		else
		{
			Format( RecordString, sizeof( RecordString ), "%s \x03%N%s broke \x03%s%s record [%s%s%s]!\n\x06(%s\x06) Improving \x03%.2f\x06sec!", CHAT_PREFIX, client, COLOR_TEXT, RunName[ iClientRun[client] ], COLOR_TEXT, COLOR_GRAY, ModeName[MODENAME_SHORT][ iClientMode[client] ], COLOR_TEXT, FormattedTime, flLeftSeconds );
			bIsBest = true;
		}
	}
	else
	{
		if ( flNewTime > flMapBestTime[ iClientRun[client] ][ iClientMode[client] ] )
		{
			if ( flNewTime > flClientBestTime[client][ iClientRun[client] ][ iClientMode[client] ] )
				Format( RecordString, sizeof( RecordString ), "%s \x03%N%s finished \x03%s%s [%s%s%s]!\n\x06(%s\x06)", CHAT_PREFIX, client, COLOR_TEXT, RunName[ iClientRun[client] ], COLOR_TEXT, COLOR_GRAY, ModeName[MODENAME_SHORT][ iClientMode[client] ], COLOR_TEXT, FormattedTime );
			else
				Format( RecordString, sizeof( RecordString ), "%s \x03%N%s finished \x03%s%s [%s%s%s]!\n\x06(%s\x06) Improving \x03%.2f\x06sec!", CHAT_PREFIX, client, COLOR_TEXT, RunName[ iClientRun[client] ], COLOR_TEXT, COLOR_GRAY, ModeName[MODENAME_SHORT][ iClientMode[client] ], COLOR_TEXT, FormattedTime, flClientBestTime[client][ iClientRun[client] ][ iClientMode[client] ] - flNewTime );
		}
		else
		{
			Format( RecordString, sizeof( RecordString ), "%s \x03%N%s broke \x03%s%s record [%s%s%s]!\n\x06(%s\x06) Improving \x03%.2f\x06sec!", CHAT_PREFIX, client, COLOR_TEXT, RunName[ iClientRun[client] ], COLOR_TEXT, COLOR_GRAY, ModeName[MODENAME_SHORT][ iClientMode[client] ], COLOR_TEXT, FormattedTime, flLeftSeconds );
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
	
	// Update client and map best time if needed.
	if ( !bNewTime && flNewTime < flClientBestTime[client][ iClientRun[client] ][ iClientMode[client] ] )
	{
		flClientBestTime[client][ iClientRun[client] ][ iClientMode[client] ] = flNewTime;
		
		Format( Buffer, sizeof( Buffer ), "UPDATE '%s' SET time = '%.3f', name = '%N', jumps = %i, strafes = %i WHERE mode = %i AND run = %i AND steamid = '%s';", CurrentMap, flNewTime, client, iClientJumpCount[client], iClientStrafeCount[client], iClientMode[client],  iClientRun[client] , SteamId );
		
		if ( !SQL_FastQuery( Database, Buffer ) )
		{
			SQL_GetError( Database, Error, sizeof( Error ) );
			LogError( "%s Couldn't save player's record!\nError: %s", CONSOLE_PREFIX, Error );
			
			return false;
		}
	}
	
	// Save if best time and save the recording on disk. :)
	if ( flMapBestTime[ iClientRun[client] ][ iClientMode[client] ] <= 0.0 || flNewTime < flMapBestTime[ iClientRun[client] ][ iClientMode[client] ] )
	{
		flMapBestTime[ iClientRun[client] ][ iClientMode[client] ] = flNewTime;
		
#if defined RECORD
		if ( iClientRun[client] == RUN_MAIN && bIsClientRecording[client] && hClientRecording[client] != INVALID_HANDLE )
		{
			new len = GetArraySize( hClientRecording[client] );
			
			if ( len > MIN_REC_SIZE )
			{
				if ( !SaveRecording( client, len ) )
					return false;
				
				// We saved. Now let's update the bot!
				
				// Reset stuff just in case we happen to fuck up something.
				bIsClientMimicing[ iMimic[ iClientMode[client] ] ] = false;
				iClientTick[ iMimic[ iClientMode[client] ] ] = -1;
				
				hMimicRecording[ iClientMode[client] ] = CloneArray( hClientRecording[client] );
				iMimicTickMax[ iClientMode[client] ] = len;
				
				Format( MimicName[ iClientMode[client] ], sizeof( MimicName[] ), "%N", client );
				
				ArrayCopy( vecInitPos[client], vecInitMimicPos[ iClientMode[client] ], 3 );
				ArrayCopy( angInitAngles[client], angInitMimicAngles[ iClientMode[client] ], 2 );
				
				if ( iMimic[ iClientMode[client] ] != 0 ) // We already have a bot? Let's use him instead.
				{
					decl String:Name[32];
					Format( Name, sizeof( Name ), "REC* %s [%s]", MimicName[ iClientMode[client] ], ModeName[MODENAME_SHORT][ iClientMode[client] ] );
					SetClientInfo( iMimic[ iClientMode[client] ], "name", Name );
					
					decl String:MimicTime[13];
					FormatSeconds( flMapBestTime[RUN_MAIN][ iClientMode[client] ], MimicTime, false );
					CS_SetClientClanTag( iMimic[ iClientMode[client] ], MimicTime );
					
					TeleportEntity( iMimic[ iClientMode[client] ], vecInitMimicPos[ iMimic[ iClientMode[client] ] ], angInitMimicAngles[ iMimic[ iClientMode[client] ] ], vecNull );
					CreateTimer( 2.0, Timer_Rec_Start, iMimic[ iClientMode[client] ] );
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
	
	return true;
}

// SAVE EVERYTHINNNNNNNNNNNNNNGGGGGGGGGGGGGGGGGGG
stock bool:SaveClientInfo( client )
{
	if ( Database == INVALID_HANDLE ) return false;
	
	decl String:SteamId[32];
	
	if ( !GetClientAuthString( client, SteamId, sizeof( SteamId ) ) )
	{
		LogError( "%s There was an error at trying to retrieve player's \"%N\" Steam ID! Cannot save record.", CONSOLE_PREFIX, client );
		return false;
	}
	
	decl String:Buffer[256];
	
	Format( Buffer, sizeof( Buffer ), "UPDATE player_data SET fov = %i, hideflags = %i WHERE steamid = '%s';", iClientFOV[client], iClientHideFlags[client], SteamId );
		
	if ( !SQL_FastQuery( Database, Buffer ) )
	{
		SQL_GetError( Database, Error, sizeof( Error ) );
		LogError( "%s Couldn't save player's \"%N\" profile!\nError: %s", CONSOLE_PREFIX, client, Error );
	
		return false;
	}
	
	return true;
}

// Get client options (fov and hideflags) and time it took him/her to beat the map in all modes.
stock bool:RetrieveClientInfo( client )
{
	decl String:SteamId[32];
	
	if ( !GetClientAuthString( client, SteamId, sizeof( SteamId ) ) )
	{
		LogError( "%s There was an error at trying to retrieve player's \"%N\" Steam ID! Cannot save record.", CONSOLE_PREFIX, client );
		
		return false;
	}
	
	decl String:Buffer[128];
	
	Format( Buffer, sizeof( Buffer ), "SELECT * FROM player_data WHERE steamid = '%s';", SteamId );
	new Handle:ClientQuery = SQL_Query( Database, Buffer );
	
	if ( ClientQuery == INVALID_HANDLE )
	{
		SQL_GetError( Database, Error, sizeof( Error ) );
		LogError( "%s Couldn't retrieve player data!\n Error: %s", CONSOLE_PREFIX, Error );
		
		return false;
	}
	
	if ( SQL_GetRowCount( ClientQuery ) == 0 )
	{
		Format( Buffer, sizeof( Buffer ), "INSERT INTO player_data ( steamid, fov, hideflags ) VALUES ( '%s', 90, 0 );", SteamId );
		CloseHandle( ClientQuery );
		
		if ( !SQL_FastQuery( Database, Buffer ) )
		{
			LogError( "%s Error! Couldn't add a row for new profile!! Steam ID: %s", CONSOLE_PREFIX, SteamId );
			return false;
		}

		return true;
	}

	new field;
	while ( SQL_FetchRow( ClientQuery ) )
	{
		SQL_FieldNameToNum( ClientQuery, "fov", field );
		iClientFOV[client] = SQL_FetchInt( ClientQuery, field );
		
		SQL_FieldNameToNum( ClientQuery, "hideflags", field );
		iClientHideFlags[client] = SQL_FetchInt( ClientQuery, field );
	}
	
	Format( Buffer, sizeof( Buffer ), "SELECT time, mode, run FROM '%s' WHERE steamid = '%s' ORDER BY run;", CurrentMap, SteamId );
	ClientQuery = SQL_Query( Database, Buffer );
	
	if ( ClientQuery != INVALID_HANDLE )
	{
		new iMode, iRun;
		while ( SQL_FetchRow( ClientQuery ) )
		{
			SQL_FieldNameToNum( ClientQuery, "run", field );
			iRun = SQL_FetchInt( ClientQuery, field );
			
			SQL_FieldNameToNum( ClientQuery, "mode", field );
			iMode = SQL_FetchInt( ClientQuery, field );
		
			SQL_FieldNameToNum( ClientQuery, "time", field );
			flClientBestTime[client][iRun][iMode] = SQL_FetchFloat( ClientQuery, field );
		}
	}
	
	CloseHandle( ClientQuery );
	
	UpdateScoreboard( client );
	
	return true;
}

// Initialize sounds so important. I'm so cool.
// Create connection with database and get all valid run-able maps so we can vote for them.
stock InitializeDatabase()
{
	Database = SQL_DefConnect( Error, sizeof( Error ) );
	
	if ( Database == INVALID_HANDLE )
		SetFailState( "%s Unable to establish connection to database!\n Error: %s", CONSOLE_PREFIX, Error );
	
	if ( !SQL_FastQuery( Database, "CREATE TABLE IF NOT EXISTS player_data ( steamid VARCHAR( 32 ), fov INTEGER, hideflags INTEGER );" ) )
	{
		SQL_GetError( Database, Error, sizeof( Error ) );
		SetFailState( "%s Plugin was unable to create table for player profiles!\nError: %s", CONSOLE_PREFIX, Error );
	}
	
	PrintToServer( "%s Established connection with database!", CONSOLE_PREFIX );
}

// Get map bounds :^)
stock InitializeMapBounds()
{
	if ( Database == INVALID_HANDLE )
		SetFailState( "%s No connection to database. Unable to retrieve map data!", CONSOLE_PREFIX );
	
	// Really hacky way, soz.
	// For servers that updated from v1.0 to v1.1
	
	// ALTER TABLE _mapbounds ADD COLUMN b1_smin0 REAL;ALTER TABLE _mapbounds ADD COLUMN b1_smin1 REAL;ALTER TABLE _mapbounds ADD COLUMN b1_smin2 REAL;ALTER TABLE _mapbounds ADD COLUMN b1_smax0 REAL;ALTER TABLE _mapbounds ADD COLUMN b1_smax1 REAL;ALTER TABLE _mapbounds ADD COLUMN b1_smax2 REAL;ALTER TABLE _mapbounds ADD COLUMN b1_emin0 REAL;ALTER TABLE _mapbounds ADD COLUMN b1_emin1 REAL;ALTER TABLE _mapbounds ADD COLUMN b1_emin2 REAL;ALTER TABLE _mapbounds ADD COLUMN b1_emax0 REAL;ALTER TABLE _mapbounds ADD COLUMN b1_emax1 REAL;ALTER TABLE _mapbounds ADD COLUMN b1_emax2 REAL;ALTER TABLE _mapbounds ADD COLUMN b2_smin0 REAL;ALTER TABLE _mapbounds ADD COLUMN b2_smin1 REAL;ALTER TABLE _mapbounds ADD COLUMN b2_smin2 REAL;ALTER TABLE _mapbounds ADD COLUMN b2_smax0 REAL;ALTER TABLE _mapbounds ADD COLUMN b2_smax1 REAL;ALTER TABLE _mapbounds ADD COLUMN b2_smax2 REAL;ALTER TABLE _mapbounds ADD COLUMN b2_emin0 REAL;ALTER TABLE _mapbounds ADD COLUMN b2_emin1 REAL;ALTER TABLE _mapbounds ADD COLUMN b2_emin2 REAL;ALTER TABLE _mapbounds ADD COLUMN b2_emax0 REAL;ALTER TABLE _mapbounds ADD COLUMN b2_emax1 REAL;ALTER TABLE _mapbounds ADD COLUMN b2_emax2 REAL;ALTER TABLE _mapbounds ADD COLUMN fs1min0 REAL;ALTER TABLE _mapbounds ADD COLUMN fs1min1 REAL;ALTER TABLE _mapbounds ADD COLUMN fs1min2 REAL;ALTER TABLE _mapbounds ADD COLUMN fs1max0 REAL;ALTER TABLE _mapbounds ADD COLUMN fs1max1 REAL;ALTER TABLE _mapbounds ADD COLUMN fs1max2 REAL;ALTER TABLE _mapbounds ADD COLUMN fs2min0 REAL;ALTER TABLE _mapbounds ADD COLUMN fs2min1 REAL;ALTER TABLE _mapbounds ADD COLUMN fs2min2 REAL;ALTER TABLE _mapbounds ADD COLUMN fs2max0 REAL;ALTER TABLE _mapbounds ADD COLUMN fs2max1 REAL;ALTER TABLE _mapbounds ADD COLUMN fs2max2 REAL;ALTER TABLE _mapbounds ADD COLUMN fs3min0 REAL;ALTER TABLE _mapbounds ADD COLUMN fs3min1 REAL;ALTER TABLE _mapbounds ADD COLUMN fs3min2 REAL;ALTER TABLE _mapbounds ADD COLUMN fs3max0 REAL;ALTER TABLE _mapbounds ADD COLUMN fs3max1 REAL;ALTER TABLE _mapbounds ADD COLUMN fs3max2 REAL;
	
	// ALTER TABLE mapname ADD COLUMN run INTEGER; UPDATE mapname SET run = 0;
	
	// Fuq me
	// Now, we COULD store all different bounds in separate tables with a key assigning it to specific bound, but IN THE END IT DOESN'T EVEN MATTER.
	// You see, we are going to have to limit the amount of bounds we have in the first place. Having a static array just makes things a lot easier.
	// I wouldn't trust dynamic arrays in this case. Especially when we do calculations on bounds every frame.
	
	if ( !SQL_FastQuery( Database, "CREATE TABLE IF NOT EXISTS _mapbounds ( map VARCHAR( 32 ), smin0 REAL, smin1 REAL, smin2 REAL, smax0 REAL, smax1 REAL, smax2 REAL, emin0 REAL, emin1 REAL, emin2 REAL, emax0 REAL, emax1 REAL, emax2 REAL, bl1min0 REAL, bl1min1 REAL, bl1min2 REAL, bl1max0 REAL, bl1max1 REAL, bl1max2 REAL, bl2min0 REAL, bl2min1 REAL, bl2min2 REAL, bl2max0 REAL, bl2max1 REAL, bl2max2 REAL, bl3min0 REAL, bl3min1 REAL, bl3min2 REAL, bl3max0 REAL, bl3max1 REAL, bl3max2 REAL, b1_smin0 REAL, b1_smin1 REAL, b1_smin2 REAL, b1_smax0 REAL, b1_smax1 REAL, b1_smax2 REAL, b1_emin0 REAL, b1_emin1 REAL, b1_emin2 REAL, b1_emax0 REAL, b1_emax1 REAL, b1_emax2 REAL, b2_smin0 REAL, b2_smin1 REAL, b2_smin2 REAL, b2_smax0 REAL, b2_smax1 REAL, b2_smax2 REAL, b2_emin0 REAL, b2_emin1 REAL, b2_emin2 REAL, b2_emax0 REAL, b2_emax1 REAL, b2_emax2 REAL, fs1min0 REAL, fs1min1 REAL, fs1min2 REAL, fs1max0 REAL, fs1max1 REAL, fs1max2 REAL, fs2min0 REAL, fs2min1 REAL, fs2min2 REAL, fs2max0 REAL, fs2max1 REAL, fs2max2 REAL, fs3min0 REAL, fs3min1 REAL, fs3min2 REAL, fs3max0 REAL, fs3max1 REAL, fs3max2 REAL );" ) )
	{
		SQL_GetError( Database, Error, sizeof( Error ) );
		SetFailState( "%s Couldn't create map bounds table!\nError: %s", CONSOLE_PREFIX, Error );
	}
	
	decl String:Buffer[256];
	
	Format( Buffer, sizeof( Buffer ), "CREATE TABLE IF NOT EXISTS '%s' ( steamid VARCHAR( 32 ), name VARCHAR( 64 ), time REAL, jumps INTEGER, mode INTEGER, run INTEGER, strafes INTEGER );", CurrentMap );
	
	if ( !SQL_FastQuery( Database, Buffer ) )
	{
		SQL_GetError( Database, Error, sizeof( Error ) );
		SetFailState( "%s Couldn't create map record table!\nError: %s", CONSOLE_PREFIX, Error );
	}
	
	Format( Buffer, sizeof( Buffer ), "SELECT * FROM _mapbounds WHERE map = '%s';", CurrentMap );
	new Handle:TempQuery = SQL_Query( Database, Buffer );
	
	if ( TempQuery == INVALID_HANDLE )
	{
		SQL_GetError( Database, Error, sizeof( Error ) );
		SetFailState( "%s Unable to retrieve map bounds!\nError: %s", CONSOLE_PREFIX, Error );
	}
	
	new field;
	
	if ( SQL_GetRowCount( TempQuery ) == 0 )
	{
		Format( Buffer, sizeof( Buffer ), "INSERT INTO _mapbounds ( map ) VALUES ( '%s' );", CurrentMap );
		
		if ( !SQL_FastQuery( Database, Buffer ) ) {
			SQL_GetError( Database, Error, sizeof( Error ) );
			
			SetFailState( "%s Couldn't create map bounds table!\nError: %s", CONSOLE_PREFIX, Error );
		}
		
		return;
	}
	else
	{
		while ( SQL_FetchRow( TempQuery ) )
		{
			// START BOUNDS
			SQL_FieldNameToNum( TempQuery, "smin0", field );
			
			if ( !SQL_IsFieldNull( TempQuery, field ) )
			{
				vecBoundsMin[BOUNDS_START][0] = SQL_FetchFloat( TempQuery, field );

				SQL_FieldNameToNum( TempQuery, "smin1", field );
				vecBoundsMin[BOUNDS_START][1] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "smin2", field );
				vecBoundsMin[BOUNDS_START][2] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "smax0", field );
				vecBoundsMax[BOUNDS_START][0] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "smax1", field );
				vecBoundsMax[BOUNDS_START][1] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "smax2", field );
				vecBoundsMax[BOUNDS_START][2] = SQL_FetchFloat( TempQuery, field );

				bZoneExists[BOUNDS_START] = true;
			}
			else bZoneExists[BOUNDS_START] = false;
			
			// END BOUNDS
			SQL_FieldNameToNum( TempQuery, "emin0", field );

			if ( !SQL_IsFieldNull( TempQuery, field ) )
			{
				vecBoundsMin[BOUNDS_END][0] = SQL_FetchFloat( TempQuery, field );

				SQL_FieldNameToNum( TempQuery, "emin1", field );
				vecBoundsMin[BOUNDS_END][1] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "emin2", field );
				vecBoundsMin[BOUNDS_END][2] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "emax0", field );
				vecBoundsMax[BOUNDS_END][0] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "emax1", field );
				vecBoundsMax[BOUNDS_END][1] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "emax2", field );
				vecBoundsMax[BOUNDS_END][2] = SQL_FetchFloat( TempQuery, field );

				bZoneExists[BOUNDS_END] = true;
			}
			else bZoneExists[BOUNDS_END] = false;
	
			// BLOCK BOUNDS
			// BLOCK #1
			SQL_FieldNameToNum( TempQuery, "bl1min0", field );
			
			if ( !SQL_IsFieldNull( TempQuery, field ) )
			{
				vecBoundsMin[BOUNDS_BLOCK_1][0] = SQL_FetchFloat( TempQuery, field );

				SQL_FieldNameToNum( TempQuery, "bl1min1", field );
				vecBoundsMin[BOUNDS_BLOCK_1][1] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "bl1min2", field );
				vecBoundsMin[BOUNDS_BLOCK_1][2] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "bl1max0", field );
				vecBoundsMax[BOUNDS_BLOCK_1][0] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "bl1max1", field );
				vecBoundsMax[BOUNDS_BLOCK_1][1] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "bl1max2", field );
				vecBoundsMax[BOUNDS_BLOCK_1][2] = SQL_FetchFloat( TempQuery, field );
				
				bZoneExists[BOUNDS_BLOCK_1] = true;
			}
			else bZoneExists[BOUNDS_BLOCK_1] = false;
			
			// BLOCK #2
			SQL_FieldNameToNum( TempQuery, "bl2min0", field );
			
			if ( !SQL_IsFieldNull( TempQuery, field ) )
			{
				vecBoundsMin[BOUNDS_BLOCK_2][0] = SQL_FetchFloat( TempQuery, field );

				SQL_FieldNameToNum( TempQuery, "bl2min1", field );
				vecBoundsMin[BOUNDS_BLOCK_2][1] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "bl2min2", field );
				vecBoundsMin[BOUNDS_BLOCK_2][2] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "bl2max0", field );
				vecBoundsMax[BOUNDS_BLOCK_2][0] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "bl2max1", field );
				vecBoundsMax[BOUNDS_BLOCK_2][1] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "bl2max2", field );
				vecBoundsMax[BOUNDS_BLOCK_2][2] = SQL_FetchFloat( TempQuery, field );

				bZoneExists[BOUNDS_BLOCK_2] = true;
			}
			else bZoneExists[BOUNDS_BLOCK_2] = false;
			

			
			// BLOCK #3
			SQL_FieldNameToNum( TempQuery, "bl3min0", field );
			
			if ( !SQL_IsFieldNull( TempQuery, field ) )
			{
				vecBoundsMin[BOUNDS_BLOCK_3][0] = SQL_FetchFloat( TempQuery, field );

				SQL_FieldNameToNum( TempQuery, "bl3min1", field );
				vecBoundsMin[BOUNDS_BLOCK_3][1] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "bl3min2", field );
				vecBoundsMin[BOUNDS_BLOCK_3][2] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "bl3max0", field );
				vecBoundsMax[BOUNDS_BLOCK_3][0] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "bl3max1", field );
				vecBoundsMax[BOUNDS_BLOCK_3][1] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "bl3max2", field );
				vecBoundsMax[BOUNDS_BLOCK_3][2] = SQL_FetchFloat( TempQuery, field );

				bZoneExists[BOUNDS_BLOCK_3] = true;
			}
			else bZoneExists[BOUNDS_BLOCK_3] = false;
			
			
			// BONUS #1 START
			SQL_FieldNameToNum( TempQuery, "b1_smin0", field );
			
			if ( !SQL_IsFieldNull( TempQuery, field ) )
			{
				vecBoundsMin[BOUNDS_BONUS_1_START][0] = SQL_FetchFloat( TempQuery, field );

				SQL_FieldNameToNum( TempQuery, "b1_smin1", field );
				vecBoundsMin[BOUNDS_BONUS_1_START][1] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "b1_smin2", field );
				vecBoundsMin[BOUNDS_BONUS_1_START][2] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "b1_smax0", field );
				vecBoundsMax[BOUNDS_BONUS_1_START][0] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "b1_smax1", field );
				vecBoundsMax[BOUNDS_BONUS_1_START][1] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "b1_smax2", field );
				vecBoundsMax[BOUNDS_BONUS_1_START][2] = SQL_FetchFloat( TempQuery, field );

				bZoneExists[BOUNDS_BONUS_1_START] = true;
			}
			else bZoneExists[BOUNDS_BONUS_1_START] = false;
			
			// BONUS #1 END
			SQL_FieldNameToNum( TempQuery, "b1_emin0", field );
			
			if ( !SQL_IsFieldNull( TempQuery, field ) )
			{
				vecBoundsMin[BOUNDS_BONUS_1_END][0] = SQL_FetchFloat( TempQuery, field );

				SQL_FieldNameToNum( TempQuery, "b1_emin1", field );
				vecBoundsMin[BOUNDS_BONUS_1_END][1] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "b1_emin2", field );
				vecBoundsMin[BOUNDS_BONUS_1_END][2] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "b1_emax0", field );
				vecBoundsMax[BOUNDS_BONUS_1_END][0] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "b1_emax1", field );
				vecBoundsMax[BOUNDS_BONUS_1_END][1] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "b1_emax2", field );
				vecBoundsMax[BOUNDS_BONUS_1_END][2] = SQL_FetchFloat( TempQuery, field );

				bZoneExists[BOUNDS_BONUS_1_END] = true;
			}
			else bZoneExists[BOUNDS_BONUS_1_END] = false;
			
			// BONUS #2 START
			SQL_FieldNameToNum( TempQuery, "b2_smin0", field );
			
			if ( !SQL_IsFieldNull( TempQuery, field ) )
			{
				vecBoundsMin[BOUNDS_BONUS_2_START][0] = SQL_FetchFloat( TempQuery, field );

				SQL_FieldNameToNum( TempQuery, "b2_smin1", field );
				vecBoundsMin[BOUNDS_BONUS_2_START][1] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "b2_smin2", field );
				vecBoundsMin[BOUNDS_BONUS_2_START][2] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "b2_smax0", field );
				vecBoundsMax[BOUNDS_BONUS_2_START][0] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "b2_smax1", field );
				vecBoundsMax[BOUNDS_BONUS_2_START][1] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "b2_smax2", field );
				vecBoundsMax[BOUNDS_BONUS_2_START][2] = SQL_FetchFloat( TempQuery, field );

				bZoneExists[BOUNDS_BONUS_2_START] = true;
			}
			else bZoneExists[BOUNDS_BONUS_2_START] = false;
			
			// BONUS #2 END
			SQL_FieldNameToNum( TempQuery, "b2_emin0", field );
			
			if ( !SQL_IsFieldNull( TempQuery, field ) )
			{
				vecBoundsMin[BOUNDS_BONUS_2_END][0] = SQL_FetchFloat( TempQuery, field );

				SQL_FieldNameToNum( TempQuery, "b2_emin1", field );
				vecBoundsMin[BOUNDS_BONUS_2_END][1] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "b2_emin2", field );
				vecBoundsMin[BOUNDS_BONUS_2_END][2] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "b2_emax0", field );
				vecBoundsMax[BOUNDS_BONUS_2_END][0] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "b2_emax1", field );
				vecBoundsMax[BOUNDS_BONUS_2_END][1] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "b2_emax2", field );
				vecBoundsMax[BOUNDS_BONUS_2_END][2] = SQL_FetchFloat( TempQuery, field );

				bZoneExists[BOUNDS_BONUS_2_END] = true;
			}
			else bZoneExists[BOUNDS_BONUS_2_END] = false;
			
			
			// FREESTYLE #1
			// ROCK THE MICROPHONE WITH A FREESTYLER
			SQL_FieldNameToNum( TempQuery, "fs1min0", field );
			
			if ( !SQL_IsFieldNull( TempQuery, field ) )
			{
				vecBoundsMin[BOUNDS_FREESTYLE_1][0] = SQL_FetchFloat( TempQuery, field );

				SQL_FieldNameToNum( TempQuery, "fs1min1", field );
				vecBoundsMin[BOUNDS_FREESTYLE_1][1] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "fs1min2", field );
				vecBoundsMin[BOUNDS_FREESTYLE_1][2] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "fs1max0", field );
				vecBoundsMax[BOUNDS_FREESTYLE_1][0] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "fs1max1", field );
				vecBoundsMax[BOUNDS_FREESTYLE_1][1] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "fs1max2", field );
				vecBoundsMax[BOUNDS_FREESTYLE_1][2] = SQL_FetchFloat( TempQuery, field );

				bZoneExists[BOUNDS_FREESTYLE_1] = true;
			}
			else bZoneExists[BOUNDS_FREESTYLE_1] = false;
			
			// FREESTYLE #2
			SQL_FieldNameToNum( TempQuery, "fs2min0", field );
			
			if ( !SQL_IsFieldNull( TempQuery, field ) )
			{
				vecBoundsMin[BOUNDS_FREESTYLE_2][0] = SQL_FetchFloat( TempQuery, field );

				SQL_FieldNameToNum( TempQuery, "fs2min1", field );
				vecBoundsMin[BOUNDS_FREESTYLE_2][1] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "fs2min2", field );
				vecBoundsMin[BOUNDS_FREESTYLE_2][2] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "fs2max0", field );
				vecBoundsMax[BOUNDS_FREESTYLE_2][0] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "fs2max1", field );
				vecBoundsMax[BOUNDS_FREESTYLE_2][1] = SQL_FetchFloat( TempQuery, field );
				
				SQL_FieldNameToNum( TempQuery, "fs2max2", field );
				vecBoundsMax[BOUNDS_FREESTYLE_2][2] = SQL_FetchFloat( TempQuery, field );

				bZoneExists[BOUNDS_FREESTYLE_2] = true;
			}
			else bZoneExists[BOUNDS_FREESTYLE_2] = false;
			
			// FREESTYLE #3
			SQL_FieldNameToNum( TempQuery, "fs3min0", field );
			
			if ( !SQL_IsFieldNull( TempQuery, field ) )
			{
				vecBoundsMin[BOUNDS_FREESTYLE_3][0] = SQL_FetchFloat( TempQuery, field );

				SQL_FieldNameToNum( TempQuery, "fs3min1", field );
				vecBoundsMin[BOUNDS_FREESTYLE_3][1] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "fs3min2", field );
				vecBoundsMin[BOUNDS_FREESTYLE_3][2] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "fs3max0", field );
				vecBoundsMax[BOUNDS_FREESTYLE_3][0] = SQL_FetchFloat( TempQuery, field );
			
				SQL_FieldNameToNum( TempQuery, "fs3max1", field );
				vecBoundsMax[BOUNDS_FREESTYLE_3][1] = SQL_FetchFloat( TempQuery, field );
				
				SQL_FieldNameToNum( TempQuery, "fs3max2", field );
				vecBoundsMax[BOUNDS_FREESTYLE_3][2] = SQL_FetchFloat( TempQuery, field );

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
	
	Format( Buffer, sizeof( Buffer ), "SELECT run, mode, MIN( time ), steamid, name FROM %s GROUP BY run, mode;", CurrentMap );
	TempQuery = SQL_Query( Database, Buffer );
	
	if ( TempQuery == INVALID_HANDLE )
	{
		SQL_GetError( Database, Error, sizeof( Error ) );
		SetFailState( "%s Unable to retrieve map best times!\nError: %s", CONSOLE_PREFIX, Error );
	}
	
	new iMode, iRun;
	
#if defined RECORD
	decl String:SteamID[32], String:Name[MAX_NAME_LENGTH];
	
	iNumMimic = 0;
#endif

	while ( SQL_FetchRow( TempQuery ) )
	{
		iRun = SQL_FetchInt( TempQuery, 0 );
	
		iMode = SQL_FetchInt( TempQuery, 1 ); // Using SQL_FieldNameToNum seems to break everything for some reason.
		flMapBestTime[iRun][iMode] = SQL_FetchFloat( TempQuery, 2 );
		
#if defined RECORD
		if ( iRun != RUN_MAIN ) continue;
		// Load records from disk.
		// Assigning the records to bots are done in OnClientPostAdminCheck()
		SQL_FetchString( TempQuery, 3, SteamID, sizeof( SteamID ) );
		SQL_FetchString( TempQuery, 4, Name, sizeof( Name ) );

		if ( LoadRecording( SteamID, iMode ) )
		{
			PrintToServer( "%s Recording found! (%s)", CONSOLE_PREFIX, ModeName[MODENAME_LONG][iMode] );
			
			strcopy( MimicName[iMode], sizeof( MimicName[] ), Name );
			iNumMimic++;
		}
#endif

	}
	
	CloseHandle( TempQuery );
	
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
	new Handle:Query = SQL_Query( Database, "SELECT map FROM _mapbounds WHERE smin0 IS NOT NULL AND emin0 IS NOT NULL AND ( map LIKE 'bhop_%' OR map LIKE 'kz_%' ) ORDER BY map;" );

	if ( Query == INVALID_HANDLE )
	{
		SQL_GetError( Database, Error, sizeof( Error ) );
		SetFailState( "%s Plugin was unable to recieve tables (map names) from database!!\nError: %s", CONSOLE_PREFIX, Error );
	}

	decl String:MapName[32];
	hMapList = CreateArray( MAX_MAP_NAME_LENGTH );
	
	while( SQL_FetchRow( Query ) )
	{
		SQL_FetchString( Query, 0, MapName, sizeof( MapName ) );
		
		new iMap[MAX_MAP_NAME_LENGTH];
		strcopy( iMap[MAP_NAME], sizeof( iMap[MAP_NAME] ), MapName );
		
		PushArrayArray( hMapList, iMap, _:MapInfo );
	}
	
	CloseHandle( Query );
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
	
	if ( !SQL_FastQuery( Database, Buffer ) )
	{
		SQL_GetError( Database, Error, sizeof( Error ) );
		LogError( "%s Couldn't save map's ending bounds!\nError: %s", CONSOLE_PREFIX, Error );
		
		return false;
	}
	
	bZoneExists[bounds] = true;
	return true;
}

stock bool:EraseMapCoords( bounds )
{
	decl String:Buffer[300];
	
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
	
	if ( !SQL_FastQuery( Database, Buffer ) )
	{
		SQL_GetError( Database, Error, sizeof( Error ) );
		LogError( "%s Couldn't erase map's ending bounds!\nError: %s", CONSOLE_PREFIX, Error );
		
		return false;
	}
	
	bZoneExists[bounds] = false;
	return true;
}