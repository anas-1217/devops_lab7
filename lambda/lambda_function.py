import base64
import json
import os
import time
import urllib.parse

import boto3

s3 = boto3.client("s3")
BUCKET = os.environ["BUCKET"]
PREFIX = os.environ.get("PREFIX", "site/").strip("/") + "/"
FUNCTION_NAME = os.environ.get("AWS_LAMBDA_FUNCTION_NAME", "unknown")


def response(status, body, content_type="text/html; charset=utf-8",
             headers=None, is_base64=False):
    result_headers = {"Content-Type": content_type}
    if headers:
        result_headers.update(headers)
    return {
        "statusCode": status,
        "headers": result_headers,
        "body": body,
        "isBase64Encoded": is_base64,
    }


def lambda_handler(event, context):
    started = time.time()
    path = "/"
    status = 500
    try:
        raw_path = event.get("rawPath")
        if not raw_path:
            raw_path = event.get("path", "/")
        path = urllib.parse.unquote(raw_path or "/")
        if path == "/":
            path = "/index.html"

        mapping = {
            "/index.html": ("index.html", "text/html; charset=utf-8"),
            "/style.css": ("style.css", "text/css; charset=utf-8"),
            "/cv.pdf": ("cv.pdf", "application/pdf"),
        }
        if path not in mapping:
            status = 404
            result = response(404, "<!doctype html><html><body><h1>404 Not Found</h1></body></html>")
        else:
            filename, content_type = mapping[path]
            obj = s3.get_object(Bucket=BUCKET, Key=PREFIX + filename)
            data = obj["Body"].read()
            if filename == "index.html":
                text = data.decode("utf-8")
                text = text.replace("{{HOSTED_ON}}", f"Lambda — {FUNCTION_NAME}")
                status = 200
                result = response(200, text, content_type,
                                  {"Cache-Control": "max-age=60"})
            elif filename == "style.css":
                status = 200
                result = response(200, data.decode("utf-8"), content_type)
            else:
                status = 200
                result = response(200, base64.b64encode(data).decode("ascii"),
                                  content_type, is_base64=True)
    except Exception:
        # Do not expose bucket names, AWS details, or exception text to visitors.
        status = 500
        result = response(500, "<!doctype html><html><body><h1>Internal Server Error</h1></body></html>")

    print(json.dumps({
        "fn": FUNCTION_NAME,
        "path": path,
        "status": status,
        "ms": round((time.time() - started) * 1000, 2),
    }))
    return result
