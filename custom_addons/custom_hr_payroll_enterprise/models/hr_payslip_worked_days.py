from odoo import fields, models


class HrPayslipWorkedDays(models.Model):
    _name = "hr.payslip.worked_days"
    _table = "hr_payslip_worked_days"
    _description = "Payslip Worked Days"
    _order = "sequence, id"

    sequence = fields.Integer(default=10)
    payslip_id = fields.Many2one("hr.payslip", required=True, ondelete="cascade", index=True)
    work_entry_type_id = fields.Many2one("hr.work.entry.type", required=True, ondelete="restrict")
    name = fields.Char()
    code = fields.Char()
    number_of_days = fields.Float()
    number_of_hours = fields.Float()
    amount = fields.Monetary(currency_field="currency_id")
    ytd = fields.Monetary(currency_field="currency_id")
    is_paid = fields.Boolean()
    is_credit_time = fields.Boolean()
    currency_id = fields.Many2one(
        "res.currency",
        related="payslip_id.currency_id",
        readonly=True,
    )
