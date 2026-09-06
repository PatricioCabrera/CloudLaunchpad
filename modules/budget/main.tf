data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "allow_services" {
  statement {
    sid = "1"

    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com", "costalerts.amazonaws.com"]
    }

    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.budget_alerts.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sns_topic" "budget_alerts" {
  name = "budget-alerts"
}

resource "aws_sns_topic_policy" "publish_policy" {
  policy = data.aws_iam_policy_document.allow_services.json
  arn    = aws_sns_topic.budget_alerts.arn
}

resource "aws_sns_topic_subscription" "budget_alerts_target" {
  topic_arn = aws_sns_topic.budget_alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_budgets_budget" "cloudlaunchpad_budget" {
  name         = "budget-cloudlaunchpad-monthly"
  limit_amount = "10"
  limit_unit   = "USD"
  budget_type  = "COST"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = "50"
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.budget_alerts.arn]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = "80"
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.budget_alerts.arn]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = "100"
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.budget_alerts.arn]
  }
}

resource "aws_ce_anomaly_monitor" "cloudlaunchpad_anomaly_monitor" {
  name              = "anomaly-monitor-cloudlaunchpad"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

resource "aws_ce_anomaly_subscription" "cloudlaunchpad_anomaly_subscription" {
  name      = "daily_subscription_cloudlaunchpad"
  frequency = "DAILY"

  monitor_arn_list = [aws_ce_anomaly_monitor.cloudlaunchpad_anomaly_monitor.arn]

  subscriber {
    type    = "SNS"
    address = aws_sns_topic.budget_alerts.arn
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = ["100"]
    }
  }
}