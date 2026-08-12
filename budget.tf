# Billing budget + alerts. This is the "don't get surprised by a $400
# bill" guardrail — notifications only, it does not stop spend on its
# own (that would need a separate Pub/Sub -> Cloud Function pattern to
# actually disable billing, which is a deliberate follow-up, not a default,
# since auto-disabling billing can take down things you didn't intend to).

resource "google_monitoring_notification_channel" "budget_email" {
  for_each     = toset(var.budget_alert_emails)
  display_name = "Budget alert - ${each.value}"
  type         = "email"

  labels = {
    email_address = each.value
  }
}

data "google_project" "current" {
  project_id = var.project_id
}

resource "google_billing_budget" "monthly" {
  provider        = google.with_quota
  billing_account = var.billing_account_id
  display_name    = "${var.project_id} monthly budget"

  budget_filter {
    projects = ["projects/${data.google_project.current.number}"]
  }

  amount {
    specified_amount {
      units = tostring(var.budget_amount)
    }
  }

  dynamic "threshold_rules" {
    for_each = var.budget_alert_thresholds
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

  all_updates_rule {
    monitoring_notification_channels = [
      for c in google_monitoring_notification_channel.budget_email : c.id
    ]
    disable_default_iam_recipients = false
  }
}
