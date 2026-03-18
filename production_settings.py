from pretix.settings import *  # noqa

STATIC_ROOT = "/pretix/src/static.dist"
STATICFILES_STORAGE = "django.contrib.staticfiles.storage.ManifestStaticFilesStorage"

LOGGING["handlers"]["mail_admins"]["class"] = "logging.NullHandler"  # noqa
