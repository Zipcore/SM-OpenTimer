public Action:Command_ToggleHUD( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	SetEntProp( client, Prop_Data, "m_iHideHUD", 0 );
	
	new Handle:hHudMenu = CreateMenu( Handler_Hud );
	
	SetMenuTitle( hHudMenu, "HUD Menu\n " );

	
	if ( iClientHideFlags[client] & HIDEHUD_HUD )
		AddMenuItem( hHudMenu, "", "HUD: OFF" );
	else
		AddMenuItem( hHudMenu, "", "HUD: ON" );
	
	
	if ( iClientHideFlags[client] & HIDEHUD_VM )
		AddMenuItem( hHudMenu, "", "Viewmodel: OFF" );
	else
		AddMenuItem( hHudMenu, "", "Viewmodel: ON" );
		
		
	if ( iClientHideFlags[client] & HIDEHUD_PLAYERS )
		AddMenuItem( hHudMenu, "", "Players: OFF" );
	else
		AddMenuItem( hHudMenu, "", "Players: ON" );
	
	
	if ( iClientHideFlags[client] & HIDEHUD_TIMER )
		AddMenuItem( hHudMenu, "", "Timer: OFF" );
	else
		AddMenuItem( hHudMenu, "", "Timer: ON" );
	
	
	if ( iClientHideFlags[client] & HIDEHUD_SIDEINFO )
		AddMenuItem( hHudMenu, "", "Sidebar: OFF" );
	else
		AddMenuItem( hHudMenu, "", "Sidebar: ON" );
	
	if ( iClientHideFlags[client] & HIDEHUD_CHAT )
		AddMenuItem( hHudMenu, "", "Chat: OFF\n " );
	else
		AddMenuItem( hHudMenu, "", "Chat: ON\n " );
	
	AddMenuItem( hHudMenu, "", "Exit" );
	SetMenuExitButton( hHudMenu, false );
	
	DisplayMenu( hHudMenu, client, MENU_TIME_FOREVER );
	
	return Plugin_Handled;
}

public Handler_Hud( Handle:hHudMenu, MenuAction:action, client, item )
{
	if ( action == MenuAction_End )
	{
		if ( client > 0 )
			if ( iClientHideFlags[client] & HIDEHUD_HUD )
				SetEntProp( client, Prop_Data, "m_iHideHUD", 3946 );
			else
				ClientCommand( client, "sm_hud" );
		
		CloseHandle( hHudMenu );
	}
	else if ( action == MenuAction_Select )
	{
		switch ( item )
		{
			case 0 :
			{
				if ( iClientHideFlags[client] & HIDEHUD_HUD )
				{
					iClientHideFlags[client] &= ~HIDEHUD_HUD;
					
					SetEntProp( client, Prop_Data, "m_iHideHUD", 0 );
					
					PrintColorChat( client, client, "%s Restored HUD. (cl_radaralpha 200)", CHAT_PREFIX );
				}
				else
				{
					iClientHideFlags[client] |= HIDEHUD_HUD;
					
					SetEntProp( client, Prop_Data, "m_iHideHUD", 3946 );
					ClientCommand( client, "cl_radaralpha 0" );
					
					PrintColorChat( client, client, "%s Your HUD is now partially hidden. (cl_radaralpha 0)", CHAT_PREFIX );
				}
			}
			case 1 :
			{
				if ( iClientHideFlags[client] & HIDEHUD_VM )
				{
					iClientHideFlags[client] &= ~HIDEHUD_VM;
					
					SetEntProp( client, Prop_Data, "m_bDrawViewmodel", 1 );
				}
				else
				{
					iClientHideFlags[client] |= HIDEHUD_VM;
					
					SetEntProp( client, Prop_Data, "m_bDrawViewmodel", 0 );
				}
			}
			case 2 :
			{
				if ( iClientHideFlags[client] & HIDEHUD_PLAYERS )
				{
					iClientHideFlags[client] &= ~HIDEHUD_PLAYERS;
					
					SDKUnhook( client, SDKHook_SetTransmit, Event_ClientTransmit );
			
					PrintColorChat( client, client, "%s All players show up again!", CHAT_PREFIX );
				}
				else
				{
					iClientHideFlags[client] |= HIDEHUD_PLAYERS;
					
					SDKHook( client, SDKHook_SetTransmit, Event_ClientTransmit );
					
					PrintColorChat( client, client, "%s All players are hidden!", CHAT_PREFIX );
				}
			}
			case 3 :
			{
				if ( iClientHideFlags[client] & HIDEHUD_TIMER )
				{
					iClientHideFlags[client] &= ~HIDEHUD_TIMER;
					
					if ( !( iClientHideFlags[client] & HIDEHUD_TIMER ) && !( iClientHideFlags[client] & HIDEHUD_SIDEINFO ) )
						CreateTimer( TIMER_UPDATE_INTERVAL, Timer_ShowClientInfo, client, TIMER_REPEAT );
					
					PrintColorChat( client, client, "%s Your timer is back!", CHAT_PREFIX );
				}
				else
				{
					iClientHideFlags[client] |= HIDEHUD_TIMER;
					
					PrintColorChat( client, client, "%s Your timer is now hidden!", CHAT_PREFIX );
				}
			}
			case 4 :
			{
				if ( iClientHideFlags[client] & HIDEHUD_SIDEINFO )
				{
					iClientHideFlags[client] &= ~HIDEHUD_SIDEINFO;
					
					PrintColorChat( client, client, "%s Sidebar enabled!", CHAT_PREFIX );
					
					if ( !( iClientHideFlags[client] & HIDEHUD_TIMER ) && !( iClientHideFlags[client] & HIDEHUD_SIDEINFO ) )
						CreateTimer( TIMER_UPDATE_INTERVAL, Timer_ShowClientInfo, client, TIMER_REPEAT );
				}
				else
				{
					iClientHideFlags[client] |= HIDEHUD_SIDEINFO;
					
					PrintColorChat( client, client, "%s Sidebar is now hidden!", CHAT_PREFIX );
				}
			}
			case 5 :
			{
				if ( iClientHideFlags[client] & HIDEHUD_CHAT )
				{
					iClientHideFlags[client] &= ~HIDEHUD_CHAT;
					
					PrintColorChat( client, client, "%s Chat enabled!", CHAT_PREFIX );
				}
				else
				{
					iClientHideFlags[client] |= HIDEHUD_CHAT;
					
					PrintColorChat( client, client, "%s Chat is now hidden!", CHAT_PREFIX );
				}
			}
		}
		
		if ( !SaveClientInfo( client ) )
			PrintColorChat( client, client, "%s Couldn't save your settings!", CHAT_PREFIX );
	}
}

#if defined VOTING
public Action:Command_VoteMap( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( hMapList == INVALID_HANDLE )
	{
		PrintColorChat( client, client, "%s Voting is currently disabled!", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	if ( !IsPlayerAlive( client ) )
	{
		PrintColorChat( client, client, "%s You cannot participate in the vote if you're not doing anything, silly.", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	new len = GetArraySize( hMapList );
	
	if ( len < 1 )
	{
		PrintColorChat( client, client, "%s Voting is currently disabled!", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	SetEntProp( client, Prop_Data, "m_iHideHUD", 0 );
	
	new Handle:hVoteMenu = CreateMenu( Handler_Vote );
	
	SetMenuTitle( hVoteMenu, "Vote\n " );
	
	new iMap[MAX_MAP_NAME_LENGTH];
	decl String:MapName[MAX_MAP_NAME_LENGTH];
	
	for ( new i; i < len; i++ )
	{
		GetArrayArray( hMapList, i, iMap, _:MapInfo );
		strcopy( MapName, sizeof( MapName ), iMap[MAP_NAME] );
		
		AddMenuItem( hVoteMenu, "", MapName );
	}
	
	//AddMenuItem( hVoteMenu, "", "\n", ITEMDRAW_RAWLINE );
	AddMenuItem( hVoteMenu, "", "Exit" );
	SetMenuExitButton( hVoteMenu, false );
	
	DisplayMenu( hVoteMenu, client, MENU_TIME_FOREVER );
	
	return Plugin_Handled;
}

public Handler_Vote( Handle:hVoteMenu, MenuAction:action, client, index )
{
	if ( action == MenuAction_End )
	{
		if ( client > 0 && iClientHideFlags[client] & HIDEHUD_HUD )
			SetEntProp( client, Prop_Data, "m_iHideHUD", 3946 );
		
		CloseHandle( hVoteMenu );
	}
	else if ( action == MenuAction_Select )
	{	
		if ( iClientVote[client] != index )
		{	
			new len = GetArraySize( hMapList );
			
			if ( index < len )
			{
				new iMap[MAX_MAP_NAME_LENGTH];
				decl String:MapName[MAX_MAP_NAME_LENGTH];
				
				GetArrayArray( hMapList, index, iMap, _:MapInfo );
				
				strcopy( MapName, sizeof( MapName ), iMap[MAP_NAME] );
				
				if ( iClientVote[client] != -1 )
					PrintColorChatAll( client, false, "%s \x03%N%s changed his/her vote to \x03%s%s!", CHAT_PREFIX, client, COLOR_TEXT, MapName, COLOR_TEXT );
				else
					PrintColorChatAll( client, false, "%s \x03%N%s voted for \x03%s%s!", CHAT_PREFIX, client, COLOR_TEXT, MapName, COLOR_TEXT );
				
				iClientVote[client] = index;
				
				CalcVotes();
				//else PrintColorChat( client, client, "%s Was unable to process your vote. Try again.", CHAT_PREFIX );
			}
		}
	}
}
#endif

public Action:Command_Admin_ZoneMenu( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	SetEntProp( client, Prop_Data, "m_iHideHUD", 0 );
	
	new Handle:hZoneMenu = CreateMenu( Handler_ZoneMain );
	
	SetMenuTitle( hZoneMenu, "Zone Menu\n " );
	
	decl String:GridSize[16];
	Format( GridSize, sizeof( GridSize ), "Grid Size: %i\n ", iBuilderGridSize );
	
	if ( iBuilderIndex == 0 )
	{
		AddMenuItem( hZoneMenu, "", "New Zone" );
		AddMenuItem( hZoneMenu, "", "End Zone", ITEMDRAW_DISABLED );
		AddMenuItem( hZoneMenu, "", GridSize );
	}
	else
	{
		AddMenuItem( hZoneMenu, "", "New Zone", ITEMDRAW_DISABLED );
		
		if ( iBuilderIndex == client )
		{
			AddMenuItem( hZoneMenu, "", "End Zone" );
			AddMenuItem( hZoneMenu, "", GridSize );
		}
		else
		{
			AddMenuItem( hZoneMenu, "", "End Zone", ITEMDRAW_DISABLED );
			AddMenuItem( hZoneMenu, "", GridSize, ITEMDRAW_DISABLED );
		}
	}
	
	AddMenuItem( hZoneMenu, "", "Delete Zone\n " );
	
	AddMenuItem( hZoneMenu, "", "Exit" );
	SetMenuExitButton( hZoneMenu, false );
	
	DisplayMenu( hZoneMenu, client, MENU_TIME_FOREVER );
	
	return Plugin_Handled;
}

public Handler_ZoneMain( Handle:hZoneMenu, MenuAction:action, client, index )
{
	if ( action == MenuAction_End )
	{
		if ( client > 0 && iClientHideFlags[client] & HIDEHUD_HUD )
			SetEntProp( client, Prop_Data, "m_iHideHUD", 3946 );
			
		CloseHandle( hZoneMenu );
	}
	else if ( action == MenuAction_Select )
	{	
		switch ( index )
		{
			case 0 : ClientCommand( client, "sm_startzone" );
			case 1 : ClientCommand( client, "sm_endzone" );
			case 2 :
			{
				if ( iBuilderGridSize >= 16 ) iBuilderGridSize = 1;
				else iBuilderGridSize = iBuilderGridSize * 2;
				
				ClientCommand( client, "sm_zone" );
			}
			case 3 : ClientCommand( client, "sm_deletezone" );
		}
	}
}

public Action:Command_Admin_ZoneStart( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	if ( iBuilderIndex != client && iBuilderIndex != 0 )
	{
		PrintColorChat( client, client, "%s Somebody is already building!", CHAT_PREFIX );
		return Plugin_Handled;
	}
	
	SetEntProp( client, Prop_Data, "m_iHideHUD", 0 );
	
	new Handle:hZoneCreate = CreateMenu( Handler_ZoneCreate );
	
	SetMenuTitle( hZoneCreate, "Zone Creation\n " );
	
	new bool:bFound;
	
	for ( new i; i < MAX_BOUNDS; i++ )
		if ( !bZoneExists[i] )
		{
			AddMenuItem( hZoneCreate, "", ZoneNames[i] );
			bFound = true;
		}
		else AddMenuItem( hZoneCreate, "", ZoneNames[i], ITEMDRAW_DISABLED );
	
	if ( !bFound )
	{
		PrintColorChat( client, client, "%s All the zones already exist!", CHAT_PREFIX );
		
		CloseHandle( hZoneCreate );
		return Plugin_Handled;
	}
	
	//AddMenuItem( hZoneCreate, "", "\n", ITEMDRAW_RAWLINE );
	AddMenuItem( hZoneCreate, "", "Exit" );
	SetMenuExitButton( hZoneCreate, false );
	
	DisplayMenu( hZoneCreate, client, MENU_TIME_FOREVER );
	
	return Plugin_Handled;
}

public Handler_ZoneCreate( Handle:hZoneCreate, MenuAction:action, client, zone )
{
	if ( action == MenuAction_End )
	{
		if ( client > 0 && iClientHideFlags[client] & HIDEHUD_HUD )
			SetEntProp( client, Prop_Data, "m_iHideHUD", 3946 );
			
		CloseHandle( hZoneCreate );
	}
	else if ( action == MenuAction_Select )
	{
		if ( zone > -1 && zone < MAX_BOUNDS )
		{
			decl Float:vecClientPos[3];
			GetClientAbsOrigin( client, vecClientPos );
			
			vecBoundsMin[zone][0] = vecClientPos[0] - ( RoundFloat( vecClientPos[0] ) % iBuilderGridSize );
			vecBoundsMin[zone][1] = vecClientPos[1] - ( RoundFloat( vecClientPos[1] ) % iBuilderGridSize );
			vecBoundsMin[zone][2] = float( RoundFloat( vecClientPos[2] - 0.5 ) );
			
			iBuilderZone = zone;
			iBuilderIndex = client;
			
			CreateTimer( 0.1, Timer_DrawBuildZoneBeams, client, TIMER_REPEAT );
			
			PrintColorChat( client, client, "%s You started %s! Go to the other side of the room.", CHAT_PREFIX, ZoneNames[zone] );
		}
		
		ClientCommand( client, "sm_zone" );
	}
}

public Action:Command_Admin_ZoneDelete( client, args )
{
	if ( client < 1 ) return Plugin_Handled;
	
	SetEntProp( client, Prop_Data, "m_iHideHUD", 0 );
	
	new Handle:hZoneDelete = CreateMenu( Handler_ZoneDelete );
	
	SetMenuTitle( hZoneDelete, "Zone Delete\n " );
	
	new bool:bFound;
	
	for ( new i; i < MAX_BOUNDS; i++ )
		if ( bZoneExists[i] )
		{
			AddMenuItem( hZoneDelete, "", ZoneNames[i] );
			bFound = true;
		}
		else AddMenuItem( hZoneDelete, "", ZoneNames[i], ITEMDRAW_DISABLED );
	
	if ( !bFound )
	{
		PrintColorChat( client, client, "%s There are no zones!", CHAT_PREFIX );
		
		CloseHandle( hZoneDelete );
		return Plugin_Handled;
	}
	
	//AddMenuItem( hZoneDelete, "", "\n", ITEMDRAW_RAWLINE );
	AddMenuItem( hZoneDelete, "", "Exit" );
	SetMenuExitButton( hZoneDelete, false );
	
	DisplayMenu( hZoneDelete, client, MENU_TIME_FOREVER );
	
	return Plugin_Handled;
}

public Handler_ZoneDelete( Handle:hZoneCreate, MenuAction:action, client, zone )
{
	//PrintToServer( "INDEX: %i", zone );
	
	if ( action == MenuAction_End )
	{
		if ( client > 0 && iClientHideFlags[client] & HIDEHUD_HUD )
			SetEntProp( client, Prop_Data, "m_iHideHUD", 3946 );
			
		CloseHandle( hZoneCreate );
	}
	else if ( action == MenuAction_Select )
	{
		if ( zone > -1 && zone < MAX_BOUNDS )
		{
			bZoneExists[zone] = false;
			
			PrintColorChat( client, client, "%s %s deleted.", CHAT_PREFIX, ZoneNames[zone] );
			
			if ( zone == BOUNDS_START || zone == BOUNDS_END )
			{
				bIsLoaded[RUN_MAIN] = false;
				PrintColorChatAll( client, false, "%s Map is currently not available for running!", CHAT_PREFIX );
			}
			
			EraseMapCoords( zone );
		}
		
		ClientCommand( client, "sm_zone" );
	}
}