from odoo import fields, models


class HrPayrollDashboardWarning(models.Model):
    _name = "hr.payroll.dashboard.warning"
    _table = "hr_payroll_dashboard_warning"
    _description = "Payroll Dashboard Warning (placeholder)"
    _rec_name = "name"

    country_id = fields.Many2one("res.country")
    sequence = fields.Integer()
    color = fields.Integer()
    evaluation_code = fields.Text()
    active = fields.Boolean()

    name = fields.Char(translate=True, required=True)

