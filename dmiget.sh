#!/bin/bash

vendor=`dmidecode -s system-manufacturer`
bios_version=`dmidecode -s bios-version`
model=`dmidecode -s system-product-name`
serial=`dmidecode -s system-serial-number`
hw_version=`dmidecode -s baseboard-version | awk '{print $1}'`
asset_tag=`dmidecode -s baseboard-asset-tag | awk '{print $1}'`
processor_count=`dmidecode -s processor-version|wc -l|awk '{print $1}'` # (count of returned lines is how many processors)
processor=`dmidecode -s processor-version|uniq|tr -s ' '|sed 's/[ \t]*$//'`
processor_vendor=`dmidecode -s processor-manufacturer|uniq`

echo -n "{"
echo -n "\"vendor\":\"${vendor}\","
echo -n "\"bios_version\":\"${bios_version}\","
echo -n "\"model\":\"${model}\","
echo -n "\"serial\":\"${serial}\","
echo -n "\"hw_version\":\"${hw_version}\","
echo -n "\"asset_tag\":\"${asset_tag}\","
echo -n "\"processor_count\":\"${processor_count}\","
echo -n "\"processor\":\"${processor}\","
echo -n "\"processor_vendor\":\"${processor_vendor}\","
echo -n "\"memory\":["

dmidecode -t 17 | \
    grep -A 17 '^Handle' | \
    egrep 'Size|Type:|Speed|Manufacturer|Serial|Part|Handle ' | \
    sed 's/^[[:space:]]//' | \
    sed 's/Handle 0x11/DIMM: /' | \
    sed 's/^DIMM: \([0-9]*\).*/DIMM: \1/' | \
    sed 's/[ \t]*$//' | \
    awk -F ':' 'BEGIN {
init=1;
}
{
    gsub(/^[ \t]+/, "", $1);
    gsub(/^[ \t]+/, "", $2);
    if ($1 == "DIMM") {
        if (init != 1) {
            printf("},");
        }
        init=0;
        gsub(/[ \t]+$/, "", $2);
        printf("{\"dimm\":\"%s\"", $2);
    } else {
        printf(",\"%s\":\"%s\"", $1, $2);
    }
}
END {
    printf("}");
}'

echo "]}"
