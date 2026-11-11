"""Rooted growth atlases built from the approved, hand drawn resource stages.

Twelve discrete frames: trunk/branches first for oak, staggered crown for
birch, mineral facets for rock. No scaling or moving the original drawing.
"""
from pathlib import Path
import numpy as np
from PIL import Image

FRAMES = 12

def atlas(before, after, origin, mode):
    width,height = after.size
    assert before.size == after.size
    old,new = np.array(before),np.array(after)
    yy,xx = np.mgrid[:height,:width]
    ox,oy = origin
    # Bottom to top, with branch/facet islands rather than a straight wipe.
    vertical = np.clip((oy-yy)/max(1,oy),0,1)
    # Coherent leaf/facet clusters with broad ramps, without a chopped crown.
    cluster = ((xx//12*73856093) ^ (yy//12*19349663)) % 101 / 100
    if mode in ('oak','birch'):
        green = (new[...,1] > new[...,0]*.93) & (new[...,1] > new[...,2]*1.12)
        crown = .24 + vertical*.28 + cluster*.22
        if mode == 'oak':
            crown += np.abs(xx-ox)/max(1,width)*.15
        else:
            crown += ((xx//24)%3)*.035
        threshold = np.where(green,crown,vertical*.3)
    else:
        threshold = vertical*.4 + cluster*.3
    threshold = np.clip(threshold,0,.9)
    sheet = Image.new('RGBA',(width*FRAMES,height))
    for frame in range(FRAMES):
        if frame == 0 or frame == FRAMES-1:
            sheet.paste(before if frame == 0 else after,(frame*width,0))
            continue
        t = frame/(FRAMES-1)
        weight = np.clip((t*1.6-threshold)/.7,0,1)[...,None]
        if frame == 0: weight *= 0
        if frame == FRAMES-1: weight[:] = 1
        # Premultiplied blend avoids dark transparent borders.
        a,b = old.astype(float)/255,new.astype(float)/255
        alpha = a[...,3:4]*(1-weight)+b[...,3:4]*weight
        rgb = (a[...,:3]*a[...,3:4]*(1-weight)+b[...,:3]*b[...,3:4]*weight)/np.maximum(alpha,1/255)
        rgba = np.concatenate([rgb,alpha],axis=2)
        sheet.paste(Image.fromarray(np.round(np.clip(rgba,0,1)*255).astype('uint8')),(frame*width,0))
    assert np.array_equal(np.array(sheet.crop((0,0,width,height))), old)
    assert np.array_equal(np.array(sheet.crop(((FRAMES-1)*width,0,FRAMES*width,height))), new)
    return sheet

def build(root,manifest):
    out = root/'assets/world_hd/props'
    generated = []
    for species in ('oak','birch'):
        for start,end,suffix in [('cut','young','sprout'),('young','ready','growth')]:
            prefix = f'tree_{species}_'
            key = f'world_hd/props/{prefix}{end}.png'
            origin = manifest[key]['origin']
            before = Image.open(out/f'{prefix}{start}.png').convert('RGBA')
            after = Image.open(out/f'{prefix}{end}.png').convert('RGBA')
            name = f'{prefix}{suffix}.png'
            atlas(before,after,origin,species).save(out/name,optimize=True)
            manifest[f'world_hd/props/{name}'] = {'size':[after.width*FRAMES,after.height],'origin':origin,'scale':.5,'frames':FRAMES}
            generated.append('assets/world_hd/props/'+name)
    # Stone uses the same mineral regrowth family as ore, with a rooted depleted stage.
    before = Image.open(out/'vein_cut.png').convert('RGBA')
    after = Image.open(out/'vein_ready.png').convert('RGBA')
    origin = manifest['world_hd/props/vein_ready.png']['origin']
    aligned = Image.new('RGBA',after.size)
    cut_origin = manifest['world_hd/props/vein_cut.png']['origin']
    aligned.alpha_composite(before,(origin[0]-cut_origin[0],origin[1]-cut_origin[1]))
    atlas(aligned,after,origin,'rock').save(out/'vein_growth.png',optimize=True)
    manifest['world_hd/props/vein_growth.png'] = {'size':[after.width*FRAMES,after.height],'origin':origin,'scale':.5,'frames':FRAMES}
    generated.append('assets/world_hd/props/vein_growth.png')
    # A playback of the exact exported frames, not a separate concept drawing.
    previews = []
    sheets = [Image.open(out/name).convert('RGBA') for name in
              ('tree_oak_sprout.png','tree_oak_growth.png','tree_birch_sprout.png','tree_birch_growth.png','vein_growth.png')]
    for tick in range(32):
        canvas = Image.new('RGBA',(840,350),(27,34,37,255))
        phase = min(tick,23)
        for species,x,offset in [('oak',170,0),('birch',490,2)]:
            sheet = sheets[offset+(phase//12)]
            width = sheet.width//FRAMES
            frame = sheet.crop(((phase%12)*width,0,(phase%12+1)*width,sheet.height))
            origin = manifest[f'world_hd/props/tree_{species}_ready.png']['origin']
            canvas.alpha_composite(frame,(x-origin[0],330-origin[1]))
        sheet = sheets[4]; width = sheet.width//FRAMES
        index = min(11,max(0,phase-12))
        frame = sheet.crop((index*width,0,(index+1)*width,sheet.height))
        origin = manifest['world_hd/props/vein_ready.png']['origin']
        canvas.alpha_composite(frame,(740-origin[0],330-origin[1]))
        previews.append(canvas.convert('RGB'))
    folder = root/'docs/screenshots'
    folder.mkdir(parents=True,exist_ok=True)
    previews[0].save(folder/'resource_growth.gif',save_all=True,append_images=previews[1:],duration=100,loop=0,optimize=True,disposal=2)
    return generated
