#!/bin/bash

EXPIRATION=${EXPIRATION:-6 hours}  # delete Jobs created before this time
NS_BLACKLIST=(${NS_BLACKLIST:-kube-system})  # do NOT delete Jobs from these namespaces

echo "starting reaper with:"
echo "EXPIRATION=$EXPIRATION"
echo "NS_BLACKLIST:${NS_BLACKLIST[@]}"
EXPIRATION_DEADLINE=$(date -u -d "-${EXPIRATION}" "+%FT%H:%M:%SZ")
echo "deleting jobs older than $EXPIRATION_DEADLINE"

# delete Jobs that do not have any parent resources (e.g. ignore those managed by CronJobs) and are older than $EXPIRATION_DEADLINE
for j in $(kubectl get jobs --all-namespaces -o json | jq -r ".items[].metadata | select(has(\"ownerReferences\") | not) | select(.creationTimestamp < \"$EXPIRATION_DEADLINE\") | [.name,.namespace] | @csv" | sed 's/"//g'); do
  job=$(echo $j | cut -d ',' -f 1)
  ns=$(echo $j | cut -d ',' -f 2)
  blacklisted=0
  for n in "${NS_BLACKLIST[@]}"; do  # check if in a blacklisted namespace
    [ "$n" == "$ns" ] && blacklisted=1
  done
  [ $blacklisted -eq 0 ] && kubectl delete job -n $ns $job
done

echo "reaper finished"
