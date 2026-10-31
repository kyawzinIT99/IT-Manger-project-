import modal
from fastapi import FastAPI
from fastapi.responses import HTMLResponse
from pathlib import Path

app = modal.App("northpoint-architecture-presentation")

dir_path = Path(__file__).parent
pres_file = dir_path / "northpoint-architecture-presentation.html"
subm_file = dir_path / "northpoint-submission.html"

image = (
    modal.Image.debian_slim()
    .pip_install("fastapi")
    .add_local_file(pres_file, remote_path="/root/northpoint-architecture-presentation.html")
    .add_local_file(subm_file, remote_path="/root/northpoint-submission.html")
)

web_app = FastAPI(title="Northpoint Living Architecture Presentation")

@web_app.get("/", response_class=HTMLResponse)
def presentation():
    content = Path("/root/northpoint-architecture-presentation.html").read_text(encoding="utf-8")
    return HTMLResponse(content=content)

@web_app.get("/presentation", response_class=HTMLResponse)
def presentation_alt():
    content = Path("/root/northpoint-architecture-presentation.html").read_text(encoding="utf-8")
    return HTMLResponse(content=content)

@web_app.get("/submission", response_class=HTMLResponse)
def submission():
    content = Path("/root/northpoint-submission.html").read_text(encoding="utf-8")
    return HTMLResponse(content=content)

@app.function(image=image)
@modal.asgi_app()
def serve():
    return web_app
