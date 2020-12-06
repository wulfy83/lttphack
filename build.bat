set version="11.0.0"
cd target
copy alttp.sfc "lttphack-%version%.sfc"
copy alttp.sfc "lttphack-%version% SD2SNES.sfc"
copy alttp.sfc "lttphack-%version% VanillaHUD.sfc"
copy alttp.sfc "lttphack-%version% SD2SNES VanillaHUD.sfc"
copy alttp.sfc "lttphack-%version% Rando.sfc"
copy alttp.sfc "lttphack-%version% SD2SNES Rando.sfc"
cd ../src
asar.exe -DFEATURE_SD2SNES=0 -DFEATURE_HUD=1 -DFEATURE_RANDO=0 -DVERSION=%version% main.asm "../target/lttphack-%version%.sfc"
asar.exe -DFEATURE_SD2SNES=1 -DFEATURE_HUD=1 -DFEATURE_RANDO=0 -DVERSION=%version% main.asm "../target/lttphack-%version% SD2SNES.sfc"
asar.exe -DFEATURE_SD2SNES=0 -DFEATURE_HUD=0 -DFEATURE_RANDO=0 -DVERSION=%version% main.asm "../target/lttphack-%version% VanillaHUD.sfc"
asar.exe -DFEATURE_SD2SNES=1 -DFEATURE_HUD=0 -DFEATURE_RANDO=0 -DVERSION=%version% main.asm "../target/lttphack-%version% SD2SNES VanillaHUD.sfc"
asar.exe -DFEATURE_SD2SNES=0 -DFEATURE_HUD=1 -DFEATURE_RANDO=1 -DVERSION=%version% main.asm "../target/lttphack-%version% Rando.sfc"
asar.exe -DFEATURE_SD2SNES=1 -DFEATURE_HUD=1 -DFEATURE_RANDO=1 -DVERSION=%version% main.asm "../target/lttphack-%version% SD2SNES Rando.sfc"
pause
