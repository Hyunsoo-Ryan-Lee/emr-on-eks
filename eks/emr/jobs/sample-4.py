from pyspark.sql import SparkSession, Row
from pyspark import SparkContext
from pyspark.sql import functions as F
import sys

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
        result = ddf.join(mem, ddf.UserID == mem.system_id)
        result.coalesce(1).write.mode('overwrite').parquet('s3://developer-personal-storage/hyunsoo/emr_on_eks/result/')

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])