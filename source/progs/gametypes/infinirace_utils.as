void RotateBBoxOld( Vec3&in mins, Vec3&in maxs, Vec3&out outmins, Vec3&out outmaxs, Vec3 angle )
{
  Vec3 posmins = Rotate(mins, angle);
  Vec3 posmaxs = Rotate(maxs, angle);
  Vec3 negmins = Rotate(mins, angle*-1);
  Vec3 negmaxs = Rotate(maxs, angle*-1);
  outmins = Vec3( absmax(posmins.x,negmins.x), absmax(posmins.y,negmins.y), absmax(posmins.z,negmins.z) );
  outmaxs = Vec3( absmax(posmaxs.x,negmaxs.x), absmax(posmaxs.y,negmaxs.y), absmax(posmaxs.z,negmaxs.z) );
}

void RotateBBox( Vec3&in mins, Vec3&in maxs, Vec3&out outmins, Vec3&out outmaxs, Vec3 angle )
{
  Vec3 halfsize = (maxs-mins)*0.5;
  Vec3 offset = (maxs+mins)*0.5;
  Vec3 center = Vec3(0);

  Vec3 dirx,diry,dirz;
  angle.angleVectors(dirx,diry,dirz);
  Vec3 rotated = Vec3(
    abs(dirx.x*halfsize.x) + abs(diry.x*halfsize.y) + abs(dirz.x*halfsize.z),
    abs(dirx.y*halfsize.x) + abs(diry.y*halfsize.y) + abs(dirz.y*halfsize.z),
    abs(dirx.z*halfsize.x) + abs(diry.y*halfsize.y) + abs(dirz.z*halfsize.z)
  );

  outmins = center - rotated;
  outmaxs = center + rotated;
}

float absmax(float a, float b)
{
  if ( abs(a) > abs(b) )
    return a;
  else
    return b;
}

Vec3 Rotate(Vec3 v, Vec3 angle)
{
  v = RotateX(v, angle.x);
  v = RotateY(v, angle.y);
  v = RotateZ(v, angle.z);
  return v;
}

Vec3 RotateX(Vec3 v, float a)
{
	a *= 0.01745329251;
	return Vec3(
		v.x,
		v.y*cos(a)-v.z*sin(a),
		v.y*sin(a)+v.z*cos(a)
	);
}

Vec3 RotateY(Vec3 v, float a)
{
	a *= 0.01745329251;
	return Vec3(
		cos(a)*v.x - sin(a)*v.y,
		sin(a)*v.x + cos(a)*v.y,
		v.z
	);
}

Vec3 RotateZ(Vec3 v, float a)
{
	a *= 0.01745329251;
	return Vec3(
		v.x*cos(a)+v.z*sin(a),
		v.y,
		-v.x*sin(a)+v.z*cos(a)
	);
}

void ListEntities()
{
  G_Print("total entities: "+numEntities+"\n");
  for ( int i = 0; i < numEntities; i++ )
  {
    Entity@ ent = @G_GetEntity(i);
    G_Print("Ent#"+i+" classname: "+ent.classname+" targetname: "+ent.targetname+"\n");
  }
}

void setSeed(String& seed)
{
  setSeed(seed, xor_x, 0);
  setSeed(seed, xor_y, xor_x);
  setSeed(seed, xor_z, xor_y);
  setSeed(seed, xor_w, xor_z);
}

void setSeed(String& seed, uint&out var, uint start)
{
  uint h = start;
  for ( uint i = 0; i < seed.length(); i++ )
  {
    h ^= (h << 5) + (h >> 2) + seed[i];
  }
  var = h;
}

uint xor_x = 0;
uint xor_y = 0;
uint xor_z = 0;
uint xor_w = 0;

float xorshift()
{
  uint t = xor_x;
  t ^= t << 11;
  t ^= t >> 8;
  xor_x = xor_y; xor_y = xor_z; xor_z = xor_w;
  xor_w ^= xor_w >> 19;
  xor_w ^= t;
  return float(xor_w)/4294967296.0;
}

int randint(int min, int max)
{
  return min + int((max-min) * xorshift());
}
