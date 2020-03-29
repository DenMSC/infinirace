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
