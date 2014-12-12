// Doesn't work?
// Hide other players
public Action:Event_ClientTransmit( ent, client )
	return ( client != ent && ent > 0 && ent <= MaxClients ) ? Plugin_Handled : Plugin_Continue;

// Doesn't work.
// Hide player name changes.
/*public Action:Event_ClientName( Handle:event, const String:name[], bool:dontBroadcast )
{
	dontBroadcast = true;
	SetEventBroadcast( event, true );
	
	return Plugin_Handled;
}*/

// Set client ready for the map. Collision groups, bots, transparency, etc.
public Event_ClientSpawn( Handle:event, const String:name[], bool:dontBroadcast )
{
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	
	if ( client < 1 ) return;
	
	if ( IsPlayerAlive( client ) && GetClientTeam( client ) > 1 )
	{
		if ( bIsLoaded[RUN_MAIN] ) TeleportEntity( client, vecSpawnPos[RUN_MAIN], angSpawnAngles[RUN_MAIN], vecNull );
		
		if ( !IsFakeClient( client ) )
		{
			SetEntProp( client, Prop_Data, "m_CollisionGroup", 2 ); // Disable player collisions.
			
			SetEntityRenderMode( client, RENDER_TRANSALPHA );
		}
		else
		{
#if defined RECORD
			// Hide those silly bots that do not have a record :^)
			if ( iMimicTickMax[ iClientMode[client] ] == 0 )
				SetEntityRenderMode( client, RENDER_NONE );
			else
				SetEntityRenderMode( client, RENDER_TRANSALPHA );
#endif
			SetEntProp( client, Prop_Data, "m_CollisionGroup", 1 ); // No trigger collision for bots.
		}
		
		CreateTimer( 0.1, Timer_ClientSpawn, client );
		
		
		SetEntityRenderColor( client, _, _, _, 92 );
	}
}

// Continued from above event.
public Action:Timer_ClientSpawn( Handle:timer, any:client )
{
	if ( !IsClientInGame( client ) ) return Plugin_Handled;
	
	SetEntProp( client, Prop_Data, "m_nHitboxSet", 2 );
	
	if ( IsFakeClient( client ) )
	{
#if defined RECORD
		SetEntityGravity( client, 0.0 );
		
		// Also, hide their guns so they are not just floating around
		new wep;
		for ( new i; i < 4; i++ )
			if ( ( wep = GetPlayerWeaponSlot( client, i ) ) > 0 )
				SetEntityRenderMode( wep, RENDER_NONE );
#endif

		return Plugin_Handled;
	}
	
	SetClientFOV( client, iClientFOV[client], false );
	
	// Hides deathnotices, health and weapon. Radar and crosshair stuff can be disabled client side. Disabling those won't allow you to switch between weapons.
	if ( iClientHideFlags[client] & HIDEHUD_HUD ) SetEntProp( client, Prop_Data, "m_iHideHUD", HIDE_FLAGS );
	if ( iClientHideFlags[client] & HIDEHUD_VM ) SetEntProp( client, Prop_Data, "m_bDrawViewmodel", 0 );
	
	return Plugin_Handled;
}
////////////
// EZHOP //
////////////
public Event_ClientJump( Handle:event, const String:name[], bool:dontBroadcast )
{
	if ( !bAutoHop ) return;
	
	SetEntPropFloat( GetClientOfUserId( GetEventInt( event, "userid" ) ), Prop_Send, "m_flStamina", 0.0 );
}

public Event_ClientHurt( Handle:event, const String:name[], bool:dontBroadcast )
{
	if ( !bAutoHop ) return;
	
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	
	SetEntPropFloat( client, Prop_Send, "m_flVelocityModifier", 1.0 );
	SetEntProp( client, Prop_Data, "m_iHealth", 100 );
}

public Event_ClientDeath( Handle:event, const String:name[], bool:dontBroadcast )
{
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	
	PrintColorChat( client, client, "%s Type !respawn to spawn again.", CHAT_PREFIX );
}
//////////
// CHAT //
//////////
#if defined CHAT
public Action:Listener_Say( client, const String:command[], argc )
{
	if ( client == 0 ) return Plugin_Continue; // No team messages
	
	if ( IsClientInGame( client ) )
	{
		decl String:Arg[130]; // MAX MESSAGE LENGTH ( SayText ) + QUOTES
		GetCmdArgString( Arg, sizeof( Arg ) );
		
		if ( Arg[1] == '@' || Arg[1] == '/' || Arg[1] == '!' ) return Plugin_Handled;
		
		StripQuotes( Arg );
		
#if defined VOTING
		if ( StrEqual( Arg, "rtv" ) || StrEqual( Arg, "rockthevote" ) || StrEqual( Arg, "nominate" ) || StrEqual( Arg, "choosemap" ) )
		{
			ClientCommand( client, "sm_choosemap" );
			return Plugin_Handled;
		}
#endif
		
		if ( !IsPlayerAlive( client ) ) PrintColorChatAll( client, true, "%s[%sSPEC%s] \x03%N\x01: %s%s", COLOR_TEXT, COLOR_PURPLE, COLOR_TEXT, client, COLOR_TEXT, Arg );
		else PrintColorChatAll( client, true, "\x03%N\x01: %s%s", client, COLOR_TEXT, Arg );
		
		PrintToServer( "%N: %s", client, Arg );
		
		for ( new i = 1; i <= MaxClients; i++ )
			if ( IsClientInGame( i ) ) PrintToConsole( i, "%N: %s", client, Arg );
	}
	
	return Plugin_Handled;
}
#endif
//////////////////////////////////////
// AUTOBHOP, MODES, SYNC, RECORDING //
//////////////////////////////////////

#if defined RECORD
static bool:bClientTeleported[MAXPLAYERS_BHOP];

public Event_Teleport( const String:output[], caller, activator, Float:delay )
{
	// This is a really bad way to do this, lol.
	// Have to update to use DHOOKS.
	if ( activator < 1 || activator > MaxClients ) return;
	
	if ( bIsClientRecording[activator] )
		bClientTeleported[activator] = true;
}
#endif

static iClientSync[MAXPLAYERS_BHOP];
static Float:flClientLastVel[MAXPLAYERS_BHOP];

public Action:OnPlayerRunCmd( client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2] )
{
	if ( !IsPlayerAlive( client ) ) return Plugin_Continue;
	
	new bool:bIsBot = true;
	if ( !IsFakeClient( client ) )
	{
		bIsBot = false;
		// MODES AND "ANTI-CHEAT"
		if ( iClientMode[client] == MODE_SIDEWAYS )
		{
			if ( buttons & IN_MOVELEFT ) CheckFreestyle( client );
			else if ( buttons & IN_MOVERIGHT ) CheckFreestyle( client );
		}
		else if ( iClientMode[client] == MODE_W )
			if ( buttons & IN_BACK ) CheckFreestyle( client );
			else if ( buttons & IN_MOVELEFT ) CheckFreestyle( client );
			else if ( buttons & IN_MOVERIGHT ) CheckFreestyle( client );
		
		if ( buttons & IN_RELOAD )
		{
			SetEntProp( client, Prop_Data, "m_iFOV", iClientFOV[client] );
			SetEntProp( client, Prop_Data, "m_iDefaultFOV", iClientFOV[client] );
		}
		
		if ( !bForbiddenCommands )
		{
			if ( buttons & IN_LEFT ) ForcePlayerSuicide( client );
			if ( buttons & IN_RIGHT ) ForcePlayerSuicide( client );
		}
		
		// SYNC AND AUTOHOP
		// We don't want ladders or water counted as jumpable space.
		if ( iClientState[client] == STATE_RUNNING && GetEntityMoveType( client ) != MOVETYPE_LADDER && GetEntProp( client, Prop_Data, "m_nWaterLevel" ) < 2 )
		{
			if ( bAutoHop && bClientAutoHop[client] ) // Server setting && Client setting
			{
				new oldbuttons = GetEntProp( client, Prop_Data, "m_nOldButtons" );
				oldbuttons &= ~IN_JUMP;
				
				SetEntProp( client, Prop_Data, "m_nOldButtons", oldbuttons );
			}
			
			new flags = GetEntityFlags( client );
			
			if ( buttons & IN_JUMP && flags & FL_ONGROUND )
				iClientJumpCount[client]++;
			
			if ( !( flags & FL_ONGROUND ) )
			{
				if ( iClientLastStrafe[client] != STRAFE_LEFT && buttons & IN_MOVELEFT && !( buttons & IN_MOVERIGHT ) && mouse[0] < 0 )
				{
					// Player is in 'perfect' left strafe.
					iClientLastStrafe[client] = STRAFE_LEFT;
					iClientStrafeCount[client]++;
				}
				else if ( iClientLastStrafe[client] != STRAFE_RIGHT && buttons & IN_MOVERIGHT && !( buttons & IN_MOVELEFT ) && mouse[0] > 0 )
				{
					// Player is in 'perfect' right strafe.
					iClientLastStrafe[client] = STRAFE_RIGHT;
					iClientStrafeCount[client]++;
				}
				/*else if ( iClientLastStrafe[client] != STRAFE_RIGHT && mouse[0] > 0 && ( buttons & IN_MOVELEFT || !( buttons & IN_MOVERIGHT ) ) )
				{
					// Mouse going right but we're not holding right strafe key!
					iClientGoodSync[client][ iClientSync[client] ] = 0;
					iClientSync[client]++;
				}
				else if ( iClientLastStrafe[client] != STRAFE_LEFT && mouse[0] < 0 && ( buttons & IN_MOVERIGHT || !( buttons & IN_MOVELEFT ) ) )
				{
					// Mouse going left but we're not holding left strafe key!
					iClientGoodSync[client][ iClientSync[client] ] = 0;
					iClientSync[client]++;
				}*/
				
				if ( ( buttons & IN_MOVERIGHT || buttons & IN_MOVELEFT ) && mouse[0] != 0 )
				{
					new Float:flCurVel = GetClientVelocity( client );
					
					if ( flClientLastVel[client] < flCurVel )
						iClientGoodSync[client][ iClientSync[client] ] = 1;
					else
						iClientGoodSync[client][ iClientSync[client] ] = 0;
					
					iClientSync[client]++;
					
					flClientLastVel[client] = flCurVel;
					
					if ( iClientSync[client] >= SYNC_MAX_SAMPLES )
						iClientSync[client] = 0;
				}
			}
			else if ( !( buttons & IN_JUMP ) )
				flClientLastVel[client] = 0.0;
		}
	}
	
	// RECORDING
#if defined RECORD
	if ( hClientRecording[client] != INVALID_HANDLE && bIsClientRecording[client] && iClientState[client] == STATE_RUNNING )
	{
		new iFrame[FRAME_SIZE];
		
		// Remove distracting buttons.
		// Seriously, we don't even need them...
		// This also prevents the bot from constantly duckjumping.
		if ( buttons & IN_DUCK ) iFrame[FRAME_BUTTONS] = IN_DUCK;
		
		ArrayCopy( angles, iFrame[FRAME_ANGLES], 2 );
		ArrayCopy( vel, iFrame[FRAME_VELOCITY], 3 );
		
		decl Float:vecAbsVelocity[3];
		GetEntPropVector( client, Prop_Data, "m_vecAbsVelocity", vecAbsVelocity );
		iFrame[FRAME_ABSVELOCITY] = vecAbsVelocity;
		
		if ( iClientTick[client] % SNAPSHOT_INTERVAL == 0 || iClientTick[client] == 0 || bClientTeleported[client] )
		{
			decl Float:vecPos[3];
			GetClientAbsOrigin( client, vecPos );
			ArrayCopy( vecPos, iFrame[FRAME_POS], 3 );
			
			bClientTeleported[client] = false;
			iFrame[FRAME_DOTELE] = true;
		}
		
		iClientTick[client]++;
		
		PushArrayArray( hClientRecording[client], iFrame, _:FrameInfo );
	}
	else if ( bIsClientMimicing[client] )
	{
		new iFrame[FRAME_SIZE];
		GetArrayArray( hMimicRecording[ iClientMode[client] ], iClientTick[client], iFrame, _:FrameInfo );
		
		buttons = iFrame[FRAME_BUTTONS];
		
		ArrayCopy( iFrame[FRAME_ANGLES], angles, 2 );
		ArrayCopy( iFrame[FRAME_VELOCITY], vel, 3 );
		
		decl Float:vecAbsVelocity[3];
		ArrayCopy( iFrame[FRAME_ABSVELOCITY], vecAbsVelocity, 3 );
		
		if ( iFrame[FRAME_DOTELE] )
		{
			decl Float:vecPos[3];
			ArrayCopy( iFrame[FRAME_POS], vecPos, 3 );
			
			// Using this is very inconsistent.
			// Again, using DHOOKS for actual teleporting and this for snapshots should make it look a lot better.
			SetEntPropVector( client, Prop_Send, "m_vecOrigin", vecPos );
		}
		
		TeleportEntity( client, NULL_VECTOR, angles, vecAbsVelocity );
		
		iClientTick[client]++;
		
		if ( iClientTick[client] >= iMimicTickMax[ iClientMode[client] ] )
		{
			bIsClientMimicing[client] = false;
			
			CreateTimer( 2.0, Timer_Rec_Restart, client );
			
			return Plugin_Handled;
		}
		
		return Plugin_Changed;
	}
	else if ( iClientTick[client] < 0 )
	{
		// -1 means that we are at the start of the run, about to begin our recorded run.
		// Kinda hacky, but works.
		ArrayCopy( angInitMimicAngles[ iClientMode[client] ], angles, 2 );
		vel = vecNull;
		
		TeleportEntity( client, vecInitMimicPos[ iClientMode[client] ], angInitMimicAngles[ iClientMode[client] ], vecNull );
		
		return Plugin_Changed;
	}
#endif
	
	// Freezes bots when they don't need to do anything.
	return bIsBot ? Plugin_Handled : Plugin_Continue;
}