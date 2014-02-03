#!/bin/bash
#
# This script is designed to be run on any physical Unix-based host in the
# Broad environment where the "dmidecode" application is installed.  It uses
# dmidecode to get various hardware information about the host, including CPU,
# memory, and vendor information.
#
# All output of this script is in JSON format so that it can be easily digested
# by a higher-level programming language.
#
# Andrew Teixeira <teixeira@broadinstitute.org>
#

echoerr() {
    echo "$@" 1>&2;
}

which dmidecode >/dev/null 2>&1

if [ $? -ne 0 ];
then
    echoerr "dmidecode was not found.  Exiting!"
    echo "{}"
    exit 1
fi

if [[ $EUID -ne 0 ]];
then
    echoerr "This script must be run as root"
    echo "{}"
    exit 1
fi

vendor=`dmidecode -s system-manufacturer`

if [[ $vendor =~ VMware.* ]];
then
    echo "{}"
    exit 0
fi

bios_version=`dmidecode -s bios-version|sed 's/[ \t]*$//'`
model=`dmidecode -s system-product-name|sed 's/[ \t]*$//'`
serial=`dmidecode -s system-serial-number|sed 's/[ \t]*$//'`
hw_version=`dmidecode -s baseboard-version|sed 's/[ \t]*$//'`
asset_tag=`dmidecode -s baseboard-asset-tag|sed 's/[ \t]*$//'`
# count of returned lines is how many processors there are
processor_count=`dmidecode -s processor-version|wc -l|awk '{print $1}'`
processor=`dmidecode -s processor-version|uniq|tr -s ' '|sed 's/[ \t]*$//'`
processor_vendor=`dmidecode -s processor-manufacturer|uniq|sed 's/[ \t]*$//'`

echo -n "{"
echo -n "\"vendor\":\"${vendor}\","
echo -n "\"bios_version\":\"${bios_version}\","
echo -n "\"model\":\"${model}\","
echo -n "\"serial\":\"${serial}\","
echo -n "\"hw_version\":\"${hw_version}\","
echo -n "\"asset_tag\":\"${asset_tag}\","
echo -n "\"processor_count\":\"${processor_count}\","
echo -n "\"processor\":\"${processor}\","
echo -n "\"processor_vendor\":\"${processor_vendor}\""

MEM=`dmidecode -t 17 | \
    grep -A 17 '^Handle' | \
    egrep 'Size|Type:|Speed|Manufacturer|Serial|Part|Handle ' | \
    sed 's/^[[:space:]]//' | \
    sed 's/^Handle /Handle: /' | \
    sed 's/[ \t]*$//' | \
    awk -F ':' 'BEGIN {
init=1;
}
{
    gsub(/^[ \t]+/, "", $1);
    gsub(/^[ \t]+/, "", $2);
    if ($1 == "Handle") {
        if (init != 1) {
            printf("},");
        }
        init=0;
        gsub(/[ \t]+$/, "", $2);
        printf("{\"handle \":\"%s\"", $2);
    } else {
        printf(",\"%s\":\"%s\"", $1, $2);
    }
}
END {
    printf("}");
}' 2>/dev/null`

if [ $? -eq 0 ];
then
    echo -n ",\"memory\":["
    echo -n $MEM
    echo -n "]"
fi

echo "}"
