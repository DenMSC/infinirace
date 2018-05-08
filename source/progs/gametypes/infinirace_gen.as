Piece@[] pieces;
Piece@ last_piece;
Piece@ end_piece;
Piece@ end_trigger;

Entity@ kill_trigger;
uint nextThink;
uint path_length = 10;

uint lastGen;
Cvar infinirace_length("infinirace_length", "1", 0);

uint pathAttempts = 0;
uint maxPathAttempts = 100;

class CollisionBox
{
  Vec3 mins, maxs;
  Vec3 origin;
  Vec3 angles;

  CollisionBox()
  {
    this.mins = Vec3(0);
    this.maxs = Vec3(0);
    this.origin = Vec3(0);
  }
  CollisionBox(Entity@ ent)
  {
    this.Update(@ent);
  }
  ~CollisionBox() {}

  void Update(Entity@ ent)
  {
    Vec3 mins,maxs;
    ent.getSize(mins, maxs);
    mins += Vec3(1,1,1);
    maxs -= Vec3(1,1,1);

    this.mins = mins;
    this.maxs = maxs;

    this.origin = ent.origin;
    this.angles = ent.angles;
  }

  Vec3 GetWorldMins()
  {
    return this.GetWorldMins(this.origin, this.angles);
  }
  Vec3 GetWorldMins(Vec3 position, Vec3 angles)
  {
    Vec3 mins, maxs;
    RotateBBox(this.mins, this.maxs, mins, maxs, angles);
    mins -= Vec3(0,0,128);
    return mins + position;
  }

  Vec3 GetWorldMaxs()
  {
    return this.GetWorldMaxs(this.origin, this.angles);
  }
  Vec3 GetWorldMaxs(Vec3 position, Vec3 angles)
  {
    Vec3 mins, maxs;
    RotateBBox(this.mins, this.maxs, mins, maxs, angles);
    maxs += Vec3(0,0,128);
    return maxs + position;
  }

  bool CheckCollision(CollisionBox@ box, Vec3 position, Vec3 angles)
  {
    Vec3 amins = this.GetWorldMins(position, angles);
    Vec3 amaxs = this.GetWorldMaxs(position, angles);

    Vec3 bmins = box.GetWorldMins();
    Vec3 bmaxs = box.GetWorldMaxs();

    return (
      (amins.x <= bmaxs.x && amaxs.x >= bmins.x ) &&
      (amins.y <= bmaxs.y && amaxs.y >= bmins.y ) &&
      (amins.z <= bmaxs.z && amaxs.z >= bmins.z )
    );
  }
}

Vec3 colorToVec3(int rgb)
{
  Vec3 vrgb = Vec3(
    (rgb >> 0) & 0xFF,
    (rgb >> 8) & 0xFF,
    (rgb >> 16) & 0xFF
  );
  if ( vrgb.x == 255 ) vrgb.x = 1;
  if ( vrgb.y == 255 ) vrgb.y = 1;
  if ( vrgb.z == 255 ) vrgb.z = 1;
  return vrgb;
}

class Piece
{
  Entity@ ent;
  Vec3 angle;
  Vec3 delta;
  CollisionBox@ box;
  int start_type;
  int end_type;

  Piece(Entity@ ent)
  {
    @this.ent = @ent;
    this.angle = ent.angles*-1;
    Entity@[] targets = ent.findTargets();
    if ( targets.isEmpty() )
    {
      Vec3 norm_origin = ent.origin;
      norm_origin.x = int(norm_origin.x / 1024)*1024;
      norm_origin.y = int( (norm_origin.y-512) / 1024)*1024;
      norm_origin.z = int( (norm_origin.z-512) / 1024)*1024;
      this.delta = ent.origin-norm_origin;
    } else {
      this.delta = ent.origin - targets[0].origin;
    }
    Vec3 type = colorToVec3(ent.light);
    this.start_type = int(type.x);
    this.end_type = int(type.y);
    ent.light = 0;
    ent.angles = Vec3(0,0,0);

    @this.box = @CollisionBox(@ent);
  }

  ~Piece()
  {

  }

  void ResetPos()
  {
    this.ent.origin = Vec3(0, 0, 0);
    this.ent.angles = Vec3(0, 0, 0);
    this.ent.svflags |= SVF_NOCLIENT;
    this.ent.linkEntity();
    this.box.Update(@this.ent);
  }

  bool TestCollisionNew(Piece@[]@ pieces, Vec3 position, Vec3 angles, int ignore = -1)
  {
    for ( uint i = 0; i < pieces.length; i++ )
    {
      if ( ignore != -1 )
      {
        if ( i == uint(ignore) )
          continue;
      }

      Piece@ piece = @pieces[i];
      if ( this.box.CheckCollision( piece.box, position, angles ) )
      {
        return false;
      }
    }
    return true;
  }

  bool TestCollision(Piece@[]@ pieces, Vec3 position, Vec3 angles, int ignore = -1)
  {
    Trace tr;
    Vec3 mins, maxs;
    ent.getSize(mins, maxs);
    mins += Vec3(1,1,1);
    maxs -= Vec3(1,1,1);

    RotateBBox( mins, maxs, mins, maxs, angles );

    if ( ignore != -1 )
      ignore = pieces[ignore].ent.entNum;

    if ( tr.doTrace( position-Vec3(0,0,128), mins, maxs, position+Vec3(0,0,128), ignore, MASK_SOLID ) )
      return false;
    if ( tr.startSolid || tr.allSolid )
      return false;

    return true;
  }

  void Place(Vec3 position, Vec3 angles)
  {
    this.ent.origin = position;
    this.ent.angles = angles;
    this.ent.solid = SOLID_YES;
    this.ent.svflags &= ~SVF_NOCLIENT;
    //this.ent.setupModel( "*" + this.ent.modelindex ); // recalculate model clipping
    this.ent.clipMask = MASK_SOLID;
    this.ent.solid = SOLID_YES;
    this.ent.linkEntity();
    this.box.Update(@this.ent);
  }
}

class Path
{
  Vec3 path_pos = Vec3(0,0,2048);
  Vec3 path_angle;
  Piece@[] path;
  Piece@[] pool;
  uint pool_index;
  uint length;
  Piece@ end_piece;
  Piece@ end_trigger;

  Path(uint length, Piece@[] pool, Piece@ end_piece, Piece@ end_trigger)
  {
    this.length = length;
    for ( int i = 0; i < int(pool.length); i++ )
    {
      Piece@ piece = @pool[i];
      piece.ResetPos();
      this.pool.push_back(@piece);
    }
    end_piece.ResetPos();
    @this.end_piece = @end_piece;
    @this.end_trigger = @end_trigger;
  }
  ~Path()
  {
  }

  void ShufflePool()
  {
    if ( this.pool.length == 0 )
      return;
    for ( uint i = this.pool.length - 1; i > 0; i-- )
    {
      uint j = randint(0,i+1);
      Piece@ temp_piece = @this.pool[i];
      @this.pool[i] = @this.pool[j];
      @this.pool[j] = @temp_piece;
    }
    this.pool_index = 0;
  }

  Piece@ NextPiece()
  {
    if ( this.pool_index >= this.pool.length)
    {
      return null;
    }

    Piece@ piece = @this.pool[this.pool_index];
    this.pool_index++;
    return @piece;
  }

/*  bool FindPiece(bool last = false)
  {
    this.ShufflePool();
    Piece@ rand_piece;
    while (true) {
      @rand_piece = @this.NextPiece();
      if ( @rand_piece == null )
      {
        //end of pool, nothing found
        Vec3 end_pos = this.path_pos + Rotate(this.end_piece.delta, this.path_angle);

        this.end_piece.Place(end_pos, this.path_angle);
        this.end_trigger.Place(end_pos, this.path_angle);
        G_PrintMsg(null,"Failed to reach desired length, end might clip.\n");
        break;
      }

      Vec3 new_pos = this.path_pos + Rotate(rand_piece.delta, this.path_angle);
      Vec3 new_angle = this.path_angle + rand_piece.angle;

      int ignore = this.path.length-1;

      if ( rand_piece.TestCollision(@this.path, new_pos, this.path_angle, ignore ) )
      {
        if ( last )
        {
          Vec3 end_angle = this.path_angle + rand_piece.angle;
          Vec3 end_pos = new_pos + Rotate(this.end_piece.delta, end_angle);

          if ( this.end_piece.TestCollision(@this.path, end_pos, end_angle) )
          {
            this.end_piece.Place(end_pos, new_angle);
            this.end_trigger.Place(end_pos, new_angle);
          } else {
            continue;
          }
        }

        // remove from pool and add to path
        rand_piece.Place(new_pos, this.path_angle);

        this.pool.removeAt(this.pool_index-1);
        this.pool_index--;
        this.path.push_back(@rand_piece);

        this.path_angle = new_angle;
        this.path_pos = new_pos;
        return true;
      } else {
        // move on to next piece
        G_PrintMsg(null, "Collided at "+this.path.length+": "+rand_piece.ent.targetname+"\n");
      }
    }
    return false;
  }
  bool PopPiece(Piece@ piece)
  {
    return true;
  }
  bool Generate()
  {
    while ( this.path.length < this.length )
    {
      if ( !this.FindPiece( this.path.length == this.length-1 ) )
        return false;
    }
    return false;
  }
*/
  bool newGenerate(Piece@[] pool, Vec3 pos, Vec3 angles, int type = 0)
  {
    //G_Print("curr type: " + type + "\n");
    if ( this.path.length >= this.length )
    {
      Vec3 new_pos = pos + Rotate(this.end_piece.delta, angles);
      Vec3 new_angles = angles + this.end_piece.angle;
      int ignore = this.path.length-1;

      if ( this.end_piece.TestCollision(@this.path, new_pos, angles, ignore) )
      {
        this.end_piece.Place(new_pos, angles);
        this.end_trigger.Place(new_pos, angles);
        return true;
      } else {
        return false;
      }
    }

    Piece@[] rand_pool = Shuffle(pool);
    for ( uint i = 0; i < rand_pool.length; i++ )
    {
      Piece@ piece = @rand_pool[i];
      Vec3 new_pos = pos + Rotate(piece.delta, angles);
      Vec3 new_angles = angles + piece.angle;

      int ignore = this.path.length-1;

      if ( piece.start_type == type )
      {
        if ( piece.TestCollision(@this.path, new_pos, angles, ignore) )
        {
          //G_Print("add "+piece.ent.targetname+"to path\n");
          //G_AppendToFile( "infinitest.txt", "add "+piece.ent.targetname+"to path\n");
          this.path.push_back(@piece);
          piece.Place(new_pos, angles);

          Piece@[] new_pool = rand_pool;
          new_pool.removeAt(i);
          if ( this.newGenerate(new_pool, new_pos, new_angles, piece.end_type) )
          {
            return true;
          } else {
            pathAttempts++;
            if ( pathAttempts > maxPathAttempts )
            {
              G_Print( "Giving up after " + maxPathAttempts + " fails\n" );
              this.length = 0;
              return this.newGenerate(new_pool, new_pos, new_angles, piece.end_type);
            }
            this.path.removeLast();
            piece.ResetPos();
            //G_Print("remove "+piece.ent.targetname+"from path\n");
            //G_AppendToFile( "infinitest.txt", "remove "+piece.ent.targetname+"from path\n");
          }
        }
      }
    }
    return false;
  }
}

Piece@[] Shuffle(Piece@[] pieces)
{
  Piece@[] shuffled = pieces;
  for ( uint i = shuffled.length - 1; i > 0; i-- )
  {
    uint j = randint(0,i+1);
    Piece@ temp_piece = @shuffled[i];
    @shuffled[i] = @shuffled[j];
    @shuffled[j] = @temp_piece;
  }
  return shuffled;
}


void INFINI_Init()
{
  for ( int i = 0; i < numEntities; i++ )
  {
    Entity@ ent = @G_GetEntity(i);
    if ( ent.classname == "func_static" )
    {
      if ( ent.targetname == "map_end" )
      {
        @end_piece = @Piece(ent);
      } else if ( ent.targetname == "map_end_trigger" )
      {
        Entity@ end = @G_SpawnEntity("map_end");
        end.modelindex = ent.modelindex;
        end.origin = ent.origin;
        end.angles = ent.angles;
        //end.type = ET_PUSH_TRIGGER;
        end.solid = SOLID_YES;
        end.setupModel("*"+ent.modelindex);
        @end.touch = end_Touch;
        end.linkEntity();
        end.svflags &= ~SVF_NOCLIENT;

        ent.unlinkEntity();
        ent.freeEntity();
        @end_trigger = @Piece(end);
      } else
        pieces.push_back(@Piece(ent));
    }
  }

  @kill_trigger = G_SpawnEntity("kill_trigger");
  kill_trigger.origin = Vec3(0,0,0);
  kill_trigger.setSize(Vec3(-10000,-10000,-128), Vec3(10000,10000,0));
  kill_trigger.solid = SOLID_TRIGGER;
  //kill_trigger.clipMask = MASK_PLAYERSOLID;
  @kill_trigger.touch = kill_Touch;
  kill_trigger.svflags &= ~SVF_NOCLIENT;
  kill_trigger.linkEntity();

  String seed = String(random());
  //seed = "bsl";
  setSeed(seed);
  //G_Print("seed : "+seed+"\n");

  Restart();

  /*Path@ path = @Path(infinirace_length.integer,pieces,@end_piece,@end_trigger);
  path.Generate();*/
}

void end_Touch(Entity @ent, Entity @other, const Vec3 planeNormal, int surfFlags)
{
  //G_PrintMsg(null,"finish"+surfFlags+"\n");
  if ( @other.client == null )
    return;

  ent.solid = SOLID_NOT;
  ent.setupModel("*"+ent.modelindex);

  infini_round.Finish(@other.client);
}

void kill_Touch(Entity @ent, Entity @other, const Vec3 planeNormal, int surfFlags)
{
  if ( @other.client == null )
    return;

  other.client.respawn(false);
}


void Restart()
{
  String seed = String(random());
  //seed = "0.911893"; //crash
  //seed = "0.000976592"; //buggy
  if ( voted_seed != "" )
    seed = voted_seed;

  setSeed(seed);
  uint length = randint(5, pieces.length);
  //length = pieces.length;
  G_Print("seed : "+seed+", length : "+length+", max: "+pieces.length+"\n");
  Path@ path = @Path(length,pieces,@end_piece,@end_trigger);
  /*while( true ) {
    if ( path.Generate() )
      break;
  }*/
  //G_WriteFile( "infinitest.txt", "" );
  pathAttempts = 0;
  path.newGenerate( pieces, Vec3(0,0,2048), Vec3(0,0,0) );
  lastGen = levelTime;


  float lowest = 1024;
  for ( uint i = 0; i < path.path.length; i++ )
  {
    Entity@ curr = @path.path[i].ent;
    float height = curr.origin.z;
    Vec3 mins, maxs;
    curr.getSize(mins,maxs);
    height += mins.z - 128;

    if ( lowest > height )
    {
      lowest = height;
    }
  }
  kill_trigger.setSize(Vec3(-10000,-10000,lowest-128), Vec3(10000,10000,lowest));
  kill_trigger.linkEntity();
  //G_Print("lowest: "+lowest+"\n");
  //ListEntities();
}

void INFINI_Think()
{
  /*for ( uint i = 0; i < pieces.length; i++ )
  {
    Piece@ ent = @pieces[i];
    ent.ent.light = COLOR_RGBA(random()*255,random()*255,random()*255,255);
  }*/

  /*for ( int j = 0; j < maxClients; j++ )
  {
    Client@ client = G_GetClient(j);
    if ( @client == null )
      continue;
    Entity@ clientent = @client.getEnt();
    if ( @clientent.groundEntity == null )
      continue;
    if ( @clientent.groundEntity == @end_piece.ent )
    {
      //infini_round.Finish(@client);
      break;
    }
    G_CenterPrintMsg(clientent, "standing on: " + clientent.groundEntity.targetname);
  }*/

  /*if ( levelTime >= nextThink )
  {
    Restart();
    nextThink = levelTime + 500;
  }*/
}
