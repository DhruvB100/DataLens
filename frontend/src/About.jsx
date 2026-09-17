// static content, no fetching - just explains the pipeline behind the page above
export default function About() {
    return (
        <div style={{ padding: "20px", textAlign: "left", maxWidth: "700px", margin: "0 auto" }}>
            <p>
                DataLens is a small serverless data pipeline I built to learn AWS end-to-end -
                from raw data all the way to a UI you can actually use. Everything above this
                section (the chart, the table, the ask box) is powered by the pipeline below.
            </p>

            <pre style={{
                overflowX: "auto",
                background: "var(--code-bg)",
                padding: "16px",
                borderRadius: "6px",
                fontSize: "14px",
                lineHeight: "1.5"
            }}>
{`USGS earthquake feed
        |
        v
 [ingest Lambda]  <- runs every 6 hours (EventBridge)
        |
        v
 S3 bronze/  (raw JSON)
        |  new file triggers this automatically
        v
 [transform Lambda]  <- cleans it up, writes Parquet
        |
        v
 S3 gold/  ->  Glue Data Catalog  ->  Athena
                                        |
                    ------------------------------------
                    |                                  |
             [query Lambda]                    [ai_query Lambda]
             (fixed SQL per endpoint)      (Gemini writes the SQL)
                    |                                  |
                    ------------- API Gateway ----------
                                        |
                                        v
                              this React page`}
            </pre>

            <p>
                Ingestion and transforming happen completely on their own, six hours apart,
                with no server running in between - that's the "serverless" part. The dashboard
                above always runs the same three fixed queries. The Ask box is the more
                interesting piece: it sends your question to Gemini along with the table's
                schema and a list of rules, gets back a SQL query, checks that query is actually
                safe (read-only, only touches this one table) before running it, and then asks
                Gemini a second time to turn the raw results into a plain-English sentence.
            </p>
        </div>
    );
}
