# smapi-proton-installer

Install [SMAPI](https://smapi.io) for Stardew Valley running under **Proton on Linux**, implementing the [wiki's manual Proton steps](https://stardewvalleywiki.com/Modding:Installing_SMAPI_on_Linux#SMAPI_with_Proton) as a script.

Written for SMAPI v4.5.2.

## REQUIREMENTS

- [Nushell v0.115](https://www.nushell.sh)
- `unzip` and `ln`
- network (first run only, releases are cached)
- Stardew Valley installed via Steam

## USAGE

```nu
./smapi-proton.nu install
./smapi-proton.nu uninstall
./smapi-proton.nu link-saves
```

## LICENSE

Copyright (C) 2026 yilisharcs <yilisharcs@gmail.com>

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program. If not, see <https://www.gnu.org/licenses/>.
