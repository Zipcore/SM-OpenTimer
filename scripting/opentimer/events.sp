// Hide other players (doesn't work with bots?)
public Action Event_ClientTransmit( int ent, int client )
{
	if ( !IsPlayerAlive( client ) ) return Plugin_Continue;
	
	return ( client != ent ) ? Plugin_Handled : Plugin_Continue;
}

// Tell the client to respawn!
public Action Event_ClientDeath( Handle hEvent, const char[] szEvent, bool bDontBroadcast )
{
	int client;

	if ( ( client = GetClientOfUserId( GetEventInt( hEvent, "userid" ) ) ) < 1 ) return;
	
	
	PrintColorChat( client, client, "%s Type !respawn to spawn again.", CHAT_PREFIX );
}

// Hide player name changes. Doesn't work.
/*
public Action Event_ClientName( Handle hEvent, const char[] szEvent, bool bDontBroadcast )
{
	bDontBroadcast = true;
	SetEventBroadcast( hEvent, true );
	
	return Plugin_Handled;
}*/

// Set client ready for the map. Collision groups, bots, transparency, etc.
public Action Event_ClientSpawn( Handle hEvent, const char[] szEvent, bool bDontBroadcast )
{
	int client = GetClientOfUserId( GetEventInt( hEvent, "userid" ) );
	
	if ( client < 1 || GetClientTeam( client ) < 2 || !IsPlayerAlive( client ) ) return;

	if ( g_bIsLoaded[ g_iClientRun[client] ] )
	{
		TeleportEntity( client, g_vecSpawnPos[ g_iClientRun[client] ], g_angSpawnAngles[ g_iClientRun[client] ], g_vecNull );
	}
	
	// -----------------------------------------------------------------------------------------------
	// Story time!
	// 
	// Once upon a time I had a great idea of making a timer plugin. I started to experiment with movement recording and playback.
	// I was pretty happy what I had at the time. It followed you pretty well, not perfect, though.
	// The bot movement was really choppy, so I tried to perfect the movement. I recorded the player's velocity. That didn't change a thing.
	// I tried recording absolute velocity... didn't work.
	// I couldn't figure it out and months flew by... still didn't find a solution.
	// Fast forward to today! I decided to make the bots visible again since I wanted to debug the movement.
	// I was surprised how smooth it looked. I thought I had accidentally discovered the secret of smooth recording(TM).
	// Then I realized what I changed.
	// 
	// Moral of the story: DO NOT SET PLAYERS' RENDER MODE TO RENDER_NONE!
	// If you do that, all movement smoothing will be thrown out of the window.
	// This cost me almost a year of suffering, trying to figure out why my bots looked so choppy.
	// You can't imagine how enraged I was to learn that it was a simple fix.
	// I can't. I've lost the ability to can.
	// BUT YOU LEARN SOMETHING EVERY DAY! :^)
	// -----------------------------------------------------------------------------------------------
	SetEntityRenderMode( client, RENDER_TRANSALPHA );
	
	if ( !IsFakeClient( client ) )
	{
		SetEntProp( client, Prop_Data, "m_CollisionGroup", 2 ); // Disable player collisions.
		SetEntityRenderColor( client, _, _, _, 128 );
	}
	else
	{
		SetEntProp( client, Prop_Data, "m_CollisionGroup", 1 ); // Same + no trigger collision for bots.
		SetEntityRenderColor( client, _, _, _, 0 ); // The bot is still technically there, but you cannot see it.
	}
	
	CreateTimer( 0.1, Timer_ClientSpawn, GetClientUserId( client ), TIMER_FLAG_NO_MAPCHANGE );
}


// Continued from above event.
public Action Timer_ClientSpawn( Handle hTimer, any client )
{
	if ( ( client = GetClientOfUserId( client ) ) < 1 ) return Plugin_Handled;
	
	
	// Hides deathnotices, health and weapon.
	// Radar and crosshair stuff can be disabled client side. Disabling those server-side won't allow you to switch between weapons.
	if ( g_iClientHideFlags[client] & HIDEHUD_HUD ) SetEntProp( client, Prop_Data, "m_iHideHUD", HIDE_FLAGS );
	if ( g_iClientHideFlags[client] & HIDEHUD_VM ) SetEntProp( client, Prop_Data, "m_bDrawViewmodel", 0 );
	
	SetEntProp( client, Prop_Data, "m_nHitboxSet", 2 ); // Don't get damaged from weapons.
	
	if ( IsFakeClient( client ) )
	{
#if defined RECORD
		SetEntityGravity( client, 0.0 );
		SetEntityMoveType( client, MOVETYPE_NOCLIP );
		
		// Also, hide their guns so they are not just floating around
		int wep;
		for ( int i; i < 5; i++ ) // Slot count (5)
			if ( ( wep = GetPlayerWeaponSlot( client, i ) ) > 0 )
				AcceptEntityInput( wep, "Kill" );
				//SetEntityRenderMode( wep, RENDER_NONE );
#endif

		return Plugin_Handled;
	}
	
	
	SetClientFOV( client, g_iClientFOV[client] );
	
	return Plugin_Handled;
}


///////////
// EZHOP //
///////////
public Action Event_ClientJump( Handle hEvent, const char[] szEvent, bool bDontBroadcast )
{
	if ( !g_bEZHop ) return;
	
	
	SetEntPropFloat( GetClientOfUserId( GetEventInt( hEvent, "userid" ) ), Prop_Send, "m_flStamina", 0.0 );
}

public Action Event_ClientDamage( int victim, int &attacker, int &inflictor, float &damage, int &damagetype )
{
	if ( g_bEZHop )
	{
		//SetEntPropFloat( client, Prop_Send, "m_flVelocityModifier", 1.0 );
		return Plugin_Handled;
	}
	
	
	damage = 0.0;
	return Plugin_Continue;
}


//////////
// CHAT //
//////////
public Action Listener_Say( int client, const char[] szCommand, int argc )
{
	// Let the server talk :^)
	if ( client == 0 || !IsClientInGame( client ) ) return Plugin_Continue;
	
	if ( BaseComm_IsClientGagged( client ) ) return Plugin_Handled;
	
	
#if defined CHAT
	static char szArg[131]; // MAX MESSAGE LENGTH (SayText) + QUOTES
	GetCmdArgString( szArg, sizeof( szArg ) );
	
	if ( szArg[1] == '@' || szArg[1] == '/' || szArg[1] == '!' ) return Plugin_Handled;
	
	StripQuotes( szArg );
	
	
#if defined VOTING
	if ( StrEqual( szArg, "rtv" ) || StrEqual( szArg, "rockthevote" ) || StrEqual( szArg, "nominate" ) || StrEqual( szArg, "choosemap" ) )
	{
		ClientCommand( client, "sm_choosemap" );
		return Plugin_Handled;
	}
#endif
	
	
	if ( !IsPlayerAlive( client ) )
	{
		PrintColorChatAll( client, true, "%s[%sSPEC%s] \x03%N\x01: %s%s", COLOR_TEXT, COLOR_PURPLE, COLOR_TEXT, client, COLOR_TEXT, szArg );
	}
	else
	{
		PrintColorChatAll( client, true, "\x03%N\x01: %s%s", client, COLOR_TEXT, szArg );
	}
	
	
	// Print to server and players' consoles.
	PrintToServer( "%N: %s", client, szArg );
	
	for ( int i = 1; i <= MaxClients; i++ )
		if ( IsClientInGame( i ) ) PrintToConsole( i, "%N: %s", client, szArg );
	
	
	return Plugin_Handled;
#else
	
	// Just to check if client typed out ! in front of the message. This is so god damn annoying to see...
	char szArg[4];
	GetCmdArgString( szArg, sizeof( szArg ) );
	
	if ( szArg[1] == '!' ) return Plugin_Handled;
	
	return Plugin_Continue;
#endif
}

// For block zones.
public void Event_TouchBlock( int trigger, int activator )
{
	if ( activator < 1 || activator > MaxClients ) return;
	
	if ( g_bIsClientPractising[activator] ) return;
	
	
	if ( IsClientInGame( activator ) )
	{
		if ( g_flClientWarning[activator] < GetEngineTime() )
			PrintColorChat( activator, activator, "%s You are not allowed to go there!", CHAT_PREFIX );
		
		
		TeleportEntity( activator, g_vecSpawnPos[ g_iClientRun[activator] ], g_angSpawnAngles[ g_iClientRun[activator] ], g_vecNull );
		
		g_flClientWarning[activator] = GetEngineTime() + WARNING_INTERVAL;
	}
}

// Anti-doublestep
public Action Listener_AntiDoublestep_On( int client, const char[] szCommand, int argc )
{
	g_bClientHoldingJump[client] = true;
	return Plugin_Handled;
}
public Action Listener_AntiDoublestep_Off( int client, const char[] szCommand, int argc )
{
	g_bClientHoldingJump[client] = false;
	return Plugin_Handled;
} 