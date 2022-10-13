> ℹ This was fixed upstream in TF2 version 7580501, released on 2022-10-13.  This plugin is no
> longer required.

# TF2 Workshop Map Sounds Fix

A plugin that loads Workshop map soundscapes and overrides by display name.

Fixes a bug where soundscapes and sound overrides have been broken on Workshop maps for as long
as the Steam Workshop has existed.  They fixed navigation meshes forever ago, what's taking them
so long with this?

This only fixes issues with those two files; while it should result in working ambient sounds
for those that are already built into the game, it's still on Valve to fix client-side embedded
sound file playback.  Don't hold your breath.

## Dependencies

* Requires [DHooks with Detour support][dynhooks].
* [stocksoup] is a build dependency.  It is available as a submodule.

[dynhooks]: https://forums.alliedmods.net/showpost.php?p=2588686&postcount=589
[stocksoup]: https://github.com/nosoop/stocksoup
