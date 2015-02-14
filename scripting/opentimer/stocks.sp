// From SMLIB
stock void ArrayCopy( const any[] oldArray, any[] newArray, int size = 1 )
{
	for ( int i; i < size; i++ ) newArray[i] = oldArray[i];
}

stock void ArrayFill( any[] Array, any data, int size = 1 )
{
	for ( int i; i < size; i++ ) Array[i] = data;
}

// Format seconds and make them look nice.
stock void FormatSeconds( float flSeconds, char[] szTarget, int iLength, bool bIsDeci, bool bColored = false )
{
	int iHours, iMins;
	static char szHours[3], szMins[3], szSec[7];
	
	while ( flSeconds >= 3600.0 )
	{
		iHours++;
		flSeconds -= 3600.0;
	}
	
	while ( flSeconds >= 60.0 )
	{
		iMins++;
		flSeconds -= 60.0;
	}
	
	Format( szHours, sizeof( szHours ), ( iHours < 10 ) ? "0%i" : "%i", iHours );
	
	Format( szMins, sizeof( szMins ), ( iMins < 10 ) ? "0%i" : "%i", iMins );
	
	if ( flSeconds < 10.0 )
	{
		Format( szSec, sizeof( szSec ), bIsDeci ? "0%.2f" : "0%.1f", flSeconds );
	}
	else
	{
		Format( szSec, sizeof( szSec ), bIsDeci ? "%.2f" : "%.1f", flSeconds );
	}
	
	// "XX:XX:XX.X" - [11] (HINT)
	// "XX:XX:XX.XX" - [12] (RECORDS)
	// "CXXC:CXXC:CXX.XX" - [17] (CHAT)
	if ( !bColored )
	{
		Format( szTarget, iLength, "%s:%s:%s", szHours, szMins, szSec );
	}
	else
	{
		Format( szTarget, iLength, "\x03%s\x06:\x03%s\x06:\x03%s", szHours, szMins, szSec );
	}
}

// "Real" velocity
stock float GetClientVelocity( int client )
{
	static float vecVel[3];
	GetEntPropVector( client, Prop_Data, "m_vecVelocity", vecVel );
	
	return SquareRoot( ( vecVel[0] * vecVel[0] ) + ( vecVel[1] * vecVel[1] ) );
}

// Tell people what our time is in the clan section of scoreboard.
stock void UpdateScoreboard( int client )
{
	if ( g_flClientBestTime[client][ g_iClientRun[client] ][ g_iClientStyle[client] ] <= TIME_INVALID )
	{
		CS_SetClientClanTag( client, "" );
		return;
	}
	
	char szNewTime[11];
	FormatSeconds( g_flClientBestTime[client][ g_iClientRun[client] ][ g_iClientStyle[client] ], szNewTime, sizeof( szNewTime ), false );
	CS_SetClientClanTag( client, szNewTime );
}

stock void SetClientFOV( int client, int fov, bool bClientSet = false )
{
	if ( bClientSet )
		PrintColorChat( client, client, "%s Your field of view is now %i!", CHAT_PREFIX, fov );
	
	SetEntProp( client, Prop_Data, "m_iFOV", fov );
	SetEntProp( client, Prop_Data, "m_iDefaultFOV", fov );
}

stock int GetActivePlayers()
{
	int clients;
	
	for ( int i = 1; i <= MaxClients; i++ )
		if ( IsClientInGame( i ) && !IsFakeClient( i ) && IsPlayerAlive( i ) )
			clients++;
			
	return clients++;
}

#if defined VOTING
stock void CalcVotes()
{
	int iClients = GetActivePlayers();
	
	if ( iClients < 1 || g_hMapList == null ) return;
	
	int len = GetArraySize( g_hMapList );
	int[] iMapVotes = new int[len];
	
	// Gather votes
	for ( int i = 1; i <= MaxClients; i++ )
		if ( IsClientInGame( i ) && g_iClientVote[i] != -1 )
			iMapVotes[ g_iClientVote[i] ]++;
	
	// Get maximum needed votes.
	int iReq = 1;
	
	if ( iClients > 2 )
	{
		iReq = RoundFloat( iClients * 0.8 );
	}
	
	// Check if we have a winrar
	for ( int i; i < len; i++ )
		if ( iMapVotes[i] >= iReq )
		{
			int iMap[MAX_MAP_NAME_LENGTH];
			GetArrayArray( g_hMapList, i, iMap, view_as<int>MapInfo );
			strcopy( g_szNextMap, sizeof( g_szNextMap ), iMap[MAP_NAME] );
			
			CreateTimer( 3.0, Timer_ChangeMap );
			PrintColorChatAll( 0, false, "%s Enough people voted for \x03%s%s! Changing map...", CHAT_PREFIX, g_szNextMap, COLOR_TEXT );
			
			return;
		}
}
#endif
// Used for players and other entities.
stock bool IsInsideBounds( int ent, int bounds )
{
	if ( !g_bZoneExists[bounds] ) return false;
	
	static float vecPos[3];
	GetEntPropVector( ent, Prop_Data, "m_vecOrigin", vecPos );
	
	// Basically, a shit ton of checking if the entity is between coordinates.
	// This allows mins and maxs to be "switched", meaning that mins can actually be bigger than maxs.
	return (
		( ( vecPos[0] >= g_vecBoundsMin[bounds][0] && vecPos[0] <= g_vecBoundsMax[bounds][0] ) || ( vecPos[0] <= g_vecBoundsMin[bounds][0] && vecPos[0] >= g_vecBoundsMax[bounds][0] ) )
		&&
		( ( vecPos[1] >= g_vecBoundsMin[bounds][1] && vecPos[1] <= g_vecBoundsMax[bounds][1] ) || ( vecPos[1] <= g_vecBoundsMin[bounds][1] && vecPos[1] >= g_vecBoundsMax[bounds][1] ) )
		&&
		( ( vecPos[2] >= g_vecBoundsMin[bounds][2] && vecPos[2] <= g_vecBoundsMax[bounds][2] ) || ( vecPos[2] <= g_vecBoundsMin[bounds][2] && vecPos[2] >= g_vecBoundsMax[bounds][2] ) ) );
}

stock void CheckFreestyle( int client )
{
	if ( g_iClientState[client] == STATE_START
		|| IsInsideBounds( client, BOUNDS_FREESTYLE_1 )
		|| IsInsideBounds( client, BOUNDS_FREESTYLE_2 )
		|| IsInsideBounds( client, BOUNDS_FREESTYLE_3 ) )
		return;
	
	// SERVER_CAN_EXECUTE blocks these...
	//ClientCommand( client, "-forward; -back; -moveleft; -moveright" );
	
	PrintColorChat( client, client, "%s That key is not allowed in \x03%s%s!", CHAT_PREFIX, g_szStyleName[NAME_LONG][ g_iClientStyle[client] ], COLOR_TEXT );
	
	
	if ( !g_bIsLoaded[ g_iClientRun[client] ] )
	{
		ForcePlayerSuicide( client );
		return;
	}
	
	TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_angSpawnAngles[ g_iClientRun[client] ], g_vecNull );
}

stock void PrintColorChat( int target, int author, const char[] szMsg, any ... )
{
	static char szBuffer[256];
	VFormat( szBuffer, sizeof( szBuffer ), szMsg, 4 );
	
	SendColorMessage( target, author, szBuffer );
}

stock void PrintColorChatAll( int author, bool bAllowHide, const char[] szMsg, any ... )
{
	static char szBuffer[256];
	VFormat( szBuffer, sizeof( szBuffer ), szMsg, 4 );
	
	if ( bAllowHide )
	{
		for ( int client = 1; client <= MaxClients; client++ )
			if ( IsClientInGame( client ) && !( g_iClientHideFlags[client] & HIDEHUD_CHAT ) )
				SendColorMessage( client, author, szBuffer );
	}
	else
	{
		for ( int client = 1; client <= MaxClients; client++ )
			if ( IsClientInGame( client ) )
				SendColorMessage( client, author, szBuffer );
	}
}

stock void SendColorMessage( int target, int author, const char szMsg[256] )
{
	// If we don't use the reliable channel, sometimes clients won't receive the message.
	// Happens more than you'd normally think.
	Handle hMsg = StartMessageOne( "SayText2", target, USERMSG_RELIABLE );
	
	if ( hMsg != null )
	{
		BfWriteByte( hMsg, author );
		
		// false for no console print. We do this manually because it would display the hex codes in the console.
		BfWriteByte( hMsg, false );
		
		BfWriteString( hMsg, szMsg );
		
		EndMessage();
	}
}

stock void ShowKeyHintText( int client, int target )
{
	Handle hMsg = StartMessageOne( "KeyHintText", client );
	
	if ( hMsg != null )
	{
		static char szTime[12];
		static char szText[128];
		
		if ( g_flClientBestTime[target][ g_iClientRun[target] ][ g_iClientStyle[target] ] != TIME_INVALID )
		{
			FormatSeconds( g_flClientBestTime[target][ g_iClientRun[target] ][ g_iClientStyle[target] ], szTime, sizeof( szTime ), true );
		}
		else Format( szTime, sizeof( szTime ), "N/A" );
		
		if ( g_iClientState[target] != STATE_START )
		{
			// Strafe Sync
			float flSyncTotal;
			
			for ( int i; i < SYNC_MAX_SAMPLES; i++ )
				flSyncTotal += g_iClientGoodSync[target][i];
			
			Format( szText, sizeof( szText ), "Strafes: %i\nSync: %.1f\nJumps: %i\n \nStyle: %s\nPersonal Best: %s", g_iClientStrafeCount[target], ( flSyncTotal / SYNC_MAX_SAMPLES ) * 100, g_iClientJumpCount[target], g_szStyleName[NAME_LONG][ g_iClientStyle[target] ], szTime );
			/*if ( g_iClientStyle[target] == STYLE_NORMAL )
				Format( szText, sizeof( szText ), "Strafes: %i\nSync: %.1f\nJumps: %i\n \nStyle: %s\nPersonal Best: %s", g_iClientStrafeCount[target], ( flSyncTotal / SYNC_MAX_SAMPLES ) * 100, g_iClientJumpCount[target], g_szStyleName[NAME_LONG][ g_iClientStyle[target] ], szTime );
			else
				Format( szText, sizeof( szText ), "Jumps: %i\n \nStyle: %s\nPersonal Best: %s", g_iClientJumpCount[target], g_szStyleName[NAME_LONG][ g_iClientStyle[target] ], szTime );*/
		}
		else
			Format( szText, sizeof( szText ), "Style: %s\nPersonal Best: %s", g_szStyleName[NAME_LONG][ g_iClientStyle[target] ], szTime );
		
		BfWriteByte( hMsg, 1 );
		BfWriteString( hMsg, szText );
		
		EndMessage();
	}
}

// Find a destination where we are suppose to go to when teleporting back to a zone.
stock void DoMapStuff()
{
	PrintToServer( "%s Relocating spawnpoints...", CONSOLE_PREFIX ); // "Reallocating" lol
	
	
	int ent;
	
	// If we don't have an angle, we will calculate it so we are looking to the direction of the end!
	bool bFoundAng[MAX_RUNS];
	
	while ( ( ent = FindEntityByClassname( ent, "info_teleport_destination" ) ) != -1 )
	{
		static float angAngle[3];
		
		if ( IsInsideBounds( ent, BOUNDS_START ) )
		{
			GetEntPropVector( ent, Prop_Data, "m_angRotation", angAngle );
			
			ArrayCopy( angAngle, g_angSpawnAngles[RUN_MAIN], 2 );
			bFoundAng[RUN_MAIN] = true;
		}
		else if ( IsInsideBounds( ent, BOUNDS_BONUS_1_START ) )
		{
			GetEntPropVector( ent, Prop_Data, "m_angRotation", angAngle );
			
			ArrayCopy( angAngle, g_angSpawnAngles[RUN_BONUS_1], 2 );
			bFoundAng[RUN_BONUS_1] = true;
		}
		else if ( IsInsideBounds( ent, BOUNDS_BONUS_2_START ) )
		{
			GetEntPropVector( ent, Prop_Data, "m_angRotation", angAngle );
			
			ArrayCopy( angAngle, g_angSpawnAngles[RUN_BONUS_2], 2 );
			bFoundAng[RUN_BONUS_2] = true;
		}
	}
	
	if ( g_bZoneExists[BOUNDS_START] )
	{
		if ( g_vecBoundsMin[BOUNDS_START][0] < g_vecBoundsMax[BOUNDS_START][0] )
			g_vecSpawnPos[RUN_MAIN][0] = g_vecBoundsMin[BOUNDS_START][0] + ( g_vecBoundsMax[BOUNDS_START][0] - g_vecBoundsMin[BOUNDS_START][0] ) / 2;
		else
			g_vecSpawnPos[RUN_MAIN][0] = g_vecBoundsMax[BOUNDS_START][0] + ( g_vecBoundsMin[BOUNDS_START][0] - g_vecBoundsMax[BOUNDS_START][0] ) / 2;
			
		if ( g_vecBoundsMin[BOUNDS_START][1] < g_vecBoundsMax[BOUNDS_START][1] )
			g_vecSpawnPos[RUN_MAIN][1] = g_vecBoundsMin[BOUNDS_START][1] + ( g_vecBoundsMax[BOUNDS_START][1] - g_vecBoundsMin[BOUNDS_START][1] ) / 2;
		else
			g_vecSpawnPos[RUN_MAIN][1] = g_vecBoundsMax[BOUNDS_START][1] + ( g_vecBoundsMin[BOUNDS_START][1] - g_vecBoundsMax[BOUNDS_START][1] ) / 2;
			
		g_vecSpawnPos[RUN_MAIN][2] = g_vecBoundsMin[BOUNDS_START][2] + 16.0;
		
		// Direction of the end!
		if ( !bFoundAng[RUN_MAIN] )
			g_angSpawnAngles[RUN_MAIN][1] = ArcTangent2( g_vecBoundsMin[BOUNDS_END][1] - g_vecBoundsMin[BOUNDS_START][1], g_vecBoundsMin[BOUNDS_END][0] - g_vecBoundsMin[BOUNDS_START][0] ) * 180 / 3.14159265359;
	}
	
	if ( g_bZoneExists[BOUNDS_BONUS_1_START] )
	{
		if ( g_vecBoundsMin[BOUNDS_BONUS_1_START][0] < g_vecBoundsMax[BOUNDS_BONUS_1_START][0] )
			g_vecSpawnPos[RUN_BONUS_1][0] = g_vecBoundsMin[BOUNDS_BONUS_1_START][0] + ( g_vecBoundsMax[BOUNDS_BONUS_1_START][0] - g_vecBoundsMin[BOUNDS_BONUS_1_START][0] ) / 2;
		else
			g_vecSpawnPos[RUN_BONUS_1][0] = g_vecBoundsMax[BOUNDS_BONUS_1_START][0] + ( g_vecBoundsMin[BOUNDS_BONUS_1_START][0] - g_vecBoundsMax[BOUNDS_BONUS_1_START][0] ) / 2;
			
		if ( g_vecBoundsMin[BOUNDS_BONUS_1_START][1] < g_vecBoundsMax[BOUNDS_BONUS_1_START][1] )
			g_vecSpawnPos[RUN_BONUS_1][1] = g_vecBoundsMin[BOUNDS_BONUS_1_START][1] + ( g_vecBoundsMax[BOUNDS_BONUS_1_START][1] - g_vecBoundsMin[BOUNDS_BONUS_1_START][1] ) / 2;
		else
			g_vecSpawnPos[RUN_BONUS_1][1] = g_vecBoundsMax[BOUNDS_BONUS_1_START][1] + ( g_vecBoundsMin[BOUNDS_BONUS_1_START][1] - g_vecBoundsMax[BOUNDS_BONUS_1_START][1] ) / 2;
			
		g_vecSpawnPos[RUN_BONUS_1][2] = g_vecBoundsMin[BOUNDS_BONUS_1_START][2] + 16.0;
		
		// Direction of the end!
		if ( !bFoundAng[RUN_BONUS_1] )
			g_angSpawnAngles[RUN_BONUS_1][1] = ArcTangent2( g_vecBoundsMin[BOUNDS_BONUS_1_END][1] - g_vecBoundsMin[BOUNDS_BONUS_1_START][1], g_vecBoundsMin[BOUNDS_BONUS_1_END][0] - g_vecBoundsMin[BOUNDS_BONUS_1_START][0] ) * 180 / 3.14159265359;
	}
	
	if ( g_bZoneExists[BOUNDS_BONUS_2_START] )
	{
		if ( g_vecBoundsMin[BOUNDS_BONUS_2_START][0] < g_vecBoundsMax[BOUNDS_BONUS_2_START][0] )
			g_vecSpawnPos[RUN_BONUS_2][0] = g_vecBoundsMin[BOUNDS_BONUS_2_START][0] + ( g_vecBoundsMax[BOUNDS_BONUS_2_START][0] - g_vecBoundsMin[BOUNDS_BONUS_2_START][0] ) / 2;
		else
			g_vecSpawnPos[RUN_BONUS_2][0] = g_vecBoundsMax[BOUNDS_BONUS_2_START][0] + ( g_vecBoundsMin[BOUNDS_BONUS_2_START][0] - g_vecBoundsMax[BOUNDS_BONUS_2_START][0] ) / 2;
			
		if ( g_vecBoundsMin[BOUNDS_BONUS_2_START][1] < g_vecBoundsMax[BOUNDS_BONUS_2_START][1] )
			g_vecSpawnPos[RUN_BONUS_2][1] = g_vecBoundsMin[BOUNDS_BONUS_2_START][1] + ( g_vecBoundsMax[BOUNDS_BONUS_2_START][1] - g_vecBoundsMin[BOUNDS_BONUS_2_START][1] ) / 2;
		else
			g_vecSpawnPos[RUN_BONUS_2][1] = g_vecBoundsMax[BOUNDS_BONUS_2_START][1] + ( g_vecBoundsMin[BOUNDS_BONUS_2_START][1] - g_vecBoundsMax[BOUNDS_BONUS_2_START][1] ) / 2;
			
		g_vecSpawnPos[RUN_BONUS_2][2] = g_vecBoundsMin[BOUNDS_BONUS_2_START][2] + 16.0;
		
		// Direction of the end!
		if ( !bFoundAng[RUN_BONUS_2] )
			g_angSpawnAngles[RUN_BONUS_2][1] = ArcTangent2( g_vecBoundsMin[BOUNDS_BONUS_2_END][1] - g_vecBoundsMin[BOUNDS_BONUS_2_START][1], g_vecBoundsMin[BOUNDS_BONUS_2_END][0] - g_vecBoundsMin[BOUNDS_BONUS_2_START][0] ) * 180 / 3.14159265359;
	}
	
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
	
	
	
#if defined DELETE_ENTS
	CreateTimer( 3.0, Timer_DoMapStuff );
#endif
}

#if defined RECORD
stock bool ExCreateDir( const char[] szPath )
{
	if ( !DirExists( szPath ) )
	{
		CreateDirectory( szPath, 511 );
		
		if ( !DirExists( szPath ) )
		{
			PrintToServer( "%s Couldn't create folder! (%s)", CONSOLE_PREFIX, szPath );
			return false;
		}
	}
	
	return true;
}

// RECORD STUFF
stock bool SaveRecording( int client, float flTime, int iLength )
{
	char szSteamId[STEAMID_MAXLENGTH];
	
	if ( !GetClientAuthId( client, AuthId_Engine, szSteamId, sizeof( szSteamId ) ) )
		return false;
	
	ReplaceString( szSteamId, sizeof( szSteamId ), "STEAM_", "" );
	
	// STEAM_0:1:30495520 to 0_1_30495520
	for ( int i; i < 5; i++ )
		if ( szSteamId[i] == ':' )
			szSteamId[i] = '_';
	
	
	static char szPath[PLATFORM_MAX_PATH];
	BuildPath( Path_SM, szPath, sizeof( szPath ), "records" );
	if ( !ExCreateDir( szPath ) ) return false;
	
	
	Format( szPath, sizeof( szPath ), "%s/%s", szPath, g_szCurrentMap ); // records/bhop_map
	if ( !ExCreateDir( szPath ) ) return false;

	Format( szPath, sizeof( szPath ), "%s/%s", szPath, g_szRunName[NAME_SHORT][ g_iClientRun[client] ] ); // records/bhop_map/M
	if ( !ExCreateDir( szPath ) ) return false;
	
	Format( szPath, sizeof( szPath ), "%s/%s", szPath, g_szStyleName[NAME_SHORT][ g_iClientStyle[client] ] ); // records/bhop_map/M/HSW
	if ( !ExCreateDir( szPath ) ) return false;
	
	
	Format( szPath, sizeof( szPath ), "%s/%s.rec", szPath, szSteamId ); // records/bhop_map/N/HSW/0_1_30495520
	
	Handle hFile = OpenFile( szPath, "wb" );
	if ( hFile == null )
	{
		PrintToServer( "%s Couldn't open file! (%s)", CONSOLE_PREFIX, szPath );
		return false;
	}
	
	// Save file header
	int iHeader[HEADER_SIZE];
	
	iHeader[HEADER_BINARYFORMAT] = BINARY_FORMAT;
	iHeader[HEADER_TICKCOUNT] = iLength;
	
	ArrayCopy( g_vecInitPos[client], iHeader[HEADER_INITPOS], 3 );
	ArrayCopy( g_angInitAngles[client], iHeader[HEADER_INITANGLES], 2 );
	//iHeader[HEADER_TIME] = flTime;
	
	WriteFileCell( hFile, MAGIC_NUMBER, 4 );
	WriteFileCell( hFile, iHeader[ view_as<int>HEADER_BINARYFORMAT ], 1 );
	
	
	WriteFileCell( hFile, iHeader[ view_as<int>HEADER_TICKCOUNT ], 4 );
	
	WriteFileCell( hFile, view_as<int>flTime, 4 );
	
	WriteFile( hFile, view_as<int>iHeader[ view_as<int>HEADER_INITPOS ], 3, 4 );
	WriteFile( hFile, view_as<int>iHeader[ view_as<int>HEADER_INITANGLES ], 2, 4 );
	
	// Save frames on to the file.
	int iFrame[FRAME_SIZE];
	
	for ( int i; i < iLength; i++ )
	{
		GetArrayArray( g_hClientRecording[client], i, iFrame, view_as<int>FrameInfo );
		
		if ( !WriteFile( hFile, iFrame, view_as<int>FrameInfo, 4 ) )
		{
			LogError( "%s An error occured while trying to write on to file!", CONSOLE_PREFIX );
			
			delete hFile;
			
			return false;
		}
	}
	
	delete hFile;
	
	return true;
}

stock bool LoadRecording( char szSteamId[STEAMID_MAXLENGTH], int iRun, int iStyle )
{
	ReplaceString( szSteamId, STEAMID_MAXLENGTH, "STEAM_", "" );
	
	// STEAM_0:1:30495520 to 0_1_30495520
	for ( int i; i < 5; i++ )
		if ( szSteamId[i] == ':' )
			szSteamId[i] = '_';
	
	
	static char szPath[PLATFORM_MAX_PATH];
	BuildPath( Path_SM, szPath, sizeof( szPath ), "records/%s/%s/%s/%s.rec", g_szCurrentMap, g_szRunName[NAME_SHORT][iRun], g_szStyleName[NAME_SHORT][iStyle], szSteamId );
	
	Handle hFile = OpenFile( szPath, "rb" );
	
	if ( hFile == null )
		return false;
	
	// GET HEADER
	int iMagic;
	ReadFileCell( hFile, iMagic, 4 );
	
	if ( iMagic != MAGIC_NUMBER )
	{
		LogError( "%s Tried to read from a record with different magic number!", CONSOLE_PREFIX );
		
		delete hFile;
		return false;
	}
	
	int iFormat;
	ReadFileCell( hFile, iFormat, 1 );
	
	if ( iFormat != BINARY_FORMAT )
	{
		LogError( "%s Tried to read from a record with different binary format!", CONSOLE_PREFIX );
		
		delete hFile;
		return false;
	}
	
	ReadFileCell( hFile, g_iMimicTickMax[iRun][iStyle], 4 );
	
	if ( g_iMimicTickMax[iRun][iStyle] < 1 )
	{
		delete hFile;
		return false;
	}
	
	int iHeader[HEADER_SIZE];
	
	if ( ReadFileCell( hFile, view_as<int>iHeader[ view_as<int>HEADER_TIME ], 4 ) == -1 )
	{
		LogError( "%s Tried to read from file with no time specified in the header(?)", CONSOLE_PREFIX );
	}
	
	ReadFile( hFile, view_as<int>iHeader[ view_as<int>HEADER_INITPOS ], 3, 4 );
	ReadFile( hFile, view_as<int>iHeader[ view_as<int>HEADER_INITANGLES ], 2, 4 );
	
	//iHeader[ view_as<int>HEADER_INITANGLES ];
	ArrayCopy( iHeader[ view_as<int>HEADER_INITPOS ], g_vecInitMimicPos[iRun][iStyle], 3 );
	ArrayCopy( iHeader[ view_as<int>HEADER_INITANGLES ], g_angInitMimicAngles[iRun][iStyle], 2 );
	
	// GET FRAMES
	int iFrame[FRAME_SIZE];
	g_hMimicRecording[iRun][iStyle] = CreateArray( view_as<int>FrameInfo );
	
	for ( int i; i < g_iMimicTickMax[iRun][iStyle]; i++ )
	{
		if ( ReadFile( hFile, iFrame, view_as<int>FrameInfo, 4 ) == -1 )
		{
			LogError( "%s An unexpected end of file while reading from record!", CONSOLE_PREFIX );
			
			delete hFile;
			return false;
		}
		
		PushArrayArray( g_hMimicRecording[iRun][iStyle], iFrame, view_as<int>FrameInfo );
	}
	
	delete hFile;
	
	return true;
}

stock bool RemoveAllRecords( int iRun, int iStyle )
{
	static char szPath[PLATFORM_MAX_PATH];
	BuildPath( Path_SM, szPath, sizeof( szPath ), "records/%s/%s/%s", g_szCurrentMap, g_szRunName[NAME_SHORT][iRun], g_szStyleName[NAME_SHORT][iStyle] );
	
	Handle hDir = OpenDirectory( szPath );
	
	if ( hDir == null )
		return false;
	
	static char szFile[64], char szFilePath[PLATFORM_MAX_PATH];
	while ( ReadDirEntry( hDir, szFile, sizeof( szFile ) ) )
	{
		Format( szFilePath, sizeof( szFilePath ), "%s/%s", szPath, szFile );
		
		if ( !FileExists( szFilePath ) )
			continue;
		
		DeleteFile( szFilePath );
	}
	
	return true;
}

stock bool RemoveRecord( char szSteamId[STEAMID_MAXLENGTH], int iRun, int iStyle )
{
	ReplaceString( szSteamId, STEAMID_MAXLENGTH, "STEAM_", "" );
	
	// STEAM_0:1:30495520 to 0_1_30495520
	for ( int i; i < 5; i++ )
		if ( szSteamId[i] == ':' )
			szSteamId[i] = '_';
	
	BuildPath( Path_SM, szPath, sizeof( szPath ), "records/%s/%s/%s/%s.rec", g_szCurrentMap, g_szRunName[NAME_SHORT][iRun], g_szStyleName[NAME_SHORT][iStyle], szSteamId );
	
	if ( !FileExists( szPath ) )
		return false;
	
	return DeleteFile( szPath );
}
#endif