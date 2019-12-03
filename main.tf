locals {
  enable_sns_topic         = var.enabled && var.sns_topic
  enable_read_accounts     = var.enabled && length(var.read_accounts) > 0
  enable_write_accounts    = var.enabled && length(var.write_accounts) > 0
  enable_protect           = var.enabled && var.protect
}

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
      enabled = lifecycle_rule.value.enabled
      id      = lifecycle_rule.value.id
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

data "aws_iam_policy_document" "bucket_policy_read" {
  count = local.enable_read_accounts ? 1 : 0

  statement {
    sid = "read"
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
    sid = "write"
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
    sid    = "protect"
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

resource "aws_sns_topic" "this" {
  count = local.enable_sns_topic ? 1 : 0

  name = "${var.local_prefix}-${var.name}-s3"
}
locals {
  topic_name = concat(aws_sns_topic.this.*.name, [""])[0]
  topic_arn = concat(aws_sns_topic.this.*.arn, [""])[0]
}

data "aws_iam_policy_document" "sns_policy_base" {
  count = local.enable_sns_topic ? 1 : 0

  statement {
    sid = "publish"
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
    sid = "subscribe"
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
    sid    = "protect_topic"
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
  statement {
    sid    = "protect_policy"
    effect = "Deny"
    resources = [local.topic_arn]
    actions = [
      # Unfortunately, we cannot only prevent deletion of the topic policy.
      # Hence, we prevent any modifications - but only to Drone role (comment below)
      "sns:SetTopicAttributes",
    ]
    principals {
      type = "AWS"

      # This prevents us from accidentally changing the topic policy via Drone
      # but still allows manual changes via console / cli
      identifiers = ["arn:aws:iam::${var.account_id}:role/drone-infra"]
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

resource "aws_sns_topic_policy" "this" {
  count  = local.enable_sns_topic ? 1 : 0
  arn    = local.topic_arn
  policy = data.aws_iam_policy_document.sns_policy[0].json
}

resource "aws_s3_bucket_notification" "this" {
  count  = local.enable_sns_topic ? 1 : 0
  bucket = local.bucket_id

  topic {
    id        = local.topic_name
    topic_arn = local.topic_arn
    events    = ["s3:ObjectCreated:*"]
  }
}
