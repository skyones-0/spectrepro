# Windows Tests

Manual test programs for Windows-specific functionality.

## test_dll_init.c

Regression test for the DLL CRT initialization fix. Loads
spectrepro-internal.dll at runtime and calls spectrepro_info + spectrepro_init to
verify the MSVC C runtime is properly initialized.

### Build

First build spectrepro-internal.dll, then compile the test:

```
zig build -Dapp-runtime=none -Demit-exe=false
zig cc test_dll_init.c -o test_dll_init.exe -target native-native-msvc
```

### Run

From this directory:

```
copy ..\..\zig-out\lib\spectrepro-internal.dll . && test_dll_init.exe
```

Expected output (after the CRT fix):

```
spectrepro_info: <version string>
```

The spectrepro_info call verifies the DLL loads and the CRT is initialized.
Before the fix, loading the DLL would crash with "access violation writing
0x0000000000000024".
