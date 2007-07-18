#================
# FILE          : KIWIConfig.sh
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module contains common used functions
#               : for the config.sh image scripts
#               : 
#               :
# STATUS        : Development
#----------------
#======================================
# suseInsertService
#--------------------------------------
function suseInsertService {
	# /.../
	# Recursively insert a service. If there is a service
	# required for this service it will be inserted first
	# -----
	local service=$1
	local result
	while true;do
		result=`/sbin/insserv $service 2>&1`
		if [ $? = 0 ];then
			echo "Service $service inserted"
			break
		else
			result=`echo $result | head -n 1 | cut -f3 -d " "`
			if [ -f /etc/init.d/$result ];then
				suseInsertService /etc/init.d/$result
			else
				echo "$service: required service: $result not found...skipped"
				break
			fi
		fi
	done
}

#======================================
# suseRemoveService
#--------------------------------------
function suseRemoveService {
	# /.../
	# Remove a service and its dependant services
	# using insserv -r
	# ----
	local service=/etc/init.d/$1
	while true;do
		/sbin/insserv -r $service &>/dev/null
		if [ $? = 0 ];then
			echo "Service $service removed"
			break
		else
			result=`/sbin/insserv -r $service 2>&1|tail -n 2|cut -f10 -d " "`
			if [ -f /etc/init.d/$result ];then
				suseRemoveService $result
			else
				echo "$service: $result not found...skipped"
				break
			fi
		fi
	done
}

#======================================
# suseActivateServices
#--------------------------------------
function suseActivateServices {
	# /.../
	# Check all services in /etc/init.d/ and activate them
	# by calling insertService
	# -----
	for i in /etc/init.d/*;do
		if [ -x $i ] && [ -f $i ];then
			echo $i | grep -q skel
			if [ $? = 0 ];then
				continue
			fi
			suseInsertService $i
		fi
	done
}

#======================================
# suseService
#--------------------------------------
function suseService {
	# /.../
	# if a service exist then enable or disable it using chkconfig
	# example : suseService apache2 on
	# example : suseService apache2 off
	# ----
	local service=$1
	local action=$2
	if [ -x /etc/init.d/$i ] && [ -f /etc/init.d/$service ];then
		if [ $action = on ];then
			/sbin/chkconfig $service on
		elif [ $action = off ];then
			/sbin/chkconfig $service off
		fi
	fi
}

#======================================
# suseServiceDefaultOn
#--------------------------------------
function suseServiceDefaultOn {
	# /.../
	# Some basic services that needs to be on.
	# ----
	services=(
		boot.rootfsck
		boot.cleanup
		boot.localfs
		boot.localnet
		boot.clock
		policykitd
		haldaemon
		network
		atd
		syslog
		cron
	)
	for i in "${services[@]}";do
		if [ -x /etc/init.d/$i ] && [ -f /etc/init.d/$i ];then
			/sbin/chkconfig $i on
		fi
	done
}

#======================================
# baseSetupUserPermissions
#--------------------------------------
function baseSetupUserPermissions {
	while read line in;do
		dir=`echo $line | cut -f6 -d:`
		uid=`echo $line | cut -f3 -d:`
		usern=`echo $line | cut -f1 -d:`
		group=`echo $line | cut -f4 -d:`
		if [ -d "$dir" ] && [ $uid -gt 200 ] && [ $usern != "nobody" ];then
			group=`cat /etc/group | grep "$group" | cut -f1 -d:`
			chown -c -R $usern:$group $dir/*
		fi
	done < /etc/passwd
}

#======================================
# baseSetupBoot
#--------------------------------------
function baseSetupBoot {
	if [ -f /linuxrc ];then
		cp linuxrc init
		exit 0
	fi
}

#======================================
# suseConfig
#--------------------------------------
function suseConfig {
	/sbin/SuSEconfig
}

#======================================
# baseCleanMount
#--------------------------------------
function baseCleanMount {
	umount /proc/sys/fs/binfmt_misc
	umount /proc
	umount /dev/pts
	umount /sys
}

#======================================
# stripLocales
#--------------------------------------
function baseStripLocales {
	local imageLocales="$@"
	local directories="
		/opt/gnome/share/locale
		/usr/share/locale
		/opt/kde3/share/locale
		/usr/lib/locale
	"
	for dir in $directories; do
		locales=`find $dir -type d -maxdepth 1 2>/dev/null`
		for locale in $locales;do
			if test $locale = $dir;then
				continue
			fi
			
			local baseLocale=`basename $locale`
			local found="no"
			for keep in $imageLocales;do
				if echo $baseLocale | grep $keep;then
					found="yes"
					break
				fi
			done

			if test $found = "no";then
				rm -rf $locale
			fi
		done
	done
}

#======================================
# baseStripTools
#--------------------------------------
function baseStripTools {
	local tpath=$1
	local tools=$2
	for file in `find $tpath`;do
		found=0
		base=`basename $file`
		for need in $tools;do
			if [ $base = $need ];then
				found=1
				break
			fi
		done
		if [ $found = 0 ];then
			rm -f $file
		fi
	done
}

#======================================
# suseStripInitrd
#--------------------------------------
function suseStripInitrd {
	#==========================================
	# remove unneeded files
	#------------------------------------------
	rpm -e popt bzip2 --nodeps
	rm -rf `find -type d | grep .svn`
	local files="
		/usr/share/info /usr/share/man /usr/share/cracklib /usr/lib/python*
		/usr/lib/perl* /usr/share/locale /usr/share/doc/packages /var/lib/rpm
		/usr/lib/rpm /var/lib/smart /boot/* /opt/* /usr/include /root/.gnupg
		/etc/PolicyKit /etc/sysconfig /etc/init.d /etc/profile.d /etc/skel
		/etc/ssl /etc/java /etc/default /etc/cron* /etc/dbus* /etc/modprobe*
		/etc/pam.d* /etc/DIR_COLORS /etc/rc* /usr/share/hal /usr/share/ssl
		/usr/lib/hal /usr/lib/*.a /usr/lib/*.la /usr/lib/librpm*
		/usr/lib/libssl* /usr/lib/libpanel* /usr/lib/libncursesw*
		/usr/lib/libmenu*
		/lib/modules/*/kernel/drivers/net/wireless
		/lib/modules/*/kernel/drivers/net/pcmcia
		/lib/modules/*/kernel/drivers/net/tokenring
		/lib/modules/*/kernel/drivers/net/bonding
		/lib/modules/*/kernel/drivers/net/hamradio
	"
	for i in $files;do
		rm -rf $i
	done
	#==========================================
	# remove unneeded tools
	#------------------------------------------
	local tools="
		tune2fs swapon shutdown sfdisk resize_reiserfs
		reiserfsck reboot halt pivot_root modprobe modinfo
		mkswap mkinitrd mkreiserfs mkfs.ext3 mkfs.ext2 mkfs.cramfs
		losetup ldconfig insmod init ifconfig fdisk e2fsck dhcpcd
		depmod atftpd klogconsole hwinfo xargs wc tail tac readlink
		mkfifo md5sum head expr file free find env du dirname cut
		column chroot atftp clear tr host test printf mount dd uname umount
		true touch sleep sh pidof sed rmdir rm pwd ps mv mkdir kill hostname
		gzip grep false df cp cat bash basename arch sort ls uniq lsmod
		usleep parted mke2fs pvcreate vgcreate lvm resize2fs ln
	"
	for path in /sbin /usr/sbin /usr/bin /bin;do
		baseStripTools "$path" "$tools"
	done
}
