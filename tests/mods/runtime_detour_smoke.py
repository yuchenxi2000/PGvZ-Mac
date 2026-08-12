import Lawn
import LawnMod
import System.IO

_hook_calls = 0


@LawnMod.MonoModUtils.HookTo(Lawn.LawnApp.UpdateFrames)
def LawnApp__UpdateFrames(orig, lawnapp):
    global _hook_calls
    _hook_calls += 1
    if _hook_calls == 1:
        System.IO.File.WriteAllText("runtime_detour_smoke.ok", "ok")
        print("[PGVZ_MAC_SMOKE] RuntimeDetour hook invoked")
    orig(lawnapp)


print("[PGVZ_MAC_SMOKE] IronPython mod loaded")
