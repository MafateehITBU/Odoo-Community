-- JoFotara migration support for local rebuild.

-- Deactivate temporary migration-era fallback template override.
UPDATE ir_ui_view
SET active = false
WHERE key = 'custom.account_report_invoice_logo_fallback'
  AND active = true;

-- Ensure original JoFotara report views are active.
UPDATE ir_ui_view
SET active = true
WHERE key IN ('l10n_jo_edi.report_invoice_document', 'l10n_jo_edi.report_invoice');

-- Force fresh regeneration of invoice PDFs after report routing/template changes.
DELETE FROM ir_attachment
WHERE res_model = 'account.move'
  AND mimetype = 'application/pdf';
