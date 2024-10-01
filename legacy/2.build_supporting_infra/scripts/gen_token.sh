#!/usr/bin/env bash

echo "Deprecated"
exit 1

# JENKINS_IP=$(grep "^URL:" ./appinfo/jenkins.txt | cut -d: -f3 | tr -d [:space:] | tr -d "/") 
# JENKINS_LOGIN=$(grep "^Builder login details:" ./appinfo/jenkins.txt | cut -d: -f2 | tr -d [:space:] | tr "/" ":")

# JENKINS_IP=10.20.20.40

# echo "Get crumb from  http://$JENKINS_IP:8080/crumbIssuer/api/json with $JENKINS_LOGIN"
# crumb=$(curl -c cookies.txt -s http://$JENKINS_IP:8080/crumbIssuer/api/json --user $JENKINS_LOGIN | jq -r .crumb)
# echo $crumb

# echo "Now get Token"
# curl -b cookies.txt -s "http://$JENKINS_IP:8080/me/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken" --data "newTokenName=my-second-token" --user $JENKINS_LOGIN  -H "Jenkins-Crumb: $crumb" | jq -r .data.tokenValue