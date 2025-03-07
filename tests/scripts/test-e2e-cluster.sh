#!/bin/bash
set -eou pipefail

# Input env variables:
# - [PROVIDERNAME]_PROVIDER_KEY_PATH - path to a file containing the credentials to be used with the llm provider
# - OLS_IMAGE - pullspec for the ols image to deploy on the cluster


# Script flow:
# 1) Install OLS into a namespace on the cluster with valid config/api tokens and exposed via a route
# 2) Setup a service account w/ permission to access OLS
# 3) Wait for the ols api server to be available
# 4) Invoke the test-e2e Makefile target

make install-deps && make install-deps-test

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "$DIR/utils.sh"

function finish() {
    if [ "${LOCAL_MODE:-0}" -eq 1 ]; then
      # When running locally, cleanup the tmp files
      rm -rf "$ARTIFACT_DIR"
    fi
}
trap finish EXIT

# ARTIFACT_DIR is defined when running in a prow job, content
# in this location is automatically collected at the end of the test job
# If ARTIFACT_DIR is not defined, we are running locally on a developer machine
if [ -z "${ARTIFACT_DIR:-}" ]; then
    # temp directory for generated resource yamls
    export ARTIFACT_DIR=$(mktemp -d)
    # Clean up the tmpdir on exit
    readonly LOCAL_MODE=1
fi


rc=0

set +e
# runsuite arguments:
# suiteid test_tags provider provider_keypath provider_url provider_project_id provider provider_deployment_name llm_model ols_image
run_suite "azure_openai" "not standalone" "azure_openai" "$AZUREOPENAI_PROVIDER_KEY_PATH" "https://ols-test.openai.azure.com/" "" "0301-dep" "gpt-3.5-turbo" "quay.io/openshift/lightspeed-service-api-rag:latest"
(( rc = rc || $? ))

run_suite "bam" "not standalone" "bam" "$BAM_PROVIDER_KEY_PATH" "" "" "" "ibm/granite-13b-chat-v2" "quay.io/openshift/lightspeed-service-api-rag:latest" 
(( rc = rc || $? ))

run_suite "openai" "not standalone" "openai" "$OPENAI_PROVIDER_KEY_PATH" "" "" "" "gpt-3.5-turbo" "quay.io/openshift/lightspeed-service-api-rag:latest" 
(( rc = rc || $? ))

run_suite "watsonx" "not standalone" "watsonx" "$WATSONX_PROVIDER_KEY_PATH" "" "ad629765-c373-4731-9d69-dc701724c081" "" "ibm/granite-13b-chat-v2" "quay.io/openshift/lightspeed-service-api-rag:latest" 
(( rc = rc || $? ))
set -e

exit $rc