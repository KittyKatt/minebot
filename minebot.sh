#!/bin/bash
#################################################################################################

#DEFAULT_SETTINGS (Can be overriden by command-line arguments)
#Host and port:
BIRCHOST=localhost
BIRCPORT=6667
#Nic to use:
BIRCNICK=minebot
#Channel to join:
BIRCCHAN=\#minecraft
#Wait N seconds before first try to join:
BIRCWAIT=5
#Try to rejoin after N seconds since connected:
BIRCJOIW=10
#Clean socket file every N seconds:
BIRCLEAN=120
#Where to save socket file?
BIRCSDIR='/all/minebot/'
BIRCSOCK="$BIRCSDIR"/sock
#NetCat binary (see comments ^^^):
NETCAT="telnet"
#NET/IO Interval (tail -s N):
TAILSLEEP=0.3
TAILSLEEPM=2.5
MINE_LOG='/all/minebot/server.log'
# Owner
# BIRCOWNER="KittyKatt!kittykatt@netadmin.silverirc.com"
BIRCOWNER="@netadmin.silverirc.com"

minebot_version="2.3.7"

function findConfig() {
	if [ ! -f /all/minebot/config ]; then
		echo "mb_verbosity = 2" > /all/minebot/config
	fi
}

get_pid() {
	MY_PID=$(pidof -o %PPID "/bin/bash /all/minebot/minebot.sh")
}

function findVerbosity() {
	local mb_verbosity=$(cat /all/minebot/config | grep "mb_verbosity" | awk -F'=' '{print $2}')
	echo $mb_verbosity
}

function setVerbosity() {
	local verbosity_level="$1"
	old_verbosity_level=$(findVerbosity)
	sed 's/mb_verbosity = '$old_verbosity_level'//' /all/minebot/config > /all/minebot/config
	echo "mb_verbosity = $verbosity_level" > /all/minebot/config
}

#################################################################################################

### IRC Colors
bold="\x02"
reset="\x03"
color1="\x032"
color2="\x030"
color3="\x035"
color4="\x033"

### Terminal Colors

tcolor0="\e[0m"      # Reset
tcolor1="\e[1;32m"   # Light Green
tcolor2="\e[1;30m"   # Dark Grey
tcolor3="\e[1;34m"   # Light Blue
tcolor4="\e[1;31m"   # Light Red
tcolor5="\e[1;37m"   # White

  
#################################################################################################

#BIRC_NETCAT_WRAPPERS (RTFM)
birc_bash_netcat() {
	exec 5<>"/dev/tcp/$1/$2";
 	cat <&5 &
	cat >&5;
}

#################################################################################################

#BIRC_FUNCTIONS (BIRC Library)
birc_help() {
	# BIRC Help - prints help and exit
	echo "BIRC - BASH IRC (lib,client,bot) - Harvie 2oo7";
	echo -e "\tUsage:";
	echo -ne "\t$0 ";
	echo "[server [port [nick [channel [ sockfile [ netcatbin]]]]]]";
	echo -e "\tDefault: $BIRCHOST $BIRCPORT $BIRCNICK $BIRCCHAN $BIRCSOCK $NETCAT";
	echo;
	exit;
}

birc_parse() {
	# BIRC Parse (data, socket)
	# You can handle each incoming line ($1) here

	#PRINT
	echo -e "${tcolor5}[${tcolor1} IRC ${tcolor5}]${tcolor0}  $1";

	#PING/PONG
        #if [[ "$1" =~ ^PING\ *:\(.*\) ]]; then
	if [[ "$1" =~ "PING" ]]; then
		ping_match=$(echo "$1" | sed 's/PING ://')
                echo -e "${tcolor5}[${tcolor1} IRC ${tcolor5}]${tcolor0} PONG :${ping_match}"
		echo "PONG :${ping_match}" >> "$2"
        fi;

	# BOT FUNCTIONS

	# Ping responder
	if [[ "$1" =~ "${BIRCNICK}: ping" ]]; then
		echo -e "${tcolor5}[${tcolor1} IRC ${tcolor5}]${tcolor0}  PRIVMSG ${BIRCCHAN} PONG!"
		echo "PRIVMSG ${BIRCCHAN} PONG!" >> "$2"
	fi;

	# Version Information
	if [[ "$1" =~ "!version" || "$1" =~ "${BIRCNICK}: version" ]]; then
		echo -e "${tcolor5}[${tcolor1} IRC ${tcolor5}]${tcolor0} PRIVMSG ${BIRCCHAN} I am owned and operated by KittyKatt and run on ArcherSeven's server. I am currently at version ${minebot_version}."
		echo "PRIVMSG ${BIRCCHAN} I am owned and operated by KittyKatt and run on ArcherSeven's server. I am currently at version ${minebot_version}." >> "$2"
	fi;

	# MineCraft Server Information
	# if [[ "$1" =~ "!serverinfo" || "$1" =~ "${BIRCNICK}: serverinfo" ]]; then
	# 	echo -e "${tcolor5}[${tcolor1} IRC ${tcolor5}]${tcolor0} PRIVMSG ${BIRCCHAN} The MineCraft server can be connected to by supplying your Multiplayer server input bar with \"archerseven.com\" and hitting connect."
	# 	echo "PRIVMSG ${BIRCCHAN} The MineCraft server can be connected to by supplying your Multiplayer server input bar with \"archerseven.com\" and hitting connect." >> "$2"
	# fi

	# Shutdown
	if [[ "$1" =~ "!shutdown" || "$1" =~ "${BIRCNICK}: shutdown" ]]; then
		issue_nickhost=$(echo "$1" | awk '{print $1}')
		if [[ "$issue_nickhost" =~ "${BIRCOWNER}" ]]; then
			echo -e "${tcolor5}[${tcolor1} IRC ${tcolor5}]${tcolor0} PRIVMSG ${BIRCCHAN} Shutting down...."
			echo "PRIVMSG ${BIRCCHAN} Shutting down...." >> "$2"
			birc_cleanup
		fi
	fi

	# Set verbosity
	if [[ "$1" =~ "!setverbosity" ]]; then
		issue_nickhost=$(echo "$1" | awk '{print $1}')
		if [[ "$issue_nickhost" =~ "${BIRCOWNER}" ]]; then
			local mb_message=$(echo "$1" | awk -F':' '{print $3}')
			old_verbosity_level=$(findVerbosity)
			new_verbosity_level=$(echo "$mb_message" | awk '{print $2}')
			setVerbosity "$new_verbosity_level"
			echo -e "${tcolor5}[${tcolor1} IRC ${tcolor5}]${tcolor0} PRIVMSG ${BIRCCHAN} New verbosity level set to $new_verbosity_level. (Old: $old_verbosity_level)"
			echo "PRIVMSG ${BIRCCHAN} New verbosity level set to $new_verbosity_level. (Old: $old_verbosity_level)" >> "$2"
		fi
	fi
}

birc_parse_m() {

	# Parser for logged in
	# if [[ "$1" =~ "logged in with entity" ]]; then
	if [[ "$1" =~ "logged in with entity" ]]; then
		if [[ $(findVerbosity) > "0" ]]; then
			logged_nick=$(echo "$1" | awk '{print $4}' | sed 's/\[\/[0-9.]*:[0-9]*\]//')
			echo -e "${tcolor5}[${tcolor2} MINECRAFT ${tcolor5}]${tcolor0}  PRIVMSG ${BIRCCHAN} ${bold}${color1}["${reset}"MineCraft${color1}]${bold}  ${color4}<==${reset} ${logged_nick} has joined the game."
			echo -e "PRIVMSG ${BIRCCHAN} ${bold}${color1}["${reset}"MineCraft${color1}]${bold}  ${color4}<==${reset}  ${logged_nick} has joined the game." >> "$2"
		fi
	fi;

	# Parser for kicked
	if [[ "$1" =~ "server command: /kick" ]]; then
		if [[ $(findVerbosity) > "1" ]]; then
			kicked_nick=$(echo "$1" | awk '{print $9}')
			kicker_nick=$(echo "$1" | awk '{print $4}')
			kicked_reason=$(echo "$1" |  awk '{ s = ""; for (i = 10; i <= NF; i++) s = s $i " "; print s }')
			if [ -z ${kicked_reason} ]; then kicked_reason="None given."; fi
			echo -e "${tcolor5}[${tcolor2} MINECRAFT ${tcolor5}]${tcolor0}  PRIVMSG ${BIRCCHAN} ${bold}${color1}["${reset}"MineCraft${color1}]${bold}  ${color3}==>${reset}  ${kicked_nick} has been kicked from the game by ${kicker_nick}. (Reason: ${kicked_reason})"
			echo -e "PRIVMSG ${BIRCCHAN} ${bold}${color1}["${reset}"MineCraft${color1}]${bold}  ${color3}==>${reset}  ${kicked_nick} has been kicked from the game by ${kicker_nick}. (Reason: ${kicked_reason})" >> "$2"
		fi
	fi;

	# Parser for logged out
	# if [[ "$1" =~ "lost connection: disconnect.quitting" ]]; then
	if [[ "$1" =~ "lost connection:" ]]; then
		if [[ $(findVerbosity) > "0" ]]; then
			logged_nick=$(echo "$1" | awk '{print $4}')
			if [[ "$1" =~ "disconnect.endOfStream" ]]; then logged_reason="End of Stream"; fi
			if [[ "$1" =~ "disconnect.overflow" ]]; then logged_reason="Overflow"; fi
			if [[ "$1" =~ "disconnect.genericReason" ]]; then logged_reason="Other"; fi
			#if [[ "${logged_reason}" != "Other" ]]; then
			#	echo -e "${tcolor5}[${tcolor2} MINECRAFT ${tcolor5}]${tcolor0}  PRIVMSG ${BIRCCHAN} ${bold}${color1}["${reset}"MineCraft${color1}]${bold}  ${color3}==>${reset}  ${logged_nick} has exited the game abnormally."
			#	echo -e "PRIVMSG ${BIRCCHAN} ${bold}${color1}["${reset}"MineCraft${color1}]${bold}  ${color3}==>${reset}  ${logged_nick} has exited the game abnormally." >> "$2"
			#else
				echo -e "${tcolor5}[${tcolor2} MINECRAFT ${tcolor5}]${tcolor0}  PRIVMSG ${BIRCCHAN} ${bold}${color1}["${reset}"MineCraft${color1}]${bold}  ${color3}==>${reset}  ${logged_nick} has exited the game."
				echo -e "PRIVMSG ${BIRCCHAN} ${bold}${color1}["${reset}"MineCraft${color1}]${bold}  ${color3}==>${reset}  ${logged_nick} has exited the game." >> "$2"
			#fi
		fi
	fi;

	# Parser for SET/ADD TIME
	if [[ "$1" =~ "server command: /time set" ]]; then
		if [[ $(findVerbosity) > "3" ]]; then
			issued_nick=$(echo "$1" | awk '{print $4}')
			time_set_to=$(echo "$1" | awk '{print $NF}')
			echo -e "${tcolor5}[${tcolor2} MINECRAFT ${tcolor5}]${tcolor0}  PRIVMSG ${BIRCCHAN} ${bold}${color1}["${reset}"MineCraft${color1}]${bold}  ${color1}::${reset}  ${issued_nick} has set the in-game time to ${time_set_to}."
			echo -e "PRIVMSG ${BIRCCHAN} ${bold}${color1}["${reset}"MineCraft${color1}]${bold}  ${color1}::${reset}  ${issued_nick} has set the in-game time to ${time_set_to}." >> "$2"
		fi
	fi;

	if [[ "$1" =~ "server command: /time add" ]]; then
		if [[ $(findVerbosity) > "3" ]]; then
			issued_nick=$(echo "$1" | awk '{print $4}')
			time_set_to=$(echo "$1" | awk '{print $NF}')
			echo -e "${tcolor5}[${tcolor2} MINECRAFT ${tcolor5}]${tcolor0}  PRIVMSG ${BIRCCHAN} ${bold}${color1}["${reset}"MineCraft${color1}]${bold}  ${color1}::${reset}  ${issued_nick} has added ${time_set_to} to the in-game time."
			echo -e "PRIVMSG ${BIRCCHAN} ${bold}${color1}["${reset}"MineCraft${color1}]${bold}  ${color1}::${reset}  ${issued_nick} has added ${time_set_to} to the in-game time." >> "$2"
		fi
	fi;

	# parser for teleportation blocks (happy? :P)
	if [[ "$1" =~ "@: Teleported" ]]; then
		if [[ $(findVerbosity) > "2" ]]; then
			teleported_nick=$(echo "$1" | awk '{print $6}')
			teleported_coords=$(echo "$1" | awk '{print $8}' | sed 's/]//')
			# parser for known destinations
			if [ "$teleported_coords" == "19,60,-30" ]; then
				teleported_coords="VilleVille"
			elif [ "$teleported_coords" == "-1525,69,722" ]; then
				teleported_coords="IceVille"
			elif [ "$teleported_coords" == "-973,60,716" ]; then
				teleported_coords="A7's House"
			elif [ "$teleported_coords" == "46,65,1531" ]; then
				teleported_coords="Eevee's Mountains"
			elif [ "$teleported_coords" == "-241,74,286" ]; then
				teleported_coords="Katt's Castle"
			fi
			echo -e "${tcolor5}[${tcolor2} MINECRAFT ${tcolor5}]${tcolor0}  PRIVMSG ${BIRCCHAN} ${bold}${color1}["${reset}"MineCraft${color1}]${bold}  ${color1}::${reset}  ${teleported_nick} was tele'd to ${teleported_coords}."
			echo -e "PRIVMSG ${BIRCCHAN} ${bold}${color1}["${reset}"MineCraft${color1}]${bold}  ${color1}::${reset}  ${teleported_nick} was tele'd to ${teleported_coords}." >> "$2"
		fi
	fi
			

	# parser for chat
	if echo "$1" | grep '<.*> IRC:' >/dev/null 2>&1; then
		if [[ $(findVerbosity) > "2" ]]; then
			chat_nick=$(echo "$1" | awk '{print $4}' | sed -e 's/<//' -e 's/>//')
			chat_message=$(echo "$1" | awk -v nr=5 '{ for (x=nr; x<=NF; x++) {printf $x " "; }; print " " }' | sed 's/IRC: //')	
			echo -e "${tcolor5}[${tcolor2} MINECRAFT ${tcolor5}]${tcolor0}  PRIVMSG ${BIRCCHAN} ${bold}${color1}["${reset}"MineCraft${color1}]${bold} ${color1}<"${reset}"${chat_nick}${color1}>${reset} ${chat_message}"
			echo -e "PRIVMSG ${BIRCCHAN} ${bold}${color1}["${reset}"MineCraft${color1}]${bold} ${color1}<"${reset}"${chat_nick}${color1}>${reset} ${chat_message}" >> "$2"
		fi
	fi
	if echo "$1" | grep '<.*>' >/dev/null 2>&1; then
		if [[ $(findVerbosity) > "4" ]]; then
			chat_nick=$(echo "$1" | awk '{print $4}' | sed -e 's/<//' -e 's/>//')
			chat_message=$(echo "$1" | awk -v nr=5 '{ for (x=nr; x<=NF; x++) {printf $x " "; }; print " " }')	
			echo -e "${tcolor5}[${tcolor2} MINECRAFT ${tcolor5}]${tcolor0}  PRIVMSG ${BIRCCHAN} ${bold}${color1}["${reset}"MineCraft${color1}]${bold} ${color1}<"${reset}"${chat_nick}${color1}>${reset} ${chat_message}"
			echo -e "PRIVMSG ${BIRCCHAN} ${bold}${color1}["${reset}"MineCraft${color1}]${bold} ${color1}<"${reset}"${chat_nick}${color1}>${reset} ${chat_message}" >> "$2"
		fi
	fi
}


 birc_connect() {
	# IRC Connect (socket, host, port)
	# Create new socket fifos...
	rm -f "$1"; touch "$1";
	rm -f "$1"r; touch "$1"r;

	# Open connection and pipes on background
	birc_startnc() {
		echo "birc_start_nc (1):   $1    $2    $3"
		tail -f --retry -s "$TAILSLEEP" "$1" 2> /dev/null | "$NETCAT" "$2" "$3" >> "$1"r;
		# Close birc after connection closed
		kill -2 $$; sleep 1; kill -9 $$;
	}
	birc_startnc "$1" "$2" "$3" &

	get_pid;
	echo "$MY_PID"

	# Recieve and process incoming commands
	tail -f --retry -s "$TAILSLEEP" "$1"r 2> /dev/null | while read BIRCLINE; do
		birc_parse "$BIRCLINE" "$1"
	done &

	tail -f --retry -s "$TAILSLEEPM" "$MINE_LOG" 2> /dev/null | while read MINELINE; do
		birc_parse_m "$MINELINE" "$1"
	done &
 }

 birc_login() {
	# IRC Login (socket, nick)
	echo NICK "$2" >> "$1"
	echo USER "$2 $2 $2 :$2" >> "$1"
	echo >> "$1"
 }

 birc_join() {
	# IRC Join (socket, channel)
	echo JOIN "$2" >> "$1"
 }

 birc_delayed_join() {
	# IRC Join with delay on BG (socket, channel, delay (secs))
	sleep "$3" && birc_join "$1" "$2" &
 }

 birc_say() {
	# IRC Send (socket, data[, receiver])
	# -> MORE USER-FUNCTIONS HERE <-

	if [[ "$2" =~ ^/\(.*\) ]]; then
		#Server command
                echo "${BASH_REMATCH[1]}" >> "$1"
        else
		#Common message
		echo PRIVMSG "$3" :"$2" >> "$1"
	fi;
 }

 birc_cleanup() {
	# BIRC Cleanup (socket)
	# Cleanup mess leaved in system before BIRC exit
	birc_jobs=$(jobs -p)
	for i in $birc_jobs; do
		echo "$i"
		kill -s SIGINT  $i; > /dev/null 2>&1
		kill -s SIGKILL $i; > /dev/null 2>&1
	done
	birc_conn_jobs=$(pidof telnet kittykatt.silverirc.com)
	kill -s SIGINT  $birc_conn_jobs; > /dev/null 2>&1
	kill -s SIGKILL $birc_conn_jobs; > /dev/null 2>&1
	echo \[!\] All background jobs stoped!
	rm -f "$1"; > /dev/null 2>&1
        rm -f "$1"r; > /dev/null 2>&1
	echo \[!\] All temp files removed!
        echo \[X\] Quiting BIRC...
	exit;
 }

 birc_autocleand() {
	# BIRC Autoclean Daemon (socket, delay)
	# starts on background, clean socket each $2 seconds
	while true; do
		sleep "$2";
		echo -n > "$1" > /dev/null 2>&1;
		echo -n > "$1"r > /dev/null 2>&1;
	done &
 }

#################################################################################################

#MAIN_C0DE (BIRC-Lib example)
 #ARGUMENTS
 if [ "$1" == "-h" ]; then birc_help; fi;
 if [ -n "$1" ]; then BIRCHOST="$1"; fi;
 if [ -n "$2" ]; then BIRCPORT="$2"; fi;
 if [ -n "$3" ]; then BIRCNICK="$3"; fi;
 if [ -n "$4" ]; then BIRCCHAN="$4"; fi;
 if [ -n "$5" ]; then BIRCSOCK="$5"; fi;
 if [ -n "$6" ]; then NETCAT="$6"; fi;

 echo \[*\] Starting BASH IRC Client\\Bot
	trap "echo -e \"${tcolor5}[${tcolor4} ERROR ${tcolor5}]${tcolor0} Caught SIGINT - terminating...\"; birc_cleanup \"$BIRCSOCK\"" SIGINT SIGKILL;
	mkdir -p "$BIRCSDIR";
 echo;

 echo -e "${tcolor5}[${tcolor3} INFO ${tcolor5}]${tcolor0} Using socket wrapper $NETCAT";
 echo -e "${tcolor5}[${tcolor3} INFO ${tcolor5}]${tcolor0}Using socket Files/FIFOs $BIRCSOCK\(r\)";
 echo -e "${tcolor5}[${tcolor3} INFO ${tcolor5}]${tcolor0} Using socket interval "$TAILSLEEP" seconds between I/O";
	birc_connect "$BIRCSOCK" "$BIRCHOST" "$BIRCPORT";
	birc_autocleand "$BIRCSOCK" "$BIRCLEAN";
		sleep 1;

 echo -e "${tcolor5}[${tcolor3} INFO ${tcolor5}]${tcolor0} $USER@$(hostname) -\> $BIRCNICK@$BIRCCHAN@$BIRCHOST:$BIRCPORT";
	birc_login "$BIRCSOCK" "$BIRCNICK";
                sleep "$BIRCWAIT";

 echo -e "${tcolor5}[${tcolor1} IRC ${tcolor5}]${tcolor0} Joining channel $BIRCCHAN";
	birc_join "$BIRCSOCK" "$BIRCCHAN";
	birc_delayed_join "$BIRCSOCK" "$BIRCCHAN" "$BIRCJOIW";
	findConfig

 echo -e "${tcolor5}[${tcolor3} INFO ${tcolor5}]${tcolor0} Now waiting for your messages on STDIN";
	while true; do
		read BIRCSEND;
		birc_say "$BIRCSOCK" "$BIRCSEND" "$BIRCCHAN";
	done;

 birc_cleanup "$BIRCSOCK";
 exit;
