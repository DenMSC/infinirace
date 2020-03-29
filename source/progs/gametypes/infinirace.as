/*
Copyright (C) 2009-2010 Chasseur de bots

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*/

const int IR_ROUNDSTATE_NONE = 0;
const int IR_ROUNDSTATE_PREROUND = 1;
const int IR_ROUNDSTATE_ROUND = 2;
const int IR_ROUNDSTATE_ROUNDFINISHED = 3;
const int IR_ROUNDSTATE_POSTROUND = 4;

Cvar autoskip ( "g_autoskip", "5", CVAR_ARCHIVE );

/// A variable for time correction
int hh;

/// This variable prevents bugs when the game autoskips a level during normal game
int lock;

String voted_seed = "";

IR_Round infini_round;

class IR_Round
{
  int state;
  uint roundStateStartTime;
  uint roundStateEndTime;
  int countDown;

  bool finishReached;

  IR_Round()
  {
    this.state = IR_ROUNDSTATE_NONE;
    this.roundStateStartTime = 0;
    this.countDown = 0;
    this.finishReached = false;
  }
  ~IR_Round()
  {}

  void NewGame()
  {
    gametype.readyAnnouncementEnabled = false;
    gametype.scoreAnnouncementEnabled = true;
    gametype.countdownEnabled = false;

    this.NewRound();
  }

  void EndGame()
  {
    this.NewRoundState( IR_ROUNDSTATE_NONE );

    GENERIC_SetUpEndMatch();
  }

  void NewRound()
  {
    G_RemoveDeadBodies();
    G_RemoveAllProjectiles();

    this.NewRoundState( IR_ROUNDSTATE_PREROUND );
  }

  void Finish( Client@ client )
  {
    if ( this.finishReached )
      return;

    G_PrintMsg(null, client.name + " ^3finished first!\n");
    int soundIndex = G_SoundIndex("sounds/announcer/ctf/score0" + (1 + (rand()&1)) );
    G_AnnouncerSound(client, soundIndex, GS_MAX_TEAMS, false, null );
    G_CenterPrintMsg(null, client.name + " ^3finished first!\n");
    this.finishReached = true;

    if ( match.getState() == MATCH_STATE_WARMUP )
    {
      this.ResetMap();
      int ( hh = 0 );
      return;
    }

    if ( this.state != IR_ROUNDSTATE_ROUND )
      return;

    client.stats.addScore(1);

    this.NewRoundState( IR_ROUNDSTATE_POSTROUND );
  }

  void ResetMap(bool freeze = false)
  {
    Restart();

    Entity@ ent;
    Team@ team;

    for ( int i = TEAM_PLAYERS; i < GS_MAX_TEAMS; i++ )
    {
      @team = @G_GetTeam( i );
      for ( int j = 0; @team.ent(j) != null; j++ )
      {
        @ent = @team.ent(j);
        ent.client.respawn(false);
        if ( freeze )
        {
          ent.client.pmoveMaxSpeed = 0;
          ent.client.pmoveDashSpeed = 0;
          ent.client.pmoveFeatures = ent.client.pmoveFeatures & ~( PMFEAT_WALK | PMFEAT_JUMP | PMFEAT_DASH | PMFEAT_WALLJUMP );
        }
      }
    }
    this.finishReached = false;
    int ( hh = 0 );
  }

  void NewRoundState( int newState )
  {
    if ( newState > IR_ROUNDSTATE_POSTROUND )
    {
      this.NewRound();
      return;
    }
    this.state = newState;
    this.roundStateStartTime = levelTime;

    switch ( this.state )
    {
      case IR_ROUNDSTATE_NONE:
        this.roundStateEndTime = 0;
        this.countDown = 0;
        break;
      case IR_ROUNDSTATE_PREROUND:
        {
		  // A variable used to prevent autoskip from getting stuck
		  // It's reset to 0 here after the new map generates during the match
		  lock = 0;
          this.roundStateEndTime = levelTime + 5000;
          this.countDown = 4;

          gametype.shootingDisabled = true;
          gametype.removeInactivePlayers = false;

          this.ResetMap(true);
        }
        break;
      case IR_ROUNDSTATE_ROUND:
        {
          gametype.shootingDisabled = false;
          gametype.removeInactivePlayers = true;
          this.countDown = 0;
          this.roundStateEndTime = 0;
          int soundIndex = G_SoundIndex("sounds/announcer/countdown/go0" + (1 + (rand()&1)) );
          G_AnnouncerSound(null, soundIndex, GS_MAX_TEAMS, false, null );
          G_CenterPrintMsg(null, "Go!");

          Entity@ ent;
          Team@ team;

          for ( int i = TEAM_PLAYERS; i < GS_MAX_TEAMS; i++ )
          {
            @team = @G_GetTeam( i );
            for ( int j = 0; @team.ent(j) != null; j++ )
            {
              @ent = @team.ent(j);
              ent.client.pmoveMaxSpeed = -1;
              ent.client.pmoveDashSpeed = -1;
              ent.client.pmoveFeatures = ent.client.pmoveFeatures | ( PMFEAT_WALK | PMFEAT_JUMP | PMFEAT_DASH | PMFEAT_WALLJUMP );
            }
          }
        }
        break;
      case IR_ROUNDSTATE_ROUNDFINISHED:
        gametype.shootingDisabled = true;
        this.roundStateEndTime = levelTime + 0;
        this.countDown = 0;
        break;
      case IR_ROUNDSTATE_POSTROUND:
        this.roundStateEndTime = levelTime + 1500;
        //stuff cba
        break;
      default:
        break;
    }
  }

  void Think()
  {
    if ( this.state == IR_ROUNDSTATE_NONE )
      return;

    if ( match.getState() != MATCH_STATE_PLAYTIME )
    {
      this.EndGame();
      return;
    }

    if ( this.roundStateEndTime != 0 )
    {
      if ( this.roundStateEndTime < levelTime )
      {
        this.NewRoundState( this.state + 1 );
        return;
      }

      if ( this.countDown > 0 )
      {
        // we can't use the authomatic countdown announces because their are based on the
        // matchstate timelimit, and prerounds don't use it. So, fire the announces "by hand".
        int remainingSeconds = int( ( this.roundStateEndTime - levelTime ) * 0.001f ) + 1;
        if ( remainingSeconds < 0 )
            remainingSeconds = 0;

        if ( remainingSeconds < this.countDown )
        {
          this.countDown = remainingSeconds;

          if ( this.countDown <= 3 )
          {
            int soundIndex = G_SoundIndex( "sounds/announcer/countdown/" + this.countDown + "_0" + (1 + (rand() & 1)) );
            G_AnnouncerSound( null, soundIndex, GS_MAX_TEAMS, false, null );
          }
          G_CenterPrintMsg( null, String( this.countDown ) );
        }
      }
    }

    if ( this.state == IR_ROUNDSTATE_ROUND )
    {
      // dno
    }
  }
}

///*****************************************************************
/// MODULE SCRIPT CALLS
///*****************************************************************


bool GT_Command( Client @client, const String &cmdString, const String &argsString, int argc )
{
    if ( cmdString == "gametype" )
    {
        String response = "";
        Cvar fs_game( "fs_game", "", 0 );
        String manifest = gametype.manifest;

        response += "\n";
        response += "Gametype " + gametype.name + " : " + gametype.title + "\n";
        response += "----------------\n";
        response += "Version: " + gametype.version + "\n";
        response += "Author: " + gametype.author + "\n";
        response += "Mod: " + fs_game.string + ( !manifest.empty() ? " (manifest: " + manifest + ")" : "" ) + "\n";
        response += "----------------\n";

        G_PrintMsg( client.getEnt(), response );
        return true;
    }
    else if ( cmdString == "cvarinfo" )
    {
        GENERIC_CheatVarResponse( client, cmdString, argsString, argc );
        return true;
    }
    else if ( cmdString == "callvotevalidate" )
    {
        String votename = argsString.getToken( 0 );

        if ( votename == "seed" )
        {
          String voteArg = argsString.getToken(1);
          if ( voteArg.len() < 1 )
          {
            client.printMessage( "Callvote " + votename + " requires at least one argument\n" );
            return false;
          }
        } else if ( votename == "skip" )
        {
          String voteArg = argsString.getToken(1);
          if ( voteArg.len() < 1 )
          {
            client.printMessage( "Callvote " + votename + " requires at least one argument\n" );
            return false;
          }
        }
		else if ( votename == "autoskip" )
		{
          String voteArg = argsString.getToken(1);
          if ( voteArg.len() < 1 || voteArg < 0 || voteArg > 30 )
          {
            client.printMessage( "Callvote " + votename + " requires at least one argument in range 0-30\n" );
            return false;
          }
		}
        else
        {
            client.printMessage( "Unknown callvote " + votename + "\n" );
            return false;
        }

        return true;
    }
    else if ( cmdString == "callvotepassed" )
    {
        String votename = argsString.getToken( 0 );

        if ( votename == "seed" )
        {
          String voteArg = argsString.getToken(1);

          voted_seed = voteArg;
          if ( match.getState() == MATCH_STATE_PLAYTIME )
          {
            infini_round.NewRoundState(IR_ROUNDSTATE_POSTROUND);
          } else if ( match.getState() == MATCH_STATE_WARMUP )
          {
            infini_round.ResetMap();
          }
        }

        if ( votename == "skip" )
        {
          String voteArg = argsString.getToken(1);

          if ( match.getState() == MATCH_STATE_PLAYTIME )
          {
            infini_round.NewRoundState(IR_ROUNDSTATE_POSTROUND);
          } else if ( match.getState() == MATCH_STATE_WARMUP )
          {
            infini_round.ResetMap();
          }
        }
		if ( votename == "autoskip" )
		{
		int arg = argsString.getToken( 1 );
		autoskip.set( arg );
		}

        return true;
    }
    else if ( ( cmdString == "racerestart" ) || ( cmdString == "kill" ) )
    {
      if ( match.getState() == MATCH_STATE_PLAYTIME )
      {
        if ( infini_round.state != IR_ROUNDSTATE_ROUND )
          return true;
      }


      if ( @client != null )
      {
          if ( client.team == TEAM_SPECTATOR && !gametype.isTeamBased )
              client.team = TEAM_PLAYERS;
          client.respawn( false );
      }

      return true;
    }
    else if ( ( cmdString == "newmap" )  )
    {
      Restart();
      return true;
    }

    G_PrintMsg( null, "unknown: " + cmdString + "\n" );

    return false;
}

// When this function is called the weights of items have been reset to their default values,
// this means, the weights *are set*, and what this function does is scaling them depending
// on the current bot status.
// Player, and non-item entities don't have any weight set. So they will be ignored by the bot
// unless a weight is assigned here.
bool GT_UpdateBotStatus( Entity @self )
{
    return false; // let the default code handle it itself
}

// select a spawning point for a player
Entity @GT_SelectSpawnPoint( Entity @self )
{
    return GENERIC_SelectBestRandomSpawnPoint( self, "info_player_deathmatch" );
}

String @GT_ScoreboardMessage( uint maxlen )
{
    String scoreboardMessage = "";
    String entry;
    Team @team;
    Entity @ent;
    int i;

    @team = @G_GetTeam( TEAM_PLAYERS );

    // &t = team tab, team tag, team score (doesn't apply), team ping (doesn't apply)
    entry = "&t " + int( TEAM_PLAYERS ) + " " + team.stats.score + " 0 ";
    if ( scoreboardMessage.len() + entry.len() < maxlen )
        scoreboardMessage += entry;

    for ( i = 0; @team.ent( i ) != null; i++ )
    {
        @ent = @team.ent( i );

		int playerID = ( ent.isGhosting() && ( match.getState() == MATCH_STATE_PLAYTIME ) ) ? -( ent.playerNum + 1 ) : ent.playerNum;

        entry = "&p " + playerID + " "
                + ent.client.clanName + " "
                + ent.client.stats.score + " "
                + ent.client.ping + " "
                + ( ent.client.isReady() ? "1" : "0" ) + " ";

        if ( scoreboardMessage.len() + entry.len() < maxlen )
            scoreboardMessage += entry;
    }

    return scoreboardMessage;
}

// Some game actions trigger score events. These are events not related to killing
// oponents, like capturing a flag
// Warning: client can be null
void GT_ScoreEvent( Client @client, const String &score_event, const String &args )
{
    if ( score_event == "dmg" )
    {
    }
    else if ( score_event == "kill" )
    {
        Entity @attacker = null;

        if ( @client != null )
            @attacker = client.getEnt();

        int arg1 = args.getToken( 0 ).toInt();
        int arg2 = args.getToken( 1 ).toInt();

        // target, attacker, inflictor
        //RACE_playerKilled( G_GetEntity( arg1 ), attacker, G_GetEntity( arg2 ) );
    }
    else if ( score_event == "award" )
    {
    }
    else if ( score_event == "enterGame" )
    {
    }
    else if ( score_event == "userinfochanged" )
    {
    }
}

// a player is being respawned. This can happen from several ways, as dying, changing team,
// being moved to ghost state, be placed in respawn queue, being spawned from spawn queue, etc
void GT_PlayerRespawn( Entity @ent, int old_team, int new_team )
{
    if ( ent.isGhosting() )
        return;

    // set player movement to pass through other players
    ent.client.pmoveFeatures = ent.client.pmoveFeatures | PMFEAT_GHOSTMOVE;

    if ( gametype.isInstagib )
        ent.client.inventoryGiveItem( WEAP_INSTAGUN );
    else
        ent.client.inventorySetCount( WEAP_GUNBLADE, 1 );

    // select rocket launcher if available
    if ( ent.client.canSelectWeapon( WEAP_ROCKETLAUNCHER ) )
        ent.client.selectWeapon( WEAP_ROCKETLAUNCHER );
    else
        ent.client.selectWeapon( -1 ); // auto-select best weapon in the inventory

    // freeze player if preround
    if ( match.getState() == MATCH_STATE_PLAYTIME && infini_round.state < IR_ROUNDSTATE_ROUND )
    {
      ent.client.pmoveMaxSpeed = 0;
      ent.client.pmoveDashSpeed = 0;
      ent.client.pmoveFeatures = ent.client.pmoveFeatures & ~( PMFEAT_WALK | PMFEAT_JUMP | PMFEAT_DASH | PMFEAT_WALLJUMP );
    }

    // add a teleportation effect
    ent.respawnEffect();
    ent.client.setRaceTime(0,1000);
}

// Thinking function. Called each frame
void GT_ThinkRules()
{
    if ( match.scoreLimitHit() || match.timeLimitHit() || match.suddenDeathFinished() )
        match.launchState( match.getState() + 1 );

    if ( match.getState() >= MATCH_STATE_POSTMATCH )
        return;

    GENERIC_Think();

    INFINI_Think();
    infini_round.Think();

    if ( match.getState() == MATCH_STATE_PLAYTIME )
    {
    }

    // set all clients race stats
    Client @client;
	
	/// Keep the timer at 0 if there are no players in-game
	/// It prevents the timer from hitting the 16-bit integer limit
	/// unless someone stays in-game for an extended period of time.
	// Calculates how many players are in-game
    Team @team;
    int[] alive( GS_MAX_TEAMS );
    alive[TEAM_PLAYERS] = 0;
    for ( int t = TEAM_PLAYERS; t < GS_MAX_TEAMS; t++ )
    {
        @team = @G_GetTeam( t );
        for ( int i = 0; @team.ent( i ) != null; i++ )
        {
            if ( !team.ent( i ).isGhosting() )
                alive[t]++;
        }
    }

	// If there are no players in-game, keep the timer at 0
	if ( alive[TEAM_PLAYERS] == 0 )
	{
		int ( hh = levelTime - lastGen );
	}

	/// Skip a map if noone finishes a course in x minutes
	/// A check is done if the game is in warmup or not.
	/// This is to prevent glitches caused by the delay
	/// between map skip and generation during the match.
	// This integer is here to prevent Signed/Unsigned mismatch warning
	int timepassed = levelTime - infini_round.roundStateStartTime;

	if ( match.getState() == MATCH_STATE_PLAYTIME )
	{
		if ( timepassed > autoskip.get_integer() * 60000 && autoskip.get_integer() > 0 && lock == 0)
		{
			infini_round.NewRoundState(IR_ROUNDSTATE_POSTROUND);
			// Lock variable makes sure the code doesn't get stuck in loop
			// before the game actually generates a new map during the match
			lock = 1;
			G_PrintMsg(null, S_COLOR_WHITE + "The maximum map time has expired, skipping map...\n");
		}
	}
	else
	{
		if ( levelTime - hh - lastGen > autoskip.get_integer() * 60000 && autoskip.get_integer() > 0 )
		{
			infini_round.ResetMap();
			G_PrintMsg(null, S_COLOR_WHITE + "The maximum map time has expired, skipping map...\n");
		}
	}
		
    for ( int i = 0; i < maxClients; i++ )
    {
        @client = G_GetClient( i );
        if ( client.state() < CS_SPAWNED )
            continue;

        // disable gunblade autoattack
        client.pmoveFeatures = client.pmoveFeatures & ~PMFEAT_GUNBLADEAUTOATTACK;
        if ( match.getState() == MATCH_STATE_WARMUP )
          client.setHUDStat( STAT_TIME_SELF, ( levelTime - hh - lastGen ) / 100 );
        if ( infini_round.state == IR_ROUNDSTATE_ROUND )
          client.setHUDStat( STAT_TIME_SELF, ( levelTime - infini_round.roundStateStartTime ) / 100 );
    }
}

// The game has detected the end of the match state, but it
// doesn't advance it before calling this function.
// This function must give permission to move into the next
// state by returning true.
bool GT_MatchStateFinished( int incomingMatchState )
{
    if ( match.getState() == MATCH_STATE_POSTMATCH )
    {
        match.stopAutorecord();
    }

    return true;
}

// the match state has just moved into a new state. Here is the
// place to set up the new state rules
void GT_MatchStateStarted()
{

    switch ( match.getState() )
    {
    case MATCH_STATE_WARMUP:
        GENERIC_SetUpWarmup();
		break;

    case MATCH_STATE_COUNTDOWN:
        GENERIC_SetUpCountdown();
        break;

    case MATCH_STATE_PLAYTIME:
        //GENERIC_SetUpMatch();
        infini_round.NewGame();
        break;

    case MATCH_STATE_POSTMATCH:
        //GENERIC_SetUpEndMatch();
        infini_round.EndGame();
        break;

    default:
        break;
    }
}

// the gametype is shutting down cause of a match restart or map change
void GT_Shutdown()
{
}

// The map entities have just been spawned. The level is initialized for
// playing, but nothing has yet started.
void GT_SpawnGametype()
{
  INFINI_Init();
}

// Important: This function is called before any entity is spawned, and
// spawning entities from it is forbidden. If you want to make any entity
// spawning at initialization do it in GT_SpawnGametype, which is called
// right after the map entities spawning.

void GT_InitGametype()
{
    gametype.title = "InfiniRace";
    gametype.version = "1.05";
    gametype.author = "Warsow Development Team";

    // if the gametype doesn't have a config file, create it
    if ( !G_FileExists( "configs/server/gametypes/" + gametype.name + ".cfg" ) )
    {
        String config;

        // the config file doesn't exist or it's empty, create it
        config = "// '" + gametype.title + "' gametype configuration file\n"
                 + "// This config will be executed each time the gametype is started\n"
                 + "\n\n// map rotation\n"
                 + "set g_maplist \"\" // list of maps in automatic rotation\n"
                 + "set g_maprotation \"0\"   // 0 = same map, 1 = in order, 2 = random\n"
                 + "\n// game settings\n"
                 + "set g_scorelimit \"10\"\n"
                 + "set g_timelimit \"0\"\n"
                 + "set g_warmup_timelimit \"0\"\n"
                 + "set g_match_extendedtime \"0\"\n"
                 + "set g_allow_falldamage \"0\"\n"
                 + "set g_allow_selfdamage \"0\"\n"
                 + "set g_allow_teamdamage \"0\"\n"
                 + "set g_allow_stun \"0\"\n"
                 + "set g_teams_maxplayers \"0\"\n"
                 + "set g_teams_allow_uneven \"0\"\n"
                 + "set g_countdown_time \"5\"\n"
                 + "set g_maxtimeouts \"0\" // -1 = unlimited\n"
                 + "set g_challengers_queue \"0\"\n"
                 + "\necho " + gametype.name + ".cfg executed\n";

        G_WriteFile( "configs/server/gametypes/" + gametype.name + ".cfg", config );
        G_Print( "Created default config file for '" + gametype.name + "'\n" );
        G_CmdExecute( "exec configs/server/gametypes/" + gametype.name + ".cfg silent" );
    }

    gametype.spawnableItemsMask = ( IT_AMMO | IT_WEAPON | IT_POWERUP );
    if ( gametype.isInstagib )
        gametype.spawnableItemsMask &= ~uint( G_INSTAGIB_NEGATE_ITEMMASK );

    gametype.respawnableItemsMask = gametype.spawnableItemsMask;
    gametype.dropableItemsMask = 0;
    gametype.pickableItemsMask = ( gametype.spawnableItemsMask | gametype.dropableItemsMask );

    gametype.isTeamBased = false;
    gametype.isRace = true;
    gametype.hasChallengersQueue = false;
    gametype.maxPlayersPerTeam = 0;

    gametype.ammoRespawn = 1;
    gametype.armorRespawn = 1;
    gametype.weaponRespawn = 1;
    gametype.healthRespawn = 1;
    gametype.powerupRespawn = 1;
    gametype.megahealthRespawn = 1;
    gametype.ultrahealthRespawn = 1;

    gametype.readyAnnouncementEnabled = false;
    gametype.scoreAnnouncementEnabled = false;
    gametype.countdownEnabled = false;
    gametype.mathAbortDisabled = false;
    gametype.shootingDisabled = false;
    gametype.infiniteAmmo = true;
    gametype.canForceModels = true;
    gametype.canShowMinimap = false;
    gametype.teamOnlyMinimap = true;

    gametype.spawnpointRadius = 0;

    if ( gametype.isInstagib )
        gametype.spawnpointRadius *= 2;

    gametype.inverseScore = false;

    // set spawnsystem type
    for ( int team = TEAM_PLAYERS; team < GS_MAX_TEAMS; team++ )
        gametype.setTeamSpawnsystem( team, SPAWNSYSTEM_INSTANT, 0, 0, false );

    // define the scoreboard layout
    G_ConfigString( CS_SCB_PLAYERTAB_LAYOUT, "%n 112 %s 52 %i 52 %l 48 %r l1" );
    G_ConfigString( CS_SCB_PLAYERTAB_TITLES, "Name Clan Score Ping R" );

    // add commands
    G_RegisterCommand( "gametype" );
    G_RegisterCommand( "racerestart" );
    G_RegisterCommand( "kill" );
    //G_RegisterCommand( "newmap" );

    // add votes
    //G_RegisterCallvote( "seed", "<seed>", "string", "Changes to seed" );
    G_RegisterCallvote( "skip", "map", "string", "skips map" );
    G_RegisterCallvote( "autoskip", "<0-30>", "integer", "Autoskips maps that haven't been completed in x minutes. 0 to disable.\n" + "Current: " + autoskip.get_integer() + " minutes\n");

    G_Print( "Gametype '" + gametype.title + "' initialized\n" );
}
