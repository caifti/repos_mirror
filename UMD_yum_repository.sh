#!/bin/sh

# script courtesy of Alexandre de Abreu [alex@fedoranews.org]
# adapted for EGI UMD repositories

# Wgets(http) rpm packages then executes yum-arch/createrepo
# creating the repository headers on local machine
# http://fedoranews.org/alex/tutorial/yum/

# Last Modified: 16/15/2014

# Setup including:
# Mirror examples for RH9 and Fedora Base/Updates
# Yum.conf configuration
# GPG/MD5 checking, Proxy support
# yum-arch and createrepo compatible

# Visit FedoraNEWS Website http://fedoranews.org
# Author: Alexandre de Abreu [alex@fedoranews.org]

# For the impatient ones: just execute this script
# and follow the advice of error messages

# Fill the MIRROR variables as you wish and test running
# on the shell, after things working try the line below
# to setup a cron job for executing every six hours:
# 1 */6 * * * user /path/to/yum_repository.sh

# Configure your clients /etc/yum.conf with the following
# lines and start a web/ftp server on the repository
# [updates-local]
# name=Linux $releasever - $basearch - Updates
# baseurl=http://repository_ipaddr/path/to/repository/
# OR
# baseurl=ftp://repository_ipaddr/path/to/repository/

# And change the local repository server yum.conf to:
# baseurl=file:///path/to/repository/

# Mirrors arrays  ###################################
# Try to use those with "Indexes" Apache option enabled
# Fedora mirrors http://fedora.redhat.com/download/mirrors.html
# RedHat mirrors http://www.redhat.com/download/mirror.html
# Yum RPM for Red Hat http://www.linux.duke.edu/projects/yum/download.ptml

# Put any numbers of mirrors here, sequentially:
# MIRROR_URL[X]="http://url"
# MIRROR_DIR[X]="/filesystem/path"

# MIRROR_URL    -> Where to get .rpm files, must be a URL
# MIRROR_DIR    -> Where .rpm files and repository struct will be on the disk
# X             -> Subscript, array index, must begin with 0

# UMD 3 Updates Mirror
MIRROR_URL[0]="http://repository.egi.eu/sw/production/umd/3/"
MIRROR_DIR[0]="/rep/repo/UMD/3/"

# other repositories - Fedora 2 Updates Mirror
#MIRROR_URL[1]="http://distro.ibiblio.org/pub/linux/distributions/fedora/linux/core/updates/2/"
#MIRROR_DIR[1]="/var/ftp/pub/linux/fedora/2/updates/"

#####################################################
# Do not edit below this line unless you know what
# you are doing

# Filter what is intersting for us
#IGNORE_FILES="*-debuginfo-*,*\.src\.rpm,*\.hdr"
IGNORE_FILES="*\.src\.rpm,robots*"
ALLOW_FILES="*i[356]86\.rpm,*x86_64\.rpm,*noarch\.rpm,*\.bz2,*\.gz,*\.xml,*\.repo"

# List of ignored directories(space separated)
# repoview/ files are ignored by default, to disable leave it blank
IGNORE_DIRS="repoview"

# Default umask
DEF_UMASK=022

# Log file, where all output will go
# If you dont want logging set LOG_FILE to /dev/null
# If you want to rotate it with logrotate every 1Mb
# edit /etc/logrotate.conf and add the following
# /var/log/yum_repository.log {
#	 create 644 user group
#        compress
#        nomail
#        missingok
#        notifempty
#        rotate 2
#        size 5M
# }
LOG_FILE="/var/log/yum_repository.log"

# Allow resume[-c]
# Do not create domain dir[-nH]
# Do not go to parent dirs[-np]
# Be recursive, needed[-r]
# Append to output log[-a]
WGET_ARGS="-a $LOG_FILE -R $IGNORE_FILES -A $ALLOW_FILES -np -nH -c -r"
WGET=$(/usr/bin/which --skip-dot --skip-tilde wget 2>/dev/null) || {
	/bin/echo "[*] Try installing wget and check PATH var"
	/bin/echo "[*] Exiting.."
	exit 1
}

# GPG/MD5 check, this can be done on yum.conf on clients too
# If enabled, bad packages will be renamed to with .BAD extentsion
# before repository structure creation/update
# This is done using "rpm -K package" command
# 0 = disable 1=enable
GPGCHECK=1

# Createrepo support for FC3+ compaibility
# Uncomment the following line is you want this
#YUMARCH=$(/usr/bin/which --skip-dot --skip-tilde yum-arch 2>/dev/null)
#CREATEREPO=$(/usr/bin/which --skip-dot --skip-tilde createrepo 2>/dev/null)

#[ -z "$YUMARCH" -a -z "$CREATEREPO" ] && {
#	/bin/echo "[*] Try installing yum-arch or createrepo programs and check PATH var"
#	/bin/echo "[*] Exiting.."
#	exit 1
#}


#[ 1$(/usr/bin/id -u) -eq 10 ] && {
#	/bin/echo "[*] Why running this as superuser? Try as a normal user and check"
#	/bin/echo "[*] write permissions to local repository directories."
#	/bin/echo "[*] Exiting.."
#	exit 1
#}

RPM=$(/usr/bin/which --skip-dot --skip-tilde rpm 2>/dev/null) || {
	/bin/echo "[*] Try installing RPM and check PATH var"
	/bin/echo "[*] Exiting.."
	exit 1
}

# Check presence of public GPG key(s)
$RPM --quiet -q gpg-pubkey || {
	/bin/echo "[*] No public GPG key(s) installed."
	/bin/echo "[*] Try to execute: rpm --import http://repository.egi.eu/sw/production/umd/UMD-RPM-PGP-KEY"
	exit 1
}

# Check if logfile is writable
#touch /var/log/yum_repository.log
[ -w $LOG_FILE ] || {
	/bin/echo "[*] No write permission on logfile: $LOG_FILE"
	/bin/echo "[*] Exiting.."
	exit 1
}

PID_FILE=/tmp/.yum_repository.pid

# Check if already running
[ -s "$PID_FILE" ] && {
	/bin/echo "[*] PID File exists $PID_FILE"
	/bin/echo "[*] Checking PID.."
	PID=$(/bin/egrep -o "^[0-9]{1,}" $PID_FILE)
	/bin/ps --pid $PID && {
		/bin/echo "[*] Process $PID found."
		/bin/echo "[*] Script seems to be already running!"
		/bin/echo "[*] Exiting.."
		exit 1
	}
	/bin/echo "[*] Process ID $PID not found"
	/bin/echo "[*] Starting new process.."
}

# Check proxy options
[ -n "$PROXY_SERVER" -a -n "$PROXY_PORT" ] && {
	# Exporting for wget
	export http_proxy="$PROXY_SERVER:$PROXY_PORT" && PROXY_FLAG=1
	WGET_ARGS="$WGET_ARGS --proxy=on"
	[ -n "$PROXY_USER" -a -n "$PROXY_PASS" ] && WGET_ARGS="$WGET_ARGS \
	--proxy-user=$PROXY_USER --proxy-passwd=$PROXY_PASS"
}

# No process running, starting new one
/bin/echo $$ > $PID_FILE

# Sets umask
umask $DEF_UMASK

# Starts from 1st mirror definition
count=0

while [ ${MIRROR_URL[count]} ]; do
	# Some checking
	[ -d ${MIRROR_DIR[count]} ] || {
		/bin/echo "[*] Try creating localdir ${MIRROR_DIR[count]}" 
		/bin/echo "[*] Exiting.."
		exit 1
	}

	[ -w ${MIRROR_DIR[count]} ] || {
		/bin/echo "[*] Check write permissions on localdir ${MIRROR_DIR[count]}" 
		/bin/echo "[*] Exiting.."
		exit 1
	}
	
	cd ${MIRROR_DIR[count]}
	
	CUT_DIRS=$(/bin/echo "${MIRROR_URL[count]}" | /bin/egrep -o "\/" | /usr/bin/wc -l)
	CUT_DIRS=$((CUT_DIRS-3))

	/bin/echo -e "[*] Writing logs to $LOG_FILE"
	/bin/echo -e "[*] Getting files from ${MIRROR_URL[count]}"
	/bin/echo -n "[*] Download started: " >> $LOG_FILE 
	/bin/date >> $LOG_FILE

	# Capture some intersting signals
	trap "{
		/bin/echo \"[*] Removing PID file..\"
		/bin/rm -f $PID_FILE
		[ 1$PROXY_FLAG -ne 1 ] && {
			/bin/echo \"[*] Unseting http_proxy var..\"
			unset http_proxy
		}
		/bin/echo -e \"[*] Exiting..\"
		exit 1
	}" 2 3 15 19

        [ -n "$IGNORE_DIRS" ] && {
                for i in $IGNORE_DIRS; do
                        WGET_ARGS="$WGET_ARGS -X /"`echo "${MIRROR_URL[count]}" | cut -d/ -f4-`"$i"
                done
        }

	eval $WGET $WGET_ARGS --cut-dirs $CUT_DIRS ${MIRROR_URL[count]}
	/bin/echo -e "[*] Download complete for ${MIRROR_URL[count]}\n" >> $LOG_FILE
	/bin/echo -e "[*] Download complete for ${MIRROR_URL[count]}\n"

	# md5 and gpg signature check
	# any package that fails this check will be renamed with extension .BAD
	[ 1$GPGCHECK -eq 11 ] && {
		for rpm in `find ${MIRROR_DIR[count]} -name "*.rpm"`; do
			$RPM -K $rpm >> $LOG_FILE || {
				/bin/echo "[*] Bad RPM found: $rpm"
				/bin/echo "[*] Moving to $rpm.BAD"
				/bin/echo -e "\n[*] BAD package found: $rpm\n" >> $LOG_FILE
				/bin/mv -f $rpm $rpm.BAD
			}
		done
	}
	
# If you want to also create the mirror repositories uncomment the following lines
#	for PROG in $YUMARCH $CREATEREPO;do
#		# create repository dirs
#		/bin/echo -e "[*] Executing $PROG on ${MIRROR_DIR[count]}"
#		/bin/echo -n "[*] Time started: " >> $LOG_FILE
#		/bin/date >> $LOG_FILE
#		eval $PROG ${MIRROR_DIR[count]} >> $LOG_FILE 2>&1
#	done
#	/bin/echo -e "[*] Repository creation complete for ${MIRROR_DIR[count]}\n" >> $LOG_FILE
#	/bin/echo -e "[*] Repository creation complete for ${MIRROR_DIR[count]}\n"
#	/bin/echo -e "[*] Done.\n\n"

	count=$((count+1))
done

/bin/chmod 600 $LOG_FILE
/bin/rm -f $PID_FILE
[ 1$PROXY_FLAG -ne 1 ] && unset http_proxy

/bin/echo "[*] Finished"
/bin/echo -n "[*] Finished on " >> $LOG_FILE
/bin/date >> $LOG_FILE

exit 0
