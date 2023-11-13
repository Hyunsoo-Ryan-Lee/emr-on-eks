from pyspark.sql import SparkSession
from pyspark import SparkContext
from pyspark.sql import functions as F
from pyspark.sql import types as T
import argparse

spark = SparkSession.builder.appName("sample_script").getOrCreate()

def main():

    df_spark = spark.createDataFrame([
        Row(a=1, b=11.2, c='apple'),
        Row(a=2, b=3.5, c='banana'),
        Row(a=3, b=7.3, c='tomato'),
    ])
    print(df_spark.columns)
    df_spark.write.mode('overwrite').parquet('s3://developer-personal-storage/hyunsoo/emr_on_eks/result/job-without-var/')

if __name__ == "__main__":
    main()