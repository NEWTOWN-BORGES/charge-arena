"""Deterministic seamless micro-surfaces; generated locally, no external artwork."""
from pathlib import Path
import numpy as np
from PIL import Image
root = Path(__file__).resolve().parents[1] / 'art/materials'
root.mkdir(exist_ok=True)
n=512
rng=np.random.default_rng(29500)
y,x=np.mgrid[:n,:n].astype(float)
noise=rng.normal(0,1,(n,n))
for name in ('ceramic','alloy','graphite'):
    grain = noise*0.18
    if name == 'alloy':
        grain += np.sin(y*2*np.pi/4)*0.18 + np.sin(y*2*np.pi/17)*0.1
    if name == 'graphite':
        grain += np.sin(x*2*np.pi/16)*np.sin(y*2*np.pi/16)*0.28
    albedo=np.clip(239 + grain*13,215,255).astype('uint8')
    rough=np.clip(({'ceramic':177,'alloy':135,'graphite':214}[name]) + grain*35,0,255).astype('uint8')
    dx=(np.roll(grain,-1,1)-np.roll(grain,1,1))*0.1
    dy=(np.roll(grain,-1,0)-np.roll(grain,1,0))*0.1
    normal=np.stack([-dx,-dy,np.ones_like(dx)],-1)
    normal/=np.linalg.norm(normal,axis=-1,keepdims=True)
    Image.fromarray(albedo).save(root/f'{name}_albedo.png')
    Image.fromarray(rough).save(root/f'{name}_roughness.png')
    Image.fromarray(np.clip((normal*.5+.5)*255,0,255).astype('uint8')).save(root/f'{name}_normal.png')
print('Generated nine 512px seamless maps')
