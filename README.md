# MeteoGroup S3 bucket Terraform module

Creates an S3 bucket - optionally with notification SNS topic, cross-account read
and/or write permissions and deletion protection.


## Inputs

`enabled` (Default: `true`)\
If set to false, the module will do nothing.
This exists because there can be no `count` meta-parameter for a module

`local_prefix`\
AWS-account-local name prefix, used for the created notification SNS topic,
e.g. `manta-staging`

`global_prefix`\
Global name prefix, used for the bucket name,
e.g. `mg-manta-staging`

`name`\
Name of the bucket (excluding the *global_prefix*)

`tags` (map)\
Additional tags to add to each created resource

`versioning` (bool, Default: `false`)\
Whether to enable
[versioning](https://docs.aws.amazon.com/AmazonS3/latest/dev/Versioning.html)
on the bucket

`sns_topic` (bool, Default: `false`)\
Whether to create an [SNS topic](https://docs.aws.amazon.com/sns/latest/dg/welcome.html)
and [publish S3 object creations](https://docs.aws.amazon.com/AmazonS3/latest/dev/NotificationHowTo.html)
to it

`read_accounts` (list(str))\
Account numbers of other AWS accounts which should get read access to the bucket -
and *subscribe* access to its SNS topic

`read_prefix` (str)\
Prefix of object keys to restrict cross-account reads to

`write_accounts` (list(str))\
Account numbers of other AWS accounts which should get write access to the bucket

`write_key_pattern` (str)\
Pattern of object keys allowed for cross-account writes

`lifecycle_rules` (list(lifecycle_rule))\
[Lifecycle rules](https://www.terraform.io/docs/providers/aws/r/s3_bucket.html#lifecycle_rule)
to transition / expire old objects in the bucket

`protect` (bool, Default: `false`)\
Whether to protect the bucket (and the SNS topic if created) from deletion
by creating a restrictive
[bucket policy](https://docs.aws.amazon.com/AmazonS3/latest/user-guide/add-bucket-policy.html)

`enable_website` (bool, Default: `false`)\
Whether to make the bucket available as a static website
