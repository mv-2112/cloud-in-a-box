#!/bin/bash
# Based on http://unix.stackexchange.com/questions/175071/how-to-decrypt-hostnames-of-a-crypted-ssh-known-hosts-with-a-list-of-the-hostna/175199#175199
# Based on https://gist.github.com/xxorax/e46341cf57fad0bdd80a
# Adapted to specific needs for Sunbeam SSH clearup.

TEMP_FILE=$(mktemp)
cp ~/.ssh/known_hosts ~/.ssh/known_hosts.orig
cp ~/.ssh/known_hosts $TEMP_FILE

function replace {
  host="$1"
  found=$(ssh-keygen -F "$host" 2>/dev/null | grep -v '^#' | sed "s/^[^ ]*/$host/")
  if [ -n "$found" ]; then
    ssh-keygen -R "$host" -f $TEMP_FILE &>/dev/null
    echo "$found" >> $TEMP_FILE
    echo "Found and replaced: $host"
  else
    echo "Not found: $host"
  fi
}


for each in $(hostname -I)
do
  replace $each
done

# echo "Show temp file before changing..."
# cat $TEMP_FILE

echo
for each in $(hostname -I)
do
  for each_key in $(grep "$each" $TEMP_FILE | awk '{ print $3 }')
  do
    echo "KEY: $each_key"
    sed -i "/^|/d" $TEMP_FILE
  done
done
echo

# echo "Show temp file after changing..."
# cat $TEMP_FILE

cp $TEMP_FILE ~/.ssh/known_hosts
