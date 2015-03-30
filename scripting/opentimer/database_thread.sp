// Query handles are closed automatically.

public void Threaded_PrintRecords( Handle hOwner, Handle hQuery, const char[] szError, any hData )
{
	int client;
	if ( ( client = GetClientOfUserId( GetArrayCell( hData, 0, 0 ) ) ) == 0 ) return;
	
	if ( hQuery == null )
	{
		SQL_GetError( g_Database, g_szError, sizeof( g_szError ) );
		LogError( "%s An error occured when trying to print times to client.\nError: %s", CONSOLE_PREFIX, g_szError );
	
		PrintColorChat( client, client, "%s Sorry, something went wrong.", CHAT_PREFIX );
		return;
	}
	
	
	int				field;
	int				ply; // Record count.
	int				iJumps[RECORDS_PRINT_MAXPLAYERS + 1];
	int				iStyle[RECORDS_PRINT_MAXPLAYERS + 1];
	static float	flSeconds[RECORDS_PRINT_MAXPLAYERS + 1];
	static char		szSteamId[RECORDS_PRINT_MAXPLAYERS + 1][STEAMID_MAXLENGTH];
	static char		szName[RECORDS_PRINT_MAXPLAYERS + 1][MAX_NAME_LENGTH];
	static char		szFormTime[RECORDS_PRINT_MAXPLAYERS + 1][12];
	
	bool bInConsole = GetArrayCell( hData, 0, 1 );
	
	while ( SQL_FetchRow( hQuery ) )
	{
		if ( bInConsole )
		{
			SQL_FieldNameToNum( hQuery, "steamid", field );
			SQL_FetchString( hQuery, field, szSteamId[ply], sizeof( szSteamId[] ) );
		
			SQL_FieldNameToNum( hQuery, "jumps", field );
			iJumps[ply] = SQL_FetchInt( hQuery, field );
			
			SQL_FieldNameToNum( hQuery, "style", field );
			iStyle[ply] = SQL_FetchInt( hQuery, field );
		}
		
		SQL_FieldNameToNum( hQuery, "name", field );
		SQL_FetchString( hQuery, field, szName[ply], sizeof( szName[] ) );
		
		SQL_FieldNameToNum( hQuery, "time", field );
		flSeconds[ply] = SQL_FetchFloat( hQuery, field );
		//flSeconds[ply] += 0.0001; // Just to make sure...
		
		FormatSeconds( flSeconds[ply], szFormTime[ply], sizeof( szFormTime[] ), true );
		
		ply++;
	}
	
	
	// Print them to a menu.
	if ( !bInConsole )
	{
		SetEntProp( client, Prop_Data, "m_iHideHUD", 0 );
		Menu mMenu = CreateMenu( Handler_Records );
		SetMenuTitle( mMenu, "Records\n " );
		
		char szRec[32];
		
		if ( ply > 0 )
		{
			for ( int i; i < ply; i++ )
			{
				Format( szRec, sizeof( szRec ), "%s - %s", szName[i], szFormTime[i] );
				AddMenuItem( mMenu, "_", szRec, ITEMDRAW_DISABLED );
			}
		}
		else
		{
			Format( szRec, sizeof( szRec ), "No one has beaten the map yet." );
			AddMenuItem( mMenu, "_", szRec, ITEMDRAW_DISABLED );
		}
		
		//SetMenuExitButton( mMenu, true );
		DisplayMenu( mMenu, client, MENU_TIME_FOREVER );
	}
	else
	{
		PrintToConsole( client, "--------------------" );
		PrintToConsole( client, ">> !printrecords <style/run> for specific styles and runs. (\"normal\", \"sideways\", \"w\", \"b1/b2\", etc.)" );
		PrintToConsole( client, ">> Records (Max. %i):", RECORDS_PRINT_MAXPLAYERS );
		
		if ( ply > 0 )
		{
			for ( int i; i < ply; i++ )
			{
				PrintToConsole( client, "%i. %s - %s - %s - %s - %i jumps", i + 1, szSteamId[i], szName[i], szFormTime[i], g_szStyleName[NAME_LONG][ iStyle[i] ], iJumps[i] );
			}
		}
		else PrintToConsole( client, "No one has beaten the map yet... :(" );
		
		PrintToConsole( client, "--------------------" );
		
		PrintColorChat( client, client, "%s Printed (\x03%i%s) records in your console.", CHAT_PREFIX, ply, COLOR_TEXT );
	}
}

public int Handler_Records( Menu mMenu, MenuAction action, int client, int item )
{
	switch ( action )
	{
		case MenuAction_End :
		{
			if ( client > 0 && g_iClientHideFlags[client] & HIDEHUD_HUD )
			{
				SetEntProp( client, Prop_Data, "m_iHideHUD", HIDE_FLAGS );
			}
			
			delete mMenu;
		}
		/*case MenuAction_Select :
		{
			char szItem[2];
			
			if ( !GetMenuItem( mMenu, item, szItem, sizeof( szItem ) ) || szItem[0] != '_' )
			{
				return 0;
			}
		}*/
	}
	
	return 0;
}

public void Threaded_RetrieveClientData( Handle hOwner, Handle hQuery, const char[] szError, any data )
{
	if ( hQuery == null )
	{
		SQL_GetError( g_Database, g_szError, sizeof( g_szError ) );
		LogError( "%s Couldn't retrieve player data!\n g_szError: %s", CONSOLE_PREFIX, g_szError );
		
		return;
	}
	
	
	int client;
	
	if ( ( client = GetClientOfUserId( data ) ) == 0 ) return;
	
	char szSteamId[STEAMID_MAXLENGTH];
	
	if ( !GetClientAuthId( client, AuthId_Engine, szSteamId, sizeof( szSteamId ) ) )
	{
		LogError( "%s There was an error at trying to retrieve player's \"%N\" Steam ID! Cannot save record.", CONSOLE_PREFIX, client );
		return;
	}
	
	
	static char szQuery[128];
	
	if ( SQL_GetRowCount( hQuery ) == 0 )
	{
		Format( szQuery, sizeof( szQuery ), "INSERT INTO player_data ( steamid, fov, hideflags ) VALUES ( '%s', 90, 0 );", szSteamId );
		
		SQL_LockDatabase( g_Database );
		
		if ( !SQL_FastQuery( g_Database, szQuery ) )
		{
			SQL_UnlockDatabase( g_Database );
			
			LogError( "%s Error! Couldn't add a row for new profile!! Steam ID: %s", CONSOLE_PREFIX, szSteamId );
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
		g_iClientHideFlags[client] = SQL_FetchInt( hQuery, field );
	}
	
	if ( g_iClientHideFlags[client] & HIDEHUD_PLAYERS )
		SDKHook( client, SDKHook_SetTransmit, Event_ClientTransmit );
	
	Format( szQuery, sizeof( szQuery ), "SELECT time, style, run FROM '%s' WHERE steamid = '%s' ORDER BY run;", g_szCurrentMap, szSteamId );
	SQL_TQuery( g_Database, Threaded_RetrieveClientTimes, szQuery, GetClientUserId( client ) );
}

public void Threaded_RetrieveClientTimes( Handle hOwner, Handle hQuery, const char[] szError, any data )
{
	if ( hQuery == null )
	{
		SQL_GetError( g_Database, g_szError, sizeof( g_szError ) );
		LogError( "%s Couldn't retrieve player data!\n Error: %s", CONSOLE_PREFIX, g_szError );
		
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