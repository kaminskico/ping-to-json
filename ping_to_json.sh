#!/bin/sh

# ----------------------------------------------------------------------------------------
# You pass the whole ping output as input stream, and this produces the JSON of it.
# You can do like this (e.g.):
#   ping -c 5 google.com | ping-script/ping_to_json.sh | jq
# ----------------------------------------------------------------------------------------

# cd to the current directory as it runs other shell scripts
cd "$(dirname "$0")" || exit

while read -r line; do
  if echo "${line}" | grep "bytes from" | grep "icmp_seq=" | grep "ttl=" | grep -q "time=" ; then
    if [ -z "${ICMP_SEQUENCES}" ]; then
      ICMP_SEQUENCES="$(echo "${line}" | ./icmp_line.sh)"
	  echo "1"
    else
      ICMP_SEQUENCES="${ICMP_SEQUENCES}, $(echo "${line}" | ./icmp_line.sh)"
	  echo "2"
    fi
  elif echo "${line}" | grep -q "rtt min/avg/max/mdev" ; then
    if [ -n "${RTT_STATISTICS_JSON}" ]; then
      >&2 echo "ERROR: There must be only one RTT statistics line, but '${line}' appeared as another one. Previous RTT statistics is:"
      >&2 echo "${RTT_STATISTICS_JSON}"
	  echo "3"
      exit 1
    else
      RTT_STATISTICS_JSON="$(echo "${line}" | ./rtt_statistics.sh)"
	  echo "4"
    fi
  elif echo "${line}" | grep "packets transmitted, " | grep "received, " | grep " packet loss, " | grep -q "time " ; then
    if [ -n "${RTT_SUMMARY_JSON}" ]; then
      >&2 echo "ERROR: There must be only one RTT summary line, but '${line}' appeared as another one. Previous RTT summary is:"
      >&2 echo "${RTT_SUMMARY_JSON}"
	  echo "5"
      exit 1
    else
      RTT_SUMMARY_JSON="$(echo "${line}" | ./rtt_summary.sh)"
	  echo "6"
    fi
  fi
echo "BOTTOM"
done < /dev/stdin


if [ -z "${RTT_STATISTICS_JSON}" ]; then
  >&2 echo "ERROR: RTT statistics line is not found, which starts with rtt min/avg/max/mdev"
  echo "7"
  exit 1
elif  [ -z "${RTT_SUMMARY_JSON}" ]; then
  >&2 echo "ERROR: RTT summary line is not found, which is like '** packets transmitted, ** received, *% packet loss, time ****ms'"
  echo "8"
  # exit 1
fi
: '
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data. --> BOTTOM
64 bytes from 8.8.8.8: icmp_seq=1 ttl=116 time=8.15 ms --> 1 & BOTTOM
64 bytes from 8.8.8.8: icmp_seq=2 ttl=116 time=10.5 ms --> 2 & BOTTOM
--> BOTTOM
--- 8.8.8.8 ping statistics --- -->BOTTOM
2 packets transmitted, 2 received, 0% packet loss, time 3ms --
rtt min/avg/max/mdev = 8.148/9.303/10.459/1.159 ms
'
echo "{"
echo "  \"rtt_summary\": ${RTT_SUMMARY_JSON},"
echo "  \"rtt_statistics\": ${RTT_STATISTICS_JSON},"
echo "  \"icmp_sequences\": [${ICMP_SEQUENCES}]"
echo "}"