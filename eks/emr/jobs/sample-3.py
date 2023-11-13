from pyspark.sql import SparkSession
from pyspark import SparkContext
from pyspark.sql import functions as F
import argparse

spark = SparkSession.builder.appName("EMR_").getOrCreate()


def main(var1, var2):
    
    with SparkSession.builder.appName("EMR_").getOrCreate() as spark:
        df1 = spark.read.parquet(var1)
        df2 = spark.read.parquet(var2)
        
        df = spark.read.parquet(var1)
        df = df.filter(F.col('MemberType') == 'S')
        ddf = df.select('Idx', 'UserID')
        
        member = spark.read.parquet(var2)
        
        mem = member.select('system_id', 'mbr_segment_nm').dropDuplicates(['system_id'])
        print("-"*50)
        print(var1)
        print(var2)
        print("-"*50)
        ddf.join(mem, ddf.UserID == mem.system_id).show()

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--var1')
    parser.add_argument('--var2')
    args = parser.parse_args()

    main(args.var1, args.var2)