1. Variable Define
snapshot retiontion, tag name can be defined in lambda_function.py file. current snapshot RETENTION_DAYS is 7 days. you can add more tags in snapshot_tags section

2. lambda package deployment
Two ways are supported, using s3 bucket and uploading from local. 
when using s3 bucket, you need to upload ebs_snapshot_creator.zip to s3 bucket, and then update bucket name and package name in the main terraform file.
when using local method, terraform will automatically zip file and upload to lambda to deploy. please comment out s3 bucket and s3 key.


