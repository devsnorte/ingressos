from pretix.settings import *  # noqa

STATIC_ROOT = "/pretix/src/static.dist"
STORAGES = {
    **STORAGES,  # noqa
    "staticfiles": {
        "BACKEND": "django.contrib.staticfiles.storage.ManifestStaticFilesStorage",
    },
}

LOGGING["handlers"]["mail_admins"]["class"] = "logging.NullHandler"  # noqa
