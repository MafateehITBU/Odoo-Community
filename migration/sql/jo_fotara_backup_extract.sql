-- Source DB: mafateeh_community18_before (restored from before_app_menu_cleanup backup)
-- Purpose: Extract source-of-truth JoFotara report/view metadata used as baseline.

SELECT id, key, name, inherit_id, active
FROM ir_ui_view
WHERE key ILIKE '%l10n_jo_edi%'
   OR key IN ('account.report_invoice_document', 'account.report_invoice', 'l10n_gcc_invoice.arabic_english_invoice')
ORDER BY id;

SELECT id, name, model, report_name, is_invoice_report
FROM ir_act_report_xml
WHERE model = 'account.move'
ORDER BY id;

SELECT rc.id,
       rc.name,
       rp.country_id,
       rc.l10n_jo_edi_taxpayer_type,
       (rc.l10n_jo_edi_client_identifier IS NOT NULL) AS has_client_id,
       (rc.l10n_jo_edi_secret_key IS NOT NULL) AS has_secret
FROM res_company rc
JOIN res_partner rp ON rp.id = rc.partner_id
ORDER BY rc.id;
