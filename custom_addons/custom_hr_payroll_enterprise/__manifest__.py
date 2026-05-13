{
    "name": "Custom HR Payroll Enterprise (Community)",
    "version": "18.0.1.0",
    "category": "Human Resources/Payroll",
    "summary": "Enterprise-like payroll menus/dashboards on Odoo 18 Community",
    "depends": ["hr", "hr_contract", "account", "web"],
    "data": [
        "views/hr_payslip_views.xml",
        "views/hr_payslip_run_views.xml",
        "views/hr_payroll_dashboard_warning_views.xml",
        "views/hr_payroll_menus.xml",
    ],
    "installable": True,
    "application": True,
    "license": "LGPL-3",
}

