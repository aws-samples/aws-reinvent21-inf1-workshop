#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

pushd ../1-ec2-instance
source ./fun.sh
popd
source ./batch.conf

function prepare_s3_bucket() {
        echo ""
        echo "Preparing S3 bucket $S3_BUCKET_NAME ..."
        CMD="aws s3 mb s3://${S3_BUCKET_NAME}"
        #echo ""
        #echo "$CMD"
        eval "$CMD > /dev/null"
}

function delete_s3_bucket() {
        echo ""
        echo "Deleting S3 bucket $S3_BUCKET_NAME ..."
        CMD="aws s3 rb s3://${S3_BUCKET_NAME}"
        #echo ""
        #echo "$CMD"
        eval "$CMD"
}

function prepare_ecs_roles
{
        echo "Preparing ecsInstanceRole ..."
        role=$(aws iam list-roles --query 'Roles[?RoleName==`ecsInstanceRole`].RoleName' --output text)
        if [ "${role}" == "" ]; then
                RESULT=$(aws iam create-role --role-name ecsInstanceRole --assume-role-policy-document file://${ECS_TRUST_FILE})
                RESULT=$(aws iam attach-role-policy --role-name ecsInstanceRole --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role)
                RESULT=$(aws iam attach-role-policy --role-name ecsInstanceRole --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore)
        fi
        echo "Preparing instance profile ..."
        INSTANCE_ROLE_NAME=$(aws iam get-instance-profile --instance-profile-name ecsInstanceRole --query InstanceProfile.Roles[0].RoleName --output text 2>/dev/null)
        if [ "$?" == "0" ]; then
                echo "Instance profile ecsInstanceRole already exists."
        else
                echo "Creating instance profile ecsInstanceRole ..."
                aws iam create-instance-profile --instance-profile-name ecsInstanceRole > /dev/null
                aws iam add-role-to-instance-profile --instance-profile-name ecsInstanceRole --role-name ecsInstanceRole > /dev/null
        fi
        echo "Preparing ecsTaskRole  ..."
        role=$(aws iam list-roles --query 'Roles[?RoleName==`ecsTaskRole`].RoleName' --output text)
        if [ "${role}" == "" ]; then
                RESULT=$(aws iam create-role --role-name ecsTaskRole --assume-role-policy-document file://${ECS_TRUST_FILE})
                policy=$(aws iam list-attached-role-policies --role-name ecsTaskRole --query 'AttachedPolicies[?PolicyName==`AmazonS3FullAccess`].PolicyName' --output text)
                if [ "${policy}" == "" ]; then
                        RESULT=$(aws iam attach-role-policy --role-name ecsTaskRole --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess)
                fi
        fi
        role_arn=$(aws iam list-roles --query 'Roles[?RoleName==`ecsTaskRole`].Arn' --output text)
        export ECS_TASK_ROLE_ARN="${role_arn}"
        echo "Preparing ecsTaskExecutionRole  ..."
        role=$(aws iam list-roles --query 'Roles[?RoleName==`ecsTaskExecutionRole`].RoleName' --output text)
        if [ "${role}" == "" ]; then
                RESULT=$(aws iam create-role --role-name ecsTaskExecutionRole --assume-role-policy-document file://${ECS_TRUST_FILE})
        fi
        policy=$(aws iam list-attached-role-policies --role-name ecsTaskExecutionRole --query 'AttachedPolicies[?PolicyName==`AmazonECSTaskExecutionRolePolicy`].PolicyName' --output text)
        if [ "${policy}" == "" ]; then
                RESULT=$(aws iam attach-role-policy --role-name ecsTaskExecutionRole --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy)
        fi
        role_arn=$(aws iam list-roles --query 'Roles[?RoleName==`ecsTaskExecutionRole`].Arn' --output text)
        export ECS_EXEC_ROLE_ARN="${role_arn}"
}

function prepare_compute_environment
{
        echo "Preparing Batch compute environment ${BATCH_COMPUTE_ENVIRONMENT_NAME} ..."
        BATCH_COMPUTE_ENVIRONMENT_NAMES=$(aws batch describe-compute-environments --query 'computeEnvironments[*].computeEnvironmentName' --output text)
        echo ${BATCH_COMPUTE_ENVIRONMENT_NAMES} | grep -w -q ${BATCH_COMPUTE_ENVIRONMENT_NAME}
        if [ "$?" == "0" ]; then
                echo "Compute environment ${BATCH_COMPUTE_ENVIRONMENT_NAME} exists"
                STATE=$(aws batch describe-compute-environments --compute-environments ${BATCH_COMPUTE_ENVIRONMENT_NAME} --query 'computeEnvironments[*].state' --output text)
                if [ ! "${STATE}" == "ENABLED" ]; then
                        echo "Enabling compute environment ${BATCH_COMPUTE_ENVIRONMENT_NAME} ..."
                        CMD="aws batch update-compute-environment --compute-environment ${BATCH_COMPUTE_ENVIRONMENT_NAME} --state ENABLED"
                        RESULT=$(eval "${CMD}")
                fi
        else
                if [ "${BATCH_MANAGE_COMPUTE_ENVIRONMENT}" == "true" ]; then
                        echo "Creating compute environment ${BATCH_COMPUTE_ENVIRONMENT_NAME} ..."
                        CMD="aws batch create-compute-environment --compute-environment-name ${BATCH_COMPUTE_ENVIRONMENT_NAME} --type MANAGED --compute-resources ${BATCH_COMPUTE_RESOURCES}"
                        RESULT=$(eval "${CMD}")
                        # Wait for compute environment to get created
                        STATUS=$(aws batch describe-compute-environments --compute-environments ${BATCH_COMPUTE_ENVIRONMENT_NAME} --query 'computeEnvironments[*].status' --output text)
                        while [ ! "${STATUS}" == "VALID" ]; do
                                echo "Waiting for ${BATCH_COMPUTE_ENVIRONMENT_NAME} status to become VALID ..."
                                sleep 2
                                STATUS=$(aws batch describe-compute-environments --compute-environments ${BATCH_COMPUTE_ENVIRONMENT_NAME} --query 'computeEnvironments[*].status' --output text)
                        done
                else
                        echo "Compute environment ${BATCH_COMPUTE_ENVIRONMENT_NAME} not found!"
                        exit 1
                fi
        fi
}

function prepare_job_queue
{
        echo "Preparing job queue ${BATCH_JOB_QUEUE_NAME} ..."
        BATCH_JOB_QUEUE_NAMES=$(aws batch describe-job-queues --query 'jobQueues[*].jobQueueName' --output text)
        echo ${BATCH_JOB_QUEUE_NAMES} | grep -w -q ${BATCH_JOB_QUEUE_NAME}
        if [ "$?" == "0" ]; then
                echo "Job queue ${BATCH_JOB_QUEUE_NAME} exists"
        else
                if [ "${BATCH_MANAGE_COMPUTE_ENVIRONMENT}" == "true" ]; then
                        echo "Creating job queue ${BATCH_JOB_QUEUE_NAME} ..."
                        CMD="aws batch create-job-queue --job-queue-name ${BATCH_JOB_QUEUE_NAME} --priority 1 --compute-environment-order order=0,computeEnvironment=${BATCH_COMPUTE_ENVIRONMENT_NAME}"
                        RESULT=$(eval "${CMD}")
                        # Wait for job queue to become valid
                        STATUS=$(aws batch describe-job-queues --job-queues ${BATCH_JOB_QUEUE_NAME} --query 'jobQueues[*].status' --output text)
                        while [ ! "${STATUS}" == "VALID" ]; do
                                echo "Waiting for ${BATCH_JOB_QUEUE_NAME} status to become VALID ..."
                                sleep 2
                                STATUS=$(aws batch describe-job-queues --job-queues ${BATCH_JOB_QUEUE_NAME} --query 'jobQueues[*].status' --output text)
                        done
                else
                        echo "Job queue ${BATCH_JOB_QUEUE_NAME} not found!"
                        exit 1
                fi
        fi
}

function register_job_definition() {
        if [ "$1" == "" ]; then
                BATCH_JOB_COMMAND="${BATCH_COMMAND_DEFAULT}"
        else
                BATCH_JOB_COMMAND="$@"
        fi
        echo "Registering job definition ${BATCH_JOB_DEFINITION_NAME} ..."
        echo "BATCH_JOB_COMMAND=${BATCH_JOB_COMMAND}"
        if [ "${BATCH_COMPUTE_ENVIRONMENT_TYPE}" == "EC2" ]; then
                export BATCH_CONTAINER_PROPERTIES="{ \"image\": \"${REGISTRY}${IMAGE}${TAG}\", \"vcpus\": $BATCH_JOB_VCPUS, \"memory\": $BATCH_JOB_MEMORY, \"jobRoleArn\": \"${ECS_TASK_ROLE_ARN}\", \"executionRoleArn\": \"${ECS_EXEC_ROLE_ARN}\", \"environment\": ${BATCH_JOB_ENV_VARS}, \"command\": ${BATCH_JOB_COMMAND}"
                if [ "${DOE_PROCESSOR_TYPE}" == "inf" ]; then
                        export BATCH_CONTAINER_PROPERTIES="${BATCH_CONTAINER_PROPERTIES},\"linuxParameters\": {\"sharedMemorySize\": $BATCH_JOB_SHARED_MEMORY, \"devices\": ["
                        for ((i=0; i<${DOE_PROCESSOR_COUNT}; i++)); do
                                if [ "$i" -gt "0" ]; then
                                        export BATCH_CONTAINER_PROPERTIES="${BATCH_CONTAINER_PROPERTIES},"
                                fi
                                export BATCH_CONTAINER_PROPERTIES="${BATCH_CONTAINER_PROPERTIES}{\"containerPath\": \"/dev/neuron${i}\", \"hostPath\": \"/dev/neuron${i}\", \"permissions\": [\"read\",\"write\"]}"
                        done
                        export BATCH_CONTAINER_PROPERTIES="${BATCH_CONTAINER_PROPERTIES}]}"
                fi
                export BATCH_CONTAINER_PROPERTIES="' ${BATCH_CONTAINER_PROPERTIES} } '"
                #export BATCH_CONTAINER_PROPERTIES="'{ \"image\": \"${REGISTRY}${IMAGE}${TAG}\", \"vcpus\": $BATCH_JOB_VCPUS, \"memory\": $BATCH_JOB_MEMORY, \"jobRoleArn\": \"${ECS_TASK_ROLE_ARN}\", \"executionRoleArn\": \"${ECS_EXEC_ROLE_ARN}\", \"environment\": ${BATCH_JOB_ENV_VARS}, \"command\": ${BATCH_JOB_COMMAND}, \"linuxParameters\": {\"devices\": [{\"containerPath\": \"/dev/neuron0\", \"hostPath\": \"/dev/neuron0\", \"permissions\": [\"read\",\"write\"]}]} }'"
        else
                export BATCH_CONTAINER_PROPERTIES="image=${REGISTRY}${IMAGE}${TAG},resourceRequirements=\"[{type=VCPU,value=${BATCH_JOB_VCPUS}},{type=MEMORY,value=${BATCH_JOB_MEMORY}}]\",jobRoleArn=${ECS_TASK_ROLE_ARN},executionRoleArn=${ECS_EXEC_ROLE_ARN},environment=\"${BATCH_JOB_ENV_VARS}\",command=${BATCH_JOB_COMMAND}"
        fi
        CMD="aws batch register-job-definition --type container --job-definition-name ${BATCH_JOB_DEFINITION_NAME} --platform-capabilities ${BATCH_COMPUTE_ENVIRONMENT_TYPE} --container-properties ${BATCH_CONTAINER_PROPERTIES}"
        echo "${CMD}"
        RESULT=$(eval "${CMD}")
}

function submit_job() {
        CMD="aws batch submit-job --job-name ${BATCH_JOB_NAME} --job-queue ${BATCH_JOB_QUEUE_NAME} --job-definition ${BATCH_JOB_DEFINITION_NAME}"
        echo ""
        echo "$CMD"
        eval "$CMD"
}

function status() {
        if [ "$1" == "" ]; then
                echo ""
                echo "Status of jobs in queue $BATCH_JOB_QUEUE_NAME ..."
                STATUS_LIST=(SUBMITTED PENDING RUNNABLE STARTING RUNNING SUCCEEDED FAILED)
                for STATUS in ${STATUS_LIST[@]}; do
                        CMD="aws batch list-jobs --job-queue ${BATCH_JOB_QUEUE_NAME} --job-status ${STATUS} --query 'jobSummaryList[*].{createdAt:createdAt,jobId:jobId,jobName:jobName,status:status,statusReason:statusReason,exitCode:container.exitCode}' --output table"
                        echo ""
                        echo "${CMD}"
                        eval "${CMD}"
                done
        else
                echo ""
                echo "Status of job IDs $@ ..."
                CMD="aws batch describe-jobs --jobs $@ --query 'jobs[*].{createdAt:createdAt,jobId:jobId,jobName:jobName,status:status,statusReason:statusReason,exitCode:container.exitCode,platformCapabilities:platformCapabilities[0]}' --output table"
                echo ""
                echo "${CMD}"
                eval "${CMD}"
        fi
}

function logs() {
        echo ""
        if [ "$1" == "" ]; then
                JOB_IDS_RUNNING=$(aws batch list-jobs --job-queue ${BATCH_JOB_QUEUE_NAME} --job-status RUNNING --query 'jobSummaryList[*].jobId' --output text)
                JOB_IDS_SUCCEEDED=$(aws batch list-jobs --job-queue ${BATCH_JOB_QUEUE_NAME} --job-status SUCCEEDED --query 'jobSummaryList[*].jobId' --output text)
                JOB_IDS_FAILED=$(aws batch list-jobs --job-queue ${BATCH_JOB_QUEUE_NAME} --job-status FAILED --query 'jobSummaryLists[*].jobId' --output text)
                JOB_IDS="$JOB_IDS_RUNNING $JOB_IDS_SUCCEEDED $JOB_IDS_FAILED"
        else
                JOB_IDS="$@"
        fi
        for JOB_ID in ${JOB_IDS}; do
                if [ ! "$JOB_ID" == "None" ]; then
                        echo ""
                        echo "Getting log evewnts for job ${JOB_ID} ..."
                        LOG_STREAM=$(aws batch describe-jobs --jobs ${JOB_ID} --query 'jobs[*].container.logStreamName' --output text)
                        CMD="aws logs get-log-events --log-group-name /aws/batch/job --no-paginate --query 'events[*].{timestamp:timestamp,message:message}' --output text --log-stream-name ${LOG_STREAM}"
                        echo "${CMD}"
                        eval "${CMD}"
                fi
        done
}

function stop_job() {
        echo ""
        echo "Stopping jobs in queue ${BATCH_JOB_QUEUE_NAME} ..."
        # Cancel SUBMITTED, PENDING or RUNNABLE jobs
        for STATUS in "SUBMITTED" "PENDING" "RUNNABLE"; do
                JOB_IDS=$(aws batch list-jobs --job-queue ${BATCH_JOB_QUEUE_NAME} --job-status ${STATUS} --query 'jobSummaryList[*].jobId' --output text)
                if [ ! "${JOB_IDS}" == "" ]; then
                        for JOB_ID in ${JOB_IDS}; do
                                echo "Cancelling job ${JOB_ID} ..."
                                CMD="aws batch cancel-job --job-id ${JOB_ID} --reason 'Stopped by user'"
                                echo "${CMD}"
                                RESULT=$(eval "${CMD}")
                        done
                fi
        done

        # Terminate STARTING or RUNNING jobs
        for STATUS in "STARTING" "RUNNING"; do
                JOB_IDS=$(aws batch list-jobs --job-queue ${BATCH_JOB_QUEUE_NAME} --job-status ${STATUS} --query 'jobSummaryList[*].jobId' --output text)
                if [ ! "${JOB_IDS}" == "" ]; then
                        for JOB_ID in "${JOB_IDS}"; do
                                echo "Terminating job ${JOB_ID} ..."
                                CMD="aws batch terminate-job --job-id ${JOB_ID} --reason 'Stopped by user'"
                                echo "${CMD}"
                                RESULT=$(eval "${CMD}")
                        done
                fi
        done
}

function deregister_job_definitions() {
        # Deregister job definitions
        REVISIONS=$(aws batch describe-job-definitions --job-definition-name ${BATCH_JOB_DEFINITION_NAME} --query 'jobDefinitions[?status==`ACTIVE`].revision' --output text)
for REVISION in ${REVISIONS}; do
                echo "Deregistering job definition ${BATCH_JOB_DEFINITION_NAME}:${REVISION} ..."
                CMD="aws batch deregister-job-definition --job-definition ${BATCH_JOB_DEFINITION_NAME}:${REVISION}"
                echo "${CMD}"
                RESULT=$(eval "${CMD}")
        done
}

function delete_job_queue() {
        JOB_QUEUE=$(aws batch describe-job-queues --job-queues ${BATCH_JOB_QUEUE_NAME} --query 'jobQueues[*].jobQueueName' --output text)
        if [ "${JOB_QUEUE}" == "${BATCH_JOB_QUEUE_NAME}" ]; then
                echo "Deleting job queue ${BATCH_JOB_QUEUE_NAME} ..."
                CMD="aws batch update-job-queue --job-queue ${BATCH_JOB_QUEUE_NAME}  --state DISABLED"
                echo "${CMD}"
                RESULT=$(eval "${CMD}")
                sleep 2
                STATE=$(aws batch describe-job-queues --job-queues ${BATCH_JOB_QUEUE_NAME} --query 'jobQueues[*].state' --output text)
                while [ ! "${STATE}" == "DISABLED" ]; do
                        echo "Waiting for ${BATCH_JOB_QUEUE_NAME} state to change to DISABLED ..."
                        sleep 2
                        STATE=$(aws batch describe-job-queues --job-queues ${BATCH_JOB_QUEUE_NAME} --query 'jobQueues[*].state' --output text)
                done
                CMD="aws batch delete-job-queue --job-queue ${BATCH_JOB_QUEUE_NAME}"
                echo "${CMD}"
                RESULT=$(eval "${CMD}")
                # Wait for job queue to be deleted
                JOB_QUEUE=$(aws batch describe-job-queues --job-queues ${BATCH_JOB_QUEUE_NAME} --query 'jobQueues[*].jobQueueName' --output text)
                while [ ! "${JOB_QUEUE}" == "" ]; do
                        echo "Waiting for job queue ${JOB_QUEUE} to be deleted ..."
                        sleep 2
                        JOB_QUEUE=$(aws batch describe-job-queues --job-queues ${BATCH_JOB_QUEUE_NAME} --query 'jobQueues[*].jobQueueName' --output text)
                done
        fi
}

function delete_compute_environment() {
        COMPUTE_ENVIRONMENT=$(aws batch describe-compute-environments --compute-environments ${BATCH_COMPUTE_ENVIRONMENT_NAME} --query 'computeEnvironments[*].computeEnvironmentName' --output text)
        if [ "${COMPUTE_ENVIRONMENT}" == "${BATCH_COMPUTE_ENVIRONMENT_NAME}" ]; then
                echo "Deleting compute environment ${BATCH_COMPUTE_ENVIRONMENT_NAME} ..."
                CMD="aws batch update-compute-environment --compute-environment ${BATCH_COMPUTE_ENVIRONMENT_NAME} --state DISABLED"
                echo "${CMD}"
                RESULT=$(eval "${CMD}")
                sleep 2
                STATE=$(aws batch describe-compute-environments --compute-environments ${BATCH_COMPUTE_ENVIRONMENT_NAME} --query 'computeEnvironments[*].state' --output text)
                while [ ! "${STATE}" == "DISABLED" ]; do
                        echo "Waiting for ${BATCH_COMPUTE_ENVIRONMENT_NAME} state to change to DISABLED ..."
                        sleep 2
                        STATE=$(aws batch describe-compute-environments --compute-environments ${BATCH_COMPUTE_ENVIRONMENT_NAME} --query 'computeEnvironments[*].state' --output text)
                done
                STATUS=$(aws batch describe-compute-environments --compute-environments ${BATCH_COMPUTE_ENVIRONMENT_NAME} --query 'computeEnvironments[*].status' --output text)
                while [ ! "${STATUS}" == "VALID" ]; do
                        echo "Waiting for ${BATCH_COMPUTE_ENVIRONMENT_NAME} status to change to VALID ..."
                        sleep 2
                        STATUS=$(aws batch describe-compute-environments --compute-environments ${BATCH_COMPUTE_ENVIRONMENT_NAME} --query 'computeEnvironments[*].status' --output text)
                done
                CMD="aws batch delete-compute-environment --compute-environment ${BATCH_COMPUTE_ENVIRONMENT_NAME}"
                echo "$CMD"
                eval "$CMD"
        else
                echo "Compute environment $BATCH_COMPUTE_ENVIRONMENT_NAME not found"
        fi
}

function report_headers() {
        echo "model_name, processor, max_length, batch_size, samples, latency_p50, latency_p90, latency_p95, total_time, throughput"
}

function report_line() {
        if [ ! "$1" == "" ]; then
                if [ -f $1 ]; then
                        MODEL_NAME=$(echo $1 | cut -d '_' -f 1)
                        PROCESSOR=$(echo $1 | cut -d '_' -f 2)
                        MAX_LENGTH=$(echo $1 | cut -d '_' -f 3)
                        BATCH_SIZE=$(echo $1 | cut -d '_' -f 4 | cut -d '.' -f 1)
                        SAMPLES=$(cat $1 | grep samples | cut -d ' ' -f 2)
                        PERCENTILES="$(cat $1 | grep '\[' | cut -d '[' -f 2 | cut -d ']' -f 1)"
                        P=( $PERCENTILES )
                        LATENCY_P50=${P[0]}
                        LATENCY_P90=${P[1]}
                        LATENCY_P95=${P[2]}
                        TOTAL_TIME=$(cat $1 | grep "Total time" | cut -d ')' -f 2 | cut -d ' ' -f 3)
                        THROUGHPUT=$(cat $1 | grep Throughput | cut -d '=' -f 2 | cut -d ' ' -f 2)
                        echo "${MODEL_NAME}, ${PROCESSOR}, ${MAX_LENGTH}, ${BATCH_SIZE}, ${SAMPLES}, ${LATENCY_P50}, ${LATENCY_P90}, ${LATENCY_P95}, ${TOTAL_TIME}, ${THROUGHPUT}"
                else
                        echo ""
                fi
        else
                echo ""
        fi
}

