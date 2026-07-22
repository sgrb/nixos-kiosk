import subprocess
import os
import time

from libqtile import hook
from libqtile.config import Click, Drag, Group, Key, Match, Screen
from libqtile.lazy import lazy
from libqtile.layout.base import Layout


class Strip(Layout):
    defaults = [("vertical", False, "Stack vertically instead of horizontally")]

    def __init__(self, **config):
        Layout.__init__(self, **config)
        self.add_defaults(Strip.defaults)
        self.clients = []

    def clone(self, group):
        return Strip(vertical=self.vertical)

    def add_client(self, client):
        self.clients.append(client)

    def remove(self, client):
        if client in self.clients:
            self.clients.remove(client)

    def configure(self, client, screen_rect):
        pass

    def focus(self, client):
        pass

    def blur(self):
        pass

    def focus_first(self):
        return self.clients[0] if self.clients else None

    def focus_last(self):
        return self.clients[-1] if self.clients else None

    def focus_next(self, client):
        if client not in self.clients:
            return None
        idx = self.clients.index(client)
        if idx < len(self.clients) - 1:
            return self.clients[idx + 1]
        return None

    def focus_previous(self, client):
        if client not in self.clients:
            return None
        idx = self.clients.index(client)
        if idx > 0:
            return self.clients[idx - 1]
        return None

    def next(self):
        pass

    def previous(self):
        pass

    def layout(self, windows, screen_rect):
        n = len(windows)
        if n == 0:
            return
        if self.vertical:
            h = screen_rect.height // n
            for i, w in enumerate(windows):
                w.place(
                    screen_rect.x,
                    screen_rect.y + i * h,
                    screen_rect.width,
                    h if i < n - 1 else screen_rect.height - i * h,
                )
        else:
            wcol = screen_rect.width // n
            for i, w in enumerate(windows):
                w.place(
                    screen_rect.x + i * wcol,
                    screen_rect.y,
                    wcol if i < n - 1 else screen_rect.width - i * wcol,
                    screen_rect.height,
                )


rotate = int(os.environ.get('ROTATE', '0'))

layouts = [Strip(vertical=rotate in (90, 270))]
screens = [Screen()]

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
