"""Build and verify the complete Hunter + supplied wardrobe compatibility bundle."""
from pathlib import Path
import hashlib
import zipfile

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'deliverables'
NAME='Hunter_v1.78-art_wardrobe_test.zip'


def main():
    path=OUT/NAME
    instruction=(ROOT/'zzzz_revolver_samson/ART_PACK_README.md').read_text()
    with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED,compresslevel=9)as archive:
        archive.writestr('安装说明.txt',instruction)
        for folder in [ROOT/'zzzz_revolver_samson',ROOT/'compat/old wardrobe_2488945061']:
            for source in sorted(folder.rglob('*')):
                if source.is_file() and '__pycache__'not in source.parts and source.suffix!='.pyc':
                    archive.write(source,str(Path(folder.name)/source.relative_to(folder)))
    assert path.stat().st_size<100*1024**2,'GitHub individual-file limit exceeded'
    with zipfile.ZipFile(path)as archive:
        assert archive.testzip()is None,'archive CRC failure'
        names=archive.namelist()
        assert len(names)==len(set(names))
        assert 'zzzz_revolver_samson/main.lua'in names and 'old wardrobe_2488945061/main.lua'in names
        assert len([name for name in names if '001.000_player_hunter_b_v178_f'in name])==15
        assert len([name for name in names if '/hunter_forms178/wings_'in name and name.endswith('.anm2')])==4
        for name in names:
            if name=='安装说明.txt':continue
            source=ROOT/name if name.startswith('zzzz_revolver_samson/') else ROOT/'compat'/name
            assert archive.read(name)==source.read_bytes(),name
    sha=hashlib.sha256(path.read_bytes()).hexdigest()
    (OUT/'SHA256SUMS.txt').write_text(f'{sha}  {NAME}\n')
    # Previous complete releases remain available in repository history.
    for old in OUT.glob('Hunter_v1.77-art_test.zip'):old.unlink()
    print(f'PASS: full two-Mod bundle, byte/CRC verified, {path.stat().st_size:,}bytes, SHA256 {sha}')


if __name__=='__main__':main()
