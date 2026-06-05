import os
from fastapi import FastAPI

app = FastAPI(title="sample-fastapi")

APP_VERSION = os.getenv("APP_VERSION", "dev")


@app.get("/")
def root():
    return {"app": "sample-fastapi", "version": APP_VERSION}


@app.get("/healthz")
def healthz():
    return {"status": "ok"}
