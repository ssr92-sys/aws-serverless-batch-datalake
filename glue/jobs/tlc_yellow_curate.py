import sys
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
from pyspark.sql import functions as F

args = getResolvedOptions(
    sys.argv,
    ["JOB_NAME", "glue_db", "raw_trips_table", "ref_table", "curated_s3_path"]
)

sc = SparkContext.getOrCreate()
glueContext = GlueContext(sc)
spark = glueContext.spark_session

job = Job(glueContext)
job.init(args["JOB_NAME"], args)

db = args["glue_db"]
raw_trips_table = args["raw_trips_table"]
ref_table = args["ref_table"]
curated_path = args["curated_s3_path"]

trips = glueContext.create_dynamic_frame.from_catalog(database=db, table_name=raw_trips_table).toDF()
ref = glueContext.create_dynamic_frame.from_catalog(database=db, table_name=ref_table).toDF()

# Derived fields + partitions
trips2 = (
    trips
    .withColumn("trip_duration_sec",
                F.col("tpep_dropoff_datetime").cast("long") - F.col("tpep_pickup_datetime").cast("long"))
    .withColumn("trip_duration_sec",
                F.when(F.col("trip_duration_sec") < 0, F.lit(None)).otherwise(F.col("trip_duration_sec")))
    .withColumn("year", F.year("tpep_pickup_datetime"))
    .withColumn("month", F.month("tpep_pickup_datetime"))
)

# Lookup prep
ref_sel = ref.select(
    F.col("locationid").cast("int").alias("locationid"),
    "borough", "zone", "service_zone"
)

# Enrich pickup + dropoff
enriched = (
    trips2
    .join(
        ref_sel.withColumnRenamed("borough", "pu_borough")
               .withColumnRenamed("zone", "pu_zone")
               .withColumnRenamed("service_zone", "pu_service_zone"),
        trips2["PULocationID"] == F.col("locationid"),
        "left"
    )
    .drop("locationid")
    .join(
        ref_sel.withColumnRenamed("borough", "do_borough")
               .withColumnRenamed("zone", "do_zone")
               .withColumnRenamed("service_zone", "do_service_zone"),
        trips2["DOLocationID"] == F.col("locationid"),
        "left"
    )
    .drop("locationid")
)

# Write curated
(
    enriched
    .repartition("year", "month")
    .write
    .mode("overwrite")
    .partitionBy("year", "month")
    .parquet(curated_path)
)

job.commit()