#!/bin/bash
rsync="$HOME/rsync/rsync --preserve-cache"
rsync_dest='man3:'
memsize=1
memsize=$(($(free -mt  | grep Mem | tr -s ' ' | cut -d ' ' -f 2)))
patternsize=100 #in MBytes
userfile_number=$(($memsize/(2*$patternsize)))
backupfile_number=$(($memsize*3/2/$patternsize))
backup_total=$(($backupfile_number*1024*patternsize))
user_total=$(($userfile_number*1024*patternsize))
TIMEFORMAT='%5R s'
READTYPE="fread"
NORMAL=NORMAL
backup=backup #backup dir
user=user #user dir
speedcount=1000

checkfiles() {
	dir=$1 # dir fo the files
	number=$2 # number of files
	total=$3 # total size of files
	size=$4
	mkdir -p $dir
	tmp=0
	tmp="$(du $dir/$number | cut -f 1)"
	if [ "$(du -s $dir | cut -f 1)" -lt "$total" ]\
	|| [ "$(du -s $dir | cut -f 1)" -gt "$(($total+1024))" ]\
	|| [  $(($tmp/1024)) != "$size" ]
	then
		echo creating $dir
		dd if=/dev/urandom of=patternfile bs=1M count=$size
		rm -r $dir
		mkdir -p $dir
		for i in $(seq -w 1 $number)
		do
			cp patternfile $dir/$i
		done
	else
		echo $dir has correct size
	fi
}

readdir()
{
	path=$1
	adv=$2
	max_count=$3
		for i in $1/* ; do
			./readfile $i $READTYPE $adv
		done
}
timedir()
{
	time readdir "$@"
}
timefind()
{
	path=$1
	adv=$2
	max_count=$3
	echo -en "reading $1\t\t\t"
	timedir "$@" 2>&1
	echo "done with $1"
	cachestats
	echo
}
readcount()
{
	path=$1
	adv=$2
	max_count=$3
	if [[ -z $max_count ]]; then max_count=100000; fi
	for i in $(ls $1 | head -n $max_count) ; do
		echo $path/$i
		./readfile $path/$i $READTYPE $adv
	done
}
timecount()
{
	echo -e "reading $1\t\t\t"
	time readcount "$@"
	echo "done with $1"
}
cleanstats()
{
	grep total | tr -s ' ' | cut -d ' ' -f 4 | printf "%5d\n" "$(cat)" | sed 's/$/ mb/'
}
cachestats()
{
	echo -en "active ref\t"
	./page-types -b 'lru' -b 'active' -b 'referenced' | cleanstats
	echo -en "active nonref\t"
	./page-types -b 'lru' -b 'active' -b '~referenced' | cleanstats
	echo -en "inactive ref\t"
	./page-types -b 'lru' -b '~active' -b 'referenced' | cleanstats
	echo -en "inactive nonref\t"
	./page-types -b 'lru' -b '~active' -b '~referenced' | cleanstats
}



echo machine physical memory size: $memsize MB
echo You will need twice your physical memory as disk space!
echo userfiles: files the user has accessed and will access again: $((patternsize*$userfile_number)) MB
echo backupfiles: files to backup which pushes the user file out of cache: $((patternsize*$backupfile_number)) MB

checkfiles $backup $backupfile_number $backup_total $patternsize
checkfiles $user $userfile_number $user_total $patternsize

echo -----------
echo compiling
if ! make; then	exit 1; fi
echo -----------

echo -----------
echo Tests will commence now!
echo -----------

echo using $READTYPE to read files

echo dropping caches
echo 3 > /proc/sys/vm/drop_caches

if [[ -z "$1" ]]; then
	timefind $user $NORMAL 100
	timefind $backup NOREUSE 100
	timefind $user $NORMAL 100
	timefind $user $NORMAL 100
elif [[ "$1" == "rsync" ]]; then
	timedir $user $NORMAL
	echo -n
	ssh man3 'rm -r /tmp/rdest'
	$rsync -av $backup/ $rsync_dest/tmp/rdest
	timedir $backup $NORMAL 5
	timedir $backup $NORMAL 5
elif [[ "$1" == "conc" ]]; then
	timecount $backup NORMAL 5 2>&1 &
	timecount $backup NOREUSE 100 2>&1
	timecount $backup $NORMAL 5 2>&1
	timecount $backup $NORMAL 5 2>&1
elif [[ "$1" == "useronly" ]]; then
	timefind $user $NORMAL 100
	timefind $user $NORMAL 100
	timefind $user $NORMAL 100
	timefind $user $NORMAL 100
elif [[ "$1" != "speedtest" ]]; then
	export TIMEFORMAT='%5R'
	timedir $user NOREUSE
	count=0
	sum=0
	tmp=0
	while [[ $count -lt $speedcount ]]
	do
		#echo -en "reading $user $count\t\t"
		tmp=$(timedir $user $NORMAL 2>&1)
		echo $tmp
		sum=$( echo "scale=5;$tmp+$sum" | bc)
		count=$((count+1))
	done
	echo $sum
	echo $count
	echo "scale=4;$sum/$count" | bc
else
	echo invalid option
fi
