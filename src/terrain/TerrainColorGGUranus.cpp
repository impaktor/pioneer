// Copyright © 2008-2025 Pioneer Developers. See AUTHORS.txt for details
// Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

#include "Terrain.h"
#include "TerrainNoise.h"

using namespace TerrainNoise;

template <>
const char *TerrainColorFractal<TerrainColorGGUranus>::GetColorFractalName() const { return "GGUranus"; }

template <>
TerrainColorFractal<TerrainColorGGUranus>::TerrainColorFractal(const SystemBody *body) :
	Terrain(body)
{
	const double height = m_maxHeightInMeters * 0.1;
	SetFracDef(0, height, 3e7, 1000.0);
	SetFracDef(1, height, 9e7, 1000.0);
	SetFracDef(2, height, 8e7, 1000.0);
}

template <>
vector3d TerrainColorFractal<TerrainColorGGUranus>::GetColor(const vector3d &p, double height, const vector3d &norm) const
{
	double n = 0.5 * ridged_octavenoise(GetFracDef(0), 0.7, vector3d(3.142 * p.y * p.y));
	n += 0.5 * octavenoise(GetFracDef(1), 0.6, vector3d(3.142 * p.y * p.y));
	n += 0.2 * octavenoise(GetFracDef(2), 0.5, vector3d(3.142 * p.y * p.y));
	n /= 2.0;
	n *= n * n;
	return interpolate_color(n, vector3d(.4, .5, .55), vector3d(.85, .95, .96));
}
