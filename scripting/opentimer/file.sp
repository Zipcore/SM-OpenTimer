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
	char szSteamID[STEAMID_MAXLENGTH];
	
	if ( !GetClientAuthId( client, AuthId_Engine, szSteamID, sizeof( szSteamID ) ) )
		return false;
	
	ReplaceString( szSteamID, sizeof( szSteamID ), "STEAM_", "" );
	
	// STEAM_0:1:30495520 to 0_1_30495520
	for ( int i; i < 5; i++ )
		if ( szSteamID[i] == ':' )
			szSteamID[i] = '_';
	
	
	static char szPath[PLATFORM_MAX_PATH];
	BuildPath( Path_SM, szPath, sizeof( szPath ), "records" );
	if ( !ExCreateDir( szPath ) ) return false;
	
	
	Format( szPath, sizeof( szPath ), "%s/%s", szPath, g_szCurrentMap ); // records/bhop_map
	if ( !ExCreateDir( szPath ) ) return false;

	Format( szPath, sizeof( szPath ), "%s/%s", szPath, g_szRunName[NAME_SHORT][ g_iClientRun[client] ] ); // records/bhop_map/M
	if ( !ExCreateDir( szPath ) ) return false;
	
	Format( szPath, sizeof( szPath ), "%s/%s", szPath, g_szStyleName[NAME_SHORT][ g_iClientStyle[client] ] ); // records/bhop_map/M/HSW
	if ( !ExCreateDir( szPath ) ) return false;
	
	
	Format( szPath, sizeof( szPath ), "%s/%s.rec", szPath, szSteamID ); // records/bhop_map/N/HSW/0_1_30495520
	
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

stock bool LoadRecording( char szSteamID[STEAMID_MAXLENGTH], int iRun, int iStyle )
{
	ReplaceString( szSteamID, STEAMID_MAXLENGTH, "STEAM_", "" );
	
	// STEAM_0:1:30495520 to 0_1_30495520
	for ( int i; i < 5; i++ )
		if ( szSteamID[i] == ':' )
			szSteamID[i] = '_';
	
	
	static char szPath[PLATFORM_MAX_PATH];
	BuildPath( Path_SM, szPath, sizeof( szPath ), "records/%s/%s/%s/%s.rec", g_szCurrentMap, g_szRunName[NAME_SHORT][iRun], g_szStyleName[NAME_SHORT][iStyle], szSteamID );
	
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
	
	static char	szFile[64];
	static char	szFilePath[PLATFORM_MAX_PATH];
	
	while ( ReadDirEntry( hDir, szFile, sizeof( szFile ) ) )
	{
		Format( szFilePath, sizeof( szFilePath ), "%s/%s", szPath, szFile );
		
		if ( !FileExists( szFilePath ) )
			continue;
		
		DeleteFile( szFilePath );
	}
	
	return true;
}

stock bool RemoveRecord( char szSteamID[STEAMID_MAXLENGTH], int iRun, int iStyle )
{
	ReplaceString( szSteamID, STEAMID_MAXLENGTH, "STEAM_", "" );
	
	// STEAM_0:1:30495520 to 0_1_30495520
	for ( int i; i < 5; i++ )
		if ( szSteamID[i] == ':' )
			szSteamID[i] = '_';
	
	BuildPath( Path_SM, szPath, sizeof( szPath ), "records/%s/%s/%s/%s.rec", g_szCurrentMap, g_szRunName[NAME_SHORT][iRun], g_szStyleName[NAME_SHORT][iStyle], szSteamID );
	
	if ( !FileExists( szPath ) )
		return false;
	
	return DeleteFile( szPath );
}