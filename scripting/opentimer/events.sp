// Hide other players (doesn't work with bots?)
public Action Event_ClientTransmit( int ent, int client )
{
	if ( ( 1 > ent > MaxClients ) || client == ent ) return Plugin_Continue;
	
	
	if ( !IsPlayerAlive( client ) )
	{
		if ( GetEntPropEnt( client, Prop_Data, "m_hObserverTarget" ) == ent )
			return Plugin_Continue;
	}
	
	
	if ( !IsFakeClient( ent ) )
	{
		if ( g_fClientHideFlags[client] & HIDEHUD_PLAYERS )
			return Plugin_Handled;
		
		return Plugin_Continue;
	}
	else
	{
		if ( g_fClientHideFlags[client] & HIDEHUD_BOTS )
			return Plugin_Handled;
		
		return Plugin_Continue;
	}
}

// Tell the client to respawn!
public Action Event_ClientDeath( Handle hEvent, const char[] szEvent, bool bDontBroadcast )
{
	int client;

	if ( ( client = GetClientOfUserId( GetEventInt( hEvent, "userid" ) ) ) < 1 ) return;
	
	
	PRINTCHAT( client, client, CHAT_PREFIX ... "Type \x03!respawn"...CLR_TEXT..." to spawn again." );
}

// Hide player name changes. Doesn't work.
/*
public Action Event_ClientName( Handle hEvent, const char[] szEvent, bool bDontBroadcast )
{
	bDontBroadcast = true;
	SetEventBroadcast( hEvent, true );
	
	return Plugin_Handled;
}*/

public void Event_WeaponSwitchPost( int client )
{
	// Higher the ping, the longer the transition period will be.
	SetClientFOV( client, g_iClientFOV[client] );
}

public void Event_WeaponDropPost( int client, int weapon )
{
	// This doesn't delete all the weapons.
	// In fact, this doesn't get called when player suicides.
	if ( IsValidEntity( weapon ) )
		AcceptEntityInput( weapon, "Kill" );
}

/*public Action CS_OnCSWeaponDrop( int client, int wep )
{
	return Plugin_Continue;
}*/

public Action Event_ClientTeam( Handle hEvent, const char[] szEvent, bool bDontBroadcast )
{
	if ( GetEventInt( hEvent, "team" ) > CS_TEAM_SPECTATOR )
	{
		CreateTimer( 2.0, Timer_ClientJoinTeam, GetEventInt( hEvent, "userid" ), TIMER_FLAG_NO_MAPCHANGE );
	}
}

// Set client ready for the map. Collision groups, bots, transparency, etc.
public Action Event_ClientSpawn( Handle hEvent, const char[] szEvent, bool bDontBroadcast )
{
	int client = GetClientOfUserId( GetEventInt( hEvent, "userid" ) );
	
	if ( client < 1 || GetClientTeam( client ) < 2 || !IsPlayerAlive( client ) ) return;

	TeleportPlayerToStart( client );
	
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
#if !defined CSGO
	SetEntityRenderMode( client, RENDER_TRANSALPHA );
	SetEntityRenderColor( client, _, _, _, 128 );
#endif
	
	// 2 = Disable player collisions.
	// 1 = Same + no trigger collision for bots.
	SetEntProp( client, Prop_Data, "m_CollisionGroup", IsFakeClient( client ) ? 1 : 2 );
	
	CreateTimer( 0.1, Timer_ClientSpawn, GetClientUserId( client ), TIMER_FLAG_NO_MAPCHANGE );
}

// Continued from above event.
public Action Timer_ClientSpawn( Handle hTimer, any client )
{
	if ( ( client = GetClientOfUserId( client ) ) < 1 ) return Plugin_Handled;
	
	
	// Hides deathnotices, health and weapon.
	// Radar and crosshair stuff can be disabled client side. Disabling those server-side won't allow you to switch between weapons.
#if !defined CSGO
	if ( g_fClientHideFlags[client] & HIDEHUD_HUD )
		SetEntProp( client, Prop_Send, "m_iHideHUD", HIDE_FLAGS );
#endif
	
	if ( g_fClientHideFlags[client] & HIDEHUD_VM )
		SetEntProp( client, Prop_Send, "m_bDrawViewmodel", 0 );
	
	SetEntProp( client, Prop_Data, "m_nHitboxSet", 2 ); // Don't get damaged from weapons.
	
	// Hide guns so they are not just floating around
	int wep;
	for ( int i; i < NUM_SLOTS; i++ )
	{
		if ( ( wep = GetPlayerWeaponSlot( client, i ) ) > 0 )
			HideEntity( wep );
		
		switch ( i )
		{
			case SLOT_BOMB :
			{
				if ( wep > 0 && IsValidEntity( wep ) )
					RemoveEdict( wep );
			}
			case SLOT_SECONDARY :
			{
				if ( wep < 1 )
				{
					wep = GivePlayerItem( client, PREF_SECONDARY );
					
					if ( wep > 0 ) HideEntity( wep );
					
					continue;
				}
			}
			case SLOT_MELEE :
			{
				if ( wep < 1 )
				{
					wep = GivePlayerItem( client, "weapon_knife" );
					
					if ( wep > 0 ) HideEntity( wep );
					
					continue;
				}
			}
		}
	}
	
	if ( IsFakeClient( client ) )
	{
#if defined RECORD
		SetEntityGravity( client, 0.0 );
		SetEntityMoveType( client, MOVETYPE_NOCLIP );
#endif

		return Plugin_Handled;
	}
	
	SetClientFOV( client, g_iClientFOV[client] );
	
	return Plugin_Handled;
}

///////////
// EZHOP //
///////////
// We assume that CS:GO servers will handle the stamina themselves.
public Action Event_ClientJump( Handle hEvent, const char[] szEvent, bool bDontBroadcast )
{
	static int client;
	if ( ( client = GetClientOfUserId( GetEventInt( hEvent, "userid" ) ) ) < 1 )
		return;
	
	
	if ( g_iClientState[client] != STATE_END )
		g_nClientJumpCount[client]++;
	
#if !defined CSGO
	if ( g_bEZHop )
	{
		SetEntPropFloat( client, Prop_Send, "m_flStamina", 0.0 );
	}
#endif
}

/*public Action Event_ClientHurt( Handle hEvent, const char[] szEvent, bool bDontBroadcast )
{
	static int client;
	if ( ( client = GetClientOfUserId( GetEventInt( hEvent, "userid" ) ) ) < 1 ) return;
	
	if ( g_bEZHop )
	{
		SetEntPropFloat( client, Prop_Send, "m_flVelocityModifier", 1.0 );
	}
	
	SetEntProp( client, Prop_Data, "m_iHealth", 100 );
}*/

public Action Event_OnTakeDamage( int victim, int &attacker, int &inflictor, float &flDamage, int &fDamage )
{
	if ( g_bEZHop ) return Plugin_Handled;

	flDamage = 0.0;
	return Plugin_Changed;
}


//////////
// CHAT //
//////////
public Action Listener_Say( int client, const char[] szCommand, int argc )
{
	// Let the server talk :^)
	if ( client == INVALID_INDEX || !IsClientInGame( client ) ) return Plugin_Continue;
	
	if ( BaseComm_IsClientGagged( client ) ) return Plugin_Handled;
	
#if defined CHAT
	static char szArg[131]; // MAX MESSAGE LENGTH (SayText) + QUOTES (?)
	GetCmdArgString( szArg, sizeof( szArg ) );
	
	if ( szArg[1] == '@' || szArg[1] == '/' || szArg[1] == '!' ) return Plugin_Handled;
	
	StripQuotes( szArg );
	
	
#if defined VOTING
	if ( StrEqual( szArg, "rtv" ) || StrEqual( szArg, "rockthevote" ) || StrEqual( szArg, "nominate" ) || StrEqual( szArg, "choosemap" ) )
	{
		ClientCommand( client, "sm_choosemap" );
		return Plugin_Handled;
	}
#endif // VOTING
	
	
	if ( !IsPlayerAlive( client ) )
	{
		PrintColorChatAll( client, true, CLR_TEXT ... "["...CLR_SPEC..."SPEC"...CLR_TEXT..."] \x03%N\x01: "...CLR_TEXT..."%s", client, szArg );
	}
	else
	{
		PrintColorChatAll( client, true, "\x03%N\x01: "...CLR_TEXT..."%s", client, szArg );
	}
	
	
	// Print to server and players' consoles.
	PrintToServer( "%N: %s", client, szArg );
	
	for ( int i = 1; i <= MaxClients; i++ )
		if ( IsClientInGame( i ) ) PrintToConsole( i, "%N: %s", client, szArg );
	
	
	return Plugin_Handled;
	
#else // CHAT
	// Just to check if client typed out ! in front of the message. This is so god damn annoying to see...
	char szArg[4];
	GetCmdArgString( szArg, sizeof( szArg ) );
	
	if ( szArg[1] == '!' ) return Plugin_Handled;
	
	return Plugin_Continue;
#endif // CHAT
}

// For block zones.
public void Event_TouchBlock( int trigger, int activator )
{
	if ( 1 > activator > MaxClients ) return;
	
	if ( g_bIsClientPractising[activator] ) return;
	
	
	if ( IsClientInGame( activator ) )
	{
		if ( IsSpamming( activator ) )
		{
			PRINTCHAT( activator, activator, CHAT_PREFIX ... "You are not allowed to go there!" );
		}
		
		TeleportPlayerToStart( activator );
	}
}

#if defined ANTI_DOUBLESTEP
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
#endif