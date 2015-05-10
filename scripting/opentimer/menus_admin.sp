public Action Command_Admin_ZoneMenu( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	
	SetEntProp( client, Prop_Data, "m_iHideHUD", 0 );
	Handle mMenu = CreateMenu( Handler_ZoneMain );
	SetMenuTitle( mMenu, "Zone Menu\n " );
	
	char szGridTxt[22]; // "Grid Size: XX unitsC "
	FormatEx( szGridTxt, sizeof( szGridTxt ), "Grid Size: %i units\n ", g_iBuilderGridSize );
	
	if ( g_iBuilderIndex == INVALID_INDEX )
	{
		// We haven't started to build a zone yet. Show them the option for it.
		AddMenuItem( mMenu, "_", "New Zone" );
		AddMenuItem( mMenu, "_", "End Zone", ITEMDRAW_DISABLED );
		AddMenuItem( mMenu, "_", szGridTxt );
	}
	else if ( g_iBuilderIndex != client )
	{
		// Some other player is building a zone.
		PrintColorChat( client, client, CHAT_PREFIX ... "Somebody is already building!" );
		
		delete mMenu;
		return Plugin_Handled;
	}
	else
	{
		// We have a builder! Might not be the same client who has this menu open, though...
		AddMenuItem( mMenu, "_", "New Zone", ITEMDRAW_DISABLED );
		
		if ( g_iBuilderIndex == client )
		{
			AddMenuItem( mMenu, "_", "End Zone" );
			AddMenuItem( mMenu, "_", szGridTxt );
		}
		else
		{
			AddMenuItem( mMenu, "_", "End Zone", ITEMDRAW_DISABLED );
			AddMenuItem( mMenu, "_", szGridTxt, ITEMDRAW_DISABLED );
		}
	}
	
	AddMenuItem( mMenu, "_", "Delete Zone\n " );
	//SetMenuExitButton( mMenu, true );
	
	DisplayMenu( mMenu, client, MENU_TIME_FOREVER );
	
	return Plugin_Handled;
}

public int Handler_ZoneMain( Menu mMenu, MenuAction action, int client, int item )
{
	switch ( action )
	{
		case MenuAction_End :
		{
			if ( client > 0 && g_fClientHideFlags[client] & HIDEHUD_HUD )
				SetEntProp( client, Prop_Data, "m_iHideHUD", HIDE_FLAGS );
			
			delete mMenu;
		}
		case MenuAction_Select :
		{
			// We got an item!
			switch ( item )
			{
				case 0 : ClientCommand( client, "sm_startzone" );
				case 1 : ClientCommand( client, "sm_endzone" );
				case 2 :
				{
					if ( g_iBuilderGridSize >= 16 ) g_iBuilderGridSize = 1;
					else g_iBuilderGridSize = g_iBuilderGridSize * 2;
					
					ClientCommand( client, "sm_zone" );
				}
				case 3 : ClientCommand( client, "sm_deletezone" );
			}
		}
	}
	
	return 0;
}

public Action Command_Admin_ZoneStart( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	if ( g_iBuilderIndex != INVALID_INDEX && g_iBuilderIndex != client )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "Somebody is already building!" );
		return Plugin_Handled;
	}
	
	
	SetEntProp( client, Prop_Data, "m_iHideHUD", 0 );
	Menu mMenu = CreateMenu( Handler_ZoneCreate );
	SetMenuTitle( mMenu, "Zone Creation\n " );
	
	bool bFound;
	
	for ( int i; i < NUM_ZONES; i++ )
		if ( !g_bZoneExists[i] )
		{
			AddMenuItem( mMenu, "_", g_szZoneNames[i] );
			bFound = true;
		}
		else AddMenuItem( mMenu, "_", g_szZoneNames[i], ITEMDRAW_DISABLED );
	
	if ( !bFound )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "All zones already exist!" );
		
		delete mMenu;
		return Plugin_Handled;
	}
	
	
	//SetMenuExitButton( mMenu, true );
	DisplayMenu( mMenu, client, MENU_TIME_FOREVER );
	
	return Plugin_Handled;
}

public int Handler_ZoneCreate( Menu mMenu, MenuAction action, int client, int zone )
{
	switch ( action )
	{
		case MenuAction_End :
		{
			if ( client > 0 && g_fClientHideFlags[client] & HIDEHUD_HUD )
				SetEntProp( client, Prop_Data, "m_iHideHUD", HIDE_FLAGS );
			
			delete mMenu;
		}
		case MenuAction_Select :
		{
			if ( 0 > zone >= NUM_ZONES ) return 0;
			
			
			if ( g_iBuilderIndex != 0 && g_iBuilderIndex != client )
			{
				PrintColorChat( client, client, CHAT_PREFIX ... "Somebody is already building!" );
				return 0;
			}
			
			float vecClientPos[3];
			GetClientAbsOrigin( client, vecClientPos );
			
			g_vecZoneMins[zone][0] = vecClientPos[0] - ( RoundFloat( vecClientPos[0] ) % g_iBuilderGridSize );
			g_vecZoneMins[zone][1] = vecClientPos[1] - ( RoundFloat( vecClientPos[1] ) % g_iBuilderGridSize );
			g_vecZoneMins[zone][2] = float( RoundFloat( vecClientPos[2] - 0.5 ) );
			
			g_iBuilderZone = zone;
			g_iBuilderIndex = client;
			
			CreateTimer( 0.1, Timer_DrawBuildZoneBeams, client, TIMER_REPEAT );
			
			PrintColorChat( client, client, CHAT_PREFIX ... "You started %s! Go to the other side of the room.", g_szZoneNames[zone] );
			
			
			ClientCommand( client, "sm_zone" );
		}
	}
	
	return 0;
}

public Action Command_Admin_ZoneDelete( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	
	SetEntProp( client, Prop_Data, "m_iHideHUD", 0 );
	Menu mMenu = CreateMenu( Handler_ZoneDelete );
	SetMenuTitle( mMenu, "Zone Delete\n " );
	
	bool bFound;
	
	for ( int i; i < NUM_ZONES; i++ )
	{
		if ( g_bZoneExists[i] )
		{
			AddMenuItem( mMenu, "_", g_szZoneNames[i] );
			bFound = true;
		}
		else
			AddMenuItem( mMenu, "_", g_szZoneNames[i], ITEMDRAW_DISABLED );
	}
	
	if ( !bFound )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "There are no zones to delete!" );
		
		delete mMenu;
		return Plugin_Handled;
	}
	
	
	//SetMenuExitButton( mMenu, true );
	DisplayMenu( mMenu, client, 5 );
	
	return Plugin_Handled;
}

public int Handler_ZoneDelete( Menu mMenu, MenuAction action, int client, int zone )
{
	switch ( action )
	{
		case MenuAction_End :
		{
			if ( client > 0 && g_fClientHideFlags[client] & HIDEHUD_HUD )
				SetEntProp( client, Prop_Data, "m_iHideHUD", HIDE_FLAGS );
				
			delete mMenu;
		}
		case MenuAction_Select :
		{
			if ( 0 > zone >= NUM_ZONES ) return 0;
			
			
			if ( zone == ZONE_START || zone == ZONE_END )
			{
				g_bIsLoaded[RUN_MAIN] = false;
				PrintColorChatAll( client, false, CHAT_PREFIX ... "\x03%s"...CLR_TEXT..." is no longer available for running!", g_szRunName[NAME_LONG][RUN_MAIN] );
			}
			else if ( zone == ZONE_BONUS_1_START || zone == ZONE_BONUS_1_END )
			{
				g_bIsLoaded[RUN_BONUS_1] = false;
				PrintColorChatAll( client, false, CHAT_PREFIX ... "\x03%s"...CLR_TEXT..." is no longer available for running!", g_szRunName[NAME_LONG][RUN_BONUS_1] );
			}
			else if ( zone == ZONE_BONUS_2_START || zone == ZONE_BONUS_2_END )
			{
				g_bIsLoaded[RUN_BONUS_2] = false;
				PrintColorChatAll( client, false, CHAT_PREFIX ... "\x03%s"...CLR_TEXT..." is no longer available for running!", g_szRunName[NAME_LONG][RUN_BONUS_2] );
			}
			// Delete the actual block zone entities!
			// The hook should be deleted with it automatically.
			else if ( zone == ZONE_BLOCK_1 )
			{
				if ( g_iBlockZoneIndex[0] == 0 || !IsValidEntity( g_iBlockZoneIndex[0] ) )
				{
					PrintColorChat( client, client, CHAT_PREFIX ... "Couldn't remove \x03%s"...CLR_TEXT..."!", g_szZoneNames[zone] );
					return 0;
				}
				
				
				RemoveEdict( g_iBlockZoneIndex[0] );
				g_iBlockZoneIndex[0] = 0;
			}
			else if ( zone == ZONE_BLOCK_2 )
			{
				if ( g_iBlockZoneIndex[1] == 0 || !IsValidEntity( g_iBlockZoneIndex[1] ) )
				{
					PrintColorChat( client, client, CHAT_PREFIX ... "Couldn't remove \x03%s"...CLR_TEXT..."!", g_szZoneNames[zone] );
					return 0;
				}
				
				
				RemoveEdict( g_iBlockZoneIndex[1] );
				g_iBlockZoneIndex[1] = 0;
			}
			else if ( zone == ZONE_BLOCK_3 )
			{
				if ( g_iBlockZoneIndex[2] == 0 || !IsValidEntity( g_iBlockZoneIndex[2] ) )
				{
					PrintColorChat( client, client, CHAT_PREFIX ... "Couldn't remove \x03%s"...CLR_TEXT..."!", g_szZoneNames[zone] );
					return 0;
				}
				
				
				RemoveEdict( g_iBlockZoneIndex[2] );
				g_iBlockZoneIndex[2] = 0;
			}
			
			g_bZoneExists[zone] = false;
			PrintColorChat( client, client, CHAT_PREFIX ... "\x03%s"...CLR_TEXT..." deleted.", g_szZoneNames[zone] );
			
			// Erase them from the database.
			DB_EraseCurMapZone( zone );
			
			
			ClientCommand( client, "sm_zone" );
		}
	}
	
	return 0;
}

/*public Action Command_Admin_Record_Delete( int client, int args )
{
	if ( client == INVALID_INDEX ) return Plugin_Handled;
	
	
	SetEntProp( client, Prop_Data, "m_iHideHUD", 0 );
	Menu mMenu = CreateMenu( Handler_RecordDelete );
	SetMenuTitle( mMenu, "Zone Delete\n " );
	
	bool bFound;
	
	for ( int i; i < NUM_ZONES; i++ )
	{
		if ( g_bZoneExists[i] )
		{
			AddMenuItem( mMenu, "_", g_szZoneNames[i] );
			bFound = true;
		}
		else
			AddMenuItem( mMenu, "_", g_szZoneNames[i], ITEMDRAW_DISABLED );
	}
	
	if ( !bFound )
	{
		PrintColorChat( client, client, CHAT_PREFIX ... "There are no zones!" );
		
		delete mMenu;
		return Plugin_Handled;
	}

	
	SetMenuExitButton( mMenu, true );
	DisplayMenu( mMenu, client, 5 );
	
	return Plugin_Handled;
}*/