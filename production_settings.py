from pretix.settings import *  # noqa

# Insert whitenoise right after the first middleware to serve static files
MIDDLEWARE.insert(1, "whitenoise.middleware.WhiteNoiseMiddleware")  # noqa

STORAGES = {
    **STORAGES,  # noqa
    "staticfiles": {
        "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage",
    },
}

LOGGING["handlers"]["mail_admins"]["class"] = "logging.NullHandler"  # noqa
