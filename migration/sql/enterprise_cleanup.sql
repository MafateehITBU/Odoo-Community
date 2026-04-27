BEGIN;

-- Remove special enterprise text search objects that are not used in Community.
DROP TEXT SEARCH CONFIGURATION IF EXISTS public.knowledge_config CASCADE;
DROP TEXT SEARCH DICTIONARY IF EXISTS public.knowledge_dictionary CASCADE;

-- Normalize enterprise license artifacts.
DELETE FROM ir_config_parameter
WHERE key IN (
    'database.enterprise_code',
    'database.expiration_date',
    'database.expiration_reason',
    'database.uuid'
);

-- Mark enterprise-like modules as uninstalled so Community registry can load.
UPDATE ir_module_module
SET state = 'uninstalled', to_buy = false
WHERE
    name IN (
        'web_enterprise',
        'web_studio',
        'documents',
        'documents_account',
        'documents_hr',
        'documents_project',
        'documents_spreadsheet',
        'documents_spreadsheet_account',
        'documents_spreadsheet_dashboard',
        'spreadsheet',
        'spreadsheet_account',
        'spreadsheet_dashboard',
        'knowledge',
        'knowledge_article_template',
        'helpdesk',
        'helpdesk_sale',
        'helpdesk_timesheet',
        'helpdesk_mrp',
        'helpdesk_fsm',
        'helpdesk_stock',
        'helpdesk_account',
        'sign',
        'sign_oca',
        'planning',
        'planning_hr',
        'planning_sale',
        'voip',
        'appointment_account_payment',
        'quality',
        'quality_control',
        'quality_mrp',
        'mrp_plm',
        'account_accountant',
        'account_avatax',
        'sale_subscription',
        'maintenance_plan_activity',
        'social',
        'whatsapp',
        'website_helpdesk'
    )
    OR name ~ '(enterprise|studio|helpdesk|documents|knowledge|spreadsheet|sign|planning|voip)';

-- Remove module metadata for enterprise namespaces from model data.
DELETE FROM ir_model_data
WHERE
    module IN (
        'web_enterprise', 'web_studio', 'documents', 'documents_account',
        'documents_hr', 'documents_project', 'documents_spreadsheet',
        'spreadsheet', 'spreadsheet_account', 'spreadsheet_dashboard',
        'knowledge', 'helpdesk', 'sign', 'planning', 'voip', 'quality',
        'mrp_plm', 'account_accountant', 'sale_subscription', 'social', 'whatsapp'
    )
    OR module ~ '(enterprise|studio|helpdesk|documents|knowledge|spreadsheet|sign|planning|voip)';

-- Keep module dependency table consistent.
DELETE FROM ir_module_module_dependency
WHERE name IN (
    SELECT name FROM ir_module_module
    WHERE state = 'uninstalled'
      AND (
        name ~ '(enterprise|studio|helpdesk|documents|knowledge|spreadsheet|sign|planning|voip)'
        OR name IN ('web_enterprise')
      )
);

-- Remove references to enterprise JS/CSS assets to avoid client load issues.
UPDATE ir_asset
SET active = false
WHERE (path ~ '(enterprise|web_studio|helpdesk|documents|knowledge|spreadsheet|sign|planning|voip)')
   OR (name ~ '(enterprise|studio|helpdesk|documents|knowledge|spreadsheet|sign|planning|voip)');

-- Disable known migrated inherited views that reference removed enterprise fields.
UPDATE ir_ui_view
SET active = false
WHERE id IN (
    4970, -- res.users.form.sign.inherit (res.users.sign_signature)
    5533, -- res.users.preferences.form.sign.inherit (res.users.sign_signature)
    6110, -- res.users.view.form.inherit.documents (res.users.document_count)
    6059, -- account.move.form studio extension referencing discount_total
    5416  -- l10n_gcc_invoice.arabic_english_invoice referencing discount_total
);

-- Ensure standard invoice report can render Saudi/ZATCA QR for paid invoices too.
UPDATE ir_ui_view
SET arch_db = regexp_replace(
    arch_db::text,
    't-value=\\"o\.display_qr_code and o\.amount_residual &gt; 0\\"',
    't-value=\\"((''l10n_sa_qr_code_str'' in o._fields and o.l10n_sa_qr_code_str) or (o.display_qr_code and o.amount_residual &gt; 0))\\"',
    'g'
)::jsonb
WHERE id = 753;

UPDATE ir_ui_view
SET arch_db = regexp_replace(
    arch_db::text,
    't-value=\\"o\._generate_qr_code\(silent_errors=True\)\\"',
    't-value=\\"((''l10n_sa_qr_code_str'' in o._fields and o.l10n_sa_qr_code_str) and (''/report/barcode/?barcode_type=QR&amp;value=%s&amp;width=200&amp;height=200'' % o.l10n_sa_qr_code_str) or o._generate_qr_code(silent_errors=True))\\"',
    'g'
)::jsonb
WHERE id = 753;

COMMIT;
