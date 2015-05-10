// Query handles are closed automatically.

public void Threaded_PrintRecords( Handle hOwner, Handle hQuery, const char[] szError, any hData )
{
	int client;
	if ( ( client = GetClientOfUserId( GetArrayCell( hData, 0, 0 ) ) ) == 0 ) return;
	
	if ( hQuery == null )
	{
		SQL_GetError( g_Database, g_szError, sizeof( g_szError ) );
		LogError( CONSOLE_PREFIX ... "An error occured when trying to print times to client. Error: %s", g_szError );
	
		PrintColorChat( client, client, CHAT_PREFIX ... "Sorry, something went wrong." );
		return;
	}
	
	
	int				field;
	int				ply; // Record count.
	int				iJumps[RECORDS_PRINT_MAX];
	int				iStyle[RECORDS_PRINT_MAX];
	static float	flSeconds[RECORDS_PRINT_MAX];
	static char		szSteamId[RECORDS_PRINT_MAX][STEAMID_MAXLENGTH];
	static char		szName[RECORDS_PRINT_MAX][MAX_NAME_LENGTH];
	static char		szFormTime[RECORDS_PRINT_MAX][SIZE_TIME_RECORDS];
	
	bool bInConsole = GetArrayCell( hData, 0, 1 );
	
	while ( SQL_FetchRow( hQuery ) )
	{
		if ( bInConsole )
		{
			SQL_FieldNameToNum( hQuery, "steamid", field );
			SQL_FetchString( hQuery, field, szSteamId[ply], sizeof( szSteamId[] ) );
		
			SQL_FieldNameToNum( hQuery, "jumps", field );
			iJumps[ply] = SQL_FetchInt( hQuery, field );
		}
		
		SQL_FieldNameToNum( hQuery, "style", field );
		iStyle[ply] = SQL_FetchInt( hQuery, field );
		
		SQL_FieldNameToNum( hQuery, "name", field );
		SQL_FetchString( hQuery, field, szName[ply], sizeof( szName[] ) );
		
		SQL_FieldNameToNum( hQuery, "time", field );
		flSeconds[ply] = SQL_FetchFloat( hQuery, field );
		
		FormatSeconds( flSeconds[ply], szFormTime[ply], sizeof( szFormTime[] ) );
		
		ply++;
	}
	
	
	// Print them to a menu.
	if ( !bInConsole )
	{
		SetEntProp( client, Prop_Data, "m_iHideHUD", 0 );
		Menu mMenu = CreateMenu( Handler_Empty );
		SetMenuTitle( mMenu, "Records\n " );
		
		char szRec[64];
		
		if ( ply > 0 )
		{
			for ( int i; i < ply; i++ )
			{
				// "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX XX:XX:XX.XX [XXXX]"
				FormatEx( szRec, sizeof( szRec ), "%s - %s [%s]", szName[i], szFormTime[i], g_szStyleName[NAME_SHORT][ iStyle[i] ] );
				AddMenuItem( mMenu, "_", szRec, ITEMDRAW_DISABLED );
			}
		}
		else
		{
			FormatEx( szRec, sizeof( szRec ), "No one has beaten the map yet." );
			AddMenuItem( mMenu, "_", szRec, ITEMDRAW_DISABLED );
		}
		
		DisplayMenu( mMenu, client, MENU_TIME_FOREVER );
	}
	else
	{
		PrintToConsole( client, "--------------------" );
		PrintToConsole( client, ">> !printrecords <style/run> for specific styles and runs. (\"normal\", \"sideways\", \"w\", \"b1/b2\", etc.)" );
		PrintToConsole( client, ">> Records (Max. %i):", RECORDS_PRINT_MAX );
		
		if ( ply > 0 )
		{
			for ( int i; i < ply; i++ )
			{
				PrintToConsole( client, "%i. %s - %s - %s - %s - %i jumps", i + 1, szSteamId[i], szName[i], szFormTime[i], g_szStyleName[NAME_LONG][ iStyle[i] ], iJumps[i] );
			}
		}
		else PrintToConsole( client, "No one has beaten the map yet... :(" );
		
		PrintToConsole( client, "--------------------" );
		
		PrintColorChat( client, client, CHAT_PREFIX ... "Printed (\x03%i"...CLR_TEXT...") records in your console.", ply );
	}
}

public void Threaded_RetrieveClientData( Handle hOwner, Handle hQuery, const char[] szError, any data )
{
	if ( hQuery == null )
	{
		SQL_GetError( g_Database, g_szError, sizeof( g_szError ) );
		LogError( CONSOLE_PREFIX ... "Couldn't retrieve player data! Error: %s", g_szError );
		
		return;
	}
	
	
	int client;
	
	if ( ( client = GetClientOfUserId( data ) ) == 0 ) return;
	
	char szSteamId[STEAMID_MAXLENGTH];
	
	if ( !GetClientAuthId( client, AuthId_Engine, szSteamId, sizeof( szSteamId ) ) )
	{
		LogError( CONSOLE_PREFIX ... "There was an error at trying to retrieve player's \"%N\" Steam ID! Cannot save record.", client );
		return;
	}
	
	
	static char szQuery[128];
	
	if ( SQL_GetRowCount( hQuery ) == 0 )
	{
		FormatEx( szQuery, sizeof( szQuery ), "INSERT INTO player_data (steamid, fov, hideflags) VALUES ('%s', 90, 0)", szSteamId );
		
		SQL_LockDatabase( g_Database );
		
		if ( !SQL_FastQuery( g_Database, szQuery ) )
		{
			SQL_UnlockDatabase( g_Database );
			
			LogError( CONSOLE_PREFIX ... "Error! Couldn't add a row for new profile!! Steam ID: %s", szSteamId );
			return;
		}
		
		SQL_UnlockDatabase( g_Database );
		
		return;
	}
	
	
	int field;
	while ( SQL_FetchRow( hQuery ) )
	{
		SQL_FieldNameToNum( hQuery, "fov", field );
		g_iClientFOV[client] = SQL_FetchInt( hQuery, field );
		
		SQL_FieldNameToNum( hQuery, "hideflags", field );
		g_fClientHideFlags[client] = SQL_FetchInt( hQuery, field );
	}
	
	/*if ( g_fClientHideFlags[client] & HIDEHUD_PLAYERS )
		SDKHook( client, SDKHook_SetTransmit, Event_ClientTransmit );*/
	
	
	// Then we get the times.
	FormatEx( szQuery, sizeof( szQuery ), "SELECT time, style, run FROM '%s' WHERE steamid = '%s' ORDER BY run", g_szCurrentMap, szSteamId );
	SQL_TQuery( g_Database, Threaded_RetrieveClientTimes, szQuery, GetClientUserId( client ), DBPrio_Normal );
}

public void Threaded_RetrieveClientTimes( Handle hOwner, Handle hQuery, const char[] szError, any data )
{
	if ( hQuery == null )
	{
		SQL_GetError( g_Database, g_szError, sizeof( g_szError ) );
		LogError( CONSOLE_PREFIX ... "Couldn't retrieve player data! Error: %s", g_szError );
		
		return;
	}
	
	
	int client;
	if ( ( client = GetClientOfUserId( data ) ) == 0 ) return;
	
	int field, iStyle, iRun;
	while ( SQL_FetchRow( hQuery ) )
	{
		SQL_FieldNameToNum( hQuery, "run", field );
		iRun = SQL_FetchInt( hQuery, field );
		
		SQL_FieldNameToNum( hQuery, "style", field );
		iStyle = SQL_FetchInt( hQuery, field );
	
		SQL_FieldNameToNum( hQuery, "time", field );
		g_flClientBestTime[client][iRun][iStyle] = SQL_FetchFloat( hQuery, field );
	}
	
	UpdateScoreboard( client );
}

// No callback is needed.
public void Threaded_Empty( Handle hOwner, Handle hQuery, const char[] szError, any data ) {}