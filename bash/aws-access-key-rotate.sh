#!/bin/bash
echo "     _______ _____  _____       __          _______   ";
echo "    |__   __|_   _|/ ____|     /\ \        / / ____|  ";
echo "       | |    | | | (___      /  \ \  /\  / / (___    ";
echo "       | |    | |  \___ \    / /\ \ \/  \/ / \___ \   ";
echo "       | |   _| |_ ____) |  / ____ \  /\  /  ____) |  ";
echo "  _  __|_|  |_____|_____/  /_/ _  \_\/  \/  |_____/   ";
echo " | |/ /           |  __ \     | |      | |            ";
echo " | ' / ___ _   _  | |__) |___ | |_ __ _| |_ ___  _ __ ";
echo " |  < / _ \ | | | |  _  // _ \| __/ _\` | __/ _ \| '__|";
echo " | . \  __/ |_| | | | \ \ (_) | || (_| | || (_) | |   ";
echo " |_|\_\___|\__, | |_|  \_\___/ \__\__,_|\__\___/|_|   ";
echo "            __/ |                                     ";
echo "           |___/                                      ";
echo " "
echo "[+] Comparing AWS held keys with local settings ..."
currentawskey1=$(aws iam list-access-keys | jq '.AccessKeyMetadata[0]' | grep AccessKeyId | cut -d '"' -f 4 | tr -d '\042\054\040')
currentawskey2=$(aws iam list-access-keys | jq '.AccessKeyMetadata[1]' | grep AccessKeyId | cut -d '"' -f 4 | tr -d '\042\054\040')
currentlocalawskey=$(aws configure get aws_access_key_id)

echo "[+] doing logic things ... :/"
if [ -n "$currentawskey2" ]
  then
    echo "[+] Found secondory key in AWS, deleteing..."
    if [ $currentawskey2 != $currentlocalawskey ]; then
      keytodelete=$(echo "$currentawskey2")
    else
      keytodelete=$(echo "$currentawskey1")
    fi
fi

if [ -n "$keytodelete" ]
  then
    echo "[+] Removing non current secondary aws key"
    aws iam delete-access-key --access-key-id $keytodelete
fi
echo "[+] Rotating AWS keys, Please wait ...."
OLD_KEY=$(aws iam list-access-keys | grep "AccessKeyId" | head -1 | cut -d ':' -f 2 | tr -d ' \t\n\r [="=] [=,=]')
echo "[+] Current Access Key: $OLD_KEY"
echo "[+] Creating New Access key"
CREATE_NEW_ACCESS_KEY=$(aws iam create-access-key)
NEW_KEY_ID=$(echo $CREATE_NEW_ACCESS_KEY | grep AccessKeyId | cut -d '"' -f 10 | tr -d '\042\054\040')
NEW_SECRET_ID=$(echo $CREATE_NEW_ACCESS_KEY | grep SecretAccessKey | cut -d '"' -f 18 | tr -d '\042\054\040')
echo "[+] Asserting if new Key has been recieved"
if [ -z "$NEW_KEY_ID" ]
then
  echo "[!] ERROR: NEW_KEY_ID not found, Exiting."
  break
else
  echo "[+] Setting new Access Key and Secret into AWS CLI"
  aws configure set aws_access_key_id $NEW_KEY_ID
  aws configure set aws_secret_access_key $NEW_SECRET_ID
  aws configure set default.region eu-west-2
  echo "[+] Waiting for new configuration to be applied"
  sleep 10
echo "[+] Checking new credentials work as expected"
test=$(aws sts get-caller-identity)
resultcode=$(echo $?)
echo "[+] Returned Test from AWS: $test"
echo "[+] HTTP code: $resultcode"
if [ $resultcode = 0 ]
  then
    echo "[+] Test successful"
  else
    echo "[!] Test failed"
    echo "[!] Unable to get response from AWS CLI. Shutting down program before deleting working credentials"
    break
fi
  echo "[+] Deleting old Access key from IAM"
  aws iam delete-access-key --access-key-id $OLD_KEY
  echo "[+] Key rotation complete"
fi
