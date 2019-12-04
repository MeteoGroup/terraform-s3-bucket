locals {
  enable_sns_topic         = var.enabled && var.sns_topic
  enable_read_accounts     = var.enabled && length(var.read_accounts) > 0
  enable_write_accounts    = var.enabled && length(var.write_accounts) > 0
  enable_protect           = var.enabled && var.protect
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
locals {
  account_id = data.aws_caller_identity.current.account_id
  region = data.aws_region.current.name
}


##########  The S3 bucket  ##########

resource "aws_s3_bucket" "this" {
  count = var.enabled ? 1 : 0

  bucket = "${var.global_prefix}-${var.name}"
  tags   = var.tags
  versioning {
    enabled = var.versioning
  }
  force_destroy = true
  request_payer = "BucketOwner"

  dynamic "lifecycle_rule" {
    for_each = var.lifecycle_rules
    content {
      id      = lifecycle_rule.value.id
      enabled = lookup(lifecycle_rule.value, "enabled", true)
      prefix  = lookup(lifecycle_rule.value, "prefix", null)
      tags    = lookup(lifecycle_rule.value, "tags", null)

      dynamic "expiration" {
        for_each = lookup(lifecycle_rule.value, "expiration", [])
        content {
          days = expiration.value.days
        }
      }

      dynamic "transition" {
        for_each = lookup(lifecycle_rule.value, "transition", [])
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }
    }
  }
}
locals {
  bucket_id = concat(aws_s3_bucket.this.*.id, [""])[0]
  bucket_arn = concat(aws_s3_bucket.this.*.arn, [""])[0]
}


##########  S3 Bucket policy  ##########

data "aws_iam_policy_document" "bucket_policy_read" {
  count = local.enable_read_accounts ? 1 : 0

  statement {
    sid = "AllowCrossAccountRead"
    resources = [
      local.bucket_arn,
      "${local.bucket_arn}/*",
    ]
    actions = [
      "s3:Get*",
      "s3:List*",
    ]
    principals {
      type        = "AWS"
      identifiers = var.read_accounts
    }
  }
}

data "aws_iam_policy_document" "bucket_policy_write" {
  count = local.enable_write_accounts ? 1 : 0

  statement {
    sid = "AllowCrossAccountWrite"
    resources = [
      local.bucket_arn,
      "${local.bucket_arn}/*",
    ]
    actions = [
      "s3:Put*",
    ]
    principals {
      type        = "AWS"
      identifiers = var.write_accounts
    }
  }
}

data "aws_iam_policy_document" "bucket_policy_protect" {
  count = local.enable_protect ? 1 : 0

  statement {
    sid    = "DenyDeletion"
    effect = "Deny"
    resources = [local.bucket_arn]
    actions = [
      "s3:DeleteBucket",
      "s3:DeleteBucketPolicy",
    ]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
  }
}

locals {
  enable_bucket_policy = local.enable_read_accounts || local.enable_write_accounts || local.enable_protect
}

data "aws_iam_policy_document" "bucket_policy_read_write" {
  count = local.enable_read_accounts || local.enable_write_accounts ? 1 : 0

  source_json = element(
    concat(data.aws_iam_policy_document.bucket_policy_read.*.json, [""]),
    0,
  )
  override_json = element(
    concat(
      data.aws_iam_policy_document.bucket_policy_write.*.json,
      [""],
    ),
    0,
  )
}

data "aws_iam_policy_document" "bucket_policy" {
  count = local.enable_bucket_policy ? 1 : 0

  source_json = element(
    concat(
      data.aws_iam_policy_document.bucket_policy_read_write.*.json,
      [""],
    ),
    0,
  )
  override_json = element(
    concat(
      data.aws_iam_policy_document.bucket_policy_protect.*.json,
      [""],
    ),
    0,
  )
}

resource "aws_s3_bucket_policy" "this" {
  count = local.enable_bucket_policy ? 1 : 0

  bucket = local.bucket_id
  policy = data.aws_iam_policy_document.bucket_policy[0].json
}


##########  SNS topic for notifications  ##########

locals {
  topic_name = local.enable_sns_topic ? "${var.local_prefix}-${var.name}-s3" : ""
  topic_arn  = local.enable_sns_topic ? "arn:aws:sns:${local.region}:${local.account_id}:${local.topic_name}" : ""
}

data "aws_iam_policy_document" "sns_policy_base" {
  count = local.enable_sns_topic ? 1 : 0

  statement {
    sid = "AllowPublishFromS3Bucket"
    resources = [local.topic_arn]
    actions   = ["sns:Publish"]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values = [local.bucket_arn]
    }
  }
}

data "aws_iam_policy_document" "sns_policy_cross_account" {
  count = local.enable_sns_topic && local.enable_read_accounts ? 1 : 0

  statement {
    sid = "AllowCrossAccountSubscribe"
    resources = [local.topic_arn]
    actions = [
      "sns:Subscribe",
      "sns:GetTopicAttributes",
      "sns:ListSubscriptionsByTopic",
    ]
    principals {
      type        = "AWS"
      identifiers = var.read_accounts
    }
  }
}

data "aws_iam_policy_document" "sns_policy_protect" {
  count = local.enable_sns_topic && local.enable_protect ? 1 : 0

  statement {
    sid    = "DenyDeletion"
    effect = "Deny"
    resources = [local.topic_arn]
    actions = [
      "sns:DeleteTopic",
    ]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
  }
}

data "aws_iam_policy_document" "sns_policy_merge_1" {
  count = local.enable_sns_topic ? 1 : 0

  source_json = element(
    concat(data.aws_iam_policy_document.sns_policy_base.*.json, [""]),
    0,
  )
  override_json = element(
    concat(
      data.aws_iam_policy_document.sns_policy_cross_account.*.json,
      [""],
    ),
    0,
  )
}

data "aws_iam_policy_document" "sns_policy" {
  count = local.enable_sns_topic ? 1 : 0

  source_json = element(
    concat(data.aws_iam_policy_document.sns_policy_merge_1.*.json, [""]),
    0,
  )
  override_json = element(
    concat(data.aws_iam_policy_document.sns_policy_protect.*.json, [""]),
    0,
  )
}

resource "aws_sns_topic" "this" {
  count = local.enable_sns_topic ? 1 : 0

  name   = local.topic_name
  tags   = var.tags

  policy = data.aws_iam_policy_document.sns_policy[0].json
}


#####  S3 notifications -> SNS topic

resource "aws_s3_bucket_notification" "this" {
  count  = local.enable_sns_topic ? 1 : 0
  bucket = local.bucket_id

  topic {
    id        = local.topic_name
    topic_arn = local.topic_arn
    events    = ["s3:ObjectCreated:*"]
  }
}
