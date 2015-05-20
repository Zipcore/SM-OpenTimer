public Action OnPlayerRunCmd(
	int client,
	int &buttons,
	int &impulse, // Not used
	float vel[3],
	float angles[3]/*,
	int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, // Not used
	int mouse[2]*/ )
{
	if ( !IsPlayerAlive( client ) ) return Plugin_Continue;
	
	
	// Shared between recording and mimicing.
#if defined RECORD
	static int		iFrame[FRAME_SIZE];
	static float	vecPos[3];
#endif
	
	if ( !IsFakeClient( client ) )
	{
		if ( g_bAntiCheat_StrafeVel )
		{
			// Anti-cheat
			// Check if player has a strafe-hack that modifies the velocity and don't actually press the keys for them.
			// 0 = forwardspeed
			// 1 = sidespeed
			// 2 = upspeed
			if ( 	vel[0] != 0.0 && !( buttons & IN_FORWARD || buttons & IN_BACK ) ||
					vel[1] != 0.0 && !( buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT ) )
			{
				if ( g_iClientState[client] == STATE_RUNNING )
				{
					TeleportPlayerToStart( client );
				}
				
				if ( !IsSpamming( client ) )
				{
					PRINTCHAT( client, client, CHAT_PREFIX ... "Potential cheat detected!" );
					PrintToServer( CONSOLE_PREFIX ... "Potential cheat detected (%N)!", client );
				}
				
				return Plugin_Handled;
			}
		}
		
		static int fFlags;
		fFlags = GetEntProp( client, Prop_Data, "m_fFlags" );
		
		// MODES
		switch ( g_iClientStyle[client] )
		{
			case STYLE_SIDEWAYS :
			{
				if ( buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT )
					CheckFreestyle( client );
			}
			case STYLE_W :
			{
				if ( buttons & IN_BACK || buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT )
					CheckFreestyle( client );
			}
			case STYLE_REAL_HSW :
			{
				// Somehow I feel like I'm making this horribly complicated when in reality it's simple.
				
				// Not holding all keys.
				if ( !( buttons & IN_BACK && buttons & IN_FORWARD && buttons & IN_MOVELEFT && buttons & IN_MOVERIGHT ) )
				{
					// Let players fail.
					if ( buttons & IN_BACK && !( buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT ) )
						CheckStyleFails( client );
					else if ( buttons & IN_FORWARD && !( buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT ) )
						CheckStyleFails( client );
					else if ( buttons & IN_MOVELEFT && !( buttons & IN_FORWARD || buttons & IN_BACK ) )
						CheckStyleFails( client );
					else if ( buttons & IN_MOVERIGHT && !( buttons & IN_FORWARD || buttons & IN_BACK ) )
						CheckStyleFails( client );
					// Holding opposite keys.
					else if ( buttons & IN_BACK && buttons & IN_FORWARD )
						CheckStyleFails( client );
					else if ( buttons & IN_MOVELEFT && buttons & IN_MOVERIGHT )
						CheckStyleFails( client );
					// Reset fails if nothing else happened.
					else if ( g_nClientStyleFail[client] > 0 )
						g_nClientStyleFail[client]--;
				}
			}
			case STYLE_HSW :
			{
				if ( buttons & IN_BACK )
					CheckFreestyle( client );
				else if ( !( buttons & IN_FORWARD ) && ( buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT ) )
					CheckFreestyle( client );
				// Let players fail.
				else if ( buttons & IN_FORWARD && !( buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT ) )
					CheckStyleFails( client );
				// Reset fails if nothing else happened.
				else if ( g_nClientStyleFail[client] > 0 )
					g_nClientStyleFail[client]--;
			}
			case STYLE_VEL :
			{
				if ( fFlags & FL_ONGROUND )
				{
					static float vecVel[3];
					GetEntPropVector( client, Prop_Data, "m_vecVelocity", vecVel );
					
					static float flSpd;
					flSpd = vecVel[0] * vecVel[0] + vecVel[1] * vecVel[1];
					
					if ( flSpd > g_flVelCapSquared )
					{
						flSpd = SquareRoot( flSpd ) / g_flVelCap;
						
						vecVel[0] /= flSpd;
						vecVel[1] /= flSpd;
						
						TeleportEntity( client, NULL_VECTOR, NULL_VECTOR, vecVel );
					}
				}
			}
			case STYLE_A_D :
			{
				if ( buttons & IN_FORWARD || buttons & IN_BACK )
					CheckFreestyle( client );
				// Determine which button player wants to hold.
				else if ( !g_iClientPrefButton[client] )
				{
					if ( buttons & IN_MOVELEFT ) g_iClientPrefButton[client] = IN_MOVELEFT;
					else if ( buttons & IN_MOVERIGHT ) g_iClientPrefButton[client] = IN_MOVERIGHT;
				}
				// Else, check if they are holding the opposite key!
				else if ( g_iClientPrefButton[client] == IN_MOVELEFT && buttons & IN_MOVERIGHT )
					CheckFreestyle( client );
				else if ( g_iClientPrefButton[client] == IN_MOVERIGHT && buttons & IN_MOVELEFT )
					CheckFreestyle( client );
			}
		}
		
		if ( !g_bAllowLeftRight && ( buttons & IN_LEFT || buttons & IN_RIGHT ) )
		{
			if ( g_iClientState[client] == STATE_RUNNING )
			{
				TeleportPlayerToStart( client );
			}
			
			if ( !IsSpamming( client ) )
			{
				PRINTCHAT( client, client, CHAT_PREFIX ... "\x03+left"...CLR_TEXT..." and \x03+right"...CLR_TEXT..." are not allowed!" );
			}
			
			
			return Plugin_Handled;
		}
		
		
		// Reset field of view in case they reloaded their gun.
		if ( buttons & IN_RELOAD )
		{
			SetClientFOV( client, g_iClientFOV[client] );
		}
		
		/////////////
		// AUTOHOP //
		/////////////
		if ( g_bAutoHop /*&& g_bClientAutoHop[client]*/ ) // Server setting && Client setting
		{
			static int iOldButtons;
			iOldButtons = GetEntProp( client, Prop_Data, "m_nOldButtons" );
			
			iOldButtons &= ~IN_JUMP;
			
			SetEntProp( client, Prop_Data, "m_nOldButtons", iOldButtons );
			
#if defined ANTI_DOUBLESTEP
			// Anti-doublestepping
			if ( g_bClientHoldingJump[client] && fFlags & FL_ONGROUND ) buttons |= IN_JUMP;
#endif
		}
		
		// Rest what we do is done in running only.
		if ( g_iClientState[client] != STATE_RUNNING ) return Plugin_Continue;
		
		
		///////////////
		// RECORDING //
		///////////////
#if defined RECORD
		if ( g_bClientRecording[client] && g_hClientRecording[client] != null )
		{
			// Remove distracting buttons.
			iFrame[FRAME_FLAGS] = ( buttons & IN_DUCK ) ? FRAMEFLAG_CROUCH : 0;
			
			ArrayCopy( angles, iFrame[FRAME_ANGLES], 2 );
			
			GetEntPropVector( client, Prop_Data, "m_vecOrigin", vecPos );
			ArrayCopy( vecPos, iFrame[FRAME_POS], 3 );
			
			
			// This is only required to check if player's recording is too long.
			g_nClientTick[client]++;
			
			PushArrayArray( g_hClientRecording[client], iFrame, view_as<int>FrameInfo );
		}
#endif
		
		// Don't calc sync and strafes for W-Only.
		if ( g_iClientStyle[client] == STYLE_W ) return Plugin_Continue;
		
		
		static float flClientPrevYaw[MAXPLAYERS_BHOP];
		
		// We don't want ladders or water counted as jumpable space.
		if ( GetEntityMoveType( client ) != MOVETYPE_WALK || GetEntProp( client, Prop_Data, "m_nWaterLevel" ) > 1 )
		{
			flClientPrevYaw[client] = angles[1];
			return Plugin_Continue;
		}
		
		
		static float flClientLastVel[MAXPLAYERS_BHOP];
		
		if ( fFlags & FL_ONGROUND && !( buttons & IN_JUMP ) )
		{
			// If we're on the ground and not jumping, we reset our last speed.
			flClientLastVel[client] = 0.0;
			flClientPrevYaw[client] = angles[1];
			
			return Plugin_Continue;
		}
		
		
		///////////////////////////
		// SYNC AND STRAFE COUNT //
		///////////////////////////
		// The reason why we don't just use mouse[0] to determine whether our player is strafing is because it isn't reliable.
		// If a player is using a strafe hack, the variable doesn't change.
		// If a player is using a controller, the variable doesn't change. (unless using no acceleration)
		// If a player has a controller plugged in and uses mouse instead, the variable doesn't change.
		static int iClientLastStrafe[MAXPLAYERS_BHOP] = { STRAFE_INVALID, ... };
		
		// Not on ground, moving mouse and we're pressing at least some key.
		if ( angles[1] != flClientPrevYaw[client] && ( buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT || buttons & IN_FORWARD || buttons & IN_BACK ) )
		{
			static int iClientSync[MAXPLAYERS_BHOP][NUM_STRAFES];
			static int iClientSync_Max[MAXPLAYERS_BHOP][NUM_STRAFES];
			
			// Thing to remember: angle is a number between 180 and -180.
			// So we give 20 degree cap where this can be registered as strafing to the left.
			int iCurStrafe = (
				!( flClientPrevYaw[client] < -170.0 && angles[1] > 170.0 ) // Make sure we didn't do -180 -> 180 because that would mean left when it's actually right.
				&& ( angles[1] > flClientPrevYaw[client] // Is our current yaw bigger than last time? Strafing to the left.
				|| ( flClientPrevYaw[client] > 170.0 && angles[1] < -170.0 ) ) ) // If that didn't pass, there might be a chance of 180 -> -180.
				? STRAFE_LEFT : STRAFE_RIGHT;
			
			
			if ( iCurStrafe != iClientLastStrafe[client] )
			// Start of a new strafe.
			{
				// Calc previous strafe's sync. This will then be shown to the player.
				if ( iClientLastStrafe[client] != STRAFE_INVALID )
				{
					g_flClientSync[client][ iClientLastStrafe[client] ] = ( g_flClientSync[client][ iClientLastStrafe[client] ] + iClientSync[client][ iClientLastStrafe[client] ] / float( iClientSync_Max[client][ iClientLastStrafe[client] ] ) ) / 2;
				}
				
				// Reset the new strafe's variables.
				iClientSync[client][iCurStrafe] = 1;
				iClientSync_Max[client][iCurStrafe] = 1;
				
				iClientLastStrafe[client] = iCurStrafe;
				g_nClientStrafeCount[client]++;
			}
			
			
			float flCurVel = GetClientSpeed( client );
			
			// We're moving our mouse, but are we gaining speed?
			if ( flCurVel > flClientLastVel[client] ) iClientSync[client][iCurStrafe]++;
			iClientSync_Max[client][iCurStrafe]++;
			
			
			flClientLastVel[client] = flCurVel;
		}
		
		flClientPrevYaw[client] = angles[1];

		return Plugin_Continue;
	}
	
	//////////////
	// PLAYBACK //
	//////////////
#if defined RECORD
	if ( !g_bPlayback ) return Plugin_Handled;
	
	
	if ( g_bClientMimicing[client] )
	{
		GetArrayArray( g_hRec[ g_iClientRun[client] ][ g_iClientStyle[client] ], g_nClientTick[client], iFrame, view_as<int>FrameInfo );
		
		// Do buttons.
		buttons = ( iFrame[FRAME_FLAGS] & FRAMEFLAG_CROUCH ) ? IN_DUCK : 0;
		
		vel = g_vecNull;
		ArrayCopy( iFrame[FRAME_ANGLES], angles, 2 );
		
		
		ArrayCopy( iFrame[FRAME_POS], vecPos, 3 );
		
		static float vecPrevPos[3];
		GetEntPropVector( client, Prop_Data, "m_vecOrigin", vecPrevPos );
		
		if ( GetVectorDistance( vecPrevPos, vecPos, false ) > 16384.0 )
		// Around the same distance as you can travel with 3500 speed in 1 tick. (128)
		{
			TeleportEntity( client, vecPos, angles, NULL_VECTOR );
		}
		else
		{
			// Make the velocity!
			static float vecDirVel[3];
			vecDirVel[0] = vecPos[0] - vecPrevPos[0];
			vecDirVel[1] = vecPos[1] - vecPrevPos[1];
			vecDirVel[2] = vecPos[2] - vecPrevPos[2];
			
			ScaleVector( vecDirVel, 100.0 ); // Based on tickrate (?)
			
			TeleportEntity( client, NULL_VECTOR, angles, vecDirVel );
			
			// If server ops want more responsive but choppy movement, here it is.
			if ( !g_bSmoothPlayback )
				SetEntPropVector( client, Prop_Send, "m_vecOrigin", vecPos );
		}
		
		
		g_nClientTick[client]++;
		
		// Are we done with our recording?
		if ( g_nClientTick[client] >= g_iRecTickMax[ g_iClientRun[client] ][ g_iClientStyle[client] ] )
		{
			g_bClientMimicing[client] = false;
			
			CreateTimer( 2.0, Timer_Rec_Restart, client, TIMER_FLAG_NO_MAPCHANGE );
		}
		
		return Plugin_Changed;
	}
	
	
	if ( g_nClientTick[client] == TICK_PRE_PLAYBLACK )
	{
		// Means that we are at the start of the run, about to begin our recorded run.
		ArrayCopy( g_vecInitRecAng[ g_iClientRun[client] ][ g_iClientStyle[client] ], angles, 2 );
		vel = g_vecNull;
		
		// Purpose of this is to stop the bot from crouching and then suddenly uncrouching at the start of the run.
		// Not quite sure if it works.
		SetEntProp( client, Prop_Data, "m_nButtons", 0 );
		buttons = 0;
		
		TeleportEntity( client, g_vecInitRecPos[ g_iClientRun[client] ][ g_iClientStyle[client] ], g_vecInitRecAng[ g_iClientRun[client] ][ g_iClientStyle[client] ], g_vecNull );
		
		return Plugin_Changed;
	}
#endif
	
	// Freezes bots when they don't need to do anything. I.e. at the end of the run.
	return Plugin_Handled;
}