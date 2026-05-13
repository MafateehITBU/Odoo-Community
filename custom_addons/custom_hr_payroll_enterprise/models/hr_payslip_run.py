from odoo import _, fields, models
from odoo.exceptions import UserError


class HrPayslipRun(models.Model):
    _name = "hr.payslip.run"
    _table = "hr_payslip_run"
    _description = "Payslip Run (Enterprise-like placeholder)"
    _rec_name = "name"

    name = fields.Char(required=True)
    state = fields.Char()
    company_id = fields.Many2one("res.company", required=True, ondelete="restrict")

    date_start = fields.Date(required=True)
    date_end = fields.Date(required=True)

    move_id = fields.Many2one("account.move", ondelete="set null")
    payment_report_filename = fields.Char()
    payment_report_date = fields.Date()
    l10n_sa_wps_file_reference = fields.Char()

    def generate_payslips(self):
        """
        Minimal payslip generation for Phase 2B:
        - for a run with 0 payslips, creates draft payslips for contracts in the run's company
        - generates 1 payslip line per salary rule (appears_on_payslip) for a best-effort payroll structure
        - links `move_id` by copying the most recent payslip move for the same employee

        This is intentionally a pragmatic workflow to make the UI work and avoid crashes.
        """
        Payslip = self.env["hr.payslip"]
        Contract = self.env["hr.contract"]
        today = fields.Date.context_today(self)

        cr = self.env.cr

        for run in self:
            if Payslip.search_count([("payslip_run_id", "=", run.id)]):
                continue

            if not run.company_id:
                raise UserError(_("Payslip run has no company."))

            company_country_id = run.company_id.account_fiscal_country_id.id
            # Best-effort: use the contract's structure_type_id to pick a payroll structure instance.
            contracts = Contract.search(
                [
                    ("company_id", "=", run.company_id.id),
                    ("employee_id", "!=", False),
                ]
            )

            for contract in contracts:
                employee = contract.employee_id
                if not employee:
                    continue

                # Pick a payroll structure instance (hr_payroll_structure table is not guaranteed
                # to be present as a model in this workspace, so we query SQL directly).
                cr.execute(
                    """
                    SELECT id
                      FROM hr_payroll_structure
                     WHERE type_id=%s
                       AND (country_id=%s OR country_id IS NULL)
                     ORDER BY (country_id=%s) DESC NULLS LAST
                     LIMIT 1
                    """,
                    (contract.structure_type_id.id, company_country_id, company_country_id),
                )
                struct_row = cr.fetchone()
                if not struct_row:
                    continue
                struct_id = struct_row[0]

                # Reuse a move_id if we find a recent payslip for the same employee.
                cr.execute(
                    """
                    SELECT move_id
                      FROM hr_payslip
                     WHERE employee_id=%s AND move_id IS NOT NULL
                     ORDER BY date_to DESC NULLS LAST
                     LIMIT 1
                    """,
                    (employee.id,),
                )
                move_row = cr.fetchone()
                move_id = move_row[0] if move_row else None

                payslip = Payslip.create(
                    {
                        "name": run.name,
                        "state": "draft",
                        "company_id": run.company_id.id,
                        "employee_id": employee.id,
                        "contract_id": contract.id,
                        "payslip_run_id": run.id,
                        "date_from": run.date_start,
                        "date_to": run.date_end,
                        "move_id": move_id,
                        "paid": False,
                        "credit_note": False,
                        "compute_date": today,
                    }
                )

                # Create one payslip line per salary rule for this structure.
                cr.execute(
                    """
                    SELECT
                        r.id,
                        r.sequence,
                        r.code,
                        COALESCE(r.name->>'en_US', r.code) AS rule_name,
                        COALESCE(r.amount_fix, 0) AS rule_amount_fix
                      FROM hr_salary_rule r
                     WHERE r.struct_id=%s
                       AND r.active=true
                       AND r.appears_on_payslip=true
                     ORDER BY r.sequence
                    """,
                    (struct_id,),
                )
                rules = cr.fetchall()
                seq = 1
                for rule_id, rule_seq, code, rule_name, rule_amount_fix in rules:
                    cr.execute(
                        """
                        INSERT INTO hr_payslip_line
                            (sequence, slip_id, salary_rule_id, contract_id, employee_id, name, code,
                             date_from, date_to, rate, quantity, amount, total)
                        VALUES
                            (%s, %s, %s, %s, %s, %s, %s,
                             %s, %s, %s, %s, %s, %s)
                        """,
                        (
                            rule_seq or seq,
                            payslip.id,
                            rule_id,
                            contract.id,
                            employee.id,
                            rule_name,
                            code,
                            run.date_start,
                            run.date_end,
                            rule_amount_fix,
                            1,
                            rule_amount_fix,
                            rule_amount_fix,
                        ),
                    )
                    seq += 1

                # Refresh totals and move the payslip to `verify` so the user can confirm it.
                payslip.compute_sheet()
        return True

