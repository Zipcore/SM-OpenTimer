public Action Command_ToggleHUD( int client, int args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	SetEntProp( client, Prop_Data, "m_iHideHUD", 0 );
	
	Menu mHud = CreateMenu( Handler_Hud );
	
	SetMenuTitle( mHud, "HUD Menu\n " );

	if ( g_iClientHideFlags[client] & HIDEHUD_HUD )
		AddMenuItem( mHud, "", "HUD: OFF" );
	else
		AddMenuItem( mHud, "", "HUD: ON" );
	
	
	if ( g_iClientHideFlags[client] & HIDEHUD_VM )
		AddMenuItem( mHud, "", "Viewmodel: OFF" );
	else
		AddMenuItem( mHud, "", "Viewmodel: ON" );
		
		
	if ( g_iClientHideFlags[client] & HIDEHUD_PLAYERS )
		AddMenuItem( mHud, "", "Players: OFF" );
	else
		AddMenuItem( mHud, "", "Players: ON" );
	
	
	if ( g_iClientHideFlags[client] & HIDEHUD_TIMER )
		AddMenuItem( mHud, "", "Timer: OFF" );
	else
		AddMenuItem( mHud, "", "Timer: ON" );
	
	
	if ( g_iClientHideFlags[client] & HIDEHUD_SIDEINFO )
		AddMenuItem( mHud, "", "Sidebar: OFF" );
	else
		AddMenuItem( mHud, "", "Sidebar: ON" );
	
	if ( g_iClientHideFlags[client] & HIDEHUD_CHAT )
		AddMenuItem( mHud, "", "Chat: OFF\n " );
	else
		AddMenuItem( mHud, "", "Chat: ON\n " );
	
	AddMenuItem( mHud, "", "Exit" );
	SetMenuExitButton( mHud, false );
	
	DisplayMenu( mHud, client, 5 );
	
	return Plugin_Handled;
}

public int Handler_Hud( Menu menu, MenuAction action, int client, int item )
{
	switch ( action )
	{
		case MenuAction_End :
		{
			if ( client > 0 )
			{
				if ( g_iClientHideFlags[client] & HIDEHUD_HUD )
					SetEntProp( client, Prop_Data, "m_iHideHUD", HIDE_FLAGS );
				else
					ClientCommand( client, "sm_hud" );
			}
			
			delete menu;
		}
		case MenuAction_Select :
		{
			// We selected an item!
			switch ( item )
			{
				case 0 :
				{
					if ( g_iClientHideFlags[client] & HIDEHUD_HUD )
					{
						g_iClientHideFlags[client] &= ~HIDEHUD_HUD;
						
						SetEntProp( client, Prop_Data, "m_iHideHUD", 0 );
						
						PrintColorChat( client, client, "%s Restored HUD. (cl_radaralpha 200)", CHAT_PREFIX );
					}
					else
					{
						g_iClientHideFlags[client] |= HIDEHUD_HUD;
						
						SetEntProp( client, Prop_Data, "m_iHideHUD", HIDE_FLAGS );
						ClientCommand( client, "cl_radaralpha 0" );
						
						PrintColorChat( client, client, "%s Your HUD is now partially hidden. (cl_radaralpha 0)", CHAT_PREFIX );
					}
				}
				case 1 :
				{
					if ( g_iClientHideFlags[client] & HIDEHUD_VM )
					{
						g_iClientHideFlags[client] &= ~HIDEHUD_VM;
						
						SetEntProp( client, Prop_Data, "m_bDrawViewmodel", 1 );
					}
					else
					{
						g_iClientHideFlags[client] |= HIDEHUD_VM;
						
						SetEntProp( client, Prop_Data, "m_bDrawViewmodel", 0 );
					}
				}
				case 2 :
				{
					if ( g_iClientHideFlags[client] & HIDEHUD_PLAYERS )
					{
						g_iClientHideFlags[client] &= ~HIDEHUD_PLAYERS;
						
						SDKUnhook( client, SDKHook_SetTransmit, Event_ClientTransmit );
				
						PrintColorChat( client, client, "%s All players show up again!", CHAT_PREFIX );
					}
					else
					{
						g_iClientHideFlags[client] |= HIDEHUD_PLAYERS;
						
						SDKHook( client, SDKHook_SetTransmit, Event_ClientTransmit );
						
						PrintColorChat( client, client, "%s All players are hidden!", CHAT_PREFIX );
					}
				}
				case 3 :
				{
					if ( g_iClientHideFlags[client] & HIDEHUD_TIMER )
					{
						g_iClientHideFlags[client] &= ~HIDEHUD_TIMER;
						
						if ( !( g_iClientHideFlags[client] & HIDEHUD_TIMER ) && !( g_iClientHideFlags[client] & HIDEHUD_SIDEINFO ) )
							CreateTimer( TIMER_UPDATE_INTERVAL, Timer_ShowClientInfo, client, TIMER_REPEAT );
						
						PrintColorChat( client, client, "%s Your timer is back!", CHAT_PREFIX );
					}
					else
					{
						g_iClientHideFlags[client] |= HIDEHUD_TIMER;
						
						PrintColorChat( client, client, "%s Your timer is now hidden!", CHAT_PREFIX );
					}
				}
				case 4 :
				{
					if ( g_iClientHideFlags[client] & HIDEHUD_SIDEINFO )
					{
						g_iClientHideFlags[client] &= ~HIDEHUD_SIDEINFO;
						
						PrintColorChat( client, client, "%s Sidebar enabled!", CHAT_PREFIX );
						
						if ( !( g_iClientHideFlags[client] & HIDEHUD_TIMER ) && !( g_iClientHideFlags[client] & HIDEHUD_SIDEINFO ) )
							CreateTimer( TIMER_UPDATE_INTERVAL, Timer_ShowClientInfo, client, TIMER_REPEAT );
					}
					else
					{
						g_iClientHideFlags[client] |= HIDEHUD_SIDEINFO;
						
						PrintColorChat( client, client, "%s Sidebar is now hidden!", CHAT_PREFIX );
					}
				}
				case 5 :
				{
					if ( g_iClientHideFlags[client] & HIDEHUD_CHAT )
					{
						g_iClientHideFlags[client] &= ~HIDEHUD_CHAT;
						
						PrintColorChat( client, client, "%s Chat enabled!", CHAT_PREFIX );
					}
					else
					{
						g_iClientHideFlags[client] |= HIDEHUD_CHAT;
						
						PrintColorChat( client, client, "%s Chat is now hidden!", CHAT_PREFIX );
					}
				}
			}
			
			if ( !SaveClientInfo( client ) )
				PrintColorChat( client, client, "%s Couldn't save your settings!", CHAT_PREFIX );
		}
	}
	
	return 0;
}

#if defined VOTING
public Action Command_VoteMap( int client, int args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( g_hMapList == null )
	{
		PrintColorChat( client, client, "%s Voting is currently disabled!", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	if ( !IsPlayerAlive( client ) )
	{
		PrintColorChat( client, client, "%s You cannot participate in the vote if you're not doing anything, silly.", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	int len = GetArraySize( g_hMapList );
	
	if ( len < 1 )
	{
		PrintColorChat( client, client, "%s Voting is currently disabled!", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	SetEntProp( client, Prop_Data, "m_iHideHUD", 0 );
	
	Menu mVote = CreateMenu( Handler_Vote );
	
	SetMenuTitle( mVote, "Vote\n " );
	
	int iMap[MAX_MAP_NAME_LENGTH];
	char MapName[MAX_MAP_NAME_LENGTH];
	
	for ( int i; i < len; i++ )
	{
		GetArrayArray( g_hMapList, i, iMap, view_as<int>MapInfo );
		strcopy( MapName, sizeof( MapName ), iMap[MAP_NAME] );
		
		AddMenuItem( mVote, "", MapName );
	}
	
	//AddMenuItem( mVote, "", "\n", ITEMDRAW_RAWLINE );
	AddMenuItem( mVote, "", "Exit" );
	SetMenuExitButton( mVote, false );
	
	DisplayMenu( mVote, client, MENU_TIME_FOREVER );
	
	return Plugin_Handled;
}

public int Handler_Vote( Menu menu, MenuAction action, int client, int index )
{
	switch ( action )
	{
		case MenuAction_End :
		{
			if ( client > 0 && g_iClientHideFlags[client] & HIDEHUD_HUD )
				SetEntProp( client, Prop_Data, "m_iHideHUD", HIDE_FLAGS );
			
			delete menu;
		}
		case MenuAction_Select :
		{
			if ( g_iClientVote[client] != index )
			{	
				int len = GetArraySize( g_hMapList );
				
				if ( index < len )
				{
					int iMap[MAX_MAP_NAME_LENGTH];
					char MapName[MAX_MAP_NAME_LENGTH];
					
					GetArrayArray( g_hMapList, index, iMap, view_as<int>MapInfo );
					
					strcopy( MapName, sizeof( MapName ), iMap[MAP_NAME] );
					
					if ( g_iClientVote[client] != -1 )
						PrintColorChatAll( client, false, "%s \x03%N%s changed his/her vote to \x03%s%s!", CHAT_PREFIX, client, COLOR_TEXT, MapName, COLOR_TEXT );
					else
						PrintColorChatAll( client, false, "%s \x03%N%s voted for \x03%s%s!", CHAT_PREFIX, client, COLOR_TEXT, MapName, COLOR_TEXT );
					
					g_iClientVote[client] = index;
					
					CalcVotes();
					//else PrintColorChat( client, client, "%s Was unable to process your vote. Try again.", CHAT_PREFIX );
				}
			}
		}
	}
	
	return 0;
}
#endif

public Action Command_Admin_ZoneMenu( int client, int args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	SetEntProp( client, Prop_Data, "m_iHideHUD", 0 );
	
	Handle mZone = CreateMenu( Handler_ZoneMain );
	
	SetMenuTitle( mZone, "Zone Menu\n " );
	
	char szGridTxt[16]; // "Grid Size: XXC "
	Format( szGridTxt, sizeof( szGridTxt ), "Grid Size: %i units\n ", g_iBuilderGridSize );
	
	if ( g_iBuilderIndex == 0 )
	{
		// We haven't started to build a zone yet. Show them the option for it.
		
		AddMenuItem( mZone, "", "New Zone" );
		AddMenuItem( mZone, "", "End Zone", ITEMDRAW_DISABLED );
		AddMenuItem( mZone, "", szGridTxt );
	}
	else
	{
		// We have a builder! Might not be the same client who has this menu open, though...
		
		AddMenuItem( mZone, "", "New Zone", ITEMDRAW_DISABLED );
		
		if ( g_iBuilderIndex == client )
		{
			AddMenuItem( mZone, "", "End Zone" );
			AddMenuItem( mZone, "", szGridTxt );
		}
		else
		{
			AddMenuItem( mZone, "", "End Zone", ITEMDRAW_DISABLED );
			AddMenuItem( mZone, "", szGridTxt, ITEMDRAW_DISABLED );
		}
	}
	
	AddMenuItem( mZone, "", "Delete Zone\n " );
	
	AddMenuItem( mZone, "", "Exit" );
	SetMenuExitButton( mZone, false );
	
	DisplayMenu( mZone, client, MENU_TIME_FOREVER );
	
	return Plugin_Handled;
}

public int Handler_ZoneMain( Menu menu, MenuAction action, int client, int item )
{
	switch ( action )
	{
		case MenuAction_End :
		{
			if ( client > 0 && g_iClientHideFlags[client] & HIDEHUD_HUD )
				SetEntProp( client, Prop_Data, "m_iHideHUD", HIDE_FLAGS );
			
			delete menu;
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
	if ( client < 1 ) return Plugin_Handled;
	
	if ( g_iBuilderIndex != client && g_iBuilderIndex != 0 )
	{
		PrintColorChat( client, client, "%s Somebody is already building!", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	SetEntProp( client, Prop_Data, "m_iHideHUD", 0 );
	
	Menu mZoneCreate = CreateMenu( Handler_ZoneCreate );
	
	SetMenuTitle( mZoneCreate, "Zone Creation\n " );
	
	bool bFound;
	
	for ( int i; i < MAX_BOUNDS; i++ )
		if ( !g_bZoneExists[i] )
		{
			AddMenuItem( mZoneCreate, "", g_szZoneNames[i] );
			bFound = true;
		}
		else AddMenuItem( mZoneCreate, "", g_szZoneNames[i], ITEMDRAW_DISABLED );
	
	if ( !bFound )
	{
		PrintColorChat( client, client, "%s All the zones already exist!", CHAT_PREFIX );
		
		delete mZoneCreate;
		return Plugin_Handled;
	}
	
	//AddMenuItem( mZoneCreate, "", "\n", ITEMDRAW_RAWLINE );
	AddMenuItem( mZoneCreate, "", "Exit" );
	SetMenuExitButton( mZoneCreate, false );
	
	DisplayMenu( mZoneCreate, client, MENU_TIME_FOREVER );
	
	return Plugin_Handled;
}

public int Handler_ZoneCreate( Menu menu, MenuAction action, int client, int zone )
{
	switch ( action )
	{
		case MenuAction_End :
		{
			if ( client > 0 && g_iClientHideFlags[client] & HIDEHUD_HUD )
				SetEntProp( client, Prop_Data, "m_iHideHUD", HIDE_FLAGS );
			
			delete menu;
		}
		case MenuAction_Select :
		{
			if ( zone > -1 && zone < MAX_BOUNDS )
			{
				static float vecClientPos[3];
				GetClientAbsOrigin( client, vecClientPos );
				
				g_vecBoundsMin[zone][0] = vecClientPos[0] - ( RoundFloat( vecClientPos[0] ) % g_iBuilderGridSize );
				g_vecBoundsMin[zone][1] = vecClientPos[1] - ( RoundFloat( vecClientPos[1] ) % g_iBuilderGridSize );
				g_vecBoundsMin[zone][2] = float( RoundFloat( vecClientPos[2] - 0.5 ) );
				
				g_iBuilderZone = zone;
				g_iBuilderIndex = client;
				
				CreateTimer( 0.1, Timer_DrawBuildZoneBeams, client, TIMER_REPEAT );
				
				PrintColorChat( client, client, "%s You started %s! Go to the other side of the room.", CHAT_PREFIX, g_szZoneNames[zone] );
			}
			
			ClientCommand( client, "sm_zone" );
		}
	}
	
	return 0;
}

public Action Command_Admin_ZoneDelete( int client, int args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	SetEntProp( client, Prop_Data, "m_iHideHUD", 0 );
	
	Menu mZoneDel = CreateMenu( Handler_ZoneDelete );
	
	//mZoneDel.SetTitle( "Zone Delete\n " );
	
	SetMenuTitle( mZoneDel, "Zone Delete\n " );
	
	bool bFound;
	
	for ( int i; i < MAX_BOUNDS; i++ )
	{
		if ( g_bZoneExists[i] )
		{
			AddMenuItem( mZoneDel, "", g_szZoneNames[i] );
			bFound = true;
		}
		else
			AddMenuItem( mZoneDel, "", g_szZoneNames[i], ITEMDRAW_DISABLED );
	}
	
	if ( !bFound )
	{
		PrintColorChat( client, client, "%s There are no zones!", CHAT_PREFIX );
		
		delete mZoneDel;
		return Plugin_Handled;
	}
	
	//AddMenuItem( mZoneDel, "", "\n", ITEMDRAW_RAWLINE );
	AddMenuItem( mZoneDel, "", "Exit" );
	SetMenuExitButton( mZoneDel, false );
	
	DisplayMenu( mZoneDel, client, 5 );
	
	return Plugin_Handled;
}

public int Handler_ZoneDelete( Menu menu, MenuAction action, int client, int zone )
{
	switch ( action )
	{
		case MenuAction_End :
		{
			if ( client > 0 && g_iClientHideFlags[client] & HIDEHUD_HUD )
				SetEntProp( client, Prop_Data, "m_iHideHUD", HIDE_FLAGS );
				
			delete menu;
		}
		case MenuAction_Select :
		{
			if ( -1 < zone < MAX_BOUNDS )
			{
				g_bZoneExists[zone] = false;
				
				PrintColorChat( client, client, "%s %s deleted.", CHAT_PREFIX, g_szZoneNames[zone] );
				
				if ( zone == BOUNDS_START || zone == BOUNDS_END )
				{
					g_bIsLoaded[RUN_MAIN] = false;
					PrintColorChatAll( client, false, "%s Map is currently not available for running!", CHAT_PREFIX );
				}
				
				EraseCurMapCoords( zone );
			}
			
			ClientCommand( client, "sm_zone" );
		}
	}
	
	return 0;
}

public Action Command_Style( int client, int args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( !IsPlayerAlive( client ) )
	{
		PrintColorChat( client, client, "%s You must be alive to change your style!", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	SetEntProp( client, Prop_Data, "m_iHideHUD", 0 );
	
	Menu mMode = CreateMenu( Handler_Mode );
	
	SetMenuTitle( mMode, "Choose Style\n " );
	
	for ( int i; i < MAX_STYLES; i++ )
		if ( g_iClientStyle[client] != i )
			AddMenuItem( mMode, "", g_szStyleName[NAME_LONG][i] );
		else
			AddMenuItem( mMode, "", g_szStyleName[NAME_LONG][i], ITEMDRAW_DISABLED );

	AddMenuItem( mMode, "", "Exit" );
	SetMenuExitButton( mMode, false );
	
	DisplayMenu( mMode, client, 5 );
	
	return Plugin_Handled;
}

public int Handler_Mode( Menu menu, MenuAction action, int client, int style )
{
	switch ( action )
	{
		case MenuAction_End :
		{
			if ( client > 0 && g_iClientHideFlags[client] & HIDEHUD_HUD )
				SetEntProp( client, Prop_Data, "m_iHideHUD", HIDE_FLAGS );
			
			delete menu;
		}
		case MenuAction_Select :
		{
			if ( IsPlayerAlive( client ) && ( -1 < style < MAX_STYLES ) )
			{
				TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_angSpawnAngles[ g_iClientRun[client] ], g_vecNull );
				g_iClientStyle[client] = style;
				
				PrintColorChat( client, client, "%s Your style is now \x03%s%s!", CHAT_PREFIX, g_szStyleName[NAME_LONG][style], COLOR_TEXT );
			}
		}
	}
	
	return 0;
}