// From SMLIB
stock ArrayCopy( const any:oldArray[], any:newArray[], size = 1 )
	for ( new i; i < size; i++ )
		newArray[i] = oldArray[i];

stock ArrayFill( any:Array[], any:data, size = 1 )
	for ( new i; i < size; i++ )
		Array[i] = data;

// Format seconds and make them look naic.
stock FormatSeconds( Float:flSeconds, String:TargetString[], bool:bIsDeci, bool:bColored=false )
{
	new iHours, iMinutes;
	decl String:Hours[3], String:Minutes[3], String:Seconds[7];
	
	while ( flSeconds >= 3600.0 )
	{
		iHours++;
		flSeconds -= 3600.0;
	}
	
	while ( flSeconds >= 60.0 )
	{
		iMinutes++;
		flSeconds -= 60.0;
	}
	
	if ( iHours < 10 ) Format( Hours, sizeof( Hours ), "0%i", iHours );
	else Format( Hours, sizeof( Hours ), "%i", iHours );
	
	if ( iMinutes < 10 ) Format( Minutes, sizeof( Minutes ), "0%i", iMinutes );
	else Format( Minutes, sizeof( Minutes ), "%i", iMinutes );
	
	if ( flSeconds < 10.0 )
	{
		if ( bIsDeci )
			Format( Seconds, sizeof( Seconds ), "0%.2f", flSeconds );
		else
			Format( Seconds, sizeof( Seconds ), "0%.1f", flSeconds );
	}
	else
	{
		if ( bIsDeci )
			Format( Seconds, sizeof( Seconds ), "%.2f", flSeconds );
		else
			Format( Seconds, sizeof( Seconds ), "%.1f", flSeconds );
	}
	
	// "XX:XX:XX.XXX"
	// "CXXC:CXXC:CXX.XXX"
	if ( !bColored )
		Format( TargetString, 13, "%s:%s:%s", Hours, Minutes, Seconds );
	else
		Format( TargetString, 18, "\x03%s\x06:\x03%s\x06:\x03%s", Hours, Minutes, Seconds );
}

// "Real" velocity
stock Float:GetClientVelocity( client )
{
	decl Float:vecVelocity[3];
	GetEntPropVector( client, Prop_Data, "m_vecVelocity", vecVelocity );
	
	return SquareRoot( ( vecVelocity[0] * vecVelocity[0] ) + ( vecVelocity[1] * vecVelocity[1] ) );
}

// Tell people what our time is in the clan section of scoreboard.
stock UpdateScoreboard( client )
{
	if ( flClientBestTime[client][ iClientRun[client] ][ iClientMode[client] ] <= 0.0 )
	{
		CS_SetClientClanTag( client, "" );
		return;
	}
	
	decl String:NewTime[13];
	FormatSeconds( flClientBestTime[client][ iClientRun[client] ][ iClientMode[client] ], NewTime, false );
	CS_SetClientClanTag( client, NewTime );
}

stock SetClientFOV( client, fov, bool:bClientSet = false )
{
	if ( bClientSet )
		PrintColorChat( client, client,"%s Your field of view is now %i!", CHAT_PREFIX, fov );
	
	SetEntProp( client, Prop_Data, "m_iFOV", fov );
	SetEntProp( client, Prop_Data, "m_iDefaultFOV", fov );
}

stock GetActivePlayers()
{
	new clients;
	
	for ( new i = 1; i <= MaxClients; i++ )
		if ( IsClientInGame( i ) && !IsFakeClient( i ) && IsPlayerAlive( i ) )
			clients++;
			
	return clients++;
}

#if defined VOTING
stock CalcVotes()
{
	new iClients = GetActivePlayers();
	
	if ( iClients < 1 || hMapList == INVALID_HANDLE ) return;
	
	new len = GetArraySize( hMapList );
	new iMapVotes[len];
	
	// Gather votes
	for ( new i = 1; i <= MaxClients; i++ )
		if ( IsClientInGame( i ) && iClientVote[i] != -1 )
			iMapVotes[ iClientVote[i] ]++;
	
	// Check if we have a winrar
	for ( new i; i < len; i++ )
		if ( iMapVotes[i] >= iClients )
		{
			new iMap[MAX_MAP_NAME_LENGTH];
			GetArrayArray( hMapList, i, iMap, _:MapInfo );
			strcopy( NextMap, sizeof( NextMap ), iMap[MAP_NAME] );
			
			CreateTimer( 3.0, Timer_ChangeMap );
			PrintColorChatAll( 0, false, "%s Enough people voted for \x03%s%s! Changing map...", CHAT_PREFIX, NextMap, COLOR_TEXT );
			
			return;
		}
}

stock GetMapVotes( index )
{
	new amt;
	
	// Gather votes
	for ( new i = 1; i <= MaxClients; i++ )
		if ( IsClientInGame( i ) && iClientVote[i] == index )
			amt++;
	
	return amt;
}
#endif
// Used for players and other entities.
stock bool:IsInsideBounds( ent, bounds )
{
	if ( !bZoneExists[bounds] ) return false;
	
	decl Float:vecPos[3];
	GetEntPropVector( ent, Prop_Data, "m_vecOrigin", vecPos );
	
	// Basically, a shit ton of checking if the entity is between coordinates.
	return ( ( ( vecPos[0] >= vecBoundsMin[bounds][0] && vecPos[0] <= vecBoundsMax[bounds][0] ) || ( vecPos[0] <= vecBoundsMin[bounds][0] && vecPos[0] >= vecBoundsMax[bounds][0] ) ) && ( ( vecPos[1] >= vecBoundsMin[bounds][1] && vecPos[1] <= vecBoundsMax[bounds][1] ) || ( vecPos[1] <= vecBoundsMin[bounds][1] && vecPos[1] >= vecBoundsMax[bounds][1] ) ) && ( ( vecPos[2] >= vecBoundsMin[bounds][2] && vecPos[2] <= vecBoundsMax[bounds][2] ) || ( vecPos[2] <= vecBoundsMin[bounds][2] && vecPos[2] >= vecBoundsMax[bounds][2] ) ) );
}

stock CheckFreestyle( client )
{
	if ( IsInsideBounds( client, BOUNDS_FREESTYLE_1 ) || IsInsideBounds( client, BOUNDS_FREESTYLE_2 ) || IsInsideBounds( client, BOUNDS_FREESTYLE_3 ) )
		return;
	
	PrintColorChat( client, client, "%s That key is not allowed in %s!", CHAT_PREFIX, ModeName[MODENAME_LONG][ iClientMode[client] ] );
	ForcePlayerSuicide( client );
}

stock PrintColorChat( target, author, const String:Message[], any:... )
{
	decl String:Buffer[256];
	VFormat( Buffer, sizeof( Buffer ), Message, 4 );
	
	SendColorMessage( target, author, Buffer );
}

stock PrintColorChatAll( author, bool:bAllowHide, const String:Message[], any:... )
{
	decl String:Buffer[256];
	VFormat( Buffer, sizeof( Buffer ), Message, 4 );
	
	if ( bAllowHide )
	{
		for ( new client = 1; client <= MaxClients; client++ )
			if ( IsClientInGame( client ) && !( iClientHideFlags[client] & HIDEHUD_CHAT ) ) SendColorMessage( client, author, Buffer );
	}
	else
	{
		for ( new client = 1; client <= MaxClients; client++ )
			if ( IsClientInGame( client ) ) SendColorMessage( client, author, Buffer );
	}
}

stock SendColorMessage( target, author, const String:Message[] )
{
	new Handle:Buffer = StartMessageOne( "SayText2", target );
	
	if ( Buffer != INVALID_HANDLE )
	{
		BfWriteByte( Buffer, author );
		BfWriteByte( Buffer, false ); // false for no console print.
		BfWriteString( Buffer, Message );
		
		EndMessage();
	}
}

stock ShowKeyHintText( client, target )
{
	new Handle:Buffer = StartMessageOne( "KeyHintText", client );
	
	if ( Buffer != INVALID_HANDLE )
	{
		decl String:Time[13], String:TextBuffer[128];
		
		if ( flClientBestTime[target][ iClientRun[target] ][ iClientMode[target] ] != 0.0 )
		{
			decl Float:flSeconds;
			flSeconds = flClientBestTime[target][ iClientRun[target] ][ iClientMode[target] ];
			
			decl String:FormattedMyTime[13];
			FormatSeconds( flSeconds, FormattedMyTime, true );
			
			Format( Time, sizeof( Time ), "%s", FormattedMyTime );
		}
		else Format( Time, sizeof( Time ), "N/A" );
		
		if ( iClientState[target] != STATE_START )
		{
			// Strafe Sync
			new Float:flSyncTotal;
			
			for ( new i; i < SYNC_MAX_SAMPLES; i++ )
				flSyncTotal += iClientGoodSync[target][i];
			
			Format( TextBuffer, sizeof( TextBuffer ), "Strafes: %i\nSync: %.1f\nJumps: %i\n \nMode: %s\nPersonal Best: %s", iClientStrafeCount[target], ( flSyncTotal / SYNC_MAX_SAMPLES ) * 100, iClientJumpCount[target], ModeName[MODENAME_LONG][ iClientMode[target] ], Time );
		}
		else
			Format( TextBuffer, sizeof( TextBuffer ), "Mode: %s\nPersonal Best: %s", ModeName[MODENAME_LONG][ iClientMode[target] ], Time );
		
		BfWriteByte( Buffer, 1 );
		BfWriteString( Buffer, TextBuffer );
		
		EndMessage();
	}
}

// Find a destination where we are supposed to go to when teleporting back to a zone.
stock DoMapStuff()
{
	PrintToServer( "%s Reallocating spawnpoints...", CONSOLE_PREFIX );
	
	new ent;
	while ( ( ent = FindEntityByClassname( ent, "info_teleport_destination" ) ) != -1 )
		if ( IsInsideBounds( ent, BOUNDS_START ) )
		{
			decl Float:angAngle[3];
			GetEntPropVector( ent, Prop_Data, "m_angRotation", angAngle );
			
			ArrayCopy( angAngle, angSpawnAngles[RUN_MAIN], 2 );
		}
		else if ( IsInsideBounds( ent, BOUNDS_BONUS_1_START ) )
		{
			decl Float:angAngle[3];
			GetEntPropVector( ent, Prop_Data, "m_angRotation", angAngle );
			
			ArrayCopy( angAngle, angSpawnAngles[RUN_BONUS_1], 2 );
		}
		else if ( IsInsideBounds( ent, BOUNDS_BONUS_2_START ) )
		{
			decl Float:angAngle[3];
			GetEntPropVector( ent, Prop_Data, "m_angRotation", angAngle );
			
			ArrayCopy( angAngle, angSpawnAngles[RUN_BONUS_2], 2 );
		}
	
	if ( bZoneExists[BOUNDS_START] )
	{
		if ( vecBoundsMin[BOUNDS_START][0] < vecBoundsMax[BOUNDS_START][0] )
			vecSpawnPos[RUN_MAIN][0] = vecBoundsMin[BOUNDS_START][0] + ( vecBoundsMax[BOUNDS_START][0] - vecBoundsMin[BOUNDS_START][0] ) / 2;
		else
			vecSpawnPos[RUN_MAIN][0] = vecBoundsMax[BOUNDS_START][0] + ( vecBoundsMin[BOUNDS_START][0] - vecBoundsMax[BOUNDS_START][0] ) / 2;
			
		if ( vecBoundsMin[BOUNDS_START][1] < vecBoundsMax[BOUNDS_START][1] )
			vecSpawnPos[RUN_MAIN][1] = vecBoundsMin[BOUNDS_START][1] + ( vecBoundsMax[BOUNDS_START][1] - vecBoundsMin[BOUNDS_START][1] ) / 2;
		else
			vecSpawnPos[RUN_MAIN][1] = vecBoundsMax[BOUNDS_START][1] + ( vecBoundsMin[BOUNDS_START][1] - vecBoundsMax[BOUNDS_START][1] ) / 2;
			
		vecSpawnPos[RUN_MAIN][2] = vecBoundsMin[BOUNDS_START][2] + 16.0;
	}
	
	if ( bZoneExists[BOUNDS_BONUS_1_START] )
	{
		if ( vecBoundsMin[BOUNDS_BONUS_1_START][0] < vecBoundsMax[BOUNDS_BONUS_1_START][0] )
			vecSpawnPos[RUN_BONUS_1][0] = vecBoundsMin[BOUNDS_BONUS_1_START][0] + ( vecBoundsMax[BOUNDS_BONUS_1_START][0] - vecBoundsMin[BOUNDS_BONUS_1_START][0] ) / 2;
		else
			vecSpawnPos[RUN_BONUS_1][0] = vecBoundsMax[BOUNDS_BONUS_1_START][0] + ( vecBoundsMin[BOUNDS_BONUS_1_START][0] - vecBoundsMax[BOUNDS_BONUS_1_START][0] ) / 2;
			
		if ( vecBoundsMin[BOUNDS_BONUS_1_START][1] < vecBoundsMax[BOUNDS_BONUS_1_START][1] )
			vecSpawnPos[RUN_BONUS_1][1] = vecBoundsMin[BOUNDS_BONUS_1_START][1] + ( vecBoundsMax[BOUNDS_BONUS_1_START][1] - vecBoundsMin[BOUNDS_BONUS_1_START][1] ) / 2;
		else
			vecSpawnPos[RUN_BONUS_1][1] = vecBoundsMax[BOUNDS_BONUS_1_START][1] + ( vecBoundsMin[BOUNDS_BONUS_1_START][1] - vecBoundsMax[BOUNDS_BONUS_1_START][1] ) / 2;
			
		vecSpawnPos[RUN_BONUS_1][2] = vecBoundsMin[BOUNDS_BONUS_1_START][2] + 16.0;
	}
	
	if ( bZoneExists[BOUNDS_BONUS_2_START] )
	{
		if ( vecBoundsMin[BOUNDS_BONUS_2_START][0] < vecBoundsMax[BOUNDS_BONUS_2_START][0] )
			vecSpawnPos[RUN_BONUS_2][0] = vecBoundsMin[BOUNDS_BONUS_2_START][0] + ( vecBoundsMax[BOUNDS_BONUS_2_START][0] - vecBoundsMin[BOUNDS_BONUS_2_START][0] ) / 2;
		else
			vecSpawnPos[RUN_BONUS_2][0] = vecBoundsMax[BOUNDS_BONUS_2_START][0] + ( vecBoundsMin[BOUNDS_BONUS_2_START][0] - vecBoundsMax[BOUNDS_BONUS_2_START][0] ) / 2;
			
		if ( vecBoundsMin[BOUNDS_BONUS_2_START][1] < vecBoundsMax[BOUNDS_BONUS_2_START][1] )
			vecSpawnPos[RUN_BONUS_2][1] = vecBoundsMin[BOUNDS_BONUS_2_START][1] + ( vecBoundsMax[BOUNDS_BONUS_2_START][1] - vecBoundsMin[BOUNDS_BONUS_2_START][1] ) / 2;
		else
			vecSpawnPos[RUN_BONUS_2][1] = vecBoundsMax[BOUNDS_BONUS_2_START][1] + ( vecBoundsMin[BOUNDS_BONUS_2_START][1] - vecBoundsMax[BOUNDS_BONUS_2_START][1] ) / 2;
			
		vecSpawnPos[RUN_BONUS_2][2] = vecBoundsMin[BOUNDS_BONUS_2_START][2] + 16.0;
	}
	
	if ( FindEntityByClassname( ent, "info_player_counterterrorist" ) != -1 )
		iPreferedTeam = CS_TEAM_CT;
	else
		iPreferedTeam = CS_TEAM_T;
	
#if defined DELETE_ENTS
	CreateTimer( 3.0, Timer_DoMapStuff );
#endif
}

#if defined RECORD
stock FindMimic( finder )
{
	for ( new i = 1; i <= MaxClients; i++ )
		if ( IsClientInGame( i ) && IsPlayerAlive( i ) && IsFakeClient( i ) && ( hClientRecording[i] == INVALID_HANDLE && !bIsClientMimicing[i] ) )
			return i;
	
	return 0;
}

stock bool:ExCreateDir( const String:Path[] )
{
	if ( !DirExists( Path ) )
	{
		CreateDirectory( Path, 511 );
		
		if ( !DirExists( Path ) )
		{
			PrintToServer( "%s Couldn't create folder! (%s)", CONSOLE_PREFIX, Path );
			return false;
		}
	}
	
	return true;
}

// RECORD STUFF
stock bool:SaveRecording( client, iLength )
{
	decl String:SteamID[32];
	
	if ( !GetClientAuthString( client, SteamID, sizeof( SteamID ) ) )
		return false;
	
	ReplaceString( SteamID, sizeof( SteamID ), "STEAM_", "" );
	
	// STEAM_0:1:30495520 to 0_1_30495520
	for ( new i; i < 5; i++ )
		if ( SteamID[i] == ':' )
			SteamID[i] = '_';
	
	
	decl String:Path[PLATFORM_MAX_PATH];
	BuildPath( Path_SM, Path, sizeof( Path ), "records" );
	
	if ( !ExCreateDir( Path ) ) return false;
	
	
	Format( Path, sizeof( Path ), "%s/%s", Path, CurrentMap );
	
	if ( !ExCreateDir( Path ) ) return false;

	
	Format( Path, sizeof( Path ), "%s/%s", Path, ModeName[MODENAME_SHORT][ iClientMode[client] ] );
	
	if ( !ExCreateDir( Path ) ) return false;
	
	
	Format( Path, sizeof( Path ), "%s/%s.rec", Path, SteamID );
	
	new Handle:hFile = OpenFile( Path, "wb" );
	if ( hFile == INVALID_HANDLE )
	{
		PrintToServer( "%s Couldn't open file! (%s)", CONSOLE_PREFIX, Path );
		return false;
	}
	
	// Save file header
	new iHeader[HEADER_SIZE];
	
	iHeader[HEADER_BINARYFORMAT] = BINARY_FORMAT;
	iHeader[HEADER_TICKCOUNT] = iLength;
	ArrayCopy( vecInitPos[client], iHeader[HEADER_INITPOS], 3 );
	ArrayCopy( angInitAngles[client], iHeader[HEADER_INITANGLES], 2 );
	
	WriteFileCell( hFile, MAGIC_NUMBER, 4 );
	WriteFileCell( hFile, iHeader[_:HEADER_BINARYFORMAT], 1 );
	WriteFileCell( hFile, iHeader[_:HEADER_TICKCOUNT], 4 );
	
	WriteFile( hFile, _:iHeader[_:HEADER_INITPOS], 3, 4 );
	WriteFile( hFile, _:iHeader[_:HEADER_INITANGLES], 2, 4 );
	
	// Save frames on to the file.
	new iFrame[FRAME_SIZE];
	
	for ( new i; i < iLength; i++ )
	{
		GetArrayArray( hClientRecording[client], i, iFrame, _:FrameInfo );
		
		if ( !WriteFile( hFile, iFrame, _:FrameInfo, 4 ) )
		{
			LogError( "%s An error occured while trying to write on to file!", CONSOLE_PREFIX );
			
			CloseHandle( hFile );
			return false;
		}
	}
	
	CloseHandle( hFile );
	
	return true;
}

stock bool:LoadRecording( String:SteamID[], iMode )
{
	ReplaceString( SteamID, 32, "STEAM_", "" );
	
	// STEAM_0:1:30495520 to 0_1_30495520
	for ( new i; i < 5; i++ )
		if ( SteamID[i] == ':' )
			SteamID[i] = '_';
	
	
	decl String:Path[PLATFORM_MAX_PATH];
	BuildPath( Path_SM, Path, sizeof( Path ), "records/%s/%s/%s.rec", CurrentMap, ModeName[MODENAME_SHORT][iMode], SteamID );
	
	new Handle:hFile = OpenFile( Path, "rb" );
	
	if ( hFile == INVALID_HANDLE )
		return false;
	
	// GET HEADER
	new iMagic;
	ReadFileCell( hFile, iMagic, 4 );
	
	if ( iMagic != MAGIC_NUMBER )
	{
		PrintToServer( "%s Tried to read from file with different magic number!", CONSOLE_PREFIX );
		
		CloseHandle( hFile );
		return false;
	}
	
	new iFormat;
	ReadFileCell( hFile, iFormat, 1 );
	
	if ( iFormat != BINARY_FORMAT )
	{
		PrintToServer( "%s Tried to read from while with different binary format!", CONSOLE_PREFIX );
		
		CloseHandle( hFile );
		return false;
	}
	
	ReadFileCell( hFile, iMimicTickMax[iMode], 4 );
	
	if ( iMimicTickMax[iMode] < 1 )
	{
		CloseHandle( hFile );
		return false;
	}
	
	new iHeader[HEADER_SIZE];
	ReadFile( hFile, _:iHeader[_:HEADER_INITPOS], 3, 4 );
	ReadFile( hFile, _:iHeader[_:HEADER_INITANGLES], 2, 4 );
	
	ArrayCopy( iHeader[_:HEADER_INITPOS], vecInitMimicPos[iMode], 3 );
	ArrayCopy( iHeader[_:HEADER_INITANGLES], angInitMimicAngles[iMode], 2 );
	
	// GET FRAMES
	new iFrame[FRAME_SIZE];
	hMimicRecording[iMode] = CreateArray( _:FrameInfo );
	
	for ( new i; i < iMimicTickMax[iMode]; i++ )
	{
		if ( ReadFile( hFile, iFrame, _:FrameInfo, 4 ) == -1 )
		{
			PrintToServer( "%s Error occured while reading from file!", CONSOLE_PREFIX );
			
			CloseHandle( hFile );
			return false;
		}
		
		PushArrayArray( hMimicRecording[iMode], iFrame, _:FrameInfo );
	}
	
	CloseHandle( hFile );
	
	return true;
}
#endif