from pyspark.sql import SparkSession
from pyspark import SparkContext
from pyspark.sql import functions as F
from pyspark.sql import types as T
import argparse

spark = SparkSession.builder.appName("EMR_").getOrCreate()


def main(read_location, write_location):
    
    with SparkSession.builder.appName("EMR_").getOrCreate() as spark:
        if read_location is not None:
            df = spark.read.parquet(read_location)
        
        df = df.groupby("sex").count()
        print("read_location = ", read_location)
        print("write_location = ", write_location)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--read_location', help="The URI for you CSV restaurant data, like an S3 bucket location.")
    parser.add_argument(
        '--write_location', help="The URI where output is saved, like an S3 bucket location.")
    args = parser.parse_args()

    main(args.read_location, args.write_location)