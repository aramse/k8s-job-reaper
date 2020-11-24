#!/bin/bash

DEFAULT_TTL=${DEFAULT_TTL:-1 day}  # delete Jobs finished before this time (if TTL not provided for the Job) -- empty string means never delete by default
DEFAULT_TTL_FAILED=${DEFAULT_TTL_FAILED:-5 days}  # same as above but for unfinished Jobs (DEFAULT_TTL *must* be set for this to take effect) -- empty string means never delete failed Jobs by default
NS_BLACKLIST=(${NS_BLACKLIST:-kube-system})  # do NOT delete Jobs from these namespaces (space delimited list)


function get_exp_date {
  local offset=$1
  date -u -d "-$offset" "+%FT%H:%M:%SZ"
}

echo "starting reaper with:"
echo "  DEFAULT_TTL: $DEFAULT_TTL"
echo "  DEFAULT_TTL_FAILED: $DEFAULT_TTL_FAILED"
echo "  NS_BLACKLIST: ${NS_BLACKLIST[@]}"

[ "$DEFAULT_TTL_FAILED" != "" ] && [ "$DEFAULT_TTL" == "" ] && echo "FATAL: DEFAULT_TTL_FAILED can only be set if DEFAULT_TTL is also set" && exit 1

# get Jobs that do not have any parent resources (e.g. ignore those managed by CronJobs)
IFS=$'\n'
for j in $(kubectl get jobs --all-namespaces -o json | jq -r ".items[] | select( .metadata | has(\"ownerReferences\") | not) | [.metadata.name,.metadata.namespace,.metadata.creationTimestamp,.status.completionTime,.metadata.annotations.ttl,.status.active,.status.succeeded] | @csv" |  sed 's/"//g'); do
  job=$(echo $j | cut -d ',' -f 1)
  ns=$(echo $j | cut -d ',' -f 2)
  begin=$(echo $j | cut -d ',' -f 3)
  fin=$(echo $j | cut -d ',' -f 4)
  ttl=$(echo $j | cut -d ',' -f 5)
  active=$(echo $j | cut -d ',' -f 6)
  succeeded=$(echo $j | cut -d ',' -f 7)

  active=${active:-0}
  succeeded=${succeeded:-0}

  delete=0
  blacklisted=0
  #echo "$job: $fin"
  for n in "${NS_BLACKLIST[@]}"; do  # check if in a blacklisted namespace
    [ "$n" == "$ns" ] && blacklisted=1
  done
  if [ $blacklisted -eq 0 ]; then
      if [ "$ttl" != "" ] ; then  # check if TTL annotation on Job
        if [ $active -eq 0 ] ; then
            if [ $succeeded -eq 1 ]; then
              exp_date=$(get_exp_date $ttl)
              [[ "$fin" < "$exp_date" ]] && echo "Finished job $ns/$job expired (at $exp_date) due to TTL($ttl) annotation, deleting" && delete=1
            else
              exp_date=$(get_exp_date $DEFAULT_TTL_FAILED)
              [[ "$begin" < "$exp_date" ]] && echo "Unfinished job $ns/$job expired (at $exp_date) due to default failed TTL ($DEFAULT_TTL_FAILED), deleting" && delete=1
            fi
        fi
      elif [ "$DEFAULT_TTL" != "" ]; then  # otherwise check if global TTL set
        if [ $active -eq 0 ] ; then
            if [ $succeeded -eq 1 ]; then
              exp_date=$(get_exp_date $DEFAULT_TTL)
              [[ "$fin" < "$exp_date" ]] && echo "Finished job $ns/$job expired (at $exp_date) due to global TTL($DEFAULT_TTL), deleting" && delete=1
            else
              exp_date=$(get_exp_date $DEFAULT_TTL_FAILED)
              [[ "$begin" < "$exp_date" ]] && echo "Unfinished job $ns/$job expired (at $exp_date) due to default failed TTL($DEFAULT_TTL_FAILED), deleting" && delete=1
            fi
        fi
      fi
      [ $delete -eq 1 ] && kubectl delete job -n $ns $job
  fi
done

echo "reaper finished"
