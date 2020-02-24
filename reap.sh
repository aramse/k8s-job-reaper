#!/bin/bash

DEFAULT_TTL=${DEFAULT_TTL:-}  # delete Jobs finished before this time (if TTL not provided for the Job) -- empty string means never delete
NS_BLACKLIST=(${NS_BLACKLIST:-kube-system})  # do NOT delete Jobs from these namespaces (space delimited list)


function get_exp_date {
  local offset=$1
  date -u -d "-$offset" "+%FT%H:%M:%SZ"
}

echo "starting reaper with:"
echo "  DEFAULT_TTL: $DEFAULT_TTL"
echo "  NS_BLACKLIST: ${NS_BLACKLIST[@]}"

# get Jobs that do not have any parent resources (e.g. ignore those managed by CronJobs)
IFS=$'\n'
for j in $(kubectl get jobs --all-namespaces -o json | jq -r ".items[] | select( .metadata | has(\"ownerReferences\") | not) | [.metadata.name,.metadata.namespace,.status.completionTime,.metadata.annotations.ttl] | @csv" | sed 's/"//g'); do
  job=$(echo $j | cut -d ',' -f 1)
  ns=$(echo $j | cut -d ',' -f 2)
  fin=$(echo $j | cut -d ',' -f 3)
  ttl=$(echo $j | cut -d ',' -f 4)
  delete=0
  blacklisted=0
  for n in "${NS_BLACKLIST[@]}"; do  # check if in a blacklisted namespace
    [ "$n" == "$ns" ] && blacklisted=1
  done
  if [ $blacklisted -eq 0 ]; then
    if [ "$fin" != "" ]; then  # only if Job has finished
      if [ "$ttl" != "" ]; then  # check if TTL annotation on Job
        exp_date=$(get_exp_date $ttl)
        [[ "$fin" < "$exp_date" ]] && echo "job $ns/$job expired (at $exp_date) due to TTL annotation, deleting" && delete=1
      elif [ "$DEFAULT_TTL" != "" ]; then  # otherwise check if global TTL set
        exp_date=$(get_exp_date $DEFAULT_TTL)
        [[ "$fin" < "$exp_date" ]] && echo "job $ns/$job expired (at $exp_date) due to global TTL, deleting" && delete=1
      fi
    fi
    [ $delete -eq 1 ] && kubectl delete job -n $ns $job
  fi
done

echo "reaper finished"
