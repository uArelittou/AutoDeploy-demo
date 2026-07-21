from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator

app = FastAPI(title="demo-app")

VERSION = "v1"


@app.get("/")
def root():
    return {"name": "demo-app", "version": VERSION}


@app.get("/health")
def health():
    
    return {"status": "ok"}          
    
    # raise Exception("模拟坏版本：运行时才暴露的问题")  

 
# 在最后一行，把 /metrics 自动挂上
Instrumentator().instrument(app).expose(app)
