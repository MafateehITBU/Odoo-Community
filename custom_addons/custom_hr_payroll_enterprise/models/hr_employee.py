from odoo import models, fields


class HrEmployee(models.Model):
    _inherit = "hr.employee"

    # Compatibility field for migrated enterprise/custom views that expect Sign app integration.
    sign_request_count = fields.Integer(string="Signature Requests", default=0, readonly=True)
    # Compatibility field for migrated timesheet/enterprise employee views.
    show_billable_time_target = fields.Boolean(string="Show Billable Time Target", default=False, readonly=True)
    # Compatibility field for migrated enterprise employee views.
    billable_time_target = fields.Float(string="Billable Time Target", default=0.0, readonly=True)

    def open_sign_requests(self):
        # Community-safe fallback: keep button/action callable if old views reference it.
        return {"type": "ir.actions.act_window_close"}

