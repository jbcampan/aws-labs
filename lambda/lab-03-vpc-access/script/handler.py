import json
import os
import pymysql


def lambda_handler(event, context):

    # ─────────────────────────────────────────────
    # 1. Connect to the RDS MySQL database
    #    Connection details come from environment variables
    #    defined in Terraform (DB_HOST, DB_USER, etc.)
    # ─────────────────────────────────────────────
    try:
        conn = pymysql.connect(
            host=os.environ["DB_HOST"],          # RDS endpoint
            user=os.environ["DB_USER"],          # MySQL username
            password=os.environ["DB_PASSWORD"],  # MySQL password
            database=os.environ["DB_NAME"],      # Target database
            port=int(os.environ["DB_PORT"]),     # MySQL port (3306)
            connect_timeout=5                    # Fail fast if unreachable
        )
    except pymysql.MySQLError as e:
        # If we can't connect, return a clear error instead of crashing.
        # Common causes in this lab:
        #   - RDS not yet fully started (wait ~5 min after terraform apply)
        #   - Security Group misconfiguration (Lambda SG not allowed in RDS SG)
        #   - Wrong DB_HOST / credentials in environment variables
        return {
            "statusCode": 500,
            "body": json.dumps({
                "error": "Could not connect to RDS",
                "detail": str(e)
            })
        }

    # ─────────────────────────────────────────────
    # 2. Execute a simple query
    #    We ask MySQL for its current server time.
    #    The cursor is the interface to run SQL commands.
    # ─────────────────────────────────────────────
    with conn.cursor() as cur:
        cur.execute("SELECT NOW()")
        result = cur.fetchone()

    # ─────────────────────────────────────────────
    # 3. Close the connection
    #    Important to free resources on the RDS side.
    #    (In production this is handled differently — see note below)
    # ─────────────────────────────────────────────
    conn.close()

    # ─────────────────────────────────────────────
    # 4. Return the Lambda response
    # ─────────────────────────────────────────────
    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "RDS connection successful",
            "mysql_time": str(result[0])
        })
    }

    # ── Production note (not needed in this lab) ──────────────────────────────
    # In production, you would NOT open and close a connection on every
    # invocation. Lambda reuses the same execution environment for warm calls,
    # so the connection can be stored in a global variable and reused.
    # This avoids the TCP/TLS handshake overhead on every request.
    # Under high load, each parallel Lambda instance holds its own connection,
    # which can exhaust RDS max_connections — that's where RDS Proxy comes in.