from odoo import _, fields, models
from odoo.exceptions import UserError


class HrPayslip(models.Model):
    _name = "hr.payslip"
    _table = "hr_payslip"
    _description = "Payslip (Enterprise-like placeholder)"
    _rec_name = "name"

    name = fields.Char(required=True)
    number = fields.Char()
    state = fields.Char()

    company_id = fields.Many2one("res.company", required=True, ondelete="restrict")
    currency_id = fields.Many2one(
        "res.currency",
        related="company_id.currency_id",
        readonly=True,
        store=False,
    )
    employee_id = fields.Many2one("hr.employee", required=True, ondelete="restrict")
    department_id = fields.Many2one("hr.department", ondelete="set null")
    job_id = fields.Many2one("hr.job", ondelete="set null")
    contract_id = fields.Many2one("hr.contract", ondelete="set null")

    payslip_run_id = fields.Many2one("hr.payslip.run", ondelete="cascade")

    date_from = fields.Date(required=True)
    date_to = fields.Date(required=True)
    paid_date = fields.Date()
    compute_date = fields.Date()

    paid = fields.Boolean()
    credit_note = fields.Boolean()
    warning_message = fields.Char()
    email_cc = fields.Char()
    note = fields.Text()
    basic_wage = fields.Monetary(currency_field="currency_id")
    gross_wage = fields.Monetary(currency_field="currency_id")
    net_wage = fields.Monetary(currency_field="currency_id")

    has_negative_net_to_report = fields.Boolean()
    edited = fields.Boolean()
    queued_for_pdf = fields.Boolean()
    sum_worked_hours = fields.Float()

    payment_report_filename = fields.Char()
    payment_report_date = fields.Date()
    l10n_sa_wps_file_reference = fields.Char()

    move_id = fields.Many2one("account.move", ondelete="set null")

    def action_repost_account_move(self):
        """
        Minimal repost helper for Phase 2A: reset the linked journal entry to draft (if posted)
        and post it again. This does not re-run payroll computations.
        """
        for slip in self:
            if not slip.move_id:
                raise UserError(
                    _(
                        "This payslip has no linked accounting entry (move_id)."
                    )
                )

            if slip.move_id.state == "posted":
                slip.move_id.button_draft()
            slip.move_id.action_post()
        return True

    def compute_sheet(self):
        """
        Minimal “compute sheet” for Phase 2B:
        - sums `hr_payslip_line.total` to refresh basic/gross/net
        - puts the payslip into `verify`
        """
        cr = self.env.cr
        today = fields.Date.context_today(self)

        for slip in self:
            if slip.state not in ("draft", "verify"):
                continue
            cr.execute(
                "SELECT COALESCE(SUM(total), 0) FROM hr_payslip_line WHERE slip_id=%s",
                (slip.id,),
            )
            total = cr.fetchone()[0] or 0
            slip.write(
                {
                    "basic_wage": total,
                    "gross_wage": total,
                    "net_wage": total,
                    "compute_date": today,
                    "state": "verify",
                }
            )
        return True

    def action_payslip_draft(self):
        for slip in self:
            slip.write({"state": "draft", "paid": False})
        return True

    def action_payslip_done(self):
        for slip in self:
            if not slip.move_id:
                # Best-effort: link the payslip to a recent move for the same employee.
                # This avoids crashes when your DB has `verify` payslips with no move yet.
                self.env.cr.execute(
                    """
                    SELECT move_id
                      FROM hr_payslip
                     WHERE employee_id=%s
                       AND move_id IS NOT NULL
                  ORDER BY date_to DESC NULLS LAST
                     LIMIT 1
                    """,
                    (slip.employee_id.id,),
                )
                move_id = self.env.cr.fetchone()
                move_id = move_id[0] if move_id else None
                if not move_id:
                    raise UserError(_("Cannot confirm payslip: no accounting move found for this employee."))
                slip.write({"move_id": move_id})

            slip.move_id.with_context(disable_abnormal_invoice_detection=True).action_post()
            slip.write({"state": "done"})
        return True

    def action_payslip_paid(self):
        today = fields.Date.context_today(self)
        for slip in self:
            if slip.state not in ("done", "verify"):
                # Keep workflow lenient: allow marking as paid if move exists.
                pass
            slip.write({"state": "paid", "paid": True, "paid_date": today})
        return True

    def action_payslip_cancel(self):
        for slip in self:
            slip.write({"state": "cancel", "paid": False})
        return True

