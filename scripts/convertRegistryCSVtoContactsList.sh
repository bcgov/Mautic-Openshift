# !/bin/bash

# requires:
# jq
# python
# base64
# curl

# VARS
# $1 path_to_csv_file
# $2 mautic url
# $3 mautic username
# $4 mautic pasword

# ASSUMPTIONS
# CSV has fields
# - POEmail, TCEmail

CSV_FILE=$1
MAUTIC_URL=$2
USERNAME=$3
PASSWORD=$4


if [ -z "$CSV_FILE" ]; then
  echo "CSV_FILE not set! run ./convertRegistryCSVtoContactsList <path_to_csv_file>"
  exit 1
fi

if [ -z "$MAUTIC_URL" ]; then
  echo "MAUTIC_URL: not set! run ./convertRegistryCSVtoContactsList <path_to_csv_file> <mautic_url>"
  exit 1
fi

if [ -z "$USERNAME" ]; then
  echo "USERNAME: not set! run ./convertRegistryCSVtoContactsList <path_to_csv_file> <mautic_url> <username>"
  exit 1
fi

if [ -z "$PASSWORD" ]; then
  echo "PASSWORD: not set! run ./convertRegistryCSVtoContactsList <path_to_csv_file> <mautic_url> <username> <password>"
  exit 1
fi

CSV_JSON=$(cat $CSV_FILE | python -c 'import csv, json, sys; print(json.dumps([dict(r) for r in csv.DictReader(sys.stdin)]))')

POS=$(echo $CSV_JSON | jq '.[].POEmail | {email: .}' -r)
TCS=$(echo $CSV_JSON | jq '.[].TCEmail | {email: .}' -r)
LIST="$POS$TCS"

FINAL_LIST=$(echo $LIST | jq -s '.' -r)

BASIC_AUTH=$(echo $USERNAME:$PASSWORD | base64)
# COLORS
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m'

echo "${WHITE}Beginning batch add of contacts$NC"

echo "${NC}Attempting with username: $CYAN$USERNAME$NC using$WHITE Basic Auth.$NC \nIf this does not work it means either the credentials\nare incorrect or mautic has incorrectly cached state"
echo "${CYAN}More info:$NC https://forum.mautic.org/t/need-help-with-mautic-api-and-basicauth/16129/2"
ENDPOINT="$MAUTIC_URL/api/contacts/batch/new"

curl -X POST $ENDPOINT -H "Authorization: Basic $BASIC_AUTH" -H 'Accept: application/json' -d "$FINAL_LIST"
