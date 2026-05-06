# JoFotara Backup Mapping

Backup source: `mafateeh_community18_before_app_menu_cleanup_2026-04-23_1053.dump`

## Report/View keys from backup

- `account.report_invoice_document` (id `753`)
- `account.report_invoice` (id `758`)
- `l10n_gcc_invoice.arabic_english_invoice` (id `5416`)
- `l10n_jo_edi.report_invoice_document` (id `6204`)
- `l10n_jo_edi.report_invoice` (id `6205`)

## Company-level JoFotara baseline

- Company `Mafateeh for Engineering Consulting Company` is Jordan (`country_id=112`) with taxpayer type `sales`
- JoFotara credentials existed in backup (`l10n_jo_edi_client_identifier`, `l10n_jo_edi_secret_key`)

## Stable XML IDs in new module

- `jo_fotara_integration.report_invoice_document_jo_fotara`
- `jo_fotara_integration.report_invoice_router`
- `jo_fotara_integration.view_move_form_jo_fotara`
- `jo_fotara_integration.view_move_tree_jo_fotara`
- `jo_fotara_integration.view_move_search_jo_fotara`
- `jo_fotara_integration.res_config_settings_view_form_jo_fotara`

## Routing rule to keep

- If invoice is JO and JoFotara send completed (`sent` + XML attachment exists), use JoFotara report template.
- Otherwise use standard invoice template path.
