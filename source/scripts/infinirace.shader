textures/msc/infinirace/concrete
{
	qer_editorimage textures/msc/infinirace/concrete.tga
  surfaceparm nonsolid

if ! deluxe
	{
		map $lightmap
	}
	{
		map $dlight
		blendfunc add
	}
	{
		map textures/msc/infinirace/concrete.tga
		blendFunc filter
	}
endif

if deluxe
	{
		material textures/msc/infinirace/concrete.tga textures/msc/infinirace/concrete_norm.tga textures/msc/infinirace/concrete_gloss.tga
	}
endif
}

textures/msc/infinirace/concrete_blue
{
	qer_editorimage textures/msc/infinirace/concrete_blue.tga
  surfaceparm nonsolid

if ! deluxe
	{
		map $lightmap
	}
	{
		map $dlight
		blendfunc add
	}
	{
		map textures/msc/infinirace/concrete_blue.tga
		blendFunc filter
	}
endif

if deluxe
	{
		material textures/msc/infinirace/concrete_blue.tga textures/msc/infinirace/concrete_norm.tga textures/msc/infinirace/concrete_gloss.tga
	}
endif
}

textures/msc/infinirace/concrete_orange
{
	qer_editorimage textures/msc/infinirace/concrete_orange.tga
  surfaceparm nonsolid

if ! deluxe
	{
		map $lightmap
	}
	{
		map $dlight
		blendfunc add
	}
	{
		map textures/msc/infinirace/concrete_orange.tga
		blendFunc filter
	}
endif

if deluxe
	{
		material textures/msc/infinirace/concrete_orange.tga textures/msc/infinirace/concrete_norm.tga textures/msc/infinirace/concrete_gloss.tga
	}
endif
}

textures/msc/infinirace/plastic
{
	qer_editorimage textures/msc/infinirace/plastic.tga
  surfaceparm nonsolid

if ! deluxe
	{
		map $lightmap
	}
	{
		map $dlight
		blendfunc add
	}
	{
		map textures/msc/infinirace/plastic.tga
		blendFunc filter
	}
endif

if deluxe
	{
		material textures/msc/infinirace/plastic.tga textures/msc/infinirace/plastic_norm.tga textures/msc/infinirace/plastic_gloss.tga
	}
endif
}

textures/msc/infinirace/plastic_dark
{
	qer_editorimage textures/msc/infinirace/plastic_dark.tga
  surfaceparm nonsolid

if ! deluxe
	{
		map $lightmap
	}
	{
		map $dlight
		blendfunc add
	}
	{
		map textures/msc/infinirace/plastic_dark.tga
		blendFunc filter
	}
endif

if deluxe
	{
		material textures/msc/infinirace/plastic_dark.tga textures/msc/infinirace/plastic_norm.tga textures/msc/infinirace/plastic_gloss.tga
	}
endif
}

textures/msc/newsky
{
	qer_editorimage textures/msc/newsky/sky_FT.jpg
	surfaceparm noimpact
	surfaceparm nolightmap
	//q3map_globaltexture
	surfaceparm sky
	q3map_sun 1.0 1.0 1.0 25 0 90

	skyparms textures/msc/newsky/sky - -
}

textures/msc/cubeclearsky
{
	qer_editorimage textures/msc/clearsky/sky_ft.jpg
	surfaceparm noimpact
	surfaceparm nolightmap
	//q3map_globaltexture
	surfaceparm sky
	q3map_sun 0.97 0.97 0.99 25 60 60

	{
		cubemap textures/msc/cubeclearsky/sky
	}
}
