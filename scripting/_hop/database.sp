static Handle:Database = INVALID_HANDLE;
static String:Error[150];

stock PrintRecords( client, bool:bInConsole, iReqMode=-1 )
{
	decl String:Buffer[128];
	new amt;
	
	if ( bInConsole ) amt = 16;
	else amt = 5;
	
	if ( iReqMode != -1 )
		Format( Buffer, sizeof( Buffer ), "SELECT * FROM '%s' WHERE mode = %i ORDER BY time LIMIT %i", CurrentMap, iReqMode, amt );
	else
		Format( Buffer, sizeof( Buffer ), "SELECT * FROM '%s' ORDER BY time LIMIT %i", CurrentMap, amt );
	
	new Handle:TimeQuery = SQL_Query( Database, Buffer );
	
	if ( TimeQuery == INVALID_HANDLE )
	{
		SQL_GetError( Database, Error, sizeof( Error ) );
		LogError( "\n\n\n%s Error occured when trying to print times to client.\nError: %s\n\n", CONSOLE_PREFIX, Error );
	
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
		flSeconds[ply] += 0.0001; // Just to make sure...
		
		SQL_FieldNameToNum( TimeQuery, "mode", field );
		iMode[ply] = SQL_FetchInt( TimeQuery, field );
		
		FormatSeconds( flSeconds[ply], FormattedTime[ply], true );
		
		ply++;
	}
	
	new index = 1;
	if ( !bInConsole )
	{
		decl String:Text[200];
		
		if ( ply > 0 )
		{
			Format( Text, sizeof( Text ), "!printrecords for detailed version." );
			
			for ( new i; i < ply; i++ )
			{
				Format( Text, sizeof( Text ), "%s\n\n%i. %s - %s - %s", Text, index, Name[i], FormattedTime[i], ModeName[MODENAME_SHORT][ iMode[i] ] );
				index++;
			}
		}
		else Format( Text, sizeof( Text ), "No one has beaten the map yet... :(" );
		
		ShowMOTDPanel( client, "Top 5 (All modes)", Text, MOTDPANEL_TYPE_TEXT );
	}
	else
	{
		PrintToConsole( client, "\nRecords (Max. 16):\n!printrecord <mode> for specific modes. (\"normal\", \"sideways\", \"w\")\n\n----------------" );
		
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

stock bool:SaveClientRecord( client, Float:flNewTime, iMode, iJumpCount, iStrafeCount )
{
	decl String:SteamId[32];
	
	if ( !GetClientAuthString( client, SteamId, sizeof( SteamId ) ) )
	{
		LogError( "\n\n\n%s There was an error at trying to retrieve player's \"%N\" Steam ID! Cannot save record.\n\n", CONSOLE_PREFIX, client );
		
		return false;
	}
	
	decl String:Buffer[300];
	
	Format( Buffer, sizeof( Buffer ), "SELECT time FROM '%s' WHERE mode = %i AND steamid = '%s';", CurrentMap, iMode, SteamId );
	new Handle:TimeBuffer = SQL_Query( Database, Buffer );
	
	if ( TimeBuffer == INVALID_HANDLE )
	{
		SQL_GetError( Database, Error, sizeof( Error ) );
		LogError( "\n\n\n%s Couldn't retrieve player's old time when saving record!\nError: %s\n\n", CONSOLE_PREFIX, Error );
		
		return false;
	}
	
	flNewTime += 0.0001; // Just to make sure the database doesn't fuck it up.
	
	new bool:_bNewTime;
	if ( SQL_GetRowCount( TimeBuffer ) == 0 ) // Beat it for the first time!
	{
		Format( Buffer, sizeof( Buffer ), "INSERT INTO '%s' ( steamid, name, time, jumps, mode, strafes ) VALUES ( '%s', '%N', '%.3f', %i, %i, %i );", CurrentMap, SteamId, client, flNewTime, iJumpCount, iMode, iStrafeCount );
		
		if ( !SQL_FastQuery( Database, Buffer ) )
			return false;
		
		flClientBestTime[client][iMode] = flNewTime;
		_bNewTime = true;
	}
	////////////////////////////////////////////////////////////////////////////////
	// Print record in chat. Only here because my eyes are dying from repetition. //
	////////////////////////////////////////////////////////////////////////////////
	new Float:flLeftSeconds;
	
	if ( flNewTime > flMapBestTime[iMode] ) flLeftSeconds = flNewTime - flMapBestTime[iMode];
	else flLeftSeconds = flMapBestTime[iMode] - flNewTime;
	
	decl String:FormattedTime[18];
	FormatSeconds( flNewTime, FormattedTime, true, true );
	
	decl String:RecordString[192];
	new bool:_IsBest;
	
	if ( _bNewTime )
	{
		if ( flNewTime > flMapBestTime[iMode] )
		{
			Format( RecordString, sizeof( RecordString ), "%s \x03%N%s finished for the first time with %i jumps [%s]!\n\x06(%s\x06)", CHAT_PREFIX, client, COLOR_WHITE, iJumpCount, ModeName[MODENAME_SHORT][iMode], FormattedTime );
			
			if ( flMapBestTime[iMode] <= 0.0 )
				_IsBest = true;
		}
		else
		{
			Format( RecordString, sizeof( RecordString ), "%s \x03%N%s broke the record with %i jumps [%s]!\n\x06(%s\x06) Improving \x03%.2f\x06sec!", CHAT_PREFIX, client, COLOR_WHITE, iJumpCount, ModeName[MODENAME_SHORT][iMode], FormattedTime, flLeftSeconds );
			_IsBest = true;
		}
	}
	else
	{
		if ( flNewTime > flMapBestTime[iMode] )
		{
			if ( flNewTime > flClientBestTime[client][iMode] )
				Format( RecordString, sizeof( RecordString ), "%s \x03%N%s finished with %i jumps [%s]!\n\x06(%s\x06)", CHAT_PREFIX, client, COLOR_WHITE, iJumpCount, ModeName[MODENAME_SHORT][iMode], FormattedTime );
			else
				Format( RecordString, sizeof( RecordString ), "%s \x03%N%s finished with %i jumps [%s]!\n\x06(%s\x06) Improving \x03%.2f\x06sec!", CHAT_PREFIX, client, COLOR_WHITE, iJumpCount, ModeName[MODENAME_SHORT][iMode], FormattedTime, flClientBestTime[client][iMode] - flNewTime );
		}
		else
		{
			Format( RecordString, sizeof( RecordString ), "%s \x03%N%s broke the record with %i jumps [%s]!\n\x06(%s\x06) Improving \x03%.2f\x06sec!", CHAT_PREFIX, client, COLOR_WHITE, iJumpCount, ModeName[MODENAME_SHORT][iMode], FormattedTime, flLeftSeconds );
			_IsBest = true;
		}
	}
	
	PrintColorChatAll( client, false, RecordString );
	
	if ( _IsBest )
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
	if ( !_bNewTime && flNewTime < flClientBestTime[client][iMode] )
	{
		flClientBestTime[client][iMode] = flNewTime;
		
		Format( Buffer, sizeof( Buffer ), "UPDATE '%s' SET time = '%.3f', name = '%N', jumps = %i, strafes = %i WHERE mode = %i AND steamid = '%s';", CurrentMap, flNewTime, client, iJumpCount, iStrafeCount, iMode, SteamId );
		
		if ( !SQL_FastQuery( Database, Buffer ) )
		{
			SQL_GetError( Database, Error, sizeof( Error ) );
			LogError( "\n\n\n%s Couldn't save player's record!\nError: %s\n\n", CONSOLE_PREFIX, Error );
			
			return false;
		}
	}
	
	// Save if best time :)
	if ( flMapBestTime[iMode] <= 0.0 || flNewTime < flMapBestTime[iMode] )
	{
		flMapBestTime[iMode] = flNewTime;
		
		if ( bIsClientRecording[client] && hClientRecording[client] != INVALID_HANDLE )
		{
			new len = GetArraySize( hClientRecording[client] );
			
			if ( len > MIN_REC_SIZE )
			{
				SaveRecording( client, iMode, hClientRecording[client], len );

				if ( iMimic[iMode] != 0 )
				{
					hClientRecording[ iMimic[iMode] ] = CloneArray( hClientRecording[client] );
					
					decl String:Name[MAX_NAME_LENGTH];
					Format( Name, sizeof( Name ), "REC* %s", MimicName[iMode] );
					SetClientInfo( iMimic[iMode], "name", Name );
					
					decl String:MimicTime[13];
					FormatSeconds( flMapBestTime[iMode], MimicTime, false );
					CS_SetClientClanTag( iMimic[iMode], MimicTime );
					
					ArrayCopy( vecInitPos[client], vecInitPos[ iMimic[iMode] ], 3 );
					ArrayCopy( vecInitPos[client], angInitAngles[ iMimic[iMode] ], 3 );
					
					iClientTick[ iMimic[iMode] ] = -1;
					iClientTickMax[ iMimic[iMode] ] = GetArraySize( hClientRecording[ iMimic[iMode] ] );
					
					TeleportEntity( iMimic[iMode], vecInitPos[ iMimic[iMode] ], angInitMimicAngles[ iMimic[iMode] ], vecNull );
					CreateTimer( 2.0, Timer_Rec_Start, iMimic[iMode] );
				}
			}
		}
	}
	
	decl String:NewTime[13];
	FormatSeconds( flNewTime, NewTime, false );
	CS_SetClientClanTag( client, NewTime );
	
	return true;
}

stock bool:SaveClientInfo( client )
{
	if ( Database == INVALID_HANDLE ) return false;
	
	decl String:SteamId[32];
	
	if ( !GetClientAuthString( client, SteamId, sizeof( SteamId ) ) ) {
		LogError( "\n\n\n%s There was an error at trying to retrieve player's \"%N\" Steam ID! Cannot save record.\n\n", CONSOLE_PREFIX, client );
	
		return false;
	}
	
	decl String:Buffer[256];
	
	Format( Buffer, sizeof( Buffer ), "UPDATE player_data SET fov = %i, hideflags = %i WHERE steamid = '%s';", iClientFOV[client], iClientHideFlags[client], SteamId );
		
	if ( !SQL_FastQuery( Database, Buffer ) ) {
		SQL_GetError( Database, Error, sizeof( Error ) );
		LogError( "\n\n\n%s Couldn't save player's \"%N\" profile!\nError: %s\n\n", CONSOLE_PREFIX, client, Error );
	
		return false;
	}
	
	return true;
}

stock bool:RetrieveClientInfo( client )
{
	decl String:SteamId[32];
	
	if ( !GetClientAuthString( client, SteamId, sizeof( SteamId ) ) )
	{
		LogError( "\n\n\n%s There was an error at trying to retrieve player's \"%N\" Steam ID! Cannot save record.\n\n", CONSOLE_PREFIX, client );
		
		return false;
	}
	
	decl String:Buffer[256];
	
	Format( Buffer, sizeof( Buffer ), "SELECT * FROM player_data WHERE steamid = '%s';", SteamId );
	new Handle:ClientQuery = SQL_Query( Database, Buffer );
	
	if ( ClientQuery == INVALID_HANDLE )
	{
		SQL_GetError( Database, Error, sizeof( Error ) );
		LogError( "\n\n\n%s Couldn't retrieve player data!\n Error: %s\n\n", CONSOLE_PREFIX, Error );
		
		return false;
	}
	
	if ( SQL_GetRowCount( ClientQuery ) == 0 )
	{
		Format( Buffer, sizeof( Buffer ), "INSERT INTO player_data ( steamid, fov, hideflags ) VALUES ( '%s', 90, 0 );", SteamId );
		
		if ( !SQL_FastQuery( Database, Buffer ) )
		{
			LogError( "\n\n\n%s Error! Couldn't add a row for new profile!! Steam ID: %s\n\n", CONSOLE_PREFIX, SteamId );
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
	
	Format( Buffer, sizeof( Buffer ), "SELECT time, mode FROM '%s' WHERE steamid = '%s';", CurrentMap, SteamId );
	ClientQuery = SQL_Query( Database, Buffer );
	
	if ( ClientQuery != INVALID_HANDLE )
	{
		new iMode;
		while ( SQL_FetchRow( ClientQuery ) )
		{
			SQL_FieldNameToNum( ClientQuery, "mode", field );
			iMode = SQL_FetchInt( ClientQuery, field );
		
			SQL_FieldNameToNum( ClientQuery, "time", field );
			flClientBestTime[client][iMode] = SQL_FetchFloat( ClientQuery, field );
		}
	}
	
	return true;
}

stock InitializeDatabase()
{
	Database = SQL_DefConnect( Error, sizeof( Error ) );
	
	if ( Database == INVALID_HANDLE )
		SetFailState( "\n\n\n%s Unable to establish connection to database!\n Error: %s\n\n", CONSOLE_PREFIX, Error );
	
	if ( !SQL_FastQuery( Database, "CREATE TABLE IF NOT EXISTS player_data ( steamid VARCHAR( 32 ), fov INTEGER, hideflags INTEGER );" ) )
	{
		SQL_GetError( Database, Error, sizeof( Error ) );
		SetFailState( "\n\n\n%s Plugin was unable to create table for player profiles!\nError: %s\n\n", CONSOLE_PREFIX, Error );
	}
	
	PrintToServer( "\n\n%s Established connection with database!\n", CONSOLE_PREFIX );
	
	new Handle:Query = SQL_Query( Database, "SELECT name FROM sqlite_master WHERE type='table' ORDER BY NAME;" );
	
	if ( Query == INVALID_HANDLE )
	{
		SQL_GetError( Database, Error, sizeof( Error ) );
		SetFailState( "\n\n\n%s Plugin was unable to recieve tables (map names) from database!!\nError: %s\n\n", CONSOLE_PREFIX, Error );
	}
	
	decl String:MapName[32];
	hMapList = CreateArray( MAX_MAP_NAME_LENGTH );
	
	while ( SQL_FetchRow( Query ) )
	{
		SQL_FetchString( Query, 0, MapName, sizeof( MapName ) );
		
		if ( StrContains( MapName, "bhop_" ) != -1 || StrContains( MapName, "kz_" ) != -1 )
		{
			new iMap[MAX_MAP_NAME_LENGTH];
			strcopy( iMap[MAP_NAME], sizeof( iMap[MAP_NAME] ), MapName );
			
			PushArrayArray( hMapList, iMap, _:MapInfo );
		}
	}
}

stock bool:InitializeMapBounds()
{
	if ( Database == INVALID_HANDLE )
		SetFailState( "\n\n\n%s No connection to database. Unable to retrieve map data!\n\n", CONSOLE_PREFIX );
	
	if ( !SQL_FastQuery( Database, "CREATE TABLE IF NOT EXISTS _mapbounds ( map VARCHAR( 32 ), smin0 REAL, smin1 REAL, smin2 REAL, smax0 REAL, smax1 REAL, smax2 REAL, emin0 REAL, emin1 REAL, emin2 REAL, emax0 REAL, emax1 REAL, emax2 REAL, bl1min0 REAL, bl1min1 REAL, bl1min2 REAL, bl1max0 REAL, bl1max1 REAL, bl1max2 REAL, bl2min0 REAL, bl2min1 REAL, bl2min2 REAL, bl2max0 REAL, bl2max1 REAL, bl2max2 REAL, bl3min0 REAL, bl3min1 REAL, bl3min2 REAL, bl3max0 REAL, bl3max1 REAL, bl3max2 REAL );" ) )
	{
		SQL_GetError( Database, Error, sizeof( Error ) );
		
		SetFailState( "%s Couldn't create map bounds table!\nError: %s", CONSOLE_PREFIX, Error );
	}
	
	decl String:Buffer[256];
	
	Format( Buffer, sizeof( Buffer ), "CREATE TABLE IF NOT EXISTS '%s' ( steamid VARCHAR( 32 ), name VARCHAR( 64 ), time REAL, jumps INTEGER, mode INTEGER, strafes INTEGER );", CurrentMap );
	
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
		SetFailState( "\n\n%s Unable to retrieve map bounds!\nError: %s\n\n", CONSOLE_PREFIX, Error );
	}
	
	new field;
	
	if ( SQL_GetRowCount( TempQuery ) == 0 )
	{
		Format( Buffer, sizeof( Buffer ), "INSERT INTO _mapbounds ( map ) VALUES ( '%s' );", CurrentMap );
		
		if ( !SQL_FastQuery( Database, Buffer ) ) {
			SQL_GetError( Database, Error, sizeof( Error ) );
			
			SetFailState( "\n\n\n%s Couldn't create map bounds table!\nError: %s\n\n", CONSOLE_PREFIX, Error );
		}
		
		return false;
	}
	else
	{
		while ( SQL_FetchRow( TempQuery ) )
		{
			// START BOUNDS
			SQL_FieldNameToNum( TempQuery, "smin0", field );
			
			if ( !SQL_IsFieldNull( TempQuery, field ) )
				vecMapBoundsMin[BOUNDS_START][0] = SQL_FetchFloat( TempQuery, field );
			else
			{
				PrintToServer( "\n\n%s No bounds were applied to map!\n\n", CONSOLE_PREFIX );
				return false;
			}
			
			SQL_FieldNameToNum( TempQuery, "smin1", field );
			vecMapBoundsMin[BOUNDS_START][1] = SQL_FetchFloat( TempQuery, field );
			
			SQL_FieldNameToNum( TempQuery, "smin2", field );
			vecMapBoundsMin[BOUNDS_START][2] = SQL_FetchFloat( TempQuery, field );
			
			SQL_FieldNameToNum( TempQuery, "smax0", field );
			vecMapBoundsMax[BOUNDS_START][0] = SQL_FetchFloat( TempQuery, field );
			
			SQL_FieldNameToNum( TempQuery, "smax1", field );
			vecMapBoundsMax[BOUNDS_START][1] = SQL_FetchFloat( TempQuery, field );
			
			SQL_FieldNameToNum( TempQuery, "smax2", field );
			vecMapBoundsMax[BOUNDS_START][2] = SQL_FetchFloat( TempQuery, field );
			
			// END BOUNDS
			SQL_FieldNameToNum( TempQuery, "emin0", field );
			vecMapBoundsMin[BOUNDS_END][0] = SQL_FetchFloat( TempQuery, field );
			
			SQL_FieldNameToNum( TempQuery, "emin1", field );
			vecMapBoundsMin[BOUNDS_END][1] = SQL_FetchFloat( TempQuery, field );
			
			SQL_FieldNameToNum( TempQuery, "emin2", field );
			vecMapBoundsMin[BOUNDS_END][2] = SQL_FetchFloat( TempQuery, field );
			
			SQL_FieldNameToNum( TempQuery, "emax0", field );
			vecMapBoundsMax[BOUNDS_END][0] = SQL_FetchFloat( TempQuery, field );
			
			SQL_FieldNameToNum( TempQuery, "emax1", field );
			vecMapBoundsMax[BOUNDS_END][1] = SQL_FetchFloat( TempQuery, field );
			
			SQL_FieldNameToNum( TempQuery, "emax2", field );
			vecMapBoundsMax[BOUNDS_END][2] = SQL_FetchFloat( TempQuery, field );
			
			// BLOCK BOUNDS
			// BLOCK #1
			SQL_FieldNameToNum( TempQuery, "bl1min0", field );
			
			if ( !SQL_IsFieldNull( TempQuery, field ) )
			{
				vecMapBoundsMin[BOUNDS_BLOCK_1][0] = SQL_FetchFloat( TempQuery, field );
				bZoneExists[BOUNDS_BLOCK_1] = true;
			}
			else
			{
				bZoneExists[BOUNDS_BLOCK_1] = false;
				continue;
			}
			
			SQL_FieldNameToNum( TempQuery, "bl1min1", field );
			vecMapBoundsMin[BOUNDS_BLOCK_1][1] = SQL_FetchFloat( TempQuery, field );
			
			SQL_FieldNameToNum( TempQuery, "bl1min2", field );
			vecMapBoundsMin[BOUNDS_BLOCK_1][2] = SQL_FetchFloat( TempQuery, field );
			
			SQL_FieldNameToNum( TempQuery, "bl1max0", field );
			vecMapBoundsMax[BOUNDS_BLOCK_1][0] = SQL_FetchFloat( TempQuery, field );
			
			SQL_FieldNameToNum( TempQuery, "bl1max1", field );
			vecMapBoundsMax[BOUNDS_BLOCK_1][1] = SQL_FetchFloat( TempQuery, field );
			
			SQL_FieldNameToNum( TempQuery, "bl1max2", field );
			vecMapBoundsMax[BOUNDS_BLOCK_1][2] = SQL_FetchFloat( TempQuery, field );
			
			// BLOCK #2
			SQL_FieldNameToNum( TempQuery, "bl2min0", field );
			
			if ( !SQL_IsFieldNull( TempQuery, field ) )
			{
				vecMapBoundsMin[BOUNDS_BLOCK_2][0] = SQL_FetchFloat( TempQuery, field );
				bZoneExists[BOUNDS_BLOCK_2] = true;
			}
			else
			{
				bZoneExists[BOUNDS_BLOCK_2] = false;
				continue;
			}
			
			SQL_FieldNameToNum( TempQuery, "bl2min1", field );
			vecMapBoundsMin[BOUNDS_BLOCK_2][1] = SQL_FetchFloat( TempQuery, field );
			
			SQL_FieldNameToNum( TempQuery, "bl2min2", field );
			vecMapBoundsMin[BOUNDS_BLOCK_2][2] = SQL_FetchFloat( TempQuery, field );
			
			SQL_FieldNameToNum( TempQuery, "bl2max0", field );
			vecMapBoundsMax[BOUNDS_BLOCK_2][0] = SQL_FetchFloat( TempQuery, field );
			
			SQL_FieldNameToNum( TempQuery, "bl2max1", field );
			vecMapBoundsMax[BOUNDS_BLOCK_2][1] = SQL_FetchFloat( TempQuery, field );
			
			SQL_FieldNameToNum( TempQuery, "bl2max2", field );
			vecMapBoundsMax[BOUNDS_BLOCK_2][2] = SQL_FetchFloat( TempQuery, field );
			
			// BLOCK #3
			SQL_FieldNameToNum( TempQuery, "bl3min0", field );
			
			if ( !SQL_IsFieldNull( TempQuery, field ) )
			{
				vecMapBoundsMin[BOUNDS_BLOCK_3][0] = SQL_FetchFloat( TempQuery, field );
				bZoneExists[BOUNDS_BLOCK_3] = true;
			}
			else
			{
				bZoneExists[BOUNDS_BLOCK_3] = false;
				continue;
			}
			
			SQL_FieldNameToNum( TempQuery, "bl3min1", field );
			vecMapBoundsMin[BOUNDS_BLOCK_3][1] = SQL_FetchFloat( TempQuery, field );
			
			SQL_FieldNameToNum( TempQuery, "bl3min2", field );
			vecMapBoundsMin[BOUNDS_BLOCK_3][2] = SQL_FetchFloat( TempQuery, field );
			
			SQL_FieldNameToNum( TempQuery, "bl3max0", field );
			vecMapBoundsMax[BOUNDS_BLOCK_3][0] = SQL_FetchFloat( TempQuery, field );
			
			SQL_FieldNameToNum( TempQuery, "bl3max1", field );
			vecMapBoundsMax[BOUNDS_BLOCK_3][1] = SQL_FetchFloat( TempQuery, field );
			
			SQL_FieldNameToNum( TempQuery, "bl3max2", field );
			vecMapBoundsMax[BOUNDS_BLOCK_3][2] = SQL_FetchFloat( TempQuery, field );
		}
	}
	
	Format( Buffer, sizeof( Buffer ), "SELECT mode, MIN( time ), steamid, name FROM '%s' GROUP BY mode;", CurrentMap );
	TempQuery = SQL_Query( Database, Buffer );
	
	if ( TempQuery == INVALID_HANDLE )
	{
		SQL_GetError( Database, Error, sizeof( Error ) );
		SetFailState( "\n\n\n%s Unable to retrieve map best times!\nError: %s\n\n", CONSOLE_PREFIX, Error );
	}
	
	new iMode;
	decl String:SteamID[32], String:Name[MAX_NAME_LENGTH];
	while ( SQL_FetchRow( TempQuery ) )
	{
		iMode = SQL_FetchInt( TempQuery, 0 ); // Using SQL_FieldNameToNum seems to break everything for some reason.
		flMapBestTime[iMode] = SQL_FetchFloat( TempQuery, 1 );
		
		SQL_FetchString( TempQuery, 2, SteamID, sizeof( SteamID ) );
		SQL_FetchString( TempQuery, 3, Name, sizeof( Name ) );
		
		PrintToServer( "%s Searching for record: %s - %s - %s", CONSOLE_PREFIX, Name, SteamID, ModeName[MODENAME_LONG][iMode] );
		if ( LoadRecording( SteamID, iMode ) )
		{
			PrintToServer( "%s Recording found! (%s)", CONSOLE_PREFIX, ModeName[MODENAME_LONG][iMode] );
			
			strcopy( MimicName[iMode], sizeof( MimicName[] ), Name );
		}
		else PrintToServer( "%s No recording found for %s!", CONSOLE_PREFIX, ModeName[MODENAME_LONG][iMode] );
		//PrintToServer( "%s Received %s best time: %.3f ( %i )", CONSOLE_PREFIX, ModeName[iMode], flMapBestTime[iMode], iMode );
	}
	
	DoMapStuff();
	
	return true;
}

stock bool:SaveMapCoords( bounds )
{
	decl String:Buffer[300];
	
	if ( bounds == BOUNDS_START )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET smin0 = %.0f, smin1 = %.0f, smin2 = %.0f, smax0 = %.0f, smax1 = %.0f, smax2 = %.0f WHERE map = '%s';", vecMapBoundsMin[BOUNDS_START][0], vecMapBoundsMin[BOUNDS_START][1], vecMapBoundsMin[BOUNDS_START][2], vecMapBoundsMax[BOUNDS_START][0], vecMapBoundsMax[BOUNDS_START][1], vecMapBoundsMax[BOUNDS_START][2], CurrentMap );
	else if ( bounds == BOUNDS_END )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET emin0 = %.0f, emin1 = %.0f, emin2 = %.0f, emax0 = %.0f, emax1 = %.0f, emax2 = %.0f WHERE map = '%s';", vecMapBoundsMin[BOUNDS_END][0], vecMapBoundsMin[BOUNDS_END][1], vecMapBoundsMin[BOUNDS_END][2], vecMapBoundsMax[BOUNDS_END][0], vecMapBoundsMax[BOUNDS_END][1], vecMapBoundsMax[BOUNDS_END][2], CurrentMap );
	else if ( bounds == BOUNDS_BLOCK_1 )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET bl1min0 = %.0f, bl1min1 = %.0f, bl1min2 = %.0f, bl1max0 = %.0f, bl1max1 = %.0f, bl1max2 = %.0f WHERE map = '%s';", vecMapBoundsMin[BOUNDS_BLOCK_1][0], vecMapBoundsMin[BOUNDS_BLOCK_1][1], vecMapBoundsMin[BOUNDS_BLOCK_1][2], vecMapBoundsMax[BOUNDS_BLOCK_1][0], vecMapBoundsMax[BOUNDS_BLOCK_1][1], vecMapBoundsMax[BOUNDS_BLOCK_1][2], CurrentMap );
	else if ( bounds == BOUNDS_BLOCK_2 )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET bl2min0 = %.0f, bl2min1 = %.0f, bl2min2 = %.0f, bl2max0 = %.0f, bl2max1 = %.0f, bl2max2 = %.0f WHERE map = '%s';", vecMapBoundsMin[BOUNDS_BLOCK_2][0], vecMapBoundsMin[BOUNDS_BLOCK_2][1], vecMapBoundsMin[BOUNDS_BLOCK_2][2], vecMapBoundsMax[BOUNDS_BLOCK_2][0], vecMapBoundsMax[BOUNDS_BLOCK_2][1], vecMapBoundsMax[BOUNDS_BLOCK_2][2], CurrentMap );
	else if ( bounds == BOUNDS_BLOCK_3 )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET bl3min0 = %.0f, bl3min1 = %.0f, bl3min2 = %.0f, bl3max0 = %.0f, bl3max1 = %.0f, bl3max2 = %.0f WHERE map = '%s';", vecMapBoundsMin[BOUNDS_BLOCK_3][0], vecMapBoundsMin[BOUNDS_BLOCK_3][1], vecMapBoundsMin[BOUNDS_BLOCK_3][2], vecMapBoundsMax[BOUNDS_BLOCK_3][0], vecMapBoundsMax[BOUNDS_BLOCK_3][1], vecMapBoundsMax[BOUNDS_BLOCK_3][2], CurrentMap );
	else return false;
	
	if ( !SQL_FastQuery( Database, Buffer ) )
	{
		SQL_GetError( Database, Error, sizeof( Error ) );
		LogError( "\n\n%s Couldn't save map's ending bounds!\nError: %s\n\n", CONSOLE_PREFIX, Error );
		
		return false;
	}
	
	bZoneExists[bounds] = true;
	return true;
}

stock bool:EraseMapCoords( bounds )
{
	decl String:Buffer[300];
	
	if ( bounds == BOUNDS_START )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET smin0 = NULL, smin1 = NULL, smin2 = NULL, smax0 = NULL, smax1 = NULL, smax2 = NULL WHERE map = '%s';", CurrentMap );
	else if ( bounds == BOUNDS_END )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET emin0 = NULL, emin1 = NULL, emin2 = NULL, emax0 = NULL, emax1 = NULL, emax2 = NULL WHERE map = '%s';", CurrentMap );
	else if ( bounds == BOUNDS_BLOCK_1 )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET bl1min0 = NULL, bl1min1 = NULL, bl1min2 = NULL, bl1max0 = NULL, bl1max1 = NULL, bl1max2 = NULL WHERE map = '%s';", CurrentMap );
	else if ( bounds == BOUNDS_BLOCK_2 )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET bl2min0 = NULL, bl2min1 = NULL, bl2min2 = NULL, bl2max0 = NULL, bl2max1 = NULL, bl2max2 = NULL WHERE map = '%s';", CurrentMap );
	else if ( bounds == BOUNDS_BLOCK_3 )
		Format( Buffer, sizeof( Buffer ), "UPDATE _mapbounds SET bl3min0 = NULL, bl3min1 = NULL, bl3min2 = NULL, bl3max0 = NULL, bl3max1 = NULL, bl3max2 = NULL WHERE map = '%s';", CurrentMap );
	else return false;
	
	if ( !SQL_FastQuery( Database, Buffer ) )
	{
		SQL_GetError( Database, Error, sizeof( Error ) );
		LogError( "\n\n%s Couldn't erase map's ending bounds!\nError: %s\n\n", CONSOLE_PREFIX, Error );
		
		return false;
	}
	
	bZoneExists[bounds] = false;
	return true;
}