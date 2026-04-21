import json
import logging
import random
import time
import uuid

# ---------------------------------------------------------------------------
# Logger setup
# ---------------------------------------------------------------------------
# Lambda automatically creates a log stream in CloudWatch for each execution.
# We retrieve the root logger and set it to INFO so that INFO, WARNING,
# and ERROR messages are all captured (DEBUG would be too verbose).
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    """
    Lambda entry point.
    'event'   : the input payload (unused here, but always required).
    'context' : runtime metadata provided by Lambda (unused here).
    """

    # Unique ID to correlate all logs belonging to the same invocation.
    # Useful in Log Insights when you want to trace a single request end-to-end.
    request_id = str(uuid.uuid4())

    # Record the start time so we can calculate execution duration later.
    start_time = time.time()

    # ---------------------------------------------------------------------------
    # Simulate different outcomes
    # ---------------------------------------------------------------------------
    # In a real service you would not pick a scenario randomly — the actual
    # business logic would determine success/warning/error.
    # Here we fake it so each Lambda invocation produces a different log level,
    # giving us a varied dataset to explore in CloudWatch Log Insights.
    scenario = random.choice(["success", "warning", "error"])

    # Duration in milliseconds from start to just before we build the log entry.
    # In production this would wrap the actual work (DB call, HTTP request, …).
    duration = int((time.time() - start_time) * 1000)

    # ---------------------------------------------------------------------------
    # Structured JSON logging
    # ---------------------------------------------------------------------------
    # We log a plain Python dict serialised to a JSON string.
    # Why JSON?  CloudWatch Log Insights can parse JSON fields automatically,
    # letting you query on `filter level = "ERROR"` or `stats avg(duration_ms)`
    # without any manual parsing.  Free-text logs require expensive regex instead.
    #
    # Why json.dumps()?  When Lambda's logging_config is set to log_format = "JSON"
    # (see lambdas.tf), Lambda already wraps every log entry in its own JSON
    # envelope.  If we passed a raw dict to logger.info(), Python would convert it
    # to its string representation (e.g. "{'level': 'INFO', ...}") and embed that
    # string inside the envelope — breaking JSON structure.
    # json.dumps() produces a proper JSON string, which Log Insights can parse
    # as nested JSON inside the Lambda envelope.

    if scenario == "success":
        log = {
            "level": "INFO",
            "message": "Operation successful",
            "request_id": request_id,
            "duration_ms": duration,
            "service": "lab-03-log-insights"
        }
        logger.info(json.dumps(log))
        return {"status": "ok"}

    elif scenario == "warning":
        log = {
            "level": "WARNING",
            "message": "Slow response detected",
            "request_id": request_id,
            "duration_ms": duration,
            "service": "lab-03-log-insights"
        }
        logger.warning(json.dumps(log))
        return {"status": "warning"}

    else:
        log = {
            "level": "ERROR",
            "message": "External service timeout",
            "request_id": request_id,
            "error_code": "TIMEOUT",   # extra field only present on errors
            "duration_ms": duration,
            "service": "lab-03-log-insights"
        }
        logger.error(json.dumps(log))
        return {"status": "error"}
