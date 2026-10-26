
pipeline {
    agent any

    parameters {
        choice(
            name: 'ACTION',
            choices: ['CREATE', 'DESTROY'],
            description: 'Create or destroy Kafka infrastructure'
        )
    }

    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 60, unit: 'MINUTES')
    }

    environment {
        PATH = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin"
        AWS_DEFAULT_REGION = 'ap-south-1'
        AWS_PROFILE = 'default'
        ANSIBLE_CONFIG = "${WORKSPACE}/ansible.cfg"
        OBJC_DISABLE_INITIALIZE_FORK_SAFETY = 'YES'
    }

    stages {
        stage('Check Tools and AWS') {
            steps {
                sh '''
                    set -eu
                    git --version
                    terraform version
                    ansible --version
                    aws --version
                    aws sts get-caller-identity
                '''
            }
        }

        stage('Terraform Init and Validate') {
            steps {
                dir('terraform') {
                    sh '''
                        set -eu
                        terraform init -reconfigure
                        terraform validate
                    '''
                }
            }
        }

        stage('Plan CREATE') {
            when {
                expression { params.ACTION == 'CREATE' }
            }
            steps {
                dir('terraform') {
                    sh '''
                        set -eu
                        terraform plan -out=tfplan
                        terraform show -no-color tfplan
                    '''
                }
            }
        }

        stage('Approve CREATE') {
            when {
                expression { params.ACTION == 'CREATE' }
            }
            steps {
                input(
                    message: 'Review the Terraform plan and estimated AWS costs before creating resources.',
                    ok: 'Approve CREATE'
                )
            }
        }

        stage('Apply CREATE') {
            when {
                expression { params.ACTION == 'CREATE' }
            }
            steps {
                dir('terraform') {
                    sh 'terraform apply -auto-approve tfplan'
                }
            }
        }

        
                    set -eu
                    echo "Waiting for SSM: ${KAFKA_INSTANCE_ID}"

                        if [ "$STATUS" = "Online" ]; then
                            echo "Kafka EC2 is Online in SSM."
                            exit 0
                        fi

                        sleep 10
                    done

                    echo "ERROR: EC2 did not become SSM Online within 10 minutes."
                    exit 1
                '''
            }
        }

        stage('Configure Kafka with Ansible') {
            when {
                expression { params.ACTION == 'CREATE' }
            }
            steps {
                script {
                    env.KAFKA_INSTANCE_ID = sh(
                        script: 'terraform -chdir=terraform output -raw kafka_instance_id',
                        returnStdout: true
                    ).trim()

                    env.KAFKA_PRIVATE_IP = sh(
                        script: 'terraform -chdir=terraform output -raw kafka_private_ip',
                        returnStdout: true
                    ).trim()

                    env.SSM_BUCKET = sh(
                        script: 'terraform -chdir=terraform output -raw ssm_transfer_bucket',
                        returnStdout: true
                    ).trim()
                }

                sh '''
                    set -eu
                    ansible-galaxy collection install amazon.aws

                    cat > ansible/inventory.ini <<INVENTORY
[kafka]
${KAFKA_INSTANCE_ID}

[kafka:vars]
ansible_connection=amazon.aws.aws_ssm
ansible_aws_ssm_region=${AWS_DEFAULT_REGION}
ansible_aws_ssm_bucket_name=${SSM_BUCKET}
ansible_aws_ssm_bucket_sse_mode=AES256
ansible_user=ec2-user
INVENTORY

                    ansible-playbook \
                        -i ansible/inventory.ini \
                        ansible/site.yml \
                        -e "kafka_advertised_host=${KAFKA_PRIVATE_IP}"
                '''
            }
        }

        stage('Verify Kafka') {
            when {
                expression { params.ACTION == 'CREATE' }
            }
            steps {
                script {
                    env.KAFKA_INSTANCE_ID = sh(
                        script: 'terraform -chdir=terraform output -raw kafka_instance_id',
                        returnStdout: true
                    ).trim()
                }

                sh '''
                    set -eu

                    COMMAND_ID=$(aws ssm send-command \
                        --region "$AWS_DEFAULT_REGION" \
                        --instance-ids "$KAFKA_INSTANCE_ID" 
                        --output text)

                    
                            Failed|Cancelled|TimedOut)
                                echo "Kafka verification failed: $STATUS"
                                aws ssm get-command-invocation \
                                    --region "$AWS_DEFAULT_REGION" \
                                    --command-id "$COMMAND_ID" \
                                    --instance-id "$KAFKA_INSTANCE_ID" \
                                    --query '{Output:StandardOutputContent,Error:StandardErrorContent}' \
                                    --output json
                                exit 1
                                ;;
                        esac

                        sleep 5
                    done

                    echo "Kafka verification timed out."
                    exit 1
                '''
            }
        }

        stage('Verify ALB and Application ASG') {
            when {
                expression { params.ACTION == 'CREATE' }
            }
            steps {
                script {
                    env.APP_URL = sh(
                        script: 'terraform -chdir=terraform output -raw app_alb_url',
                        returnStdout: true
                    ).trim()
                }

                sh '''
                    set -eu

                    TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups \
                        --region "$AWS_DEFAULT_REGION" \
                        --names kafka-one-click-app-tg \
                        --query 'TargetGroups[0].TargetGroupArn' \
                        --output text)

                    echo "Application URL: ${APP_URL}"
                    echo "Target Group: ${TARGET_GROUP_ARN}"

                    if [ -z "$TARGET_GROUP_ARN" ] || [ "$TARGET_GROUP_ARN" = "None" ]; then
                        echo "ERROR: Application target group was not found."
                        exit 1
                    fi

                    HEALTHY=0

                    for i in $(seq 1 60); do
                        HEALTHY=$(aws elbv2 describe-target-health \
                            --region "$AWS_DEFAULT_REGION" \
                            --target-group-arn "$TARGET_GROUP_ARN" \
                            --query "length(TargetHealthDescriptions[?TargetHealth.State=='healthy'])" \
                            --output text)

                        echo "Healthy application targets: $HEALTHY (attempt $i/60)"

                        if [ "$HEALTHY" -ge 1 ]; then
                            break
                        fi

                        sleep 10
                    done

                    if [ "$HEALTHY" -lt 1 ]; then
                        echo "ERROR: No healthy ALB targets after waiting."
                        aws elbv2 describe-target-health \
                            --region "$AWS_DEFAULT_REGION" \
                            --target-group-arn "$TARGET_GROUP_ARN" \
                            --output table
                        exit 1
                    fi

                    echo "Checking application health endpoint..."

                    for i in $(seq 1 12); do
                        if curl --fail --silent --show-error --max-time 10 \
                            "${APP_URL}/health"; then
                            echo
                            echo "ALB and application health verification passed."
                            exit 0
                        fi

                        echo "Application endpoint not ready (attempt $i/12)"
                        sleep 10
                    done

                    echo "ERROR: Application health endpoint did not respond successfully."
                    exit 1
                '''
            }
        }

        stage('Plan DESTROY') {
            when {
                expression { params.ACTION == 'DESTROY' }
            }
            steps {
                dir('terraform') {
                    sh '''
                        set -eu
                        terraform plan -destroy -out=tfplan
                        terraform show -no-color tfplan
                    '''
                }
            }
        }

        stage('Approve DESTROY') {
            when {
                expression { params.ACTION == 'DESTROY' }
            }
            steps {
                input(
                    message: 'WARNING: Review the destroy plan. This removes Terraform-managed infrastructure. The separate Terraform state bucket is not part of this configuration.',
                    ok: 'Approve DESTROY'
                )
            }
        }

        stage('Prepare SSM Bucket for DESTROY') {
            when {
                expression { params.ACTION == 'DESTROY' }
            }
            steps {
                sh '''
                    set -eu

                    SSM_BUCKET="kafka-one-click-ssm-506192652789"

                    echo "Checking the dedicated SSM transfer bucket..."

                    if aws s3api head-bucket \
                        --bucket "$SSM_BUCKET" \
                        --region "$AWS_DEFAULT_REGION" 2>/dev/null; then

                        echo "Removing temporary SSM transfer objects from $SSM_BUCKET"
                        aws s3 rm "s3://${SSM_BUCKET}" \
                            --recursive \
                            --region "$AWS_DEFAULT_REGION"
                    else
                        echo "SSM transfer bucket does not exist; skipping cleanup."
                    fi

                    echo "Terraform state bucket will not be cleaned up."
                '''
            }
        }

        stage('Apply DESTROY') {
            when {
                expression { params.ACTION == 'DESTROY' }
            }
            steps {
                dir('terraform') {
                    sh 'terraform apply -auto-approve tfplan'
                }
            }
        }
    }

    post {
        always {
            sh 'rm -f terraform/tfplan'
            echo 'Pipeline finished. Check the stage results.'
        }
    }
}
