from odoo import fields, models


class HrPayslipLine(models.Model):
    _name = "hr.payslip.line"
    _table = "hr_payslip_line"
    _description = "Payslip Line"
    _order = "sequence, id"

    sequence = fields.Integer(default=10)
    slip_id = fields.Many2one("hr.payslip", required=True, ondelete="cascade", index=True)
    salary_rule_id = fields.Many2one("hr.salary.rule", required=True, ondelete="restrict")
    contract_id = fields.Many2one("hr.contract", required=True, ondelete="restrict")
    employee_id = fields.Many2one("hr.employee", required=True, ondelete="restrict")
    company_id = fields.Many2one(
        "res.company",
        related="slip_id.company_id",
        store=True,
        readonly=True,
        index=True,
    )
    name = fields.Char(required=True)
    code = fields.Char(required=True)
    date_from = fields.Date()
    date_to = fields.Date()
    rate = fields.Float()
    amount = fields.Float()
    quantity = fields.Float()
    total = fields.Monetary(currency_field="currency_id")
    ytd = fields.Monetary(currency_field="currency_id")
    appears_on_payslip = fields.Boolean()
    category_id = fields.Many2one("hr.salary.rule.category", ondelete="set null")
    currency_id = fields.Many2one(
        "res.currency",
        related="slip_id.currency_id",
        readonly=True,
    )

    def get_payslip_styling_dict(self):
        # Enterprise report styling hook; empty dict keeps default report layout.
        return {}
