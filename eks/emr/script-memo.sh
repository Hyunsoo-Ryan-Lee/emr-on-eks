
# 0. 참고 사이트
https://archive.eksworkshop.com/advanced/430_emr_on_eks/prereqs/#create-iam-role-for-job-execution
https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/setting-up-cli.html
https://dev.classmethod.jp/articles/lim-awscli-version-up/


# 1. eksctl, kubectl, aws cli2 설치
    1) eksctl (https://eksctl.io/introduction/?h=installa#installation)
        ARCH=amd64
        PLATFORM=$(uname -s)_$ARCH
        curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
        curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_checksums.txt" | grep $PLATFORM | sha256sum --check
        tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz
        sudo mv /tmp/eksctl /usr/local/bin

    2) kubectl
        curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.23.17/2023-08-16/bin/linux/amd64/kubectl
        curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.23.17/2023-08-16/bin/linux/amd64/kubectl.sha256
        chmod +x ./kubectl
        mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$HOME/bin:$PATH
        echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc

    3) aws cli2 (https://docs.aws.amazon.com/ko_kr/cli/latest/userguide/getting-started-install.html)
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip awscliv2.zip
        sudo ./aws/install

# 2. eksctl 이용하여 EKS Cluster 설치
    0) (optional) EC2 keypair 없는 경우
        aws ec2 create-key-pair --region ap-northeast-2 --key-name eksKey
    
    1) cluster 생성
eksctl create cluster \
    --name emr-eks \
    --region ap-northeast-2 \
    --with-oidc \
    --ssh-access \
    --ssh-public-key 447600660135-hyunsoo \
    --instance-types=m5.xlarge \
    --managed \


kc create ns emr

eksctl create iamidentitymapping \
    --cluster eks-spark-temp \
    --namespace emr \
    --service-name "emr-containers"



eksctl create iamidentitymapping \
    --cluster eks-spark-temp \
    --arn "arn:aws:iam::447600660135:role/AWSServiceRoleForAmazonEMRContainers" \
    --username emr-containers


aws eks describe-cluster \
    --name eks-spark-temp \
    --query "cluster.identity.oidc.issuer" \
    --output text


# Enabling IAM roles for service accounts on your cluster
eksctl utils associate-iam-oidc-provider \
    --cluster eks-spark-temp \
    --approve


cat <<EoF > ~/AWS-Training/EKS/policy/emr-trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "elasticmapreduce.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EoF

aws iam create-role \
    --role-name EMRContainers-JobExecutionRole \
    --assume-role-policy-document file://~/workspace/emr-on-eks/eks/policy/emr-trust-policy.json



cat <<EoF > ~/AWS-Training/EKS/policy/EMRContainers-JobExecutionRole.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:ListBucket"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:PutLogEvents",
                "logs:CreateLogStream",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams"
            ],
            "Resource": [
                "arn:aws:logs:*:*:*"
            ]
        }
    ]
}  
EoF


aws iam put-role-policy \
    --role-name EMRContainers-JobExecutionRole \
    --policy-name EMR-Containers-Job-Execution \
    --policy-document file://~/workspace/emr-on-eks/eks/policy/EMRContainers-JobExecutionRole.json


aws emr-containers update-role-trust-policy \
    --cluster-name eks-spark-temp \
    --namespace emr \
    --role-name EMRContainers-JobExecutionRole


aws emr-containers create-virtual-cluster \
--name emr-cluster \
--container-provider '{
    "id": "eks-spark-temp",
    "type": "EKS",
    "info": {
        "eksInfo": {
            "namespace": "emr"
        }
    }
}'


aws eks \
    --region ap-northeast-2 update-kubeconfig \
    --name eks-spark-temp \


eksctl create nodegroup \
    --config-file=./nodegroup/addnodegroup-spot.yaml \


aws emr-containers describe-virtual-cluster \
    --id $VIRTUAL_CLUSTER_ID \



# Sample Spark Job 실행
aws emr-containers start-job-run \
  --virtual-cluster-id=$VIRTUAL_CLUSTER_ID \
  --name=sample \
  --execution-role-arn=$EMR_ROLE_ARN \
  --release-label=emr-6.2.0-latest \
  --job-driver='{
    "sparkSubmitJobDriver": {
      "entryPoint": "s3://developer-personal-storage/hyunsoo/emr_on_eks/sample.py",
      "sparkSubmitParameters": "--conf spark.executor.instances=1 --conf spark.executor.memory=2G --conf spark.executor.cores=1 --conf spark.driver.cores=1"
    }
  }' \




----------------------
Create Log Group
# cloudwatch log group 생성
aws logs create-log-group \
    --log-group-name=/emr-on-eks/eksworkshop-eksctl \


export s3DemoBucket=s3://hyunsoo-emr-to-eks
export KUBECTL_VERSION=$(kubectl version --short | grep 'Server Version:' | sed 's/[^0-9.]*\([0-9.]*\).*/\1/' | cut -d. -f1,2)
export ACCOUNT_ID=646664498184
export VIRTUAL_CLUSTER_ID=$(aws emr-containers list-virtual-clusters --query "virtualClusters[?state=='RUNNING'].id" --output text)
export EMR_ROLE_ARN=$(aws iam get-role --role-name EMRContainers-JobExecutionRole --query Role.Arn --output text)


aws emr-containers start-job-run \
    --cli-input-json file://jobs/sample_job.json \


aws eks describe-nodegroup \
    --cluster-name eks-spark-temp \
    --nodegroup-name spot-ng \
    --query "nodegroup.resources.autoScalingGroups" \
    --output text \


aws autoscaling \
    update-auto-scaling-group \
    --auto-scaling-group-name eks-spot-ng-30c5e20f-2e2e-289f-0911-96f59e65c6fb \
    --min-size 1 \
    --desired-capacity 2 \
    --max-size 6


aws autoscaling \
    describe-auto-scaling-groups \
    --auto-scaling-group-names eks-spot-ng-30c5e20f-2e2e-289f-0911-96f59e65c6fb \
    --query "AutoScalingGroups[? Tags[? (Key=='eks:cluster-name') && Value=='eks-spark-temp']].[AutoScalingGroupName, MinSize, MaxSize,DesiredCapacity]" \
    --output table


# node auto scaling 관련 policy 생성
aws iam create-policy   \
    --policy-name k8s-asg-policy \
    --policy-document file://~/workspace/eks/policy/k8s-asg-policy.json \


eksctl create iamserviceaccount \
    --name cluster-autoscaler \
    --namespace kube-system \
    --cluster eks-spark-temp \
    --attach-policy-arn "arn:aws:iam::447600660135:policy/k8s-asg-policy" \
    --approve \
    --override-existing-serviceaccounts \


kubectl apply -f https://www.eksworkshop.com/beginner/080_scaling/deploy_ca.files/cluster-autoscaler-autodiscover.yaml

kubectl -n kube-system \
    annotate deployment.apps/cluster-autoscaler \
    cluster-autoscaler.kubernetes.io/safe-to-evict="false"

# we need to retrieve the latest docker image available for our EKS version
export K8S_VERSION=$(kubectl version --short | grep 'Server Version:' | sed 's/[^0-9.]*\([0-9.]*\).*/\1/' | cut -d. -f1,2)
export AUTOSCALER_VERSION="1.21.2"

kubectl -n kube-system \
    set image deployment.apps/cluster-autoscaler \
    cluster-autoscaler=us.gcr.io/k8s-artifacts-prod/autoscaling/cluster-autoscaler:v${AUTOSCALER_VERSION}

kubectl get deployment cluster-autoscaler -n kube-system

aws s3 cp threadsleep.py ${s3DemoBucket}/codes/

export VIRTUAL_CLUSTER_ID=$(aws emr-containers list-virtual-clusters \
                            --query "virtualClusters[?state=='RUNNING'].id" \
                            --output text \
                        )

export EMR_ROLE_ARN=$(aws iam get-role \
                            --role-name EMRContainers-JobExecutionRole \
                            --query Role.Arn \
                            --output text \
                        )

aws emr-containers start-job-run \
    --virtual-cluster-id=$VIRTUAL_CLUSTER_ID \
    --name=threadsleep-clusterautoscaler \
    --execution-role-arn=$EMR_ROLE_ARN \
    --release-label=emr-6.2.0-latest \
 \
    --job-driver='{
    "sparkSubmitJobDriver": {
        "entryPoint": "'${s3DemoBucket}'/codes/threadsleep.py",
        "sparkSubmitParameters": "--conf spark.executor.instances=15 --conf spark.executor.memory=1G --conf spark.executor.cores=1 --conf spark.driver.cores=1"
    }
    }'
    --configuration-overrides='{
    "applicationConfiguration": [
        {
        "classification": "spark-defaults", 
        "properties": {
            "spark.dynamicAllocation.enabled":"false",
            "spark.kubernetes.executor.deleteOnTermination": "true"
            }
        }
    ]
    }'

#start spark job with start-job-run
aws emr-containers start-job-run \
    --virtual-cluster-id=$VIRTUAL_CLUSTER_ID \
    --name=threadsleep-dra \
    --execution-role-arn=$EMR_ROLE_ARN \
    --release-label=emr-6.2.0-latest \
    --job-driver='{
    "sparkSubmitJobDriver": {
        "entryPoint": "'${s3DemoBucket}'/codes/threadsleep.py",
        "sparkSubmitParameters": "--conf spark.executor.instances=1 --conf spark.executor.memory=1G --conf spark.executor.cores=1 --conf spark.driver.cores=1"
    }
    }' \
    --configuration-overrides='{
    "applicationConfiguration": [
        {
        "classification": "spark-defaults", 
        "properties": {
            "spark.dynamicAllocation.enabled":"true",
            "spark.dynamicAllocation.shuffleTracking.enabled":"true",
            "spark.dynamicAllocation.minExecutors":"1",
            "spark.dynamicAllocation.maxExecutors":"10",
            "spark.dynamicAllocation.initialExecutors":"1",
            "spark.dynamicAllocation.schedulerBacklogTimeout": "1s",
            "spark.dynamicAllocation.executorIdleTimeout": "5s"
            }
        }
    ]
    }' \



>>To reduce costs, you can schedule Spark driver tasks to run on On-Demand instances while scheduling Spark executor tasks to run on Spot instances.<<


eksctl create nodegroup \
    --config-file=./node-group/addnodegroup-spot.yaml \



aws emr-containers start-job-run \
    --virtual-cluster-id $VIRTUAL_CLUSTER_ID \
    --name pi-spot \
    --execution-role-arn $EMR_ROLE_ARN \
    --release-label emr-5.33.0-latest \
 \
    --job-driver '{
    "sparkSubmitJobDriver": {
        "entryPoint": "'${s3DemoBucket}'/codes/threadsleep.py",
        "sparkSubmitParameters": "--conf spark.kubernetes.driver.podTemplateFile=\"'${s3DemoBucket}'/pod_templates/spark_driver_pod_template.yml\" --conf spark.kubernetes.executor.podTemplateFile=\"'${s3DemoBucket}'/pod_templates/spark_executor_pod_template.yml\" --conf spark.executor.instances=15 --conf spark.executor.memory=2G --conf spark.executor.cores=2 --conf spark.driver.cores=1"}}' \
    --configuration-overrides '{
        "applicationConfiguration": [
            {
                "classification": "spark-defaults",
                "properties": {
                    "spark.dynamicAllocation.enabled": "false",
                    "spark.kubernetes.executor.deleteOnTermination": "true"
                }
            }
        ],
        "monitoringConfiguration": {
            "cloudWatchMonitoringConfiguration": {
                "logGroupName": "/emr-on-eks/eksworkshop-eksctl",
                "logStreamNamePrefix": "pi"
            },
            "s3MonitoringConfiguration": {
                "logUri": "'${s3DemoBucket}'/logs"
            }
        }
    }'




==
eksctl create nodegroup \
  --cluster eks-spark-temp \
  --name al-nodes \
  --node-type m5.xlarge \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 3 \
  --ssh-access \
  --ssh-public-key chunjae-dl-keyfair \
  --subnet-ids strings [subnet-05b89fde393057ce3, subnet-050e5d124c1f2e93d] \


eksctl create nodegroup \
--cluster=eks-spark-temp \
--region=ap-northeast-2 \
--name=eks-worker \
--node-type=t3.medium \
--nodes-min=2 \
--nodes-max=4 \
--node-volume-size=20 \
--ssh-access \
--ssh-public-key=chunjae-dl-keyfair \
--managed \
--asg-access \
--external-dns-access \
--full-ecr-access \
--appmesh-access \
--alb-ingress-access \
--node-private-networking \                   


# nodegroup delete
eksctl delete nodegroup \
    --cluster eks-spark-temp \
    --name spot-ng \
    --region ap-northeast-2
    
aws emr-containers delete-virtual-cluster --id bmodad78h40r1y286cia7uu7t

eksctl delete cluster eks-spark-temp