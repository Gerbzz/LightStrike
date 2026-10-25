"""Generate/check the approved-logo DMG backdrop using the existing TIFF writer.
Regenerate requires resvg, Pillow>=12, ds_store==1.3.3, mac_alias==2.2.3.
Only the embedded product logo changes; inherited originals and layout remain.
"""
from pathlib import Path
import argparse, hashlib, importlib.util, json
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
DIR=ROOT/"packaging/macos/dmg"
OLD='<g transform="translate(-134.0,-40.0) scale(1.0)"><image href="../../../assets/app-icon/lightcraft.svg" width="512" height="512"/></g>'
NEW='<image href="../../../assets/branding/LightStrike-logo.svg" x="0" y="84" width="232" height="232" preserveAspectRatio="xMidYMid meet"/>'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    p=argparse.ArgumentParser();p.add_argument("--check",action="store_true");args=p.parse_args()
    original=(DIR/"background.svg").read_text();assert original.count(OLD)==1
    assert (DIR/"background-approved.svg").read_text()==original.replace(OLD,NEW), "Only the embedded logo may change"
    config=json.loads((ROOT/"tools/approved-branding.json").read_text())
    assert sha(ROOT/config["source"])==config["approved_sha256"]
    manifest=DIR/"background-approved.json"
    if not args.check:
        spec=importlib.util.spec_from_file_location("dmg_generator",DIR/"generate.py")
        generator=importlib.util.module_from_spec(spec);spec.loader.exec_module(generator)
        generator.write_tiff(str(DIR/"background-approved.svg"),str(DIR/"background-approved.tiff"))
        data={"approved_sha256":config["approved_sha256"],"renderer":"resvg 0.47.0; existing generate.py write_tiff; Pillow 12+", "logo_page":[0,84,232,232],"native_acceptance":"unknown","files":{n:sha(DIR/n) for n in ["background.svg","generate.py","background-approved.svg","background-approved.tiff"]}}
        manifest.write_text(json.dumps(data,indent=2)+"\n")
    data=json.loads(manifest.read_text());assert data["approved_sha256"]==config["approved_sha256"]
    for name,digest in data["files"].items():assert sha(DIR/name)==digest,name
    with Image.open(DIR/"background-approved.tiff") as im:
        assert im.n_frames==2
        for frame,size,dpi in [(0,(660,400),(72,72)),(1,(1320,800),(144,144))]:
            im.seek(frame);assert im.size==size;assert im.info["dpi"]==dpi;im.load()
    assert 'cp "$HERE/dmg/background-approved.tiff"' in (ROOT/"packaging/macos/package.sh").read_text()
    print("Approved DMG full-page logo, unchanged surrounding SVG, hashes and two TIFF resolutions PASS")
if __name__=="__main__":main()
