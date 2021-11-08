#!/bin/bash

######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################

function usage {
        echo ""
        echo "Usage: $0 [step]"
        echo "       Run batch pipeline to compile models and benchmark performance"
        echo "       step - pipeline step to execute, if no step specified entire pipeline is executed"
        echo ""
        echo "       steps: setup | submit | report | cleanup "
        echo ""
}

if [ "$1" == "--help" ]; then
        usage
        exit 0
fi

source ./fun.sh

function setup() {
        prepare_s3_bucket
        prepare_ecs_roles
        for index in ${!DOE_INSTANCE_TYPES[@]}; do
                INSTANCE_TYPE_NAME=$(echo ${DOE_INSTANCE_TYPES[$index]} | sed -e 's/\./-/g')
                BATCH_COMPUTE_ENVIRONMENT_NAME=${BATCH_NAME}-compute-${DOE_JOB_TYPES[$index]}-${INSTANCE_TYPE_NAME}
                EC2_SG_ID=$(security_group_id)
                EC2_SUBNET_ID=$(subnet)
                BATCH_COMPUTE_RESOURCES="type=EC2,minvCpus=0,maxvCpus=256,instanceTypes=${DOE_INSTANCE_TYPES[$index]},instanceRole=ecsInstanceRole,subnets=$EC2_SUBNET_ID,launchTemplate={launchTemplateName=${EC2_TEMPLATE_NAME}}"
                prepare_compute_environment
                BATCH_JOB_QUEUE_NAME=${BATCH_NAME}-queue-${DOE_JOB_TYPES[$index]}-${INSTANCE_TYPE_NAME}
                prepare_job_queue
                DOE_PROCESSOR_TYPE=${DOE_PROCESSOR_TYPES[$index]}
                DOE_PROCESSOR_COUNT=${DOE_PROCESSOR_COUNTS[$index]}
                for batch_index in ${!DOE_BATCH_SIZES[@]}; do
                        BATCH_JOB_DEFINITION_NAME=${BATCH_NAME}-job-definition-${DOE_JOB_TYPES[$index]}-${INSTANCE_TYPE_NAME}-batch-${DOE_BATCH_SIZES[$batch_index]}
                        BATCH_JOB_ENV_VARS="[{\"name\": \"BATCH_SIZE\", \"value\": \"${DOE_BATCH_SIZES[$batch_index]}\"}]"
			register_job_definition "[\"/bin/bash\", \"-c\", \"cd /job/${DOE_MODEL_FAMILY}; python3 compile_model-${DOE_PROCESSOR_TYPE}.py; ls -alh; python3 direct_benchmark-${DOE_PROCESSOR_TYPE}.py | tee \$(ls *.pt).log; python3 neuronperf_benchmark.py | tee \$(ls *.pt).json;  aws s3 sync --exclude \\\"*\\\" --include \\\"*.pt\\\" --include \\\"*.log\\\" --include \\\"*.json\\\" . s3://$S3_BUCKET_NAME\"]"
                done
        done
}

function submit() {
        for index in ${!DOE_INSTANCE_TYPES[@]}; do
                INSTANCE_TYPE_NAME=$(echo ${DOE_INSTANCE_TYPES[$index]} | sed -e 's/\./-/g')
                BATCH_JOB_QUEUE_NAME=${BATCH_NAME}-queue-${DOE_JOB_TYPES[$index]}-${INSTANCE_TYPE_NAME}
                for batch_index in ${!DOE_BATCH_SIZES[@]}; do
                        BATCH_JOB_DEFINITION_NAME=${BATCH_NAME}-job-definition-${DOE_JOB_TYPES[$index]}-${INSTANCE_TYPE_NAME}-batch-${DOE_BATCH_SIZES[$batch_index]}
                        BATCH_JOB_NAME=${BATCH_NAME}-job-${DOE_JOB_TYPES[$index]}-${INSTANCE_TYPE_NAME}-batch-${DOE_BATCH_SIZES[$batch_index]}
                        submit_job
                done
        done
}

function report() {
        echo ""
	echo "Generating report ..."
	CMD="aws s3 sync --exclude=\"*\" --include=\"*.log\" --include=\"*.json\" s3://$S3_BUCKET_NAME ."
	echo "$CMD"
	eval "$CMD"
	report_headers > $BATCH_REPORT_CSV
	for log in $(ls *.log); do
		report_line $log >> $BATCH_REPORT_CSV
	done 
	echo ""
	cat $BATCH_REPORT_CSV
	echo ""
	CMD="aws s3 cp $BATCH_REPORT_CSV s3://$S3_BUCKET_NAME"
	eval "$CMD"
}

function cleanup() {
        for index in ${!DOE_INSTANCE_TYPES[@]}; do
                INSTANCE_TYPE_NAME=$(echo ${DOE_INSTANCE_TYPES[$index]} | sed -e 's/\./-/g')
                for batch_index in ${!DOE_BATCH_SIZES[@]}; do
                        BATCH_JOB_DEFINITION_NAME=${BATCH_NAME}-job-definition-${DOE_JOB_TYPES[$index]}-${INSTANCE_TYPE_NAME}-batch-${DOE_BATCH_SIZES[$batch_index]}
                        deregister_job_definitions $BATCH_JOB_DEFINITION_NAME
                done
                BATCH_JOB_QUEUE_NAME=${BATCH_NAME}-queue-${DOE_JOB_TYPES[$index]}-${INSTANCE_TYPE_NAME}
                delete_job_queue
                BATCH_COMPUTE_ENVIRONMENT_NAME=${BATCH_NAME}-compute-${DOE_JOB_TYPES[$index]}-${INSTANCE_TYPE_NAME}
                delete_compute_environment
        done
}

case "$1" in
        "setup")
                setup
                ;;
        "submit")
                submit
                ;;
        "report")
                report
                ;;
        "cleanup")
                cleanup
                ;;
        *)
		echo "Step $1 not recognized"
		echo "Please specify a valid step as an argument"
		usage
                ;;
esac

