"""Reproducible non-generative screen compositing authorized by the owner.
Only approved screen pixels are transformed; scenes and finger occlusion remain.
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'public/images/approved'
SCALE = 3

def composite(scene_name, source_name, crop, corners, output, finger=None):
    scene = Image.open(ASSETS / scene_name).convert('RGB')
    original = scene.resize((scene.width*SCALE, scene.height*SCALE), Image.Resampling.LANCZOS)
    screen = Image.open(ASSETS / source_name).convert('RGB').crop(crop)
    w,h=screen.size
    mask=Image.new('L',(w,h)); ImageDraw.Draw(mask).rounded_rectangle((0,0,w-1,h-1),radius=100,fill=255)
    # PIL samples output coordinates back into the original screen source.
    src=[(0,0),(w-1,0),(w-1,h-1),(0,h-1)]
    dst=[(x*SCALE,y*SCALE) for x,y in corners]
    A=[]; b=[]
    for (x,y),(u,v) in zip(dst,src):
        A.extend([[x,y,1,0,0,0,-u*x,-u*y],[0,0,0,x,y,1,-v*x,-v*y]]); b.extend([u,v])
    coeff=np.linalg.solve(np.array(A),np.array(b))
    warped=screen.transform(original.size,Image.Transform.PERSPECTIVE,coeff,Image.Resampling.BICUBIC)
    alpha=mask.transform(original.size,Image.Transform.PERSPECTIVE,coeff,Image.Resampling.BICUBIC)
    if finger:
        occlusion=Image.new('L',original.size)
        ImageDraw.Draw(occlusion).polygon([(round(x*SCALE),round(y*SCALE)) for x,y in finger],fill=255)
        occlusion=occlusion.filter(ImageFilter.GaussianBlur(.45*SCALE))
        alpha=Image.fromarray(np.minimum(np.asarray(alpha),255-np.asarray(occlusion)))
    result=Image.composite(warped,original,alpha)
    assert np.array_equal(np.asarray(result)[np.asarray(alpha)==0],np.asarray(original)[np.asarray(alpha)==0])
    result.save(ASSETS/output,'WEBP',quality=95,method=6)
    # Temporary closeups for placement inspection.
    x0,y0=min(x for x,y in corners)-15,min(y for x,y in corners)-15
    x1,y1=max(x for x,y in corners)+15,max(y for x,y in corners)+15
    result.crop((int(x0*SCALE),int(y0*SCALE),int(x1*SCALE),int(y1*SCALE))).save('/workspace/scratch/'+output+'.png')
    print(output,result.size,(ASSETS/output).stat().st_size,'bytes; all pixels outside mask preserved')

composite('account-discount-bbq.png','discounts-original.png',(240,42,857,1344),[(858,235),(1086,228),(1087,730),(858,730)],'account-discount-bbq-exact.webp')
composite('account-earned-sideline.png','boss-bucks-wallet-approved.png',(46,37,839,1726),[(960,287),(1188,301),(1134,802),(890,773)],'account-earned-sideline-exact.webp',[(850,700),(880,695),(900,690),(917,687),(928,689),(936,694),(940,700),(940,709),(935,718),(925,729),(910,740),(895,750),(875,763),(850,775)])
