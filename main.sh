#!/bin/bash

set -xe

JENKINS_URL="${INPUT_JENKINS_URL}"
JENKINS_USER="${INPUT_JENKINS_USER}"
JENKINS_USER_PASS="${INPUT_JENKINS_USER_PASS}"
JENKINS_JOB_DIRECTORY_PATH="${INPUT_JENKINS_JOB_DIRECTORY_PATH:-'/job/'}"
JOB_NAME="${INPUT_JOB_NAME}"
PARAMETERS="${INPUT_PARAMETERS}"

USER_NAME_PASSWORD="${JENKINS_USER}":"${JENKINS_USER_PASS}"

JENKINS_CRUMB=$(curl -u "${USER_NAME_PASSWORD}" -s --cookie-jar /tmp/cookies "${JENKINS_URL}"'/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,":",//crumb)')
echo "Fetched jenkins crumb"

TOKEN_NAME="GlobalToken"
TOKEN_API_RESPONSE=$(curl -u "${USER_NAME_PASSWORD}" -H "${JENKINS_CRUMB}" -s \
                    --cookie /tmp/cookies "${JENKINS_URL}/me/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken" \
                    --data "newTokenName=${TOKEN_NAME}")
ACCESS_TOKEN=$(echo "${TOKEN_API_RESPONSE}" | jq -r '.data.tokenValue')
TOKEN_UUID=$(echo "${TOKEN_API_RESPONSE}" | jq -r '.data.tokenUuid')
USER_NAME_TOKEN="${JENKINS_USER}":"${ACCESS_TOKEN}"
echo "Generated jenkins token with uuid=${TOKEN_UUID}"

function getJobState(){
  jobUrl=$1
  curl -s -u "${USER_NAME_TOKEN}" -H "${JENKINS_CRUMB}" "${jobUrl}api/json?pretty=true" | jq --raw-output '.result // empty'
}

function waitForJob() {
  jobUrl=$1
  state=""

  while [ "${state}" == "" ]
  do
     sleep 1
     state=$(getJobState "${jobUrl}")
  done
  echo "${state}"
}

function getJobUrl() {
	curl -s -u "${USER_NAME_TOKEN}" -H "${JENKINS_CRUMB}" "${QUEUE_URL}api/json?pretty=true" | jq --raw-output '.executable.url // empty'
}

function getJobUrlWithLoop() {
	curl_parameters=$(echo "${PARAMETERS}" | jq -r '. | to_entries | map("--data "+.key+"="+.value) | join(" ")')
	QUEUE_URL=$(curl -s -D - o /dev/null -u "${USER_NAME_TOKEN}" -H "${JENKINS_CRUMB}" "${JENKINS_URL}${JENKINS_JOB_DIRECTORY_PATH}${JOB_NAME}/buildWithParameters" ${curl_parameters} --data verbosity=high | awk '/^Location: / {print $2}' | tr -d '\r')

	if [[ "${QUEUE_URL}" == '' ]]; then
		echo "No jenkins queue url found. Existing with status 1" >&2
		exit 1
	fi

	JOB_URL=$(getJobUrl)

	while [ "${JOB_URL}" == "" ]; do
    	sleep 1
    	JOB_URL=$(getJobUrl)
	done
	echo "${JOB_URL}"
}

function revokeToken() {
	curl -u "${USER_NAME_PASSWORD}" -H "${JENKINS_CRUMB}" -s \
                    --cookie /tmp/cookies "${JENKINS_URL}/me/descriptorByName/jenkins.security.ApiTokenProperty/revoke" \
                    --data "tokenUuid=${TOKEN_UUID}"

}

echo "Triggering jenkins job for parameters=${PARAMETERS} ..."
JOB_URL=$( getJobUrlWithLoop )
echo "Triggered jenkins job ${JOB_URL}"

if [[ -n "$JOB_URL" ]]; then
	echo "Waiting for job status..."
	JOB_STATUS=$(waitForJob "${JOB_URL}")
	echo "Fetched jenkins job status ${JOB_STATUS}"
	revokeToken
	echo "Revoked jenkins token with uuid ${TOKEN_UUID}"
	if [[ "$JOB_STATUS" == "SUCCESS" ]]; then
		exit 0
	else
		exit 1
	fi
fi
