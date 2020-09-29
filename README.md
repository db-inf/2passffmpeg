# 2passffmpeg
Script om gemakkelijk mijn voorkeursparameters voor ffmpeg in te stellen, vooral voor 2-pass hercompressie.

Het script laat toe om alle ffpmeg-opties rechtstreeks op te geven. De equivalente opties van het script zelf zijn ofwel korter, of dienen voor automatische afleidingen van waarden en andere ffmpeg-opties. Gebruik daarom, waar mogelijk, de equivalente opties van het script i.p.v. die van ffmpeg.

## GEBRUIK:
 `2passffmpeg.sh -h` voor korte help
 `2passffmpeg.sh --help` voor uitgebreide help

## NODIG:
* bash
* ffmpeg, als het kan gecompileerd met libfdk_aac, libx265, libx264, libxvid en libmp3lame
* ffprobe, ergens op het pad
* mijn script [ffprobewaarden](https://github.com/db-inf/ffprobewaarden), ergens op het pad
* voor uw comfort: mijn scripts voor [externe process controle](https://github.com/db-inf/externe-procescontrole)
* getopt, nice, cat, ergens op het pad
