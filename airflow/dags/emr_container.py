from datetime import datetime
from airflow import DAG
from airflow.operators.dummy_operator import DummyOperator
from airflow.operators.python_operator import PythonOperator
from airflow.providers.amazon.aws.operators.emr import EmrContainerOperator
from airflow.providers.amazon.aws.sensors.emr import EmrContainerSensor

vcluster_id = 'vnj4ytlad0yl5npnxi5q51x50'

job_driver_arg = {
        "sparkSubmitJobDriver": {
            "entryPoint": "s3://developer-personal-storage/hyunsoo/emr_on_eks/sample-4.py",
            "entryPointArguments": ["s3://chunjae-text-rdb-datastore/text_rdb_ods/cjt_050/Gamification/TBL_User/yyyy=2023/mm=09/dd=10/", "s3://chunjae-datastore/learning_analytics/member_segment/"],
            "sparkSubmitParameters": "--conf spark.executor.instances=1 --conf spark.executor.memory=1G --conf spark.executor.cores=1 --conf spark.driver.cores=1"
        }
    }

configuration_overrides_arg = {
        "applicationConfiguration": [
            {
                "classification": "spark-defaults",
                "properties": {
                    "spark.dynamicAllocation.enabled":"true",
                    "spark.dynamicAllocation.shuffleTracking.enabled":"true",
                    "spark.dynamicAllocation.minExecutors":"1",
                    "spark.dynamicAllocation.maxExecutors":"4",
                    "spark.dynamicAllocation.initialExecutors":"1",
                    "spark.dynamicAllocation.schedulerBacklogTimeout": "1s",
                    "spark.dynamicAllocation.executorIdleTimeout": "5s",
                    "spark.kubernetes.executor.deleteOnTermination": "true"
                }
            }
        ],
        "monitoringConfiguration": {
            "cloudWatchMonitoringConfiguration": {
                "logGroupName": "/emr-on-eks/emr-eks-dev-logs",
                "logStreamNamePrefix": "sample"
            },
            "s3MonitoringConfiguration": {
                "logUri": "s3://developer-personal-storage/hyunsoo/emr_on_eks/log/"
            }
        }
    }


dag = DAG('emr_container', 
          description='emr_container DAG',
          schedule='@once',
        #   schedule_interval='0 12 * * *',
          start_date=datetime(2023, 9, 17), catchup=False)


job_starter = EmrContainerOperator(
    task_id="start_job",
    virtual_cluster_id=vcluster_id,
    execution_role_arn='arn:aws:iam::447600660135:role/EMRContainers-JobExecutionRole',
    release_label="emr-6.2.0-latest",
    job_driver=job_driver_arg,
    configuration_overrides=configuration_overrides_arg,
    name="asg-job",
    aws_conn_id='emr_conn',
    dag=dag
)

job_waiter = EmrContainerSensor(
    task_id="job_waiter",
    virtual_cluster_id=vcluster_id,
    job_id="{{ task_instance.xcom_pull(task_ids='start_job', key='return_value') }}",
    aws_conn_id='emr_conn',
)

job_starter >> job_waiter