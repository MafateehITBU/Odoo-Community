from odoo import api, fields, models


class HrContract(models.Model):
    _inherit = "hr.contract"

    # Enterprise payroll fields kept in migrated DB; expose them for Community models/reports.
    wage_type = fields.Selection(
        [
            ("monthly", "Fixed Wage"),
            ("hourly", "Hourly Wage"),
        ],
        string="Wage Type",
        default="monthly",
    )
    schedule_pay = fields.Selection(
        [
            ("annually", "Annually"),
            ("semi-annually", "Semi-annually"),
            ("quarterly", "Quarterly"),
            ("bi-monthly", "Bi-monthly"),
            ("monthly", "Monthly"),
            ("semi-monthly", "Semi-monthly"),
            ("bi-weekly", "Bi-weekly"),
            ("weekly", "Weekly"),
            ("daily", "Daily"),
        ],
        string="Scheduled Pay",
        default="monthly",
    )
    hourly_wage = fields.Monetary(currency_field="currency_id")
    contract_type_id = fields.Many2one("hr.contract.type", ondelete="set null")
    hours_per_week = fields.Float(compute="_compute_hours_per_week")

    @api.depends("resource_calendar_id")
    def _compute_hours_per_week(self):
        for contract in self:
            calendar = contract.resource_calendar_id
            hours = 0.0
            if calendar:
                hours = getattr(calendar, "full_time_required_hours", 0.0) or 0.0
                if not hours and calendar.attendance_ids:
                    hours = sum(
                        (att.hour_to or 0.0) - (att.hour_from or 0.0)
                        for att in calendar.attendance_ids
                    )
            contract.hours_per_week = hours or 40.0

    def _get_contract_wage(self):
        self.ensure_one()
        if self.wage_type == "hourly":
            return self.hourly_wage or 0.0
        return self.wage or 0.0
