from pretix.settings import *  # noqa

STORAGES = {
    **STORAGES,  # noqa
    "staticfiles": {
        "BACKEND": "django.contrib.staticfiles.storage.ManifestStaticFilesStorage",
    },
}

LOGGING["handlers"]["mail_admins"]["class"] = "logging.NullHandler"  # noqa
