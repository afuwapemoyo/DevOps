#! /usr/bin/env bash


arg0=$(basename "$0" .sh)
blnk=$(echo "$arg0" | sed 's/./ /g')

#set dry_run to true then artifacts only be listed and set false then artifacts will really deleted
dry_run=true

#====================

#to catch error
usage() {
    exec 1>2 usage_info exit 1
}

error()
{
    echo "$arg0: $*" >&2 exit 1
}

#catch command flags value
flags()
{
  while test $# -gt 0
  do
    case "$1" in
    (-u|--username)
      shift
      [ $# = 0 ] && error "No source username specified"
      export USERNAME="$1"
      shift;;
    (-p|--password)
      shift
      [ $# = 0 ] && error "No password specified"
      export PASSWORD="$1"
      shift;;
    (-l|--url)
      shift
      [ $# = 0 ] && error "No url specified"
      export URL="$1"
      shift;;
    (-r|--repository)
      shift
      [ $# = 0 ] && error "No repo specified"
      export REPOSITORY="$1"
      shift;;
    (*) usage;;
    esac
  done
}
flags "$@"

#check connection to artifactory
echo "connecting to Artifactory ..."
status=$(curl --connect-timeout 10 -s "$URL/api/system/ping" )
if [ "$status" = "OK" ]; then
  echo "Connected to Artifactory!"
else
  echo "can't connect to artifactory"
  exit -1
fi
echo ""
echo "checking $REPOSITORY" ...

#get list of artifacts and path with criteria using AQL
echo "Getting artifacts : not downloaded since 60 days ..."
echo ""
#set AQL query, in this case we want to retrieve artifact on some repo that its not has been downloaded since 60 days 
query='items.find({"stat.downloaded":{"$before":"60d"},"repo":{"$eq":"maven-repo"}}).include("stat.downloaded")'
#call query result using api
result=$(curl -X POST -u $USERNAME:$PASSWORD -H "content-type: text/plain" -d "$query" -s "$URL/api/search/aql" > result.json)
result=$(cat result.json)
total=$(echo "${result}" | jq -r '.range.total')

#retrieve and parse result
if [ $total -gt 0 ]
  then
    for row in $(echo "${result}" | jq -r '.results[] | @base64'); do
      _jq() {
        echo ${row} | base64 --decode | jq -r ${1}
      }
    done
  else
    echo "no artifact was found"
    rm result.json
    exit -1
fi

#delete artifact with match criteria
echo "deleting artifacts ..."
if [ $dry_run = true ]
  then
    echo "LAST_DOWNLOAD | ARTIFACT | URL" > artifact-list
    echo "Dry run mode, artifacts only be listed on this file instead deleted: artifact-list"
fi

for row in $(echo "${result}" | jq -r '.results[] | @base64'); do
  _jq() {
    echo ${row} | base64 --decode | jq -r ${1}
  }
  
  if [ $dry_run = true ]
    then
      echo "Adding : " $(_jq '.repo')"/"$(_jq '.path')"/"$(_jq '.name')
      echo "$(_jq '.stats[].downloaded') | $(_jq '.name') | $URL/"$(_jq '.repo')"/"$(_jq '.path')"/"$(_jq '.name') >> artifact-list
    else
      #real file deletion
      echo "Deleting : " $(_jq '.repo')"/"$(_jq '.path')"/"$(_jq '.name')
      result=$(curl -X DELETE -u $USERNAME:$PASSWORD -s "$URL/"$(_jq '.repo')"/"$(_jq '.path')"/"$(_jq '.name'))
  fi
done
rm result.json

echo ""
echo "ALL DONE.!"
