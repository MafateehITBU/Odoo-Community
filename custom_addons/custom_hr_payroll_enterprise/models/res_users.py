from odoo import models, fields


class ResUsers(models.Model):
    _inherit = "res.users"

    # Compatibility fields for migrated enterprise Sign-related user views.
    sign_signature = fields.Binary(string="Signature", readonly=True)
    sign_initials = fields.Binary(string="Initials", readonly=True)
    # Compatibility field for migrated enterprise Documents user views.
    document_count = fields.Integer(string="Documents", default=0, readonly=True)

