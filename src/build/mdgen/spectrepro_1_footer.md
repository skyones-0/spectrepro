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

**TERM**

: Defaults to `xterm-spectrepro`. Can be configured with the `term` configuration option.

**SPECTREPRO_RESOURCES_DIR**

: Where the SpectrePro resources can be found.

**XDG_CONFIG_HOME**

: Default location for configuration files.

**$HOME/Library/Application Support/co.skyones.spectrepro**

: **MACOS ONLY** default location for configuration files. This location takes
precedence over the XDG environment locations.

**LOCALAPPDATA**

: **WINDOWS ONLY:** alternate location to search for configuration files.

**SPECTREPRO_LOG**

: The `SPECTREPRO_LOG` environment variable can be used to control which
destinations receive logs. SpectrePro currently defines two destinations:

: - `stderr` - logging to `stderr`.
: - `macos` - logging to macOS's unified log (has no effect on non-macOS platforms).

: Combine values with a comma to enable multiple destinations. Prefix a
destination with `no-` to disable it. Enabling and disabling destinations
can be done at the same time. Setting `SPECTREPRO_LOG` to `true` will enable all
destinations. Setting `SPECTREPRO_LOG` to `false` will disable all destinations.

# BUGS

See GitHub issues: <https://github.com/spectrepro-org/spectrepro/issues>

# AUTHOR

Mitchell Hashimoto <m@mitchellh.com>
SpectrePro contributors <https://github.com/spectrepro-org/spectrepro/graphs/contributors>

# SEE ALSO

**spectrepro(5)**
