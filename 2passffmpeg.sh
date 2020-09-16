#!/bin/bash
##script om video te hercomprimeren naar h.265/h.264 of XviD, met geluid in mp3 of AAC
## GEBRUIK: 2passfmpeg.sh -h of 2passfmpeg.sh --help
function main()
{ # met alles in een functie moeten we niet kiezen tss. return of exit, en kunnen we local variabelen gebruiken
  # OPM: local maakt evt. externe variabelen met dezelfde naam onzichtbaar, ook voor unset. Overigens verwijdert unset
  #  alleen de waarde van de locale naam, maar de naam blijft local, en bekend bij declare.
 local fc parms vcodec vidbitrate acodec avbr_lame avbr_aac avbr_he2aac ext doel longoptions xpassffmpeg_resetextglob getoptlongoptions tmpGetopt dryrun pid singlepass pass2only postopts_pass1_script postopts_pass2_script inopts_pass1_script inopts_pass2_script concat ext metadata chapters uitopts_pass1_script uitopts_pass2_script novfr filteropts_pass1_script filteropts_pass2_script vcodec vidbitrate bronbr rasterbr tune vprofile preset acodec avbr_aac avbr_he2aac avbr_lame audiorate he2 spraak surround invoer bronbestand1 bronnaam brondir uitvoer ffmpeg_overschrijven mv_overschrijven modus_help_optie channels qual_bit_rate total_audio_bit_rate bR geom_bit_rate bron_sample_rate x265params threadsffmpeg threads stats passparms

 ## als ffmpeg extern gedefiniëerd is, nemen we die
 [ -z "$ffmpeg" ] && local ffmpeg="/opt/ffmpeg-dirk/ffmpeg"	## eigen build, zonder libxvid e.a. maar met mpeg4 (kan xvid
															## vervangen), fdk_aac met HE2, hevc (h.265), screen capture, ...
 #local ffmpeg=ffmpeg						## default Ubuntu versie gewoon van path :
 #local ffmpeg=/opt/ffmpeg/ffmpeg			## John Van Sickle's  static build als ffmpeg in /opt/ffmpeg
 #local ffmpeg=/opt/ffmpeg/ffmpeg-fdkaac		## ronny1982's oudere static build met fdkaac (ook HEVC 8/10 bit and HE-AAC) 

 ## AFHANDELING PARAMETERS
 ## ----------------------
 # verwijder lege parameters (bash ./script "";source ./script " ";. ./script "\t";. ./script "$nietGezetteVar";./script "$legeVar")
 #	OPM: makkelijker dan sluitende tests op b.v. resultaaat ffprobewaarden waarmee we dit script kunnen aanroepen
 #	OPM: ook getopt is hier gevoelig aan
 parms=();for parm in "$@";do [ -z "$(echo $parm)" ] || parms+=("$parm");done #	"$(echo $parm)" is "" als parm alleen IFS-chars " \t\n" bevat
 set -- "${parms[@]}" #stelt positional parameters terug in uit parm
 # defaults (zeker nodig bij sourced script)
 pid=${$}	# process ID, tenzij anders per optie --pid
 vcodec=("-c:v" "libx265")	# default video encoder, zonder opties
 vidbitrate=0	# voor het gemak numeriek i.p.v. ""
 acodec=("-c:a" "libfdk_aac")	# default geluid encoder en geluid opties (verzameld, enkel nodig voor pass 2)
 avbr_lame=6 avbr_aac=3 avbr_he2aac=2
 ext=mp4
 # --doel=xxx is directory voor uitvoer en voor evt. links naar scripts in ~/Documents/shellscripts/ExternalProcessControl
 doel="/media/ramdisk"
 #doel="/media/sdata/WERK/downloads/_hercompressie"

	# - Categorieën voor --help beginnen met '=', en worden verwijderd uit de waarde voor de --longoptions parameter van getopt.
	#  Moest dat om een of andere reden niet lukken, dan is dat geen ramp, want longoption-namen die met '=' beginnen, worden
	#  door getopt aanvaard, maar kunnen bij uitvoering toch niet als parameter opgegeven worden: b.v. in "--=cat" zou "=cat"
	#  de waarde zijn van de optie, maar de "--" als dubbelzinnige afkorting van elke mogelijke "--optie".
	# - Zet help als laatste in longoptions, zodat --help zichzelf aanroept als laatste --optie in modus_help_optie, en het
	#  script afsluit; we zetten de help-tekst voor help niet bij case --help, maar aan het einde van case "--=Algemeen".
 longoptions='=Algemeen,dryrun,pid:,1pass,singlepass,pass2only,postopts::,=Invoeropties,inopts::,concat::,=Uitvoeropties,doel:,ext:,metadata,chapters,uitopts::,novfr,filteropts::,=Video-encoders,265::,x265::,h265::,libx265::,264::,x264::,h264::,libx264::,xvid::,libxvid::,mpeg4::,vcopy,=Video-opties,vbr:,bronbr::,rasterbr::,tune:,profile:,preset:,x265params:,=Geluid-encoders,fdk_aac::,libfdk_aac::,aac::,mp3::,lame::,libmp3lame,acopy,an,=Geluid-opties,avbr:,ar:,he2,spraak,surround,help'
 fc=-1
	# activate extended globbing patterns like +(/) (is default ON, maar wil zeker zijn)
 xpassffmpeg_resetextglob=$(shopt -p extglob)	# -p : print syntax to set current state
 shopt -s extglob
	# OPM: getopt wil ALTIJD een optstring (short options), met of zonder -o
	# OPM: NIET tmpGetopt=($(getopt ...)), want getopt's quoting van output met spaties is niet geschikt voor array assignment
	# verwijder de pseudo-opties van de vorm '=Hoofdstuk' uit de optiestring, voor hem aan getopt te geven
 getoptlongoptions="${longoptions//=+([!,]),}"
	# om optie-helptekst te vragen, willen we geen optie-waarden ingeven: verwijder alle ':'
	[ "$1" = "-h" -o "$1" = "-help"  -o "$1" = "--help" ] && # OPM: niet compleet, test niet op afkortingen van "help"
		getoptlongoptions="${longoptions//:}"
 tmpGetopt=$(getopt --name 'getopt(lib)' --alternative --options "+h" --longoptions "$getoptlongoptions" -- "$@")
	# -a, --alternative : laat -longoption ook toe
	# -o, --option "+..." : stop na 1ste non-option argument (i.e. bestandsnaam) met te proberen opties te herkennen (en
	#	te verschuiven naar vóór dat non-option argument); goed om meerdere bestandsnamen met expliciete ffmpeg-argumenten te geven,
	#	b.v. ... bestand1 -f vobsub -i bestand2 ...
 [ $? -ne 0 ] && { # We need tmpGetopt as the 'eval set --' would nuke the return value of getopt.
	 >&2 echo -e "\e[1;31;107mERROR $fc: getopt kan niet alle opties verwerken\e[0m"; return "$fc"; }
 $xpassffmpeg_resetextglob # reset
	# eval zorgt dat de words in "$tmpGetopt" alsnog goed gesplitst worden
 eval set -- "$tmpGetopt" || { >&2 echo -e "\e[1;31;107mERROR $fc: getopt niet goed vertaald naar positional parameters:\e[0m";echo "$tmpGetopt"; return "$fc"; }

 while true; do
	case "$1" in
	'--=Algemeen')	# OPM: "naam" here-doc tss. aanhalingstekens, want er staan veel '$' in de tekst
		echo -e "#\n# ${1:3}\n# ${1//?/=}\b\b\b   "
		cat <<-"help" # ENKEL VOOR --=Algemeen : heredoc-naam <<-"help" i.p.v. <<-help, om bash-variabelen niet te vervangen
		# Bash-script voor hercompressie van video-bestanden met ffmpeg, in 2 doorgangen: analyse in de 1ste,
		# compressie in de 2de. Dit script zoekt o.a. getopt, ffprobe, en het uitvoerbaar script ffprobewaarden.
		# (https://github.com/db-inf/ffprobewaarden) in het pad.
		#
		# GEBRUIK:
		#	$ source 2passffmpeg [--optie[=waarde]]... [--] bronbestand \
		#	  [-ffmeg-optie [optiewaarde] | [-i] [extrabestand] | ["demuxdirectief"] ]...
		#	$ . 2passffmpeg ...
		#	$ 2passffmpeg ...
		#	$ bash 2passffmpeg ...
		help
		[ "$modus_help_optie" != "kort" ] && cat <<-"help"
		#	- de vorm met "source" of "." is aanbevolen bij herhaalde aanroepen, omdat het process ID deel is van de naam
		#	 van de statistiek-bestanden uit de 1ste doorgang, die nodig zijn voor de 2de. Als het script niet met "source"
		#	 wordt uitgevoerd, is dat telkens een andere PID, dus een nieuwe bestandsnaam, en loopt de \tmp schijf vol.
		#	- De parameters --optie[=waarde] worden vertaald naar ffmpeg opties
		#	  - namen van opties mogen verkort worden als dat nog een unieke optie-string geeft
		#	  - bij opties met een optionele waarde is de '=' verplicht, bij de andere mag het een spatie zijn.
		#	  - lange optienamen mogen ook met 1 koppelteken geschreven worden, b.v. -help i.p.v. --help (experimenteel!),
		#	   maar een mogelijke interpretatie als een reeks van 1-letter-opties heeft dan voorrang.
		#	- Als het pad naar "bronbestand" begint met een '-', wordt de optionele '--' ervoor verplicht.
		#	- "-i bronbestand" wordt ingevoegd als 1ste invoerbestand in de ffmpeg-opdracht.
		#	- "-ffmeg-optie [optiewaarde]" en "-i extrabestand" worden letterlijk ingevoegd in de ffmpeg-opdracht, direct
		#	 na "bronbestand", in de opgegeven volgorde. Deze functionaliteit dubbelt deels met --uitopts.
		#	  - Parameters van video- en geluidsspoor worden afgeleid uit "bronbestand", nooit uit "extrabestand". Deze
		#	   parameters zijn o.a. nodig bij de opties --bronbr, --rasterbr, --ar=[12]k], en zonder de optie --surround.
		#	  - De vorm "extrabestand", zonder "-i" voor, dient enkel bij gebruik van de --concat parameter, die elk
		#	   "extrabestand" toevoegt na "bronbestand", in het formaat voor het concat protocol dan wel de concat
		#	   demuxer. Met "--concat" is geen expliciete -ffmpeg-optie mogelijk, maar de concat demuxer aanvaardt na
		#	   "bronbestand" en elk "extrabestand" directieven als "inpoint hh:mm:ss.mmm" en "outpoint hh:mm:ss.mmm".
		help
		cat <<-"help"
		#
		# VOORBEELD
		#	- 1 brondbestand hercomprimeren:
		#	  $ . 2passffmpeg.sh --doel=/media/ramdisk --vbr=999k --ar=22050 --preset=slow bronbestand
		#	    --doel=directory : uiteindelijke doeldirectory (tusentijds in /tmp)
		#	    --vbr=999k video bitrate 999kb/s (bij ontstentenis berekend uit pixelraster en framerate)
		#	    --ar=22050 voor herleiding van de bemonsteringssnelheid van geluid tot 22050kHz
		#	   --preset=slow : gebruikt meer compressie-mogelijkheden dan de default 'medium'
		#	- een reeks bronbestanden hercomprimeren:
		#	  $ epcdir=/media/ramdisk; for a in *.avi; do [ -f "$a" ] && \
		#	    . 2passffmpeg.sh --doel="$epcdir" ... "$a";done
		#	- een reeks samenvoegbare bestanden samengevoegd hercomprimeren (met het ffmpeg concat protocol)
		#	  $ . 2passffmpeg --concat ... --doel="/media/schijf" bronbestand extrabestand ...
		#	- hercomprimeren en de 1ste uit een set aparte bitmap ondertitels invoegen in .mkv-bestand :
		#	  $ . 2passffmpeg --ext=mkv --uitopts="2: -map 0:V -map 0:a -map 1:s:0 -c:s dvd_subtitle" ... \
		#	     brondbestand -i bron.idx -i bron.sub
		help
		[ "$modus_help_optie" != "kort" ] && cat <<-"help"
		#
		# Externe procescontrole
		# ======================
		# Dit scripts sluit via een zelf te plaatsen symbolic link vanuit de directory "$epcdir/" de
		# proces-controlebestanden (https://github.com/db-inf/externe-procescontrole) _threads, _pauze?,
		# _slaap? en _uit? in, voor zover ze gevonden worden (anders volgt een bash foutboodschap, maar
		# het script doet verder zijn werk). Als dit script in een loop wordt aangeroepen, kan die loop
		# gepauzeerd of afgebroken worden door die symlinks in "$epcdir/" een gepaste naam te geven; zoals 
		# beschreven in die bestanden zelf. Concreet gebruikt dit script het bestand _threads als optie
		# voor ffmpeg, op het einde de scripts _slaap* en _uit*, en voor elke ffmpeg-pass de scripts
		# "_pauze* _pauze1" resp. "_pauze* _pauze2". 
		#
		# VOORBEELD
		#	- een set afleveringen hercomprimeren: de opdracht kan in meerdere shells tegelijk uitgevoerd worden,
		#	 met elk hun eigen processcontrole door de parameter _pauzeterm1 te veranderen. Elke sessie maakt bij
		#	 aanvang een leeg bestand aan met de doelnaam (touch), om een claim te leggen op die aflevering.
		#	  $ epcdir="/media/_hercompressie" ext=mp4; for a in *.{mp4,m4v,avi,mov,wmv,mkv}; do \
		#	    . "$epcdir/_pauze"* _pauzeterm1; \
		#	    [ -f "$a" -a ! -f "$epcdir/${a%.*}.$ext" ] || continue; touch "$epcdir/${a%.*}.$ext"; \
		#	    . ~/Documents/shellscripts/2passffmpeg.sh --doel="$epcdir" --ext="$ext" --bron=105% --raster=105% \
		#	    --he2 --avbr=2 --ar=1k "$a";
		#	    done
		#
		# Bash variabelen
		# ===============
		# Als de onderstaande bash-variabelen gedefiniëerd zijn, worden ze gebruikt in dit script.
		# - OPGELET: tenzij het script wordt uitgevoerd met de opdracht source- of '.', moet de variabele
		#  geëxporteerd zijn, b.v. "export epcdir=/media/ramdisk", of direct in het environment geplaatst:
		#  "epcdir=/media/ramdisk 2passffmpeg.sh ...". Opgelet: in het 2de geval kan de waarde niet gebruikt
		#  worden op de opdrachtlijn zelf, want het is geen shell variabele.
		# - $ffmpeg : pad naar de te gebruiken versie van ffmpeg; default "/opt/ffmpeg-dirk/ffmpeg"
		# - $epcdir : pad naar de directory met de scripts voor externe procescontrole (zie hoger); default "$doel"
		# - ${inopts1[@]}, ${inopts2[@]} en ${inopts[@]} : array met ffmpeg-opties te plaatsen voor de "-i invoer"
		#  van resp. de 1ste, de 2de of elke pass
		#	- deze opties wordt alleen gebruikt in het script, als de parameter --inopts
		#	 wordt opgegeven met waarde "1:"  of "2:" voor pass 1 of 2, of zonder waarde voor elke pass.
		#	- meerdere parameters (zie "Meervoudige parameters"), kunnen soms opgegeven worden als 1 splitsbare
		#	 waarde tussen aanhalingstekens met de optie --inopts, b.v. --inopts="-ss 60 -t 300"
		# - ${uitopts1[@]}, ${uitopts2[@]} en ${uitopts[@]} : array met ffmpeg-opties te plaatsen na de "-i invoer"
		#	van resp. de 1ste, de 2de of elke pass
		#	- verder zoals inopts
		# - ${filteropts1[@]}, ${filteropts2[@]} en ${filteropts[@]} : array met ffmpeg-opties te plaatsen na de --uitopts
		#	 van resp. de 1ste, de 2de of elke pass.
		#	- verder zoals inopts
		# - ${postopts1[@]}, ${postopts2[@]} en ${postopts1[@]} : array met ffmpeg-opties te plaatsen na "uitvoerbestand"
		#	van resp. de 1ste, de 2de of elke pass, b.v. om nog een 2de uitvoer te doen van dezelfde invoer
		#	- verder zoals inopts
		help
		cat <<-"help"
		#
		# Meervoudige parameters
		# ======================
		# Voor een aantal opties laten we een verplichte of facultatieve optie-waarde uit elkaar vallen
		# in words door ze te expanderen als $2 i.p.v. "$2", o.a. --inopts en de --encoder-keuzes. Ge kunt
		# ze opgeven tussen quotes als er zelf GEEN QUOTES EN SPATIES instaan, b.v.
		#	--uitopts="-filter_complex [0:v]yadif[tmp],[tmp][1:s]overlay"
		#	OF
		#	--libfdk_aac="-af pan=stereo|FL<FC+0.707*FL+0.30*BL|FR<FC+0.707*FR+0.30*BR"
		# Redirects en pipes ">", "<" en "|" worden geïnterpreteerd vóór de expansie van variabelen, en geven
		# dus geen probleem.
		# Als meervoudige parameters wel problemen geven voor woordsplitsing, kunnen ze vooraf in een bash
		# array gezet worden via het mechanisme beschreven voor o.a. --inopts in de sectie "Bash variabelen".
		#
		# Algemene opties
		# ===============
		#	-h [--optienaam]...: Toon een korte help-tekst, of volledige help-tekst voor de gevraagde optienaam(en)
		#	--help [--optienaam]...: Toon volledige help-tekst, of volledige help-tekst voor de gevraagde optienaam(en)
		help
		;;
	'--dryrun')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1 : doorloopt script, bepaalt b.v. ook video bitrates, maar echoot de samengestelde ffmpeg-
			#		opdrachten zonder ze uit te voeren, zodat ge die met gepast toevoegen van quotes en evt.
			#		bijkomend maatwerk naar een opdrachtlijn kunt kopiëren.
			help
		else
			# OPM: als dryrun unset is, faalt nice met expansie 'nice "$dryrun" ...' op lege positional parameters;
			#	daarom expanderen als array, b.v. nice "${dryrun[@]}" ...
			dryrun="echo"
		fi
	;;
	'--pid')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1=id : geef een andere identificatie dan process ID voor statistiekbestanden van pass 1 of het
			#		script voor de concat demuxer.
			help
			[ "$modus_help_optie" != "kort" ] && cat <<-help
			#		Om dit script gelijktijdig te kunnen uitvoeren in meerdere processen, wordt het process id
			#		\$\$ opgenomen in de naam van die bestanden. Met deze optie kan een andere identificatie opgegeven
			#		worden, best een unieke, b.v. om met "--pass2only" de statistiekbestanden van een eerdere sessie
			#		te hergebruiken. Omwille van de syntax van "-x265-params", bevat "id" best geen ':'.
			help
		else
			pid="$2"
			shift #shift ook $2
		fi
	;;
	'--1pass'|'--singlepass')
		if [ -v modus_help_optie ]
		then [ "${1::3}" = "--1" -a "$modus_help_optie" != "optie" ] && echo -e "#\t$1" || cat <<-help
			#	$1 : doe een gewone 1-pass hercompressie; intern is het de 1ste doorgang, de analysestap, die wordt
			#		overgeslagen, en enkel de instellingen voor de 2de doorgang worden gebruikt.
			help
		else
			singlepass=y
		fi
	;;
	'--pass2only')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1 : voer enkel de 2de doorgang uit, b.v. om de analyse-statistieken van een eerdere uitvoering te
			#		hergebruiken; enkel de instellingen voor de 2de doorgang worden gebruikt. Indien nodig kunt u 
			#		met de optie "--pid" de process identificatie van de 1ste doorgang opgeven.
			help
		else
			pass2only=y
		fi
	;;
	'--postopts')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1[="optie-strings voor bijkomende uitvoer"] : 1 of meerdere ffmpeg-opties om een 2de uitvoer te koppelen 
			#		aan dezelfde invoer, volgens de beschrijving onder de sectie "Meervoudige parameters".
			help
			[ "$modus_help_optie" != "kort" ] && cat <<-help
			#		Opties die enkel voor de 1ste of de 2de doorgang gelden, worden opgegeven in een optie-string
			#		die begint met de tekens "1:" dan wel "2:".
			# 		De "$1" opties worden in de ffmpeg-opdracht ingevoegd na de naam van het 1ste uitvoer-bestand.
			#		Meerdere "$1" parameters worden in opgegeven volgorde na elkaar toegevoegd.
			#	
			#		Voorbeelden van bijkomende uitvoeren (meestal enkel zinvol in 1 van de doorgangen):
			#		------------------------------------
			# 		- bewaar interne tekst-ondertitels bij 2de doorgang in extern bestand in subrip-formaat:
			#		  $1="2: -map s -c:s subrip naam.taal.srt"
			help
		else
			if [ "${2::2}" = "1:" ]
			then
				[ -z "${2:2}" ] && postopts_pass1_script+=("${postopts1[@]}") ||
					postopts_pass1_script+=(${2:2})	# laat $2 uiteenvallen in onderdelen (tss. "" op opdrachtlijn)
			elif [ "${2::2}" = "2:" ]
			then
				[ -z "${2:2}" ] && postopts_pass2_script+=("${postopts2[@]}") ||
					postopts_pass2_script+=(${2:2})	# laat $2 uiteenvallen in onderdelen (tss. "" op opdrachtlijn)
			else
				[ -z "$2" ] && postopts_pass1_script+=("${postopts[@]}") postopts_pass2_script+=("${postopts[@]}") ||
					{ postopts_pass1_script+=($2) postopts_pass2_script+=($2); }	# laat $2 uiteenvallen in onderdelen (tss. "" op opdrachtlijn)
			fi
			shift #shift ook $2
		fi
	;;		
	'--=Invoeropties')
		[ -v modus_help_optie ] && echo -e "#\n# ${1:3}\n# ${1//?/=}\b\b\b   "
		;;
	'--inopts')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1[="optie_strings_voor_invoer"] : 1 of meerdere ffmpeg-opties voor de interpretatie van het invoerbestand,
			#		volgens de beschrijving onder de sectie "Meervoudige parameters".
			help
			[ "$modus_help_optie" != "kort" ] && cat <<-help
			#		Opties die enkel voor de 1ste of de 2de doorgang gelden, worden opgegeven in een optie-string
			#		die begint met de tekens "1:" dan wel "2:".
			# 		De "$1" opties worden in de ffmpeg-opdracht ingevoegd voor de naam van het invoer-bestand.
			#		Meerdere "$1" parameters worden in opgegeven volgorde na elkaar toegevoegd.
			#		- ffmpeg-vertaling, naargelang doorgang 1 of 2 : \$optie_strings_voor_invoer, ontdaan van evt. "1:" of "2:"
			#		 en opgesplitst op de spaties.
			#		- ffmpeg-vertaling zonder optie_strings_voor_invoer, of met enkel "1:" of "2:": de letterlijke elementen
			#		 van de arrays "${invoeropts1[@]}", "${invoeropts2[@]}" resp. "${invoeropts2[@]}", 
			#	
			#		Voorbeelden van invoeropties (meestal enkel zinvol in beide de doorgangen):
			#		---------------------------
			#		- hercompressie-parameters snel op een korte clip uitproberen :
			#		  $1="-ss 350 -t 300 -noaccurate_seek" : 
			# 		  - OPM: -ss en -t  in --inopts zijn niet altijd nauwkeurig, o.a. voor .srt ondertitels, in
			#		   --uitopts wel
			#		  - OPM: -ss en -t  is sneller in --inopts dan in --uitopts, maar moet dan wel voor elke -i
			@		   staan als er meerdere zijn
			#		- bij pass 1 geen andere info dan errors :
			#		  $1="1: -loglevel error
			#		- kleuren dvd-subtitles: palet (16 kleuren) staat in .IFO, ffmpeg leest die niet. Die moet ge dus
			#		 door uitproberen zelf bepalen, b.v. in ffplay, of met een korte clip
			# 		  - meestal zijn enkel 1ste paar entries gebruikt: probeer eerst een clip met een felle kleur voor
			#		   de rest, en zet die achteraf voor de zekerheid op de tekstkleur:
			#		    $1="-ss 10:0 -t 60 -palette aaaa00,00aaaa,000000,ffffff,ffff00,ffff00,ffff00,ffff00,ffff00,ffff00,ffff00,ffff00,ffff00,ffff00,ffff00,ffff00"
			#		    $1="-palette f0d000,706100,383000,f0d000,f0d000,f0d000,f0d000,f0d000,f0d000,f0d000,f0d000,f0d000,f0d000,f0d000,f0d000,f0d000"
			#		- langer zoeken naar begin van een stream, b.v. bitmapped ondertitels die pas na een tijd beginnen:
			#		  $1="-analyzeduration 100M -probesize 100M"
			help
		else
			if [ "${2::2}" = "1:" ]
			then
				[ -z "${2:2}" ] && inopts_pass1_script+=("${inopts1[@]}") ||
					inopts_pass1_script+=(${2:2})	# laat $2 uiteenvallen in onderdelen (tss. "" op opdrachtlijn)
			elif [ "${2::2}" = "2:" ]
			then
				[ -z "${2:2}" ] && inopts_pass2_script+=("${inopts2[@]}") ||
					inopts_pass2_script+=(${2:2})	# laat $2 uiteenvallen in onderdelen (tss. "" op opdrachtlijn)
			else
				[ -z "$2" ] && inopts_pass1_script+=("${inopts[@]}") inopts_pass2_script+=("${inopts[@]}") ||
					{ inopts_pass1_script+=($2) inopts_pass2_script+=($2); }	# laat $2 uiteenvallen in onderdelen (tss. "" op opdrachtlijn)
			fi
			shift #shift ook $2
		fi
	;;
	'--concat')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1[=demuxer|protocol] : concateneer elk "extrabestand" met "bronbestand" met de concat demuxer (default)
			#	 of het concat protocol.
			help
			[ "$modus_help_optie" != "kort" ] && cat <<-help
			#		- de concat demuxer aanvaardt na elk bron~ of extrabestand directieven-strings als "inpoint timestamp",
			#		 "outpoint timestamp" en "duration dur", met timestamp en dur in ffmpeg-formaat.
			#		  - ffmpeg-vertaling : "-f concat -safe 0" en gegenereerd bestand "/tmp/2passffmpeg_pid\${pid}_concatdemux"
			#		   als pseudo-bronbestand
			#		- "the concat protocol works at the file level. Only certain files (MPEG-2 transport streams, possibly others)
			#		 can be concatenated. This is analogous to using cat on UNIX-like systems or copy on Windows."
			#		  - ".mp4-files can be losslessly transcoded to MPEG-2 transport streams to concatenate. All MPEG codecs
			#		   (MPEG-4 Part 10 / AVC, MPEG-4 Part 2, MPEG-2 Video, MPEG-1 Audio Layer II, MPEG-2 Audio Layer III (MP3),
			#		   MPEG-4 Part III (AAC)) are supported in the MPEG-TS container format, although the commands below would
			#		   require some change."
			#		  - b.v. voor mp4 met H.264 video en AAC audio (voor h.265-invoer: idem met "-bsf:v hevc_mp4toannexb"):
			#		     $ ffmpeg -i input1.mp4 -c copy -bsf:v h264_mp4toannexb -f mpegts intermediate1.ts
			#		     $ ffmpeg -i input2.mp4 -c copy -bsf:v h264_mp4toannexb -f mpegts intermediate2.ts
			#		     $ . 2passffmpeg --concat=protocol --libx265="-bsf:a aac_adtstoasc" ...  intermediate1.ts intermediate2.ts
			#		  - ffmpeg-vertaling : gegenereerde string "concat:bronbestand|extrabestand..." als pseudo-bronbestand
			help
		else
	fc=10
			  # breidt afkortingen uit tot volledige naam
			concat="${2:-demuxer}" strdemuxer="demuxer" strprotocol="protocol"
			if [ ${#concat} -gt 1 -a "$concat" = "${strdemuxer::${#concat}}" ]
			then
				concat="$strdemuxer"
			elif [ ${#concat} -gt 1 -a "$concat" = "${strprotocol::${#concat}}" ]
			then
				concat="$strprotocol"
			else
				>&2 echo -e "\e[1;31;107mERROR $fc: concat kent alleen de waarden 'demuxer' (default) en 'protocol': '$2'\e[0m"
				return "$fc"
			fi
			shift #shift ook $2
		fi
	;;
	'--=Uitvoeropties')
		[ -v modus_help_optie ] && echo -e "#\n# ${1:3}\n# ${1//?/=}\b\b\b   "
		;;
	'--doel')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1=doeldirectory : Bestemming van het gehercomprimeerde bestand. De bestandsnaam blijft behouden, op
			#		de extensie na.
			#		Als de variabele \$epcdir nog geen waarde heeft, wordt die ingesteld op de waarde van "$1".
			help
		else
	fc=11	
			[ -z "$2" ] && { >&2 echo -e "\e[1;31;107mERROR $fc: doel '$2' opgegeven\e[0m"; return "$fc"; }
			doel="$2"
			shift #shift ook $2
			# TEDOEN : NOOIT INVOER OVERSCHRIJVEN (zeker niet voor 2-pass).
			#			OPM: test op doel="." of ="$PWD" is niet genoeg, het gaat om directory van bronbestand1
		fi
	;;
	'--ext')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1=extensie : bestandsextensie (default "mp4") van het doelbestand, zonder voorloop-'.'; 
			#		ffmpeg leidt van de extensie ook het container-formaat af.
			help
			[ "$modus_help_optie" != "kort" ] && cat <<-help
			#		- Als ge een niet-standaard extensie opgeeft, moet ge daarom expliciet een containerformaat opgeven
			#		 als uitvoeropties voor b.v. doorgang 2: --ext=mpeg4video --uitopts "2:-f mp4"
			#		- Om een suffix toe te voegen aan de stam van de naam van de invoer, wordt die best door een '.' gescheiden
			#		 van de eigenlijke extensie, zodat ffmpeg nog steeds het containerformaat kan afleiden. B.v. om een vergelijkende
			#		 reeks in verschillende bitrates te maken:
			#		  $ for br in 900k 1000k;do . 2passffmpeg.sh ... --vbr=$br --ext=_$br.mp4 ...;done
			help
		else
	fc=12			# een prefix van de gekende formaten moet eindigen op een '.', zodat ffmpeg dat niet als deel van het doelvormaat beschouwt
			[[ "$2" =~ ^(.*\.)?(mp4|mkv|avi)$ ]] && ext="$2" ||  { >&2 echo -e "\e[1;31;107mERROR $fc: niet ondersteund doelformaat $2\e[0m"; return "$fc"; }
			shift #shift ook $2
		fi
	;;
	'--metadata')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1 : neemt zo mogelijk de metadata van de invoer over in het uitvoerbestand; default wordt die niet overgenomen.
			help
			[ "$modus_help_optie" != "kort" ] && cat <<-help
			#		- ffmpeg-vertaling : bij ontstentenis "-map_metadata:g -1 -map_metadata:s -1 -map_metadata:c -1 \\
			#		  -map_metadata:p -1"
			help
		else
			metadata=y
		fi
	;;
	'--chapters')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1 : neemt zo mogelijk de chapters metadata van de invoer over in het uitvoerbestand; default wordt
			#		die niet overgenomen.
			help
			[ "$modus_help_optie" != "kort" ] && cat <<-help
			#		- ffmpeg-vertaling : bij ontstentenis "-map_chapters -1"
			help
		else
			chapters=y
		fi
	;;
	'--uitopts')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1[="optie_strings_voor_uitvoer"] : 1 of meerdere ffmpeg-opties voor het aanmaken van het uitvoerbestand,
			#		volgens de beschrijving onder de sectie "Meervoudige parameters".
			help
			[ "$modus_help_optie" != "kort" ] && cat <<-help
			#		Opties die enkel voor de 1ste of de 2de doorgang gelden, worden opgegeven in een optie-string
			#		die begint met de tekens "1:" dan wel "2:".
			# 		De "$1" opties worden in de ffmpeg-opdracht ingevoegd direct na de naam van het invoer-bestand, zodat ge met
			#		"$1" evt. ook extra invoerbestanden kunt opgeven.
			#		Meerdere "$1" parameters worden in opgegeven volgorde na elkaar toegevoegd.
			#		- ffmpeg-vertaling, naargelang doorgang 1 of 2 : \$optie_strings_voor_uitvoer, ontdaan van evt. "1:" of "2:"
			#		 en opgesplitst op de spaties.
			#		- ffmpeg-vertaling zonder optie_strings_voor_uitvoer, of met enkel "1:" of "2:": de letterlijke elementen
			#		 van de arrays "${uitvoeropts1[@]}", "${uitvoeropts2[@]}" resp. "${uitvoeropts2[@]}", 
			#	
			#		Voorbeelden van uitvoeropties (meestal enkel zinvol in beide de doorgangen):
			#		-----------------------------
			#		- hercompressie-parameters snel op een korte clip uitproberen :
			#		  $1="-ss 350 -t 300" : 
			# 		  - OPM: -ss en -t  in --inopts zijn niet altijd nauwkeurig, o.a. voor .srt ondertitels, in $1 wel
			#		  - OPM: -ss en -t  is sneller in --inopts dan in $1, maar moet dan wel voor elke -i staan als er meerdere zijn
			#		- aspect ratio instellen :
			#		  $1="-aspect 4:3"
			#		- hercomprimeer echte video en (in pass 2) eerste geluid :
			#		  $1="-map V" $1="2: -map a:1"
			#		- verwijder ondertitels :
			#		  $1="-sn"
			#		- laat ffmpeg langer naar 1ste video frame zoeken (b.v. bij stilstaand openingsbeeld): sommige codecs lezen dit
			#		 als dropped frames, en dan moet de geluid-buffer groter om "Too many packets buffered for output stream 0:1"
			#		 te vermijden :
			#		  $1="2: -max_muxing_queue_size 10000" :
			#		  - OPM: aangezien in de 1ste doorgang geluid genegeerd wordt, is dit enkel relevant in de 2de doorgang.
			#		- video uit het normale invoerbestand (laatste parameter), subs uit een 2de en geluid uit een 3de bestamd
			#		  $ for film in *.mp4;do uitopts=(-i "${film%.*}.idx" -i "/anderpad/${film%.*}.m4a" -map 0:V);. 2passffmpeg.sh
			#		    $1 $1="2:-map 2:a" ... "$film"
			#		  - OPM: ondertitels inbakken: zie --filteropts
			#		- hercomprimeer, en bewaar van ingesloten bitmap ondertitels enkel het 2de (nederlandse) spoor zonder ze
			#		 in te branden. Dit gebeurt in doorgang 2, en vereist uitvoer in .mkv:
			#		  $1="2: -map V -map a -map s:1 -c:s copy -metadata:s:s language=dut" --ext=mkv \\
			#		    --inopts="2: -probesize 100M -analyzeduration 100M"
			help
		else
			if [ "${2::2}" = "1:" ]
			then
				[ -z "${2:2}" ] && uitopts_pass1_script+=("${uitopts1[@]}") ||
					uitopts_pass1_script+=(${2:2})	# laat $2 uiteenvallen in onderdelen (tss. "" op opdrachtlijn)
			elif [ "${2::2}" = "2:" ]
			then
				[ -z "${2:2}" ] && uitopts_pass2_script+=("${uitopts2[@]}") ||
					uitopts_pass2_script+=(${2:2})	# laat $2 uiteenvallen in onderdelen (tss. "" op opdrachtlijn)
			else
				[ -z "$2" ] && uitopts_pass1_script+=("${uitopts[@]}") uitopts_pass2_script+=("${uitopts[@]}") ||
					{ uitopts_pass1_script+=($2) uitopts_pass2_script+=($2); }	# laat $2 uiteenvallen in onderdelen (tss. "" op opdrachtlijn)
			fi
			shift #shift ook $2
		fi
	;;		
	'--novfr')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1 : behoudt het standaard gedrag van ffmpeg voor wat betreft variabele video frame rate.
			help
			[ "$modus_help_optie" != "kort" ] && cat <<-help
			#		- "for MP4, ffmpeg defaults to constant-frame rate, where it picks [ffprobe-waarde] r_frame_rate as the value.
			#		 It will then duplicate or drop frames to keep that rate."
			#		- Variabele framerate is nochtans een van de sterke compressie-kansen van h.264 en h.265. Zowat elk
			#		 containerformaat kan variabele framerate aan, dus dit script gebruikt standaard een ffmpeg-optie om de
			#		 originele frame timestamps en framerate te bewaren, ook variabele. Deze optie $1 laat dat achterwege.
			#		- Bronnen met variabele framerate zijn te herkennen met aan fps != tbr (ffprobe) of
			#		 r_frame_rate != avg_frame_rate (ffprobewaarden). Eigenlijk is r_frame_rate geen framerate:  het is 
			#		 "the least common multiple of all framerates in the stream", en daardoor "the lowest framerate with which
			#		 all timestamps can be represented accurately". Het is dus een veelvoud van elke andere feitelijke
			#		 framerate in de bron, en mogelijk veel te hoog om te misbruiken als nieuwe vaste framerate.
			#		- ffmpeg-vertaling : bij ontstentenis "-vsync vfr"
			help
		else
			novfr=y
		fi
	;;
	'--filteropts')
		# OPM filters kunnen ook bij --uitopts opgegeven worden, maar vooral voor buiten-script arrays hou ik ze liever apart
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1[="optie_strings_voor_filters"] : 1 of meerdere ffmpeg-opties voor het filteren van de invoer 
			#		(geluid en/of video), volgens de beschrijving onder de sectie "Meervoudige parameters".
			help
			[ "$modus_help_optie" != "kort" ] && cat <<-help
			#		Filters die enkel voor de 1ste of de 2de doorgang gelden, worden opgegeven in een optie-string die begint 
			#		met de tekens "1:" dan wel "2:".
			#		Elke filter begint met de te gebruiken ffmpeg-optie, zoals "-filter:v", "-af" of "-filter_complex".
			# 		De "$1" opties worden in de ffmpeg-opdracht ingevoegd na evt. uitvoer-opties (zie --uitopts) en voor video-
			#		en geluid encoders en hun opties. Meerdere "$1" parameters worden in opgegeven volgorde na elkaar ingevoegd.
			#		Filteropties kunnen ook bij --uitopts geplaatst worden, of bij de string voor de geluid- of video-encoder,
			#		maar door de soms ingewikkelde filter-opties een eigen optienaam te geven, is het gemakkelijker om eenvoudige
			#		opties elders uit te testen en weer weg te laten.
			#		- ffmpeg-vertaling, naargelang doorgang 1 of 2 : \$optie_strings_voor_filters, ontdaan van evt. "1:" of "2:"
			#		 en opgesplitst op de spaties.
			#		- ffmpeg-vertaling zonder optie_strings_voor_filters, of met enkel "1:" of "2:": de letterlijke elementen
			#		 van de arrays "${filteropts1[@]}", "${filteropts2[@]}" resp. "${filteropts2[@]}", 
			#	
			#		Voorbeelden van geluid-filters (meestal enkel zinvol in 2de doorgang:
			#		-----------------------------
			#		- herleid naar mono-geluid : $1="2: -ac 1"
			#		- gebruik bash array voor geluid filter in pass 2: herleid stereo naar mono, met meer nadruk op het
			#		  oorspronkelijke linker-kanaal :
			#		  filteropts2=("-af" "pan=1c|c0=0.6*c0+0.4*c1"); ffmpeg ... $1=2: ...
			#		- herleid naar 2 kanalen, maar geef ze dezelfde inhoud, nl. de som van beide, in stereo-layout :
			#		  filteropts2=("-ac" "2" "-af" "pan=stereo|c0<c0+c1|c1<c0+c1"); ffmpeg ... $1=2: ... 
			#	
			# 		Voorbeelden van video-filters :
			#		-----------------------------
			#		- doe alsof input vierkante pixels heeft (sample aspect ratio); 'display aspect ratio' van output
			#		  wordt sar x width / height:
			#		  $1="-vf setsar=sar=1/1" :
			#		- high quality noise filter met veel opties, defaults zijn al zeer goed :
			#		  $1="-vf hqdn3d"
			#		- Adaptive Temporal Averaging Denoiser over 5 tot 129 frames (altijd oneven, default 9)
			#		  $1="-vf atadenoise=s=5" : pver 5 frames, rest defaults
			#		  - beter dan de generieke optie "-nr integer" (noise reduction) van libavcodec (geen ffmpeg video filter)
			#		- vergroot of verklein naar 1280 breed, met behoud van hoogte/breedte-verhouding :
			#		  $1="-vf scale=1280:-1"
			#		- leg het gebruikelijke pixelformaat op, o.a. om HuffYuv in andere gangbare encoders te comprimeren
			#		  $1="-vf format=yuv420p" OF zijn alias $1="-pix_fmt yuv420p"
			#		- kleur verwijderen :
			#		  $1="-vf format=gray"
			#		- deinterlacing (yet another deinterlacing filter), zie (https://ffmpeg.org/ffmpeg-filters.html#yadif) 
			#		  $1="-vf yadif" : met default instellingen
			#		- deinterlacing met bwdif (Bob Weaver Deinterlacing Filter), een afgeleide van yadif :
			#		  $1="-vf bwdif=0:-1:0" : Output one frame for each frame, auto-parity, deinterlace all frames
			#		- deinterlace video, en bitmap subs inbakken: (geen verdere mapping nodig: elke input van filter gaat niet 
			#		  meer door naar output, en output van videofilter wordt hoofd-videostream
			#		  $1="-filter_complex yadif[tmp],[tmp][1:s]overlay"
			#		- deinterlace 2de video-stream, bitmap subs inbakken, andere videostreams laten vallen, en pixel formaat
			#		 veranderen:
			#		  $1="-filter_complex [v:1]yadif[tmp];[tmp][0:s]overlay[v_out] -map [v_out]
			#		  -map a -pix_fmt yuv420p"
			#		- witte bitmap-ondertitels vergulden (maar eerst format=yuva444p: subsampling verwijderen, met behoud van
			#		  alpha, want filters zoals colorlevels en colorbalance heffen die gewoon op, met verdubbeling van breedte
			#		  tot gevolg), en ondertiels inbakken in video:
			#		  $1="-filter_complex [s:0]format=yuva444p,colorbalance=rh=0.7:gh=0.1:bh=-.9[subs];
			#		  [V][subs]overlay"
			#		- BlueRay-ondertitels vergelen, dan vergroten (van 1440x1080 naar 1733x1300), terug centreren en verlagen
			#		  $1="-filter_complex [s:0]format=yuva444p,colorlevels=rimax=0.9:gimax=0.4:bimin=0.75,
			#		  scale=-1:1300[subs];[V][subs]overlay=(main_w-overlay_w)/2:main_h-overlay_h+70"
			#		- als bron 30.04-30.05 fps heeft, kan dat een lawine van waarschuwingen geven zoals
			#		  "Past duration 0.992332 too large"; geef de invoer dan een vaste framerate met :
			#		  $1="-filter:v fps=30"
			help
		else
			if [ "${2::2}" = "1:" ]
			then
				[ -z "${2:2}" ] && filteropts_pass1_script+=("${filteropts1[@]}") ||
					filteropts_pass1_script+=(${2:2})	# laat $2 uiteenvallen in onderdelen (tss. "" op opdrachtlijn)
			elif [ "${2::2}" = "2:" ]
			then
				[ -z "${2:2}" ] && filteropts_pass2_script+=("${filteropts2[@]}") ||
					filteropts_pass2_script+=(${2:2})	# laat $2 uiteenvallen in onderdelen (tss. "" op opdrachtlijn)
			else
				[ -z "$2" ] && filteropts_pass1_script+=("${filteropts[@]}") filteropts_pass2_script+=("${filteropts[@]}") ||
					{ filteropts_pass1_script+=($2) filteropts_pass2_script+=($2); }	# laat $2 uiteenvallen in onderdelen (tss. "" op opdrachtlijn)
			fi
			shift #shift ook $2
		fi
	;;		
	'--=Video-encoders')
		[ -v modus_help_optie ] && echo -e "#\n# ${1:3}\n# ${1//?/=}\b\b\b   " &&
			cat <<-help
			# Elk van de video-encoder-parameters aanvaardt optioneel 1 of meerdere bijkomende ffmpeg-opties t.b.v. de
			# encoder in de vorm --%encoder-naam%="[-ffmpegoptie [waarde]]...", volgens de beschrijving in de sectie
			# "Meervoudige parameters". Dit geldt natuurlijk niet voor de oneigenlijke encoder --vcopy.
			# 
			help
		;;
	# OPM: --vn en --vcopy, naar analogie met geluid opties, hebben geen zin, want dan hebben we geen 2-pass ffmpeg van doen.
	'--265'|'--x265'|'--h265'|'--libx265')
		if [ -v modus_help_optie ]
		then [ "${1::5}" != "--lib" -a "$modus_help_optie" != "optie" ] && echo -e "#\t$1" || cat <<-help
			#	$1=["ffmpeg_opties"] : hercodeer video naar h.265-formaat met de libx265 High Efficiency Video Codec.
			#		Dit is de default encoder van 2passffmpeg, maar met deze parameter kunnen extra opties opgegeven worden.
			help
			[ "${1::5}" = "--lib" -a "$modus_help_optie" = "lang" -o "$modus_help_optie" = "optie" ] && cat <<-help
			#		- ffmpeg-vertaling : "-c:v libx265 \$ffmpeg_opties" (die laatste opgesplitst op de spaties)
			help
		else
			# is hoger ingesteld default, maar met expliciete optie kunnen we extra parameters opgeven
			vcodec=("-c:v" "libx265" $2)	# laat $2 uiteenvallen in onderdelen (tss. "" op opdrachtlijn)
			shift #shift ook $2
		fi
	;;
	'--264'|'--x264'|'--h264'|'--libx264')
		if [ -v modus_help_optie ]
		then [ "${1::5}" != "--lib" -a "$modus_help_optie" != "optie" ] && echo -e "#\t$1" || cat <<-help
			#	$1=["ffmpeg_opties"] : hercodeer video naar h.264-formaat met de libx264 Advanced Video Codec.
			help
			[ "${1::5}" = "--lib" -a "$modus_help_optie" = "lang" -o "$modus_help_optie" = "optie" ] && cat <<-help
			#		- ffmpeg-vertaling : "-c:v libx264 \$ffmpeg_opties" (die laatste opgesplitst op de spaties)
			help
		else
			vcodec=("-c:v" "libx264" $2)	# laat $2 uiteenvallen in onderdelen (tss. "" op opdrachtlijn)
			shift #shift ook $2
		fi
	;;
	'--xvid'|'--libxvid')
		if [ -v modus_help_optie ]
		then [ "${1::5}" != "--lib" -a "$modus_help_optie" != "optie" ] && echo -e "#\t$1" || cat <<-help
			#	$1=["ffmpeg_opties"] : hercodeer video naar h.263-formaat met de libxvid codec.
			help
			[ "${1::5}" = "--lib" -a "$modus_help_optie" = "lang" -o "$modus_help_optie" = "optie" ] && cat <<-help
			#		- OPM: mijn eigen ffmpeg is ZONDER libxvid gecompileerd
			#		- ffmpeg-vertaling : "-c:v libxvid \$ffmpeg_opties" (die laatste opgesplitst op de spaties)
			help
		else
			vcodec=("-c:v" "libxvid" $2)	# laat $2 uiteenvallen in onderdelen (tss. "" op opdrachtlijn)
			shift #shift ook $2
		fi
	;;
	'--mpeg4')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1=["ffmpeg_opties"] : hercodeer video naar h.263-formaat met ffmpeg''s eigen mpeg4 codec, met XviD als fourCC.
			help
			[ "$modus_help_optie" != "kort" ] && cat <<-help
			#		- OPM: mijn eigen ffmpeg is ZONDER libxvid gecompileerd
			#		- ffmpeg-vertaling : "-c:v mpeg4 -vtag XVID \$ffmpeg_opties" (die laatste opgesplitst op de spaties)
			help
		else
			vcodec=("-c:v" "mpeg4" "-vtag" "XVID" $2)	# laat $2 uiteenvallen in onderdelen (tss. "" op opdrachtlijn)
			shift #shift ook $2
		fi
	;;
	'--vcopy')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1 : kopiëer het bestaande videospoor zonder hercoderen. Deze keuze zet automatisch ook de optie --singlepass.
			help
			[ "$modus_help_optie" != "kort" ] && cat <<-help
			#		- ffmpeg-vertaling : "-c:v copy"
			help
		else
			vcodec=("-c:v" 'copy') singlepass=y
		fi
	;;
	'--=Video-opties')
		[ -v modus_help_optie ] && echo -e "#\n# ${1:3}\n# ${1//?/=}\b\b\b   "
		;;
	'--vbr')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1=999k : geeft expliciet de maximaal gewenste gemiddelde video-bitrate voor de gekozen encoder.
			help
			[ "$modus_help_optie" != "kort" ] && cat <<-help
			#		Als ook een of meer van de andere video-bitrate parameters wordt opgegeven, wordt de uiteindelijke
			#		gevraagde bitrate het minimum van allemaal.
			#		- de bitrate is in decimale kilobyte
			#		- het suffix 'k' is optioneel.
			#		- ffmpeg-vertaling : "-b:v '\$999'k" of de berekende waarde
			help
		else
	fc=13
			[[ "$2" =~  ^[0-9]*k?$ ]] && vidbitrate="$((10#${2%k}*1000))" ||	# impli- of expliciete decim. kilo, decimaal naar byte
			{ >&2 echo -e "\e[1;31;107mERROR $fc: video bitrate '$2' niet geldig: '999k'\e[0m"; return "$fc"; } 
			shift #shift ook $2
		fi
	;;
	'--bronbr')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1[=999%] : leidt de nuttige  max. gemiddelde video-bitrate af van die van de bron, rekening houdend 
			#		met het verschil in bithonger van bron- en doel-encoder (b.v. h.265 60% van h.264 60% van h.263).
			help
			[ "$modus_help_optie" != "kort" ] && cat <<-help
			#		Optioneel wordt uiteindelijk het gekozen percentage genomen van wat uit de bron wordt afgeleid.
			#		Als ook een of meer van de andere video-bitrate parameters wordt opgegeven, wordt de uiteindelijke
			#		gevraagde bitrate het minimum van allemaal.
			#		- het suffix '%' is optioneel.
			#		- ffmpeg-vertaling : "-b:v 999k" met de berekende waarde
			help
		else
	fc=14
			{ [[ "$2" =~  ^([0-9]*%?)?$ ]] && bronbr="${2:-100}"; } ||	# "99"=="99%", ""=="100%"
			{ >&2 echo -e "\e[1;31;107mERROR $fc: afwijking '$2' van bron-bitrate niet geldig: geef een percentage, b.v. '$1=90%'\e[0m"; return "$fc"; } 
			shift #shift ook $2
		fi
	;;
	'--rasterbr')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1[=999%] : leidt een nuttige max. gemiddelde video-bitrate af van breedte x hoogte en framerate van de
			#		bron, rekening houdend met de bithonger van de doel-encoder (b.v. h.265 60% van h.264 60% van h.263).
			help
			[ "$modus_help_optie" != "kort" ] && cat <<-help
			#		De basis hiervoor is een aanbevolen tabel voor h.264 bitrates, die wordt toegeschreven aan Youtube.
			#		Optioneel wordt uiteindelijk het gekozen percentage genomen van wat uit de bron wordt afgeleid.
			#		Als ook een of meer van de andere video-bitrate parameters wordt opgegeven, wordt de uiteindelijke
			#		gevraagde bitrate het minimum van allemaal.
			#		- het suffix '%' is optioneel.
			#		- ffmpeg-vertaling : "-b:v 999k" met de berekende waarde
			help
		else
	fc=15
			{ [[ "$2" =~  ^([0-9]*%?)?$ ]] && rasterbr="${2:-100}"; } ||	# "99"=="99%", ""=="100%"
			{ >&2 echo -e "\e[1;31;107mERROR $fc: afwijking '$2' van aanbevolen bitrate voor deze resolutie is niet geldig: geef een percentage, b.v. '$1=90%'\e[0m"; return "$fc"; } 
			shift #shift ook $2
		fi
	;;
	'--tune')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1="video_encoder_tuning" : algemene ffmpeg-parameter voor fijnregeling van de gekozen encoder.
			help
			[ "$modus_help_optie" != "kort" ] && cat <<-help
			#		Afhankelijk van de encoder zijn de volgende waarden mogelijk:
			#		X.265: psnr, ssim, grain, zerolatency, fastdecode, animation
			#		  - geen default
			#		  - animation: improves encode quality for animated content
			#		  - grain: for grainy (or really foggy) source where the grain should be kept and is not filtered
			#		   out before encoding; neither retains nor eliminates grain, but prevents noticeable artifacts
			#		   caused by uneven distribution of grain.
			#		  - zerolatency: frame per frame, nuttig voor streaming
			#		  - fastdecode: for play back on systems with low cpu power, or 4K content at high bitrates
			#		  - geen film : X.265 is helemal voor film
			#		  - geen grayscale : "not more efficient than empty chroma planes", gebruik
			#		   desnoods --filteropts="-vf format=gray -pix_fmt yuv420p"
			#		  - psnr: for debugging
			#		  - ssim: for debugging
			#		  - zie ook https://x265.readthedocs.io/en/default/presets.html#tuning
			#		X.264 : film, animation, grain, stillimage, psnr, ssim, fastdecode, zerolatency
			#		  - script default is film
			#		  - film: normal film source encoded at a decent datarate (lowers the inloop-deblocking and tweaks
			#		   the psychovisual settings slightly)
			#		  - animation: cartoon-like source with large flat areas (boost deblocking, changes pychoviual
			#		   settings doubles reference frames)
			#		  - grain: for grainy (or really foggy) source where the grain should be kept and is not filtered
			#		   out before encoding
			#		  - fastdecode: this is ment for content that needs to be played back on systems with low cpu power
			#		  - geen grayscale : "not more efficient than empty chroma planes", gebruik
			#		   desnoods --filteropts="-vf format=gray -pix_fmt yuv420p"
			#		  - psnr: for debugging
			#		  - ssim: for debugging
			#		XviD : TE DOEN
			#		- ffmpeg-vertaling : "-tune:v '\$video_encoder_tuning'"
			help
		else
			# evt. volgende parameter -tune=xxx is X.265- of X.264 tune
			tune=("-tune:v" "$2")
			shift #shift ook $2
		fi
	;;
	'--profile')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1="video_encoder_profiel" : algemene ffmpeg-parameter om een bepaald compatibiliteitsprofiel op te
			#		geven voor de gekozen video encoder.
			help
			[ "$modus_help_optie" != "kort" ] && cat <<-help
			#		Afhankelijk van de encoder zijn de volgende waarden mogelijk:
			#		X.265 : main, mainstillpicture == msp, en een reeks profielen voor high dynamic range, minder
			#		  chroma subsampling en intra-frame encoding.
			#		  - geen default
			#		X.264 : baseline, main, high
			#		  - script default is high
			#		  - OPM: evt. level apart op te geven bij video encoder opties, b.v. --libx265="-level 3.0"
			#		XviD : TE DOEN
			#		- ffmpeg-vertaling : "-profile:v '\$video_encoder_profiel'"
			help
		else
			# evt. volgende parameter -profile=xxx is X.265- of X.264 profile
			vprofile=("-profile:v" "$2")
			shift #shift ook $2
		fi
	;;
	'--preset')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1="video_encoder_preset" : algemene ffmpeg-parameter om een vooraf bepaalde balans tussen compressie 
			#		en snelheid op te  geven voor de gekozen video encoder.
			help
			[ "$modus_help_optie" != "kort" ] && cat <<-help
			#		Afhankelijk van de encoder zijn de volgende waarden mogelijk:
			#		X.264, X.265 : ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow, placebo
			#		X.265 : Zie ook (https://x265.readthedocs.io/en/default/presets.html)
			#		  - default is medium
			#		  - medium voor 1920x1080 : 1 fps
			#		  - medium voor 640x360 : 150 fps
			#		  -  2 ffmpeg's in medium voor 640x360 : elk 110fps, en 160fps in pass 1 met no-slow-firstpass
			#		  - slow voor 640x360 : 60 fps
			#		  - slower voor 640x360 : 18 fps
			#		X.264
			#		  - script default is slower
			#		  - medium voor 640x480 : 800 fps in pass 1, 350 in pass 2
			#		  - slower voor 640x480 : 550 fps in pass 1, 200 in pass 2
			#		XviD : TE DOEN
			#		- ffmpeg-vertaling : "-profile:v '\$video_encoder_preset'"
			help
		else
			# evt. volgende parameter -preset=xxx is X.265- of X.264 preset
			preset=("-preset:v" "$2")
			shift #shift ook $2
		fi
	;;
	'--x265params')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1="naam=waarde[:naam=waarde]..." : opties voor de parameter "-x265-params" van de libx265 encoder
			help
			[ "$modus_help_optie" != "kort" ] && cat <<-help
			#		- opgegeven als ':'-gescheiden lijst "naam=waarde[:naam2=waarde2]"
			#		- namen zonder echte waarde moeten toch de pseudo-waarde "=1" krijgen om geldig te zijn
			# 		- zie https://x265.readthedocs.io/en/default/cli.html
			#		- ffmpeg-vertaling : "-x265-params '\$naam=waarde...'"
			#		  - de waarden van meerdere opties $1 worden aan elkaar geschakeld, gescheiden door een ':'.
			#
			# 		Voorbeeld
			# 		---------
			#		- snel een verliesloze omzetting doen:
			# 		   $1="lossless=1" --singlepass --preset=ultrafast
			help
		else
			x265params+=("$2")	# nu 1 niet-gesplitste string, later gebruiken we het array-zijn
			shift #shift ook $2
		fi
	;;
	'--=Geluid-encoders')
		[ -v modus_help_optie ] && echo -e "#\n# ${1:3}\n# ${1//?/=}\b\b\b   " &&
			cat <<-help
			# Elk van de audio-encoder-parameters aanvaardt optioneel 1 of meerdere bijkomende ffmpeg-opties t.b.v. de
			# encoder in de vorm --%encoder-naam%="[-ffmpegoptie [waarde]]...", volgens de beschrijving in de sectie
			# "Meervoudige parameters". Dit geldt natuurlijk niet voor de oneigenlijke encoders --an en --acopy.
			#
			help
		;;
	'--fdk_aac'|'--libfdk_aac')
		if [ -v modus_help_optie ]
		then [ "${1::5}" != "--lib" -a "$modus_help_optie" != "optie" ] && echo -e "#\t$1" || cat <<-help
			#	$1=["ffmpeg_opties"] : hercodeer geluid naar aac-formaat met libfdk_aac. Dit is de default
			#		geluidsencoder van 2passffmpeg, maar deze parameter aanvaardt bijkomende ffmpeg-opties.
			help
			[ "${1::5}" = "--lib" -a "$modus_help_optie" = "lang" -o "$modus_help_optie" = "optie" ] && cat <<-help
			#		- Variabele bitrate instellen met --avbr.
			#		- libfdk_aac is NIET beschikbaar in Ubuntu's standaard-compilatie van ffmpeg
			#		- ffmpeg-vertaling : "-c:a libfdk_aac \$ffmpeg_opties" (die laatste opgesplitst op de spaties)
			#
			#		Voorbeeld van extra opties:
			#		--------------------------
			#		- manueel ingestelde 5.1 naar stereo
			# 			$1="-af pan=stereo|FL<FC+0.707*FL+0.30*BL|FR<FC+0.707*FR+0.30*BR"
			help
		else
			# is hoger ingesteld default, maar met expliciete optie kunnen we extra parameters opgeven
			acodec=("-c:a" 'libfdk_aac' $2)	# laat $2 uiteenvallen in onderdelen (tss. "" op opdrachtlijn)
			shift #shift ook $2
		fi
	;;
	'--aac')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1=["ffmpeg_opties"] : hercodeer geluid naar aac-formaat. Als de gekozen ffmpeg-versie met 
			#		libfdk_aac gecompileerd is, wordt die genomen, en anders ffmeg's eigen aac-implementatie.
			help
			[ "$modus_help_optie" != "kort" ] && cat <<-help
			#		- OPM: ffmpeg's eigen aac ondersteunt de profielen aac-he1 en aac-he2 NIET
			#		- Zie verder beschrijving --libfdk_aac
			#		- ffmpeg-vertaling : "-c:a libfdk_aac \$ffmpeg_opties" OF "-c:a aac \$ffmpeg_opties"
			#		  (ffmpeg_opties opgesplitst op de spaties)
			help
		else
			acodec=("-c:a" 'aac' $2)
			# voorkeur voor libfdk_aac als die ondersteund wordt, anders ffmpeg-interne aac (die he2 NIET ondersteunt)
			 "$ffmpeg" -hide_banner -encoders | grep "libfdk_aac" > /dev/null && 
				acodec=("-c:a" 'libfdk_aac' $2) ||
				acodec=("-c:a" 'aac' $2)	# laat $2 uiteenvallen in onderdelen (tss. "" op opdrachtlijn)
			shift #shift ook $2
		fi
	;;
	'--mp3'|'--lame'|'--libmp3lame')
		if [ -v modus_help_optie ]
		then [ "${1::5}" != "--lib" -a "$modus_help_optie" != "optie" ] && echo -e "#\t$1" || cat <<-help
			#	$1=["ffmpeg_opties"] : hercodeer geluid naar mp3-formaat met lame.
			help
			[ "${1::5}" = "--lib" -a "$modus_help_optie" = "lang" -o "$modus_help_optie" = "optie" ] && cat <<-help
			#		- Variabele bitrate instellen met --avbr.
			#		- ffmpeg-vertaling : "-c:a libmp3lame \$ffmpeg_opties" (die laatste opgesplitst op de spaties)
			help
		else
			acodec=("-c:a" 'libmp3lame' $2)	# laat $2 uiteenvallen in onderdelen (tss. "" op opdrachtlijn)
			shift #shift ook $2
		fi
	;;
	'--acopy')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1 : kopiëer het bestaande geluid zonder hercoderen.
			help
			[ "$modus_help_optie" != "kort" ] && cat <<-help
			#		- ffmpeg-vertaling : "-c:a copy"
			help
		else
			acodec=("-c:a" 'copy')
		fi
	;;
	'--an')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1 : laat geluid volledig weg.
			help
			[ "$modus_help_optie" != "kort" ] && cat <<-help
			#		- ffmpeg-vertaling : "-an"
			help
		else
			acodec=("-an")
		fi
	;;
	'--=Geluid-opties')
		[ -v modus_help_optie ] && echo -e "#\n# ${1:3}\n# ${1//?/=}\b\b\b   "
		;;
	'--avbr')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1=9 : het kwaliteitsniveau dat met een veranderlijke geluids-bitrate wordt nagestreefd.
			help
			[ "$modus_help_optie" != "kort" ] && cat <<-help
			#		Dit is afhankelijk van de gekozen encoder:
			#		- fdk_aac met --he2 (high efficiency profile 2) typische kbps voor stereo:
			#		  --avbr=0 : (default) constante bitrate, extra op te geven als b.v. --libfdk_aac="-b:a 24k"
			#		  --avbr=1 : 16kbps, --avbr=2 : 18kbps, --avbr=3 : 20kbps
			#		- aac en fdk_aac (default profile) typische kbps voor mono, stereo en 5.1 (=2x mono + 2x stereo) :
			#		  --avbr=0 : (default) constante bitrate, extra op te geven als b.v. --aac="-b:a 128k"
			#		  --avbr=1 : mono  32kbps, stereo  40kbps, 5.1 144kbps
			#		  --avbr=2 : mono  40kbps, stereo  64kbps, 5.1 208kbps
			#		  --avbr=3 : mono  56kbps, stereo  96kbps, 5.1 304kbps
			#		  --avbr=4 : mono  72kbps, stereo 128kbps, 5.1 400kbps
			#		  --avbr=5 : mono 112kbps, stereo 192kbps, 5.1 608kbps
			#		  - zie ook http://wiki.hydrogenaud.io/index.php?title=Fraunhofer_FDK_AAC#Bitrate_Modes
			#		- Lame mp3 (--avbr: gemiddeld/van-tot in kbps)
			#		  --avbr=0: 245/220-260| ~=1: 225/190-250| ~=2: 190/170-210| ~=3: 175/150-195| ~=4: 165/140-185,
			#		  --avbr=5: 130/120-150| ~=6: 115/100-130| ~=7: 100/ 80-120| ~=8:  85/ 70-105| ~=9:  65/ 45- 85
			#		  - zie ook "ffmpeg truuks en commandos" sectie "mp3 Lame VBR opties": :
			#		- ffmpeg-vertaling : "-vbr:a \$9"
			help
		else
	fc=16
			# lame, aac en HE2 aac verschillende default, zolang we encoder niet weten wijzigen we de 3 variabelen
			[[ "$2" =~ ^[0-9]$ ]] && avbr_aac="$2" && avbr_he2aac="$2" && avbr_lame="$2" || { >&2 echo -e "\e[1;31;107mERROR $fc: variabele geluid bitrate geen cijfer: '$2'\e[0m"; return "$fc"; } 
			shift #shift ook $2
		fi
	 ;;
	'--ar')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1=99999 : herbemonster het geluid naar het opgegeven aantal kHz per seconde (sample rate)
			#		- mogelijke waarden zijn 48000, 44100, 32000, 24000, 22050, 16000, 12000, 11025, 8000
			#	$1=1k OF =2k : herbemonster het geluid naar de helft of een derde van de bronsnelheid als die 'hoog'
			#		is; meer bepaald wordt 48000 herleidt tot 16000 of 24000, 44100 tot 22050, 32000 tot 16000, 
			#		24000 tot 16000 of (onveranderd) 24000 (alles in kHz).
			help
			[ "$modus_help_optie" != "kort" ] && cat <<-help
			#		- ffmpeg-vertaling : "-ar \$99999" of de berekende waarde
			help
		else
	fc=17
			# 2k: als ar van bron > 24000 dan /=2, 1k: > 20000 dan /=2-4. Hogere wil ik nooit, deze OK voor libmp3lame en libfdk_aac
			[[ "$2" =~ ^(1k|2k|48000|44100|32000|24000|22050|16000|12000|11025|8000)$ ]] && audiorate=("-ar" "$2") || { >&2 echo -e "\e[1;31;107mERROR $fc: mogelijk niet-ondersteunde geluid sample rate opgegeven: '$2'\e[0m"; return "$fc"; } 
			shift #shift ook $2
		fi
	;;
	'--he2')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1 : gebruik het high efficiency profile van de libfdk_aac geluidsencoder.
			help
			[ "$modus_help_optie" != "kort" ] && cat <<-help
			#		- Het geluid moet stereo zijn, maar zou door verschilcodering slechts 2-3 kbps meer geven dan mono.
			#		  - hercodeer mono als stereo met --libfdk_aac="-ac 2" --he2
			#		  - zie ook --spraak
			#		  - compatibiliteit: volgens wiki.hydrogenaud.io kan he2 tegenwoordig afgespeeld worden door
			#		    alles wat aac kan afspelen, volgens anderen niet:
			#		    - WEL Medion TV : speelt aac_he_v2 in mp4 en m4a (geen mp3 in mp4!)
			#		    - WEL Onda V972 tablet : speelt aac_he_v2 in mp4 en m4a
			#		    - NIET LG dvd-speler : vindt m4a gewoon niet, en speelt geen aac_he_v2 in mp4
			#		- ffmpeg-vertaling : "-profile:a aac_he_v2"
			help
		else
			he2=y
		fi
	;;
	'--spraak')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1 : verdeel stereo geluid gelijk over 2 stereo kanalen, zodat het even compact gecodeerd wordt als mono.
			#		Deze parameter is vooral nuttig voor spraak met --libfdk_aac --he2
			help
			[ "$modus_help_optie" != "kort" ] && cat <<-help
			#		- ffmpeg-vertaling : "-ac 1", maar samen met optie --he2 "-ac 2 -af pan=stereo|c0<c0+c1|c1<c0+c1"
			help
		else
			spraak=y
		fi
	;;
	'--surround')
		if [ -v modus_help_optie ]
		then cat <<-help
			#	$1 : behoud surround geluid met meer dan 2 kanalen. Zonder deze parameter herleid ik alles behalve mono
			#		naar 2 kanalen, omdat ik toch maar 2 luidssprekers heb.
			help
			[ "$modus_help_optie" != "kort" ] && cat <<-help
			#		- ffmpeg-vertaling : bij ontstentenis "-ac 2" als er meer dan 2 kanalen zijn in het geluidsspoor
			help
		else
			surround=y
		fi
	;;
	'--')
		[ -v modus_help_optie ] && true || {
	fc=18
		[ -f "$2" ] || { >&2 echo -e "\e[2;31;107mERROR $fc: Geen invoerbestand '$2' gevonden.\e[0m"; return "$fc"; }
		shift # verwijder "--" uit "$@", en (vanwege de afsluitende break) niets anders meer; "$@" of "$*" zijn nu alle bestandsnamen
		invoer=("$@")
		# splits invoer[0] als bronbestand1 op in directory, basisnaam en extensie, t.b.v. doel in andere dir en met andere ext.
		bronbestand1="${invoer[0]}"	# gebruikt voor kenmerken (bitrate, samplerate) van evt. geconcateneerde invoer en voor naam uitvoer
		bronnaam="${bronbestand1##*/}"
		brondir="${bronbestand1%/*}"                 	# als in $bronbestand1 geen '/' stond,
		[ "$brondir" = "$bronbestand1" ] && brondir='.'	# dan is nu $brondir = $bronbestand1, gebruik '.'
		## uitvoer eerst naar tmpfs /tmp, daarna mv naar uiteindelijke doel-directory (hopelijk minder fragmentatie)
		## Dus: ffmpeg overschrijft altijd in /tmp (ffmpeg uitvoer), mv van /tmp naar $doel hier instellen: "-i" (met
		##      prompt), "-f" (altijd), "-n" (nooit, ZONDER boodschap)
		uitvoer="/tmp/${bronnaam%.*}.$ext" ffmpeg_overschrijven="-y" mv_overschrijven="-i" 
		#uitvoer="$doel/${bronnaam%.*}.$ext" ffmpeg_overschrijven="" # dan moet opdracht "mv /tmp/... $doel/" weg; geen mv_overschrijven="-i" nodig
		# evt. "prefix." van extensie niet meer nodig: eraf halen, zodat we $ext kunnen gebruiken als ffmpeg-format -f $ext
		ext=${ext##*.}
		if [ "${concat,,}" = "protocol" ]
		then
			invoer=("concat:$(IFS='|' eval 'echo "${invoer[*]}"')")	# opgelet: vervang hele array invoer
		elif [ "${concat,,}" = "demuxer" ]
		then	# OPM: process substition is niet blijvend, kan enkel in een variabele di
			{
				echo "ffconcat version 1.0"
				for lijn in "${invoer[@]}"
				do
					[ ! -f "$lijn" ] && echo "$lijn" && continue	# directieven
					# relative bestandspaden zijn t.o.v. pad naar demux input (/tmp), maak ze daarom absoluut
					# speciale tekens tss. '' of escapen met '\': zetten alles tss. '', behalve ' zelf: escape als \' en
					# omringen met sluit-' en open-'
					lijn="$(realpath "$lijn")" && echo file "'${lijn//\'/\'\\\'\'}'"	#bestanden, tss. '' en escape emmbed '
				done
			}>"/tmp/2passffmpeg_pid${pid}_concatdemux"
			#ls "/tmp/2passffmpeg_pid${pid}_concatdemux"
			#cat "/tmp/2passffmpeg_pid${pid}_concatdemux"
			invoer=("/tmp/2passffmpeg_pid${pid}_concatdemux")	# opgelet: vervang hele array invoer
			inopts_pass1_script+=("-f" "concat" "-safe" "0")	# komen voor de -i; -safe 0 is voor demux absolute paden
			inopts_pass2_script+=("-f" "concat" "-safe" "0")
		fi
		break
	} ;;
	'--help'|'-h')
		# als modus_help_optie eerder al gezet, nu script beëindigen anders modus_help_optie zetten
		# en $@ vervangen door lijst van alle (of na --help opgegeven) --optienamen (met steeds --help als laatste naam)
		if [ -v modus_help_optie ]
		then
			unset modus_help_optie
	fc=0
			return "$fc"
		else
			[ "$1" = "-h" ] && modus_help_optie="kort" || modus_help_optie="lang"
			shift # eet help-optie zelf op
			# enkel help voor de gevraagde opties, of vervang in long-options string elke komma (en evt. voorafgaande ':')
			# door " --", maar eerste naam in $longoptions komt niet na een komma, dus expliciete "--" ervoor.
			# $1 wordt nog weg-geshift na deze loopiteratie, laat dat "shiftdummy" zijn
			[ $# -gt 1 ] &&	# -gt 1: de "--" die getopt plaatste, is er ook nog
				modus_help_optie="optie" &&
				set -- "shiftdummy" "$@" --help ||
				set -- $(echo "shiftdummy" --"$longoptions" | sed -E 's/:*,/ --/g') --
		fi
	;;
	*)
		# getopt genereert lege arg. voor opties zonder een optionele waarde, en --help --optie geeft die door: skip die
		[ -v modus_help_optie -a "$1" = "" ] && true || {
	fc=30
		echo "Ongekende optie '$1'" >&2
		return "$fc" # bash: return alleen uit functies en sourced script, anders foutcode (1, niet gedocumenteerd)
	} ;;
	esac
	shift
 done

 ## CONTROLE
 [ "$0" = "bash" -a "$pid" = "${$}" ]  || cat <<-"not_running_sourced"
	#
	#	Deze reeks van scripts voor videocompressie worden best uitgevoerd met de
	#	bash-opdracht "source" of "." omdat de proces-ID gebruikt wordt in de
	#	bestandsnaam met de statistieken van de 1ste doorgang, gebruikt voor de 2de
	#	doorgang. Als de scripts zelf uitvoerbaar gemaakt en uitgevoerd worden, of als
	#	ze worden uitgevoerd als "bash scriptnaam", is die proces-ID telkens een
	#	andere, en hopen de statistiekbestanden zich op i.p.v. telkens de vorige te
	#	overschrijven.
	#
	not_running_sourced
 ## CONTROLE VIDEO OPTIES
 if [ "${vcodec[1]}" = "libx265" ]
 then	#	X.265 
 fc=31
	[[ ${#preset[@]} -le 0 || "${preset[1]}" =~ ^(ultrafast|superfast|veryfast|faster|fast|medium|slow|slower|veryslow|placebo)$ ]] ||
		{ >&2 echo -e "\e[1;31;107mERROR $fc: ongekende preset voor X.265: '${preset[1]}'\e[0m"; return "$fc"; }
 fc=32
	[[ ${#tune[@]} -le 0 || "${tune[1]}" =~ ^(psnr|ssim|grain|zerolatency|fastdecode|animation)$ ]] || # volgens 1 bron geen animation
		{ >&2 echo -e "\e[1;31;107mERROR $fc: ongekende tune voor X.265: '${tune[1]}'\e[0m"; return "$fc"; }
 fc=33
	[[ ${#vprofile[@]} -le 0 || "${vprofile[1]}" =~ ^(main|main10|mainstillpicture|msp|main-intra|main10-intra|main444-8|main444-intra|main444-stillpicture|main422-10|main422-10-intra|main444-10|main444-10-intra|main12|main12-intra|main422-12|main422-12-intra|main444-12|main444-12-intra|main444-16-intra|main444-16-stillpicture)$ ]] ||
		{ >&2 echo -e "\e[1;31;107mERROR $fc: ongekende profile voor X.265: '${profile[1]}'\e[0m"; return "$fc"; }
 elif [ "${vcodec[1]}" = "libx264" ]
 then	#	X.264 
 fc=34
	[[ ${#preset[@]} -le 0 || "${preset[1]}" =~ ^(ultrafast|superfast|veryfast|faster|fast|medium|slow|slower|veryslow|placebo)$ ]] ||
		{ >&2 echo -e "\e[1;31;107mERROR $fc: ongekende preset voor X.264: '${preset[1]}'\e[0m"; return "$fc"; }
 fc=35
	[[ ${#tune[@]} -le 0 || "${tune[1]}" =~ ^(film|animation|grain|stillimage|psnr|ssim|fastdecode|zerolatency)$ ]] ||
		{ >&2 echo -e "\e[1;31;107mERROR $fc: ongekende tune voor X.264: '${tune[1]}'\e[0m"; return "$fc"; }
 fc=36
	[[ ${#vprofile[@]} -le 0 || "${vprofile[1]}" =~ ^(baseline|main|high)$ ]] ||
		{ >&2 echo -e "\e[1;31;107mERROR $fc: ongekende profile voor X.264: '${profile[1]}'\e[0m"; return "$fc"; }
 elif [ "${vcodec[1]}" = "copy" ]
 then
		# voor vcodec copy geen andere video-opties
 fc=37
	[ "$vidbitrate" -gt 0 -o -n "$bronbr" -o -n "$rasterbr" -o "${#tune[@]}" -gt 0 -o "${#vprofile[@]}" -gt 0 -o "${#preset[@]}" -gt 0 -o "${#x265params[@]}" -gt 0 ] && { >&2 echo -e "\e[1;31;107mERROR $fc: video-codec 'copy' strijdig met alle andere video opties\e[0m"; return "$fc"; } 
 fi
 fc=38
 [ "${singlepass,,}" = "y" -a "${pass2only,,}" = "y" ] && 
	{ >&2 echo -e "\e[1;31;107mERROR $fc: opties --singlepass en --pass2only sluiten elkaar uit.\e[0m"; return "$fc"; }
 ## CONTROLE GELUID OPTIES
 if [ "${acodec[0]}" = "-an" -o "${acodec[1]}" = "copy" ]
 then
		# voor acodec copy geen andere geluid-opties, maar avbr heeft altijd minstens default-waarde, die controleren we niet
 fc=40
	[ "${he2,,}" = "y" -o "${spraak,,}" = "y" -o "${surround,,}" = "y" -o "${#audiorate[@]}" -gt 0 ] && { >&2 echo -e "\e[1;31;107mERROR $fc: --an en geluid-codec 'copy' strijdig met alle andere geluid opties\e[0m"; return "$fc"; } 
 fi
 if [ "${he2,,}" = "y" ]
 then
 fc=41
	[ "${acodec[1]}" = "libfdk_aac" ] && acodec+=("-profile:a" "aac_he_v2") ||
		{ >&2 echo -e "\e[1;31;107mERROR $fc: high efficiency profiel he2 enkel mogelijk met libfdk_aac\e[0m"; return "$fc"; }
 fi
 fc=42
 [ "${he2,,}" = "y" -a "${surround,,}" = "y" ] && 
	{ >&2 echo -e "\e[1;31;107mERROR $fc: opties --he2 en --surround sluiten elkaar uit.\e[0m"; return "$fc"; }
 fc=43
 [ "${spraak,,}" = "y" -a "${surround,,}" = "y" ] && 
	{ >&2 echo -e "\e[1;31;107mERROR $fc: opties --spraak en --surround sluiten elkaar uit.\e[0m"; return "$fc"; }
 ## VERTALING OPTIES
 [ -z "$epcdir" ] && epcdir="$doel" #Zie ~/Documents/shellscripts/ExternalProcessControl
	#	verwijder chapters-metadata (titels, ...)
 [ "$chapters,," = "y" ] || uitopts_pass2_script+=("-map_chapters" "-1")
	#	verwijder alle metadata: global, stream, chapter en program
 [ "$metadata,," = "y" ] || uitopts_pass2_script+=("-map_metadata:g" "-1" "-map_metadata:s" "-1" "-map_metadata:c" "-1" "-map_metadata:p" "-1")
	#	bewaar variabele framerate
 [ "${vcodec[1]}" = "copy" -o "$novfr,," = "y" ] || uitopts_pass1_script+=("-vsync" "vfr") uitopts_pass2_script+=("-vsync" "vfr")
 ## VERTALING VIDEO OPTIES
 if [ "${vcodec[1]}" = "libx265" ]
 then
	true; # defaults zijn OK voor film (geen tune, geen profile, preset medium)
 elif [ "${vcodec[1]}" = "libx264" ]
 then
	[ ${#tune[@]} -le 0 ] && tune=("-tune" "film") # is nog snel genoeg; evt. slow of medium kiezen voor HD
	[ ${#preset[@]} -le 0 ] && preset=("-preset" "slower") # is nog snel genoeg; evt. slow of medium kiezen voor HD
	[ ${#vprofile[@]} -le 0 ] && vprofile=("-profile:v" "high") # is nog snel genoeg; evt. slow of medium kiezen voor HD
 fi
 if [ -z "$bronbr" -a -z "$rasterbr" -a "$vidbitrate" -le 0 -a "${vcodec[1]}" != "copy" ]
 then
	rasterbr="100"
 fi
 local bron_video_width bron_video_height bron_video_codec_name bron_video_codec_tag_string bron_video_bit_rate bron_video_avg_frame_rate
 if [ -n "$bronbr" -o -n "$rasterbr" ]
 then
	eval $(ffprobewaarden V width,height,codec_name,codec_tag_string,bit_rate,avg_frame_rate "$bronbestand1" | sed -E 's/^/bron_video_/' )
	qual_bit_rate=0
	if [ -n "$bronbr" ]
	then
			# bepaal bitrate van video bron
		bron_video_bit_rate="$((bron_video_bit_rate))"	# effectief numeriek of 0
		if [ "$bron_video_bit_rate" -le 0 ]	# b.v. mkv en webm streams hebben soms geen duration, en dus geen bit_rate
		then
				# 1. als bitrate geluid stream(s) wel bekend, die gewoon aftrekken van die van format
				#	 som bit_rate geluid-kanalen; 0 is OK (geen geluid-kanalen). vervang N/A door -99999 om te testen op < 0
			total_audio_bit_rate=$(( $(ffprobewaarden a bit_rate "$bronbestand1" | sed 's|N/A|-99999|' | paste -sd+) )) || total_audio_bit_rate=-99999
			if [ "$total_audio_bit_rate" -ge 0 ]
			then	# totale audio-bitrate aftrekken van bitrate van format
				bron_video_bit_rate=$(ffprobewaarden bit_rate "$bronbestand1") &&
					((bron_video_bit_rate-=total_audio_bit_rate)) || bron_video_bit_rate=0			
			fi
		fi
		if [ "$bron_video_bit_rate" -le 0 ]
		then	# 2. SNELLE HACK: uit laatste lijn van dummy ffmpeg-transformatie aantal kbytes video bepalen :
				#	>>>video:4015069kB audio:0kB subtitle:0kB other streams:0kB global headers:0kB muxing overhead: unknown <<<
			bron_video_bit_rate=$(ffmpeg -hide_banner -nostats -i "$bronbestand1" -c copy -map V -f null /dev/null |& tail -n 1 | sed -E 's/^video: *([0-9]+).*$/\1/') &&
				# als numeriek, dan binaire kB naar bits, anders 0
			bron_video_bit_rate=$((bron_video_bit_rate*8192/$(ffprobewaarden duration "$bronbestand1" | sed -E 's/.[0-9]*$//') )) ||
				bron_video_bit_rate=0
		fi
		if [ "$bron_video_bit_rate" -le 0 ]
		then	# 3. som van bytes per video-frame maken, en delen door duur : kapselen lijst met bytes
				#	per frame (packet size) van de hoofd-videostream in in een bash arithmetic expression
				#	die ze sommeert
			bR=0	# korte naam werkt duidelijk sneller
			. <(echo -n '((';ffprobe -v error -select_streams V -show_entries packet=size -of default=noprint_wrappers=1:nokey=1 "$bronbestand1" |
				sed -E 's|^(.*)$|bR+=\1,|';echo 'bR*=8))';)
			bron_video_bit_rate=$((bR/$(ffprobewaarden duration "$bronbestand1" | sed -E 's/.[0-9]*$//') )) ||
				bron_video_bit_rate=0	# als numeriek, dan decimale kb naar bits, anders 0
		fi
		# OPM: getest en werkt, maar uitgeschakeld: als 3. geen resultaat geeft, deze ook niet want werkt met zelfde input
			#if [ false -a  "$bron_video_bit_rate" -le 0 ] 
			#then	# 4. som van bytes per video-frame maken, en delen door duur : kapselen lijst met bytes
			#		#	per frame (packet size) van de hoofd-videostream in in een formule voor calculator bc :
			#		#	- OPM: bc wil geen '\n' binnen een expression, dus o.a. echo -n
			#		#	- scale=0; en een haakje '(' zonder newline achter
			#		#	- een lijst met bytes per frame (packet size) van de hoofd-videostream, met newlines vervangen door een '+'
			#		#		- in andere formules is "paste -sd+" soms een alternatief voor "tr '\n' ' '": laat laatste \n staan, en die
			#		#			is wel nodig als er geen echo meer achter komt
			#		#	- na de afsluitende '+' van die lijst nog
			#		#		- een '0' en afsluitend haakje ')'
			#		#		- '*8' om van bytes naar bits te rekenen
			#		#		- '/' om te delen door duurtijd van het hele bestand (b.v. mkv en webm geven (soms?) geen duur per stream)
			#		bron_video_bit_rate=$(
			#			{
			#				echo -n "scale=0;(";
			#				ffprobe -v error -select_streams V -show_entries packet=size -of default=noprint_wrappers=1:nokey=1 "$bronbestand1" |
			#					tr '\n' '+';
			#				echo -n "0)*8/";
			#				ffprobewaarden duration "$bronbestand1";
			#			} | bc ) || bron_video_bit_rate=0
			#fi
			# hogere kwaliteit dan bron zinloos, vertaald naar bitrate per encoder-klasse:  maximaal zinnige bitrate voor
			# hercompressie naar h.264, ruwweg gebaseerd op 30% minder bits per generatie e.a. info 
										# legende: ffmpeg's codec_name (zie "$ ffmpeg -encoders") / codec_tag_string (FourCC) :
		case "${bron_video_codec_name,,}" in
			'mpeg2video') # mpeg2video/???? (.mpg en VCD)
				qual_bit_rate=$((bron_video_bit_rate*7/20));;	# bitrate h.264 35% van h.261-klasse (? MPEG-1 part 2)
			'mpeg1video') # mpeg1video/???? (.vob, SVCD, DVD en BlueRay)
				qual_bit_rate=$((bron_video_bit_rate*1/2));;	# bitrate h.264 50% van h.262-klasse MPEG-2 part 2
			'h263'|'mpeg4'|'wmv3'|'msmpeg4v3'|'rv10'|'rv20'|'flv1') # mpeg4/[XVID|DIVX|DX50|3IVX?] - wmv3/WMV3 - msmpeg4v3/DIV3 -
						# rv10/RV10 (Realvideo < 8) - rv20/RV20 - flv1/???? (Sorenson H.263 Flash Video)
				qual_bit_rate=$((bron_video_bit_rate*7/10));;	# bitrate h.264 70% van h.263-klasse MPEG-4 Part 2
			'hevc'|'vp9'|'rv60'|'av1') # hevc/[hev1|h.265] - vp9/???? - rv60/RV60 - (?? AV1)
				qual_bit_rate=$((bron_video_bit_rate*10/7));;	# bitrate h.264 100/70% van h.265-klasse
			'h264'|'vp8'|'rv30'|'rv40'|'rv50') # h264/[avc1|H264] - vp8/???? - rv30/RV30? - rv40/RV40 - rv50/RV50
				qual_bit_rate="$((bron_video_bit_rate))";;		# bitrate h.264 100% van andere h.264-klasse MPEG-4 Part 10
			*)	 #	onbekende klasse : indeo5/IV50 - cinepak/cvid - mjpeg/???? - gif/????
				qual_bit_rate=0;; # kunnen geen zinnige berekening doen (TEDOEN evt. zelfde berekening als mpg??)
		esac
		qual_bit_rate=$(((qual_bit_rate*10#${bronbr%\%} + 50)/100))	# zonder evt. eind-'%' en decimaal (10#) zelfs met voorloop-'0'
 fc=50
		[ "$((qual_bit_rate))" -le 0 ] && { >&2 echo -e "\e[1;31;107mERROR $fc: kan video bitrate niet afleiden uit bitrate $bron_video_bit_rate van de bron\e[0m"; return "$fc"; }
	fi
		# zie ook (https://slhck.info/video/2017/03/01/rate-control.html)
	geom_bit_rate=0
	if [ -n "$rasterbr" ]
	then
		if [ -n "$bron_video_height" -a -n "$bron_video_width" ]
		then	# bepaal nuttige bitrate voor deze geometry, gebaseerd op tabellen voor Youtube h.264
			# Google/Youtube aanbevelingen voor live streaming h.264 https://support.google.com/youtube/answer/2853702?hl=en
			#	Resol.      	kbps h.264	kbps h.265  (h.265 zelf afgeleid als 60% van h.264) :
			#   1920x1080@60	4500-9000	2700-5400  |  854x480	 500-2000  300-1200
			#   1920x1080   	3000-6000	1800-3600  |  640x360	 400-1000  240- 600
			#   1280x720@60 	2250-6000	1350-3600  |  426x240 	 300- 700  180- 420
			#   1280x720    	1500-4000	900-2400
			# https://www.tutorialguidacomefare.com/test-video-quality-720p-1080p-1440p-2160p-max-bitrate-which-compresses-youtube/
			# 	Youtube compresses ... with a bit rate of ... Mbps :
			#	to 4320p (8K) (7680×4320) - 21.2   (VP9) - 78.4   (h.264)
			#	to 2160p (4K) (3840×2160) - 17.3   (VP9) - 23.1   (h.264)
			#	to 1440p (2K) (2560×1440) -  8.589 (VP9) - 10.4   (h.264) 
			#	   1080p      (1920×1080) -  2.567 (VP9) -  2.309 (h.264)
			#	to  720p      (1280× 720) -  1.468 (VP9) -  1.378 (h.264)
			#	to  480p      ( 854× 480) -  0.727 (VP9) -  1.155 (h.264)
			#	to  360p      ( 640× 360) -  0.373 (VP9) -  0.525 (h.264)
			#	    240p      ( 426× 240) -  0.157 (VP9) -  0.242 (h.264)
			#	to  144p      ( 256× 144) -  0.085 (VP9) -  0.109 (h.264)
			# <<<
			# bitrate richtlijn voor X.264 van een videoserver http://www.lighterra.com/papers/videoencodingh264/
			#	Resol. 		kbps
			#	1920x1080HQ	7600 |	1024x576HQ 	2200 |	768x432 	1100
			#	1920x1080 	5000 |	1024x576 	1900 |	640x360 	 900 
			#	1280x720HQ 	3000 |	848x480HQ 	1500 |	424x240 	 600 
			#	1280x720 	2500 |	848x480 	1200 |
			# Hieruit afgeleid: 3 regimes ngl. aantal lijnen, en dan x aantal pixels en x aantal frames per sec. :
			if [ "$bron_video_height" -gt 800 ]	# boven 720, met beetje marge
			then
				geom_bit_rate=$((bron_video_height*bron_video_width*11/10))
			elif [ "$bron_video_height" -gt 520 ]	# boven 480, met beetje marge
			then
				geom_bit_rate=$((bron_video_height*bron_video_width*15/10))
			else
				geom_bit_rate=$((bron_video_height*bron_video_width*27/10))
			fi
				# lage framerate (typisch clips) aan overeenkomend lagere bitrate, voor 60fps geeft tabel maar 1/2 hogere bitrate
			if [ -n "$bron_video_avg_frame_rate" -a "${bron_video_avg_frame_rate##*/}" != "0" ] # meestal vorm frames/tijd, willen geen /0
			then	#	OPM: zonder $ wordt de veranderlijke, als die zelf een formule is, uitgerekend alsof ze tss. haakjes staat
				{ [ $((bron_video_avg_frame_rate)) -lt 23 ] && geom_bit_rate=$((geom_bit_rate * $bron_video_avg_frame_rate / 25)); } ||
					{ [ $((bron_video_avg_frame_rate)) -gt 50 ] && geom_bit_rate=$((geom_bit_rate * 3 / 2)); }
			fi
		fi
		geom_bit_rate=$(((geom_bit_rate*10#${rasterbr%\%} + 50)/100))	# zonder evt. eind-'%' en decimaal (10#) zelfs met voorloop-'0'
 fc=51
		[ "$((geom_bit_rate))" -le 0 ] && { >&2 echo -e "\e[1;31;107mERROR $fc: kan aanbevolen video bitrate niet afleiden uit resolutie van de bron\e[0m"; return "$fc"; }
	fi
	echo -ne "\e[1;103m H.264-bitrate-equivalent van bron $(((qual_bit_rate+500)/1000))k - van raster $(((geom_bit_rate+500)/1000))k\e[0m"
		# qual_bit_rate = min(bronbr, rasterbr)
		# - zet laagste niet-0 van geom_bit_rate en qual_bit_rate in qual_bit_rate
	[ "$qual_bit_rate" -le 0 ] || [ "$geom_bit_rate" -gt 0 -a "$geom_bit_rate" -lt "$qual_bit_rate" ] && qual_bit_rate="$geom_bit_rate"
		# reken om van h.264-klasse naar gevraagde codec :
	[ "${vcodec[1]}" = "libx265" ] && qual_bit_rate=$(($qual_bit_rate*7/10)) || # naar h.265-klasse
		{ [ "${vcodec[1]}" = "libxvid" -o "${vcodec[1]}" = "mpeg4" ] && qual_bit_rate=$(($qual_bit_rate*10/7)); } # naar h.263-klasse
		# vidbitrate = min(vidbitrate, qual_bit_rate)
	[ "$vidbitrate" -le 0 ] || [ "$qual_bit_rate" -gt 0 -a "$qual_bit_rate" -lt "$vidbitrate" ] && vidbitrate="$qual_bit_rate"
	echo -e "\e[1;103m ... doel-bitrate $(((vidbitrate+500)/1000))k\e[0m"
 fi
	# OPM: mpeg4 kan lage bitrate voor HD niet aan, geeft fout; libxvid negeert lage bitrate voor HD
 vidbitrate="$(((vidbitrate+500)/1000))"k	# naar decimale kilo
 [ "${vcodec[1]}" != "copy" ] && vcodec+=("${preset[@]}" "${tune[@]}" "${vprofile[@]}" "-b:v" "$vidbitrate")
 ## VERTALING GELUID OPTIES
 if [ "${he2,,}" = "y" ]
 then
	acodec+=("-vbr:a" "$avbr_he2aac") 
		# forceer stereo als mono, door --spraak alsnog op te zetten: vermijdt dat we bij --he2 --spraak 2 keer -ac instellen
	channels="$(ffprobewaarden a:0 channels "$bronbestand1")" && [ "$((channels))" = 1 ] && spraak=y
 elif [ "${acodec[1]}" = "libfdk_aac" -o "${acodec[1]}" = "aac" ]
 then
	acodec+=("-vbr:a" "$avbr_aac") 
 elif [ "${acodec[1]}" = "libmp3lame" ]
 then
	acodec+=("-q:a" "$avbr_lame")	# ffmpeg-optie "-q:a" wordt vertaald naar Lame-optie "-V"
 fi
 if [ "${spraak,,}" = "y" ]
 then		# voor he2: de facto mono in stereo formaat, anders gewoon mono
	[ "${he2,,}" = "y" ] && filteropts_pass2_script+=("-ac" "2" "-af" "pan=stereo|c0<c0+c1|c1<c0+c1") ||
		filteropts_pass2_script+=("-ac" "1")
 elif [ ! "${surround,,}" = "y" ]
 then
		# forceer stereo als > 2 channels of als we aantal channels niet kunnen bepalen
	channels="$(ffprobewaarden a:0 channels "$bronbestand1")" && [ "$((channels))" -le 2 ] || filteropts_pass2_script+=("-ac" "2")
 fi
 if [ "${audiorate[1]}" = "2k" -o "${audiorate[1]}" = "1k" ]
 then	# verminder samplerate tot 1/2 of 1/3, maar ga niet onder 16k want dan krijgt ge al rap oude telefoonkwaliteit
 fc=61
	bron_sample_rate=$(ffprobewaarden a:0 sample_rate "$bronbestand1") &&
		case "$bron_sample_rate" in
		48000) [ "${audiorate[1]}" = "1k" ] && audiorate[1]=16000 || audiorate[1]=24000;;
		44100) [ "${audiorate[1]}" = "1k" ] && audiorate[1]=22050 || audiorate[1]=22050;;
		32000) [ "${audiorate[1]}" = "1k" ] && audiorate[1]=16000 || audiorate[1]=16000;;
		24000) [ "${audiorate[1]}" = "1k" ] && audiorate[1]=16000 || audiorate[1]=24000;;
		# 22050) [ "${audiorate[1]}" = "1k" ] && audiorate[1]=11025 || audiorate[1]=22050;;
		*) unset audiorate;; # i.e. geen wijziging
		esac ||
		{ unset audiorate; >&2 echo -e "\e[1;31;107mERROR $fc: kan geluid sample rate van bron niet bepalen\e[0m"; return "$fc"; }
 fi
 filteropts_pass2_script+=("${audiorate[@]}")
 # PROCESCONTROLE aantal threads lezen (voor h265: -x265-params "...:pools=7")
 2>/dev/null <"$epcdir/_threads" read threads && echo THREADS gevraagd=$threads && [[ "$threads" -ge 1 && "$threads" -le $(nproc) ]] && x265params+=("pools=$threads") threadsffmpeg=("-threads:v" "$threads") || unset threadsffmpeg threads
 source "$epcdir/_pauze"* "_pauze1" 2>/dev/null	# PROCESCONTROLE pauzepunt _pauze_1
 # Multipass x.264 en XviD : pass 1 schrijft analyse, pass 2 (final pass) leest analyse; controle met ffmpeg-opties -pass en -passlogfile
 # Multipass x.265 : pass 1 schrijft analyse, pass 3 leest en herschrijft analyse, pass 2 (final pass) leest analyse; controle met
 #   -x265-params keys "pass", "stats", "no-slow-firstpass" en "slow-firstpass"
 stats="/tmp/2passffmpeg_pid${pid//:}_${vcodec[1]//:}stats"	# t.b.v. -x265-params geen ':' in naam
 #	PASS 1
	# codec-specifieke andere pass-1/pass-2 parameters: coördineer waarden voor PASS 1 en PASS 2 
 if [ "${vcodec[1]}" = "libx265" ]
 then
	[ "${singlepass,,}" != 'y' ] && x265params+=("pass=1" "stats=$stats" "no-slow-firstpass=1")
	[ "${#x265params[*]}" -gt 0 ] && passparms=("-x265-params" "$(IFS=':' eval 'echo "${x265params[*]}"')")
 else
		# werkt voor libx264 (-fastfirstpass default true), mpeg4, libxvid
		### !!! "-pass" "1" helemaal vooraan, t.b.v. wijzigen in -pass 2 !!! ###
	[ "${singlepass,,}" != 'y' ] &&
		passparms=("-pass" "1" "-passlogfile" "$stats") ||
		unset passparms
 fi
 if [ "${pass2only,,}" != 'y' -a  "${singlepass,,}" != 'y' ]
 then 
 fc=81
		# OPM: orineel met -f "${ext/mkv/matroska}", alhoewel sommige containerformaten mislukken zonder geluid (-an) en
		#  vele andere met hele hoop geluid (b.v. "-c:a copy") "-f rawvideo" is hopelijk robuuster, nog te zien welke
		#  andere problemen dat geeft.
	nice -n 20 "${dryrun[@]}" "$ffmpeg" -hide_banner "${threadsffmpeg[@]}" "${inopts_pass1_script[@]}" -i "${invoer[@]}" "${uitopts_pass1_script[@]}" "${filteropts_pass1_script[@]}" "${vcodec[@]}" "${passparms[@]}" -an -f "rawvideo" -y /dev/null "${postopts_pass1_script[@]}" ||
		{ >&2 echo -e "\e[1;31;107mERROR $fc: Eerste doorgang van ffmpeg: foutcode $?\e[0m"; return "$fc"; }
	source "$epcdir/_pauze"*  "_pauze2" 2>/dev/null	# PROCESCONTROLE pauzepunt _pauze_2
 fi
 #	PASS 2 :
 if [ "${vcodec[1]}" = "libx265" ]
 then
	[ "${#x265params[*]}" -gt 0 ] && passparms=("-x265-params" "$(IFS=':' eval 'echo "${x265params[*]/#pass=1/pass=2}"')")
 else
	[ "${passparms[0]}" = "-pass" -a "${passparms[1]}" = "1" ] && passparms[1]="2"
 fi
 fc=82
 nice -n 20 "${dryrun[@]}" "$ffmpeg" -hide_banner "${threadsffmpeg[@]}" "${inopts_pass2_script[@]}" -i "${invoer[@]}" "${uitopts_pass2_script[@]}" "${filteropts_pass2_script[@]}" "${vcodec[@]}" "${passparms[@]}" "${acodec[@]}" "$ffmpeg_overschrijven" "$uitvoer" "${postopts_pass2_script[@]}" ||
	{ >&2 echo -e "\e[1;31;107mERROR $fc: Tweede doorgang van ffmpeg: foutcode $?\e[0m"; return "$fc"; }
 [ "${concat,,}" = "demuxer" ] && rm "/tmp/2passffmpeg_pid${pid}_concatdemux"	# niet meer nodig
 # vergelijk duurtijd bron en doel om b.v. een reeks hercompressies met meld na te kijken
 [ -z "$dryrun" -a -z "$concat" ] && { echo ${bronnaam%.*}; 2>&1 ffprobe -hide_banner "${invoer[0]}" |sed -nE '/Duration/{s/.*(Duration:[^,]*),.*/\1/;p}'; } >>"$doel/_ffprobe.ou"
 [ -z "$dryrun" -a -z "$concat" ] && { echo ${bronnaam%.*}; 2>&1 ffprobe -hide_banner "$uitvoer" |sed -nE '/Duration/{s/.*(Duration:[^,]*),.*/\1/;p}'; } >>"$doel/_ffprobe.nw"
 # overschrijf bestand in doel als het niet bestaat of leeg is, anders volgens de variabele "$mv_overschrijven"
 [ -z "$dryrun" ] && { [ -s "$doel/${uitvoer##*/}" ] && mv "$mv_overschrijven" "$uitvoer" "$doel/" || mv "$uitvoer" "$doel/"; }
   
 #Origineel en resultaaat naast elkaar afspelen
	#NIET : ffplay heeft geen optie --geometry $ ffplay "$uitvoer" & ffplay "${inopts_pass2_script[@]" -an "${invoer[0]}"
 #mplayer -quiet -loop 0 -geometry 0%:960 "$uitvoer" </dev/null 2>/dev/null 2>&1 & mplayer -quiet -loop 0 -geometry 0%:960 "${inopts_pass2_script[@]" -volume 0 "${invoer[0]}" </dev/null 2>/dev/null 2>&1 &

 source "$epcdir/_uit"* 2>/dev/null	# PROCESCONTROLE uitzetten of slaapstand
 source "$epcdir/_slaap"*  2>/dev/null
}
main "$@"
