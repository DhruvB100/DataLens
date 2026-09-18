# just a namespace for the table below
resource "aws_glue_catalog_database" "datalens_db" {
  name = "datalens"
}

# tells athena how to read the parquet files sitting in gold/
resource "aws_glue_catalog_table" "earthquakes" {
  database_name = aws_glue_catalog_database.datalens_db.name
  name          = "earthquakes"
  table_type    = "EXTERNAL_TABLE"

  # projection.* below means athena computes valid dt partitions itself from a
  # date range instead of relying on the glue catalog's stored partition list -
  # without this, new days never show up until someone manually runs
  parameters = {
    "classification"            = "parquet"
    "projection.enabled"        = "true"
    "projection.dt.type"        = "date"
    "projection.dt.range"       = "2026-09-01,NOW"
    "projection.dt.format"      = "yyyy-MM-dd"
    "storage.location.template" = "s3://${aws_s3_bucket.data_lake.id}/gold/dt=$${dt}/"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data_lake.id}/gold/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name = "id"
      type = "string"
    }

    columns {
      name = "magnitude"
      type = "double"
    }

    columns {
      name = "place"
      type = "string"
    }

    columns {
      name = "event_time"
      type = "timestamp"
    }

    columns {
      name = "tsunami"
      type = "bigint" # not "int" - pandas writes these as 64-bit
    }

    columns {
      name = "longitude"
      type = "double"
    }

    columns {
      name = "latitude"
      type = "double"
    }

    columns {
      name = "depth_km"
      type = "double"
    }
  }

  # dt lives in the s3 path (dt=YYYY-MM-DD), not inside the parquet files themselves
  partition_keys {
    name = "dt"
    type = "string"
  }
}