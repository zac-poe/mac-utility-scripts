#!/bin/bash
#
# simple wrapper for top to resemble linux 'free' as a Mac port
#

byte_scale=1024

usage() {
    echo "Usage: $(basename "$0") [-h]"
    echo -e "\nOptions:"
    echo -e "\t-h"
    echo -e "\t\tHuman readable format, byte values are rounded to nearest whole byte (B),"
    echo -e "\t\tkilobyte (K), megabyte (M), or gigabyte (G)"
    exit 1
}

while getopts "h" opt; do
    case "$opt" in
        h) human_format=1;;
        *) usage;;
    esac
done

# simple support for things like 'this.sh help', or to prevent unintentional misuse with flags
if [[ ${#1} -gt 0 && $(echo "$1" | grep -c '^-') -le 0 ]]; then
    usage
fi

# retrieve actual memory information
output="$(top -S -l 1)"
memory_marker='PhysMem'
swap_marker='Swap'

get_bytes() {
    stat="$(echo "$output" | grep "^$1:" | sed "s/.* \([0-9MKG]*\) $2.*/\1/")"

    val="${stat:0:$((${#stat} - 1))}"
    label="${stat:$((${#stat} - 1)):1}"

    while [[ "${#label}" -gt 0 ]]; do
        val=$(($val * $byte_scale))
        if [[ "$label" == 'G' ]]; then
            label='M'
        elif [[ "$label" == 'M' ]]; then
            label='K'
        else
            label=''
        fi
    done
    echo $val
}

used_bytes=$(get_bytes "$memory_marker" 'used')
free_bytes=$(get_bytes "$memory_marker" 'unused')
shared_bytes=$(get_bytes 'MemRegions' 'shared')
total_bytes=$(($used_bytes + $free_bytes))
swap_used_bytes=$(get_bytes "$swap_marker" '+')
swap_free_bytes=$(get_bytes "$swap_marker" 'free')
swap_total_bytes=$(($swap_used_bytes + $swap_free_bytes))

scale_bytes() {
    val="$(($1 * 10))"
    label=''

    while [[ "$val" -gt "$(($byte_scale * 10))" ]]; do
        val=$(($val / $byte_scale))
        if [[ "${#label}" -le 0 ]]; then
            label='K'
        elif [[ "$label" == 'K' ]]; then
            label='M'
        else
            label='G'
            break
        fi
    done
    echo "$(echo "$val" | sed 's/^\(.*\)\([0-9]\)$/\1.\2/') $label"
}

if [[ "$human_format" -gt 0 ]]; then
    total_bytes=$(scale_bytes $total_bytes)
    used_bytes=$(scale_bytes $used_bytes)
    shared_bytes=$(scale_bytes $shared_bytes)
    free_bytes=$(scale_bytes $free_bytes)
    swap_used_bytes=$(scale_bytes $swap_used_bytes)
    swap_free_bytes=$(scale_bytes $swap_free_bytes)
    swap_total_bytes=$(scale_bytes $swap_total_bytes)
fi

label_width='5'
field_width='12'
print_formatted() {
    first="$1"
    if [[ "$1" == 'HEADING' ]]; then
        first=''
        field_width="-${field_width}"
    fi
    printf "%-${label_width}s %${field_width}s %${field_width}s %${field_width}s %${field_width}s\n" \
        "$first" "$2" "$3" "$4" "$5"
}

# mimic 'free' style of output
print_formatted 'HEADING' 'total' 'used' 'free' 'shared'
print_formatted 'Mem:' "$total_bytes" "$used_bytes" "$free_bytes" "$shared_bytes"
print_formatted 'Swap:' "$swap_total_bytes" "$swap_used_bytes" "$swap_free_bytes"
