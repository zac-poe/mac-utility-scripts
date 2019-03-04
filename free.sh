#!/bin/bash
#
# simple wrapper for vm_stat to resemble linux 'free' but using columns present in Activity Monitor
#

byte_scale=1024
block=$(($byte_scale*4))

usage() {
    echo "Usage: $(basename "$0") [-h]"
    echo -e "\nOptions:"
    echo -e "\t-h"
    echo -e "\t\tHuman readable format, byte values are rounded to nearest whole byte (B),"
    echo -e "\t\tkilobyte (Kb), megabyte (Mb), or gigabyte (Gb)"
    exit 1
}

while getopts "h" opt; do
    case "$opt" in
        h)
            human_format=1
        ;;
        *)
            usage
        ;;
    esac
done

# simple support for things like 'this.sh help', or to prevent unintentional misuse with flags
if [[ ${#1} -gt 0 && $(echo "$1" | grep -c '^-') -le 0 ]]; then
    usage
fi

# retrieve actual memory information
output="$(vm_stat)"

get_bytes() {
    # pages -> bytes
    echo $(($(echo "$output" | grep "^$1:" | head -n 1 | sed 's/.* \([0-9]*\)\.$/\1/') * $block))
}

app_bytes=$(($(get_bytes 'Pages active') + $(get_bytes 'Pages speculative') + $(get_bytes 'Pages purged')))
free_bytes=$(get_bytes 'Pages free')
wired_bytes=$(get_bytes 'Pages wired down')
compressed_bytes=$(get_bytes 'Pages occupied by compressor')
cache_bytes=$(($(get_bytes 'File-backed pages') + $(get_bytes 'Pages purgeable')))
used_bytes=$(($app_bytes + $wired_bytes + $compressed_bytes + $cache_bytes))
total_bytes=$(($used_bytes + $free_bytes))
swap_bytes=$(get_bytes 'Swapouts')

scale_bytes() {
    val="$(($1 * 100))"
    label='B'
    while [[ "$val" -gt "$(($byte_scale * 100))" ]]; do
        val=$(($val / $byte_scale))
        if [[ "$label" == 'B' ]]; then
            label='Kb'
        elif [[ "$label" == 'Kb' ]]; then
            label='Mb'
        else
            label='Gb'
            break
        fi
    done
    echo "$(echo "$val" | sed 's/^\(.*\)\([0-9]\{2\}\)$/\1.\2/') $label"
}

if [[ "$human_format" -gt 0 ]]; then
    total_bytes=$(scale_bytes $total_bytes)
    used_bytes=$(scale_bytes $used_bytes)
    app_bytes=$(scale_bytes $app_bytes)
    wired_bytes=$(scale_bytes $wired_bytes)
    compressed_bytes=$(scale_bytes $compressed_bytes)
    cache_bytes=$(scale_bytes $cache_bytes)
    free_bytes=$(scale_bytes $free_bytes)
    swap_bytes=$(scale_bytes $swap_bytes)
fi

label_width='5'
field_width='12'
print_formatted() {
    first="$1"
    if [[ "$1" == 'HEADING' ]]; then
        first=''
        field_width="-${field_width}"
    fi
    printf "%-${label_width}s %${field_width}s %${field_width}s %${field_width}s %${field_width}s %${field_width}s %${field_width}s %${field_width}s\n" \
        "$first" "$2" "$3" "$4" "$5" "$6" "$7" "$8"
}

# mimic 'free' style of output
print_formatted 'HEADING' 'total' 'used' 'free' 'app' 'wired' 'compressed' 'cached'
print_formatted 'Mem:' "$total_bytes" "$used_bytes" "$free_bytes" "$app_bytes" "$wired_bytes" "$compressed_bytes" "$cache_bytes"
print_formatted 'Swap:' '' "$swap_bytes"
