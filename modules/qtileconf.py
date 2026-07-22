import subprocess
import os
import time

from libqtile import layout, hook
from libqtile.config import Click, Drag, Group, Key, Match, Screen
from libqtile.lazy import lazy

layouts = [ layout.Stack(num_stacks=3) ]
screens = [ Screen() ]

keys = [
        Key(["mod1"], "r", lazy.spawn("kitty"))
        ]

groups = [
    Group("a", spawn=os.environ['CMD'])
    ]

for vt in range(1, 8):
    keys.append(
        Key(
            ["control", "mod1"],
            f"f{vt}",
            lazy.core.change_vt(vt).when(func=lambda: qtile.core.name == "wayland"),
            desc=f"Switch to VT{vt}",
        )
    )


@hook.subscribe.startup_complete
def autostart():
    print('Starting')
    lazy.spawn(os.environ['CMD'])
