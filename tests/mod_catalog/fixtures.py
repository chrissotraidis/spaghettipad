import pathlib, sys, zipfile
root = pathlib.Path(sys.argv[1]); (root / "mods").mkdir()
def pack(path, name, resources, dependency=None, version="1.0.0"):
    manifest = f'[mod]\nname="{name}"\nversion="{version}"\n'
    if dependency: manifest += f'[dependencies]\n{dependency[0]}="{dependency[1]}"\n'
    with zipfile.ZipFile(root / path, 'w') as z:
        z.writestr('mods.toml', manifest)
        for resource in resources: z.writestr(resource, b'test fixture, not game data')
pack('mk64.o2r', 'mk64-assets', [], version='1.0.0-alpha1')
pack('spaghetti.o2r', 'extended-assets', [], version='1.0.0-alpha1')
karts = ['textures/karts/'+name+'/frame.png' for name in ['luigi', 'yoshi', 'toad']]
pack('mods/hd.o2r', 'MK64-Reloaded-SK', karts+['textures/tracks/test.png'], ('mk64-assets', '>=1.0.0-alpha1'), '2026.04.03')
pack('mods/roster.o2r', 'Roster', karts)
for filename, resource in zip(['link', 'kris', 'ralsei'], karts):
    pack('mods/'+filename+'.o2r', filename, [resource], ('mk64-assets', '=1.0.0-alpha1'))
(root/'mods/broken.zip').write_text('not a zip')
for name, dependency in [('invalid', ('mk64-assets', 'nonsense')), ('future', ('mk64-assets', '>=99.0.0')), ('dependent', ('optional-pack', '>=1.0.0'))]:
    pack('mods/'+name+'.o2r', name, [karts[0]], dependency)
