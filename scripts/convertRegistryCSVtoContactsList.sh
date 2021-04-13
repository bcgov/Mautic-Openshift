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
SEGMENT_ID=$5

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

if [ -z "$SEGMENT_ID" ]; then
  echo "SEGMENT: not set! run ./convertRegistryCSVtoContactsList <path_to_csv_file> <mautic_url> <username> <password> <segment-id>"
  exit 1
fi

# COLORS
RED=`tput setaf 1`
WHITE=`tput setaf 7`
CYAN=`tput setaf 6`
RESET=`tput sgr0`
BOLD=`tput bold`
AUTH=$(echo $USERNAME:$PASSWORD)

CSV_JSON=$(cat $CSV_FILE | python -c 'import csv, json, sys; print(json.dumps([dict(r) for r in csv.DictReader(sys.stdin)]))')

POV=$(echo $CSV_JSON | jq '.[].POEmail | {email: .}' -r)
TCS=$(echo $CSV_JSON | jq '.[].TCEmail | {email: .}' -r)
LIST="$POS$TCS"
FINAL_LIST=$(echo $LIST | jq -s '.' -r)

ZERO='"0"'

echo "${RESET}Attempting with username: ${CYAN}$USERNAME${RESET} using ${WHITE}Basic Auth.${RESET}"
echo "If this does not work it means either the credentials are incorrect or mautic has incorrectly cached state"
echo "${CYAN}More info:$NC https://forum.mautic.org/t/need-help-with-mautic-api-and-basicauth/16129/2${RESET}"

# Loop through every contact
echo $FINAL_LIST | jq -c '.[]' | while read object; do

    email=$(echo $object | jq '.email')
    # check contact in mautic
    echo "checking contact ${WHITE}$email${RESET}"
    response=$(curl -s -X GET $MAUTIC_URL/api/contacts?search=email:$email -u $AUTH)

    # Get contact count to see if email exists
    contact_count=$(echo $response | jq '.total')

    # add contact if it doesnt exist
    if [ "$contact_count" = "$ZERO" ]; then
      echo "creating contact ${WHITE}$email${RESET}"
      response=$(curl -s -X POST $MAUTIC_URL/api/contacts/new -H "Content-type: application/json" -d $object -u $AUTH)
      # Extract contacts payload
      contact_id=$(echo $response | jq '.contact.id')
      # add contact to segment
      echo "Adding contact $email with ${WHITE}id:${contact_id}${RESET} to ${WHITE}segment-id:${SEGMENT_ID}${RESET}"
      curl -s -X POST $MAUTIC_URL/api/segments/${SEGMENT_ID}/contact/${contact_id}/add -u $AUTH
      echo

    else
      echo "${WHITE}$email${RESET} exists in contact"
    fi

    echo "-----------------------------------------"

done
