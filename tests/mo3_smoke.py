# Executed inside the game's IronPython engine through websocket_smoke.py.
import System
import Sexy

_module_type = System.Type.GetType("Sexy.OpenMptModule, Lawn")
if _module_type is not None:
    # Older builds do not use libopenmpt. Newer builds must decode real MO3
    # samples and expose the interactive API used for layered game music.
    _resource_root = System.IO.DirectoryInfo(System.AppContext.BaseDirectory).Parent.FullName
    _music_dir = System.IO.Path.Combine(_resource_root, "Resources", "Content", "music")
    if not System.IO.Directory.Exists(_music_dir):
        _music_dir = System.IO.Path.Combine(System.AppContext.BaseDirectory, "Content", "music")
    for _name in ("mainmusic.mo3", "mainmusic_hihats.mo3"):
        _data = System.IO.File.ReadAllBytes(System.IO.Path.Combine(_music_dir, _name))
        _module = System.Activator.CreateInstance(_module_type, System.Array[System.Object]([_data]))
        try:
            assert _module_type.GetProperty("HasInteractive").GetValue(_module), "Missing interactive interface"
            _pcm = System.Array.CreateInstance(System.Int16, 8192)
            _has_audio = False
            for _index in range(64):
                _frames = _module_type.GetMethod("ReadInterleavedStereo").Invoke(
                    _module, System.Array[System.Object]([System.Int32(44100), System.Int32(4096), _pcm]))
                assert _frames > 0, "MO3 decoder returned no frames"
                if any(_sample != 0 for _sample in _pcm):
                    _has_audio = True
                    break
            assert _has_audio, "MO3 decoded only silence: " + _name
        finally:
            _module.Dispose()
    assert Sexy.GlobalStaticVars.gLawnApp.mMusicInterface.HasMusic(15), "Game failed to load main MO3 track"
    print("[PGVZ_MAC_SMOKE] MO3 decoding and interactive interface passed")
