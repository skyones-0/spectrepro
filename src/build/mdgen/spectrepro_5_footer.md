# FILES

_\$XDG_CONFIG_HOME/spectrepro/config.spectrepro_

: Location of the default configuration file.

_\$HOME/Library/Application Support/co.skyones.spectrepro/config.spectrepro_

: **On macOS**, location of the default configuration file. This location takes
precedence over the XDG environment locations.

_\$LOCALAPPDATA/spectrepro/config.spectrepro_

: **On Windows**, if _\$XDG_CONFIG_HOME_ is not set, _\$LOCALAPPDATA_ will be searched
for configuration files.

# ENVIRONMENT

**XDG_CONFIG_HOME**

: Default location for configuration files.

**$HOME/Library/Application Support/co.skyones.spectrepro**

: **MACOS ONLY** default location for configuration files. This location takes
precedence over the XDG environment locations.

**LOCALAPPDATA**

: **WINDOWS ONLY:** alternate location to search for configuration files.

# BUGS

See GitHub issues: <https://github.com/spectrepro-org/spectrepro/issues>

# AUTHOR

Mitchell Hashimoto <m@mitchellh.com>
SpectrePro contributors <https://github.com/spectrepro-org/spectrepro/graphs/contributors>

# SEE ALSO

**spectrepro(1)**
