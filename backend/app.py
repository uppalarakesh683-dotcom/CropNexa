import os
import csv
import json
import re
import random
import mimetypes
from datetime import datetime

from flask import Flask, jsonify, request, Response, send_from_directory
from flask_cors import CORS
from dotenv import load_dotenv

from google import genai
from google.genai import types

import mysql.connector
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename


# ============================================================
# ENVIRONMENT
# ============================================================

load_dotenv()


# ============================================================
# FLASK
# ============================================================

app = Flask(__name__)
CORS(app)

app.config["MAX_CONTENT_LENGTH"] = 8 * 1024 * 1024


# ============================================================
# GEMINI
# ============================================================

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

if not GEMINI_API_KEY:
    raise RuntimeError("GEMINI_API_KEY is missing from .env")

client = genai.Client(api_key=GEMINI_API_KEY)

CHAT_MODEL = os.getenv(
    "GEMINI_CHAT_MODEL",
    "gemini-3.6-flash",
)

CROP_DOCTOR_MODEL = os.getenv(
    "GEMINI_CROP_DOCTOR_MODEL",
    "gemini-3.6-flash",
)


# ============================================================
# MARKET CSV
# ============================================================

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

MARKET_CSV_PATH = os.path.join(
    BASE_DIR,
    "market_prices.csv",
)

CROP_DOCTOR_UPLOAD_DIR = os.path.join(
    BASE_DIR,
    "uploads",
    "crop_doctor",
)
os.makedirs(CROP_DOCTOR_UPLOAD_DIR, exist_ok=True)


# ============================================================
# MYSQL
# ============================================================

DB_HOST = os.getenv("DB_HOST")
DB_PORT = int(os.getenv("DB_PORT", "10864"))
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_NAME = os.getenv("DB_NAME", "defaultdb")


def get_db_connection():
    if not DB_HOST:
        raise RuntimeError("DB_HOST is missing from environment variables.")
    if not DB_USER:
        raise RuntimeError("DB_USER is missing from environment variables.")
    if not DB_PASSWORD:
        raise RuntimeError("DB_PASSWORD is missing from environment variables.")
    if not DB_NAME:
        raise RuntimeError("DB_NAME is missing from environment variables.")

    return mysql.connector.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        connection_timeout=20,
    )


# ============================================================
# DATABASE CONFIGURATION LOG
# ============================================================

print("CROPNEXA DATABASE HOST:", DB_HOST)
print("CROPNEXA DATABASE PORT:", DB_PORT)
print("CROPNEXA DATABASE NAME:", DB_NAME)
print("CROPNEXA CHAT MODEL:", CHAT_MODEL)
print("CROPNEXA CROP DOCTOR MODEL:", CROP_DOCTOR_MODEL)


# ============================================================
# DATABASE HELPERS
# ============================================================

def close_db(connection=None, cursor=None):

    try:
        if cursor is not None:
            cursor.close()
    except Exception:
        pass

    try:
        if connection is not None and connection.is_connected():
            connection.close()
    except Exception:
        pass


def user_exists(user_id):

    connection = None
    cursor = None

    try:

        connection = get_db_connection()
        cursor = connection.cursor()

        cursor.execute(
            """
            SELECT id
            FROM users
            WHERE id = %s
            """,
            (user_id,),
        )

        return cursor.fetchone() is not None

    except Exception:
        return False

    finally:
        close_db(connection, cursor)


# ============================================================
# AUTH DATABASE
# ============================================================

def init_auth_db():

    connection = None
    cursor = None

    try:

        connection = get_db_connection()
        cursor = connection.cursor()

        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS users (
                id INT AUTO_INCREMENT PRIMARY KEY,
                full_name VARCHAR(150) NOT NULL,
                identifier VARCHAR(150) NOT NULL UNIQUE,
                password_hash VARCHAR(255) NULL,
                auth_provider VARCHAR(50) DEFAULT 'local',
                reset_token VARCHAR(100) NULL,
                reset_token_expiry DATETIME NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP
            )
            ENGINE=InnoDB
            DEFAULT CHARSET=utf8mb4;
            """
        )

        connection.commit()

        print("AUTH DATABASE READY")

    except Exception as e:

        print(
            "AUTH DATABASE ERROR:",
            repr(e),
        )

    finally:

        close_db(connection, cursor)


# ============================================================
# CROP DOCTOR DATABASE
# ============================================================

def init_crop_doctor_db():

    connection = None
    cursor = None

    try:
        connection = get_db_connection()
        cursor = connection.cursor()

        # IMPORTANT:
        # This matches the existing crop_doctor_analyses table.
        # Existing tables are not altered by CREATE IF NOT EXISTS.
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS crop_doctor_analyses (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL,
                crop_type VARCHAR(100) NOT NULL,
                image_path VARCHAR(500) NOT NULL,
                diagnosis TEXT NULL,
                confidence DECIMAL(5,2) NULL,
                treatment TEXT NULL,
                prevention TEXT NULL,
                analysis_language VARCHAR(20) DEFAULT 'English',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_crop_doctor_user_created (user_id, created_at)
            )
            ENGINE=InnoDB
            DEFAULT CHARSET=utf8mb4;
            """
        )

        connection.commit()
        print("CROP DOCTOR DATABASE READY")

    except Exception as e:
        print("CROP DOCTOR DATABASE ERROR:", repr(e))

    finally:
        close_db(connection, cursor)


# ============================================================
# PASSWORD VALIDATION
# ============================================================

def validate_password(password):

    if not isinstance(password, str):
        return False, "Password must be text."

    if len(password) < 8:
        return False, "Password must contain at least 8 characters."

    if not re.search(r"[A-Z]", password):
        return False, "Password must contain an uppercase letter."

    if not re.search(r"[a-z]", password):
        return False, "Password must contain a lowercase letter."

    if not re.search(r"[0-9]", password):
        return False, "Password must contain a number."

    if not re.search(r"[^A-Za-z0-9\s]", password):
        return False, "Password must contain a special character."

    return True, ""


# ============================================================
# HOME
# ============================================================

@app.route("/", methods=["GET"])
def home():

    return jsonify({
        "success": True,
        "message": "CropNexa backend is running",
    })


# ============================================================
# DATABASE TEST
# ============================================================

@app.route("/api/database-test", methods=["GET"])
def database_test():

    connection = None
    cursor = None

    try:

        connection = get_db_connection()
        cursor = connection.cursor()

        cursor.execute("SELECT 1")

        result = cursor.fetchone()

        return jsonify({
            "success": True,
            "database": "connected",
            "result": result[0] if result else None,
        })

    except Exception as e:

        return jsonify({
            "success": False,
            "error": str(e),
        }), 500

    finally:

        close_db(connection, cursor)


# ============================================================
# REGISTER
# ============================================================

@app.route("/api/auth/register", methods=["POST"])
def register():

    connection = None
    cursor = None

    try:

        data = request.get_json(silent=True) or {}

        full_name = str(
            data.get("full_name", "")
        ).strip()

        identifier = str(
            data.get("identifier", "")
        ).strip()

        password = str(
            data.get("password", "")
        )

        confirm_password = str(
            data.get("confirm_password", "")
        )

        if not full_name:
            return jsonify({
                "success": False,
                "error": "Full name is required.",
            }), 400

        if not identifier:
            return jsonify({
                "success": False,
                "error": "Email or phone is required.",
            }), 400

        if not password:
            return jsonify({
                "success": False,
                "error": "Password is required.",
            }), 400

        if password != confirm_password:
            return jsonify({
                "success": False,
                "error": "Passwords do not match.",
            }), 400

        valid, password_error = validate_password(password)

        if not valid:
            return jsonify({
                "success": False,
                "error": password_error,
            }), 400

        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT id
            FROM users
            WHERE identifier = %s
            """,
            (identifier,),
        )

        existing_user = cursor.fetchone()

        if existing_user:
            return jsonify({
                "success": False,
                "error":
                    "An account with this email or phone already exists.",
            }), 409

        password_hash = generate_password_hash(password)

        cursor.execute(
            """
            INSERT INTO users
            (
                full_name,
                identifier,
                password_hash,
                auth_provider
            )
            VALUES (%s, %s, %s, %s)
            """,
            (
                full_name,
                identifier,
                password_hash,
                "local",
            ),
        )

        connection.commit()

        user_id = cursor.lastrowid

        return jsonify({
            "success": True,
            "message": "Account created successfully.",
            "user": {
                "id": user_id,
                "full_name": full_name,
                "identifier": identifier,
                "auth_provider": "local",
            },
        }), 201

    except mysql.connector.IntegrityError:

        if connection:
            connection.rollback()

        return jsonify({
            "success": False,
            "error":
                "An account with this email or phone already exists.",
        }), 409

    except Exception as e:

        if connection:
            connection.rollback()

        return jsonify({
            "success": False,
            "error": str(e),
        }), 500

    finally:

        close_db(connection, cursor)


# ============================================================
# LOGIN
# ============================================================

@app.route("/api/auth/login", methods=["POST"])
def login():

    connection = None
    cursor = None

    try:

        data = request.get_json(silent=True) or {}

        identifier = str(
            data.get("identifier", "")
        ).strip()

        password = str(
            data.get("password", "")
        )

        if not identifier or not password:
            return jsonify({
                "success": False,
                "error":
                    "Email/phone and password are required.",
            }), 400

        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT
                id,
                full_name,
                identifier,
                password_hash,
                auth_provider
            FROM users
            WHERE identifier = %s
            """,
            (identifier,),
        )

        user = cursor.fetchone()

        if not user:
            return jsonify({
                "success": False,
                "error":
                    "Invalid email/phone or password.",
            }), 401

        if not user["password_hash"]:
            return jsonify({
                "success": False,
                "error":
                    "This account uses Google sign-in.",
            }), 401

        if not check_password_hash(
            user["password_hash"],
            password,
        ):
            return jsonify({
                "success": False,
                "error":
                    "Invalid email/phone or password.",
            }), 401

        return jsonify({
            "success": True,
            "message": "Login successful.",
            "user": {
                "id": user["id"],
                "full_name": user["full_name"],
                "identifier": user["identifier"],
                "auth_provider": user["auth_provider"],
            },
        })

    except Exception as e:

        return jsonify({
            "success": False,
            "error": str(e),
        }), 500

    finally:

        close_db(connection, cursor)


# ============================================================
# GOOGLE LOGIN
# ============================================================

@app.route("/api/auth/google", methods=["POST"])
def google_login():

    connection = None
    cursor = None

    try:

        data = request.get_json(silent=True) or {}

        email = str(
            data.get("email", "")
        ).strip()

        full_name = str(
            data.get("full_name", "")
        ).strip()

        if not email:
            return jsonify({
                "success": False,
                "error": "Google email is required.",
            }), 400

        if not full_name:
            full_name = email.split("@")[0]

        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT
                id,
                full_name,
                identifier,
                auth_provider
            FROM users
            WHERE identifier = %s
            """,
            (email,),
        )

        user = cursor.fetchone()

        if user:

            return jsonify({
                "success": True,
                "message": "Google login successful.",
                "user": {
                    "id": user["id"],
                    "full_name": user["full_name"],
                    "identifier": user["identifier"],
                    "auth_provider": user["auth_provider"],
                },
            })

        cursor.execute(
            """
            INSERT INTO users
            (
                full_name,
                identifier,
                password_hash,
                auth_provider
            )
            VALUES (%s, %s, NULL, %s)
            """,
            (
                full_name,
                email,
                "google",
            ),
        )

        connection.commit()

        user_id = cursor.lastrowid

        return jsonify({
            "success": True,
            "message": "Google account created.",
            "user": {
                "id": user_id,
                "full_name": full_name,
                "identifier": email,
                "auth_provider": "google",
            },
        }), 201

    except mysql.connector.IntegrityError:

        if connection:
            connection.rollback()

        return jsonify({
            "success": False,
            "error": "Google account already exists.",
        }), 409

    except Exception as e:

        if connection:
            connection.rollback()

        return jsonify({
            "success": False,
            "error": str(e),
        }), 500

    finally:

        close_db(connection, cursor)


# ============================================================
# FORGOT PASSWORD
# ============================================================

@app.route("/api/auth/forgot-password", methods=["POST"])
def forgot_password():

    connection = None
    cursor = None

    try:

        data = request.get_json(silent=True) or {}

        identifier = str(
            data.get("identifier", "")
        ).strip()

        if not identifier:
            return jsonify({
                "success": False,
                "error": "Email or phone is required.",
            }), 400

        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT id
            FROM users
            WHERE identifier = %s
            """,
            (identifier,),
        )

        user = cursor.fetchone()

        if not user:
            return jsonify({
                "success": False,
                "error":
                    "No account found with this email or phone.",
            }), 404

        reset_token = str(
            random.randint(100000, 999999)
        )

        cursor.execute(
            """
            UPDATE users
            SET
                reset_token = %s,
                reset_token_expiry =
                    DATE_ADD(NOW(), INTERVAL 15 MINUTE)
            WHERE id = %s
            """,
            (
                reset_token,
                user["id"],
            ),
        )

        connection.commit()

        return jsonify({
            "success": True,
            "message": "Password reset code generated.",
            "code_hint": reset_token,
        })

    except Exception as e:

        if connection:
            connection.rollback()

        return jsonify({
            "success": False,
            "error": str(e),
        }), 500

    finally:

        close_db(connection, cursor)


# ============================================================
# RESET PASSWORD
# ============================================================

@app.route("/api/auth/reset-password", methods=["POST"])
def reset_password():

    connection = None
    cursor = None

    try:

        data = request.get_json(silent=True) or {}

        identifier = str(
            data.get("identifier", "")
        ).strip()

        token = str(
            data.get("token", "")
        ).strip()

        new_password = str(
            data.get("new_password", "")
        )

        if not identifier or not token or not new_password:
            return jsonify({
                "success": False,
                "error":
                    "Identifier, reset code and new password are required.",
            }), 400

        valid, password_error = validate_password(
            new_password
        )

        if not valid:
            return jsonify({
                "success": False,
                "error": password_error,
            }), 400

        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT
                id,
                reset_token,
                reset_token_expiry
            FROM users
            WHERE identifier = %s
            """,
            (identifier,),
        )

        user = cursor.fetchone()

        if not user:
            return jsonify({
                "success": False,
                "error": "Account not found.",
            }), 404

        if user["reset_token"] != token:
            return jsonify({
                "success": False,
                "error": "Invalid reset code.",
            }), 400

        if (
            user["reset_token_expiry"] is None
            or user["reset_token_expiry"] < datetime.now()
        ):
            return jsonify({
                "success": False,
                "error": "Reset code has expired.",
            }), 400

        password_hash = generate_password_hash(
            new_password
        )

        cursor.execute(
            """
            UPDATE users
            SET
                password_hash = %s,
                auth_provider = 'local',
                reset_token = NULL,
                reset_token_expiry = NULL
            WHERE id = %s
            """,
            (
                password_hash,
                user["id"],
            ),
        )

        connection.commit()

        return jsonify({
            "success": True,
            "message": "Password reset successfully.",
        })

    except Exception as e:

        if connection:
            connection.rollback()

        return jsonify({
            "success": False,
            "error": str(e),
        }), 500

    finally:

        close_db(connection, cursor)


# ============================================================
# CREATE CONVERSATION
# ============================================================

@app.route("/api/conversations", methods=["POST"])
def create_conversation():

    connection = None
    cursor = None

    try:

        data = request.get_json(silent=True) or {}

        user_id = data.get("user_id")

        title = str(
            data.get(
                "title",
                "New Conversation",
            )
            or "New Conversation"
        ).strip()

        if not user_id:
            return jsonify({
                "success": False,
                "error": "user_id is required.",
            }), 400

        try:
            user_id = int(user_id)
        except Exception:
            return jsonify({
                "success": False,
                "error": "Invalid user_id.",
            }), 400

        if not user_exists(user_id):
            return jsonify({
                "success": False,
                "error": "User not found.",
            }), 404

        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute(
            """
            INSERT INTO conversations
            (
                user_id,
                title
            )
            VALUES
            (
                %s,
                %s
            )
            """,
            (
                user_id,
                title,
            ),
        )

        connection.commit()

        conversation_id = cursor.lastrowid

        return jsonify({
            "success": True,
            "conversation": {
                "id": conversation_id,
                "user_id": user_id,
                "title": title,
            },
        }), 201

    except Exception as e:

        if connection:
            connection.rollback()

        print(
            "CREATE CONVERSATION ERROR:",
            repr(e),
        )

        return jsonify({
            "success": False,
            "error": str(e),
        }), 500

    finally:

        close_db(connection, cursor)


# ============================================================
# GET CONVERSATIONS
# ============================================================

@app.route("/api/conversations", methods=["GET"])
def get_conversations():

    connection = None
    cursor = None

    try:

        user_id = request.args.get(
            "user_id",
            "",
        ).strip()

        if not user_id:
            return jsonify({
                "success": False,
                "error": "user_id is required.",
            }), 400

        try:
            user_id = int(user_id)
        except Exception:
            return jsonify({
                "success": False,
                "error": "Invalid user_id.",
            }), 400

        if not user_exists(user_id):
            return jsonify({
                "success": False,
                "error": "User does not exist.",
            }), 404

        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT
                id,
                user_id,
                title,
                created_at
            FROM conversations
            WHERE user_id = %s
            ORDER BY created_at DESC
            """,
            (user_id,),
        )

        conversations = cursor.fetchall()

        for conversation in conversations:

            if conversation.get("created_at"):
                conversation["created_at"] = (
                    conversation["created_at"].isoformat()
                )

        return jsonify({
            "success": True,
            "conversations": conversations,
        }), 200

    except Exception as e:

        print(
            "GET CONVERSATIONS ERROR:",
            repr(e),
        )

        return jsonify({
            "success": False,
            "error": str(e),
        }), 500

    finally:

        close_db(connection, cursor)


# ============================================================
# GET SINGLE CONVERSATION
# ============================================================

@app.route(
    "/api/conversations/<int:conversation_id>",
    methods=["GET"],
)
def get_conversation(conversation_id):

    connection = None
    cursor = None

    try:

        user_id = request.args.get(
            "user_id",
            "",
        ).strip()

        if not user_id:
            return jsonify({
                "success": False,
                "error": "user_id is required.",
            }), 400

        try:
            user_id = int(user_id)
        except Exception:
            return jsonify({
                "success": False,
                "error": "Invalid user_id.",
            }), 400

        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT
                id,
                user_id,
                title,
                created_at
            FROM conversations
            WHERE id = %s
              AND user_id = %s
            """,
            (
                conversation_id,
                user_id,
            ),
        )

        conversation = cursor.fetchone()

        if not conversation:
            return jsonify({
                "success": False,
                "error": "Conversation not found.",
            }), 404

        if conversation.get("created_at"):
            conversation["created_at"] = (
                conversation["created_at"].isoformat()
            )

        # IMPORTANT:
        # Actual database columns are:
        # sender
        # message
        #
        # We map them back to:
        # role
        # content
        #
        # so the existing Flutter frontend can continue
        # using role/content.

        cursor.execute(
            """
            SELECT
                id,
                conversation_id,
                sender,
                message,
                created_at
            FROM messages
            WHERE conversation_id = %s
            ORDER BY created_at ASC
            """,
            (conversation_id,),
        )

        messages = cursor.fetchall()

        for message_row in messages:

            if message_row.get("created_at"):
                message_row["created_at"] = (
                    message_row["created_at"].isoformat()
                )

            message_row["role"] = message_row.pop(
                "sender"
            )

            message_row["content"] = message_row.pop(
                "message"
            )

        conversation["messages"] = messages

        return jsonify({
            "success": True,
            "conversation": conversation,
        }), 200

    except Exception as e:

        print(
            "GET CONVERSATION ERROR:",
            repr(e),
        )

        return jsonify({
            "success": False,
            "error": str(e),
        }), 500

    finally:

        close_db(connection, cursor)


# ============================================================
# DELETE CONVERSATION
# ============================================================

@app.route(
    "/api/conversations/<int:conversation_id>",
    methods=["DELETE"],
)
def delete_conversation(conversation_id):

    connection = None
    cursor = None

    try:

        user_id = request.args.get(
            "user_id",
            "",
        ).strip()

        if not user_id:
            return jsonify({
                "success": False,
                "error": "user_id is required.",
            }), 400

        try:
            user_id = int(user_id)
        except Exception:
            return jsonify({
                "success": False,
                "error": "Invalid user_id.",
            }), 400

        connection = get_db_connection()
        cursor = connection.cursor()

        cursor.execute(
            """
            SELECT id
            FROM conversations
            WHERE id = %s
              AND user_id = %s
            """,
            (
                conversation_id,
                user_id,
            ),
        )

        conversation = cursor.fetchone()

        if not conversation:
            return jsonify({
                "success": False,
                "error": "Conversation not found.",
            }), 404

        cursor.execute(
            """
            DELETE FROM messages
            WHERE conversation_id = %s
            """,
            (conversation_id,),
        )

        cursor.execute(
            """
            DELETE FROM conversations
            WHERE id = %s
              AND user_id = %s
            """,
            (
                conversation_id,
                user_id,
            ),
        )

        connection.commit()

        return jsonify({
            "success": True,
            "message": "Conversation deleted successfully.",
        }), 200

    except Exception as e:

        if connection:
            connection.rollback()

        print(
            "DELETE CONVERSATION ERROR:",
            repr(e),
        )

        return jsonify({
            "success": False,
            "error": str(e),
        }), 500

    finally:

        close_db(connection, cursor)


# ============================================================
# AI CHAT
# ============================================================

@app.route("/api/chat", methods=["POST"])
def chat():

    connection = None
    cursor = None

    try:

        data = request.get_json(silent=True) or {}

        message = str(
            data.get("message", "")
        ).strip()

        user_id = data.get("user_id")

        conversation_id = data.get(
            "conversation_id"
        )

        if not message:
            return jsonify({
                "success": False,
                "error": "Message is required.",
            }), 400

        if not user_id:
            return jsonify({
                "success": False,
                "error": "user_id is required.",
            }), 400

        try:
            user_id = int(user_id)
        except Exception:
            return jsonify({
                "success": False,
                "error": "Invalid user_id.",
            }), 400

        if not user_exists(user_id):
            return jsonify({
                "success": False,
                "error": "User does not exist.",
            }), 404

        if not conversation_id:

            connection = get_db_connection()
            cursor = connection.cursor()

            cursor.execute(
                """
                INSERT INTO conversations
                (
                    user_id,
                    title
                )
                VALUES
                (
                    %s,
                    %s
                )
                """,
                (
                    user_id,
                    message[:100],
                ),
            )

            connection.commit()

            conversation_id = cursor.lastrowid

            close_db(
                connection,
                cursor,
            )

            connection = None
            cursor = None

        connection = get_db_connection()
        cursor = connection.cursor()

        cursor.execute(
            """
            SELECT id
            FROM conversations
            WHERE id = %s
              AND user_id = %s
            """,
            (
                conversation_id,
                user_id,
            ),
        )

        if not cursor.fetchone():
            return jsonify({
                "success": False,
                "error":
                    "Conversation does not belong to this user.",
            }), 403

        # ====================================================
        # FIX:
        # Actual messages table uses sender/message,
        # NOT role/content.
        # ====================================================

        cursor.execute(
            """
            INSERT INTO messages
            (
                conversation_id,
                sender,
                message
            )
            VALUES
            (
                %s,
                %s,
                %s
            )
            """,
            (
                conversation_id,
                "user",
                message,
            ),
        )

        connection.commit()

        # ====================================================
        # GEMINI WITH RECENT CHAT HISTORY
        # ====================================================

        cursor.execute(
            """
            SELECT sender, message
            FROM messages
            WHERE conversation_id = %s
            ORDER BY created_at DESC, id DESC
            LIMIT 12
            """,
            (conversation_id,),
        )
        recent_rows = cursor.fetchall()
        recent_rows.reverse()

        chat_contents = [
            "You are CropNexa AI Farm Assistant. Give practical, farmer-friendly answers. Keep continuity with the recent conversation. If the user speaks Telugu, respond naturally in Telugu; if English, respond in English. Do not invent farm facts that are not provided."
        ]

        for row in recent_rows:
            sender = row[0]
            text = row[1]
            label = "Farmer" if sender == "user" else "CropNexa AI"
            chat_contents.append(f"{label}: {text}")

        response = client.models.generate_content(
            model=CHAT_MODEL,
            contents="\n".join(chat_contents),
        )

        ai_reply = response.text

        if not ai_reply:
            ai_reply = "I could not generate a response."

        # ====================================================
        # SAVE AI RESPONSE
        # ====================================================

        cursor.execute(
            """
            INSERT INTO messages
            (
                conversation_id,
                sender,
                message
            )
            VALUES
            (
                %s,
                %s,
                %s
            )
            """,
            (
                conversation_id,
                "assistant",
                ai_reply,
            ),
        )

        connection.commit()

        return jsonify({
            "success": True,
            "conversation_id": conversation_id,
            "reply": ai_reply,
        })

    except Exception as e:

        if connection:
            connection.rollback()

        print(
            "CHAT ERROR:",
            repr(e),
        )

        return jsonify({
            "success": False,
            "error": str(e),
        }), 500

    finally:

        close_db(connection, cursor)


# ============================================================
# MARKET PRICES
# ============================================================

@app.route(
    "/api/market-prices",
    methods=["GET"],
)
def market_prices():

    try:

        state_filter = request.args.get(
            "state",
            "",
        ).strip().lower()

        district_filter = request.args.get(
            "district",
            "",
        ).strip().lower()

        crop_filter = request.args.get(
            "crop",
            "",
        ).strip().lower()

        market_filter = request.args.get(
            "market",
            "",
        ).strip().lower()

        if not os.path.exists(MARKET_CSV_PATH):
            return jsonify({
                "success": False,
                "error": "market_prices.csv not found.",
            }), 404

        rows = []

        with open(
            MARKET_CSV_PATH,
            "r",
            encoding="utf-8-sig",
        ) as file:

            reader = csv.DictReader(file)

            for row in reader:

                state = str(
                    row.get("State", "")
                ).strip()

                district = str(
                    row.get("District", "")
                ).strip()

                commodity = str(
                    row.get(
                        "Commodity",
                        row.get("Crop", ""),
                    )
                ).strip()

                market = str(
                    row.get("Market", "")
                ).strip()

                if state_filter and (
                    state_filter not in state.lower()
                ):
                    continue

                if district_filter and (
                    district_filter not in district.lower()
                ):
                    continue

                if crop_filter and (
                    crop_filter not in commodity.lower()
                ):
                    continue

                if market_filter and (
                    market_filter not in market.lower()
                ):
                    continue

                rows.append(row)

        return jsonify({
            "success": True,
            "count": len(rows),
            "latest_data_date":
                rows[0].get("Arrival_Date")
                if rows
                else None,
            "data": rows,
        })

    except Exception as e:

        return jsonify({
            "success": False,
            "error": str(e),
        }), 500


# ============================================================
# CREATE FARM
# ============================================================

@app.route("/api/farms", methods=["POST"])
def create_farm():

    connection = None
    cursor = None

    try:

        data = request.get_json(silent=True) or {}

        user_id = data.get("user_id")

        farm_name = str(
            data.get(
                "farm_name",
                data.get("name", ""),
            )
        ).strip()

        location = str(
            data.get(
                "location",
                "",
            )
        ).strip()

        main_crop = str(
            data.get(
                "main_crop",
                data.get("crop_type", ""),
            )
        ).strip()

        irrigation = str(
            data.get(
                "irrigation",
                "",
            )
        ).strip()

        area = data.get("area")

        area_unit = str(
            data.get(
                "area_unit",
                "acre",
            )
        ).strip()

        description = str(
            data.get(
                "description",
                "",
            )
        ).strip()

        if not user_id:
            return jsonify({
                "success": False,
                "error": "user_id is required.",
            }), 400

        try:
            user_id = int(user_id)
        except Exception:
            return jsonify({
                "success": False,
                "error": "Invalid user_id.",
            }), 400

        if not user_exists(user_id):
            return jsonify({
                "success": False,
                "error": "User does not exist.",
            }), 404

        if not farm_name:
            return jsonify({
                "success": False,
                "error": "Farm name is required.",
            }), 400

        if not location:
            return jsonify({
                "success": False,
                "error": "Farm location is required.",
            }), 400

        if not main_crop:
            return jsonify({
                "success": False,
                "error": "Main crop is required.",
            }), 400

        if area is None or str(area).strip() == "":
            return jsonify({
                "success": False,
                "error": "Farm area is required.",
            }), 400

        connection = get_db_connection()
        cursor = connection.cursor()

        cursor.execute(
            """
            INSERT INTO farms
            (
                user_id,
                farm_name,
                main_crop,
                location,
                irrigation,
                area,
                area_unit,
                description
            )
            VALUES
            (
                %s,
                %s,
                %s,
                %s,
                %s,
                %s,
                %s,
                %s
            )
            """,
            (
                user_id,
                farm_name,
                main_crop,
                location,
                irrigation,
                area,
                area_unit,
                description,
            ),
        )

        connection.commit()

        farm_id = cursor.lastrowid

        return jsonify({
            "success": True,
            "farm": {
                "id": farm_id,
                "user_id": user_id,
                "farm_name": farm_name,
                "name": farm_name,
                "main_crop": main_crop,
                "crop_type": main_crop,
                "location": location,
                "irrigation": irrigation,
                "area": area,
                "area_unit": area_unit,
                "description": description,
            },
        }), 201

    except Exception as e:

        if connection:
            connection.rollback()

        print(
            "CREATE FARM ERROR:",
            repr(e),
        )

        return jsonify({
            "success": False,
            "error": str(e),
        }), 500

    finally:

        close_db(connection, cursor)


# ============================================================
# GET FARMS
# ============================================================

@app.route("/api/farms", methods=["GET"])
def get_farms():

    connection = None
    cursor = None

    try:

        user_id = request.args.get(
            "user_id",
            "",
        ).strip()

        if not user_id:
            return jsonify({
                "success": False,
                "error": "user_id is required.",
            }), 400

        try:
            user_id = int(user_id)
        except Exception:
            return jsonify({
                "success": False,
                "error": "Invalid user_id.",
            }), 400

        if not user_exists(user_id):
            return jsonify({
                "success": False,
                "error": "User does not exist.",
            }), 404

        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT
                id,
                user_id,
                farm_name,
                main_crop,
                location,
                irrigation,
                area,
                area_unit,
                description,
                created_at,
                updated_at
            FROM farms
            WHERE user_id = %s
            ORDER BY id DESC
            """,
            (user_id,),
        )

        farms = cursor.fetchall()

        for farm in farms:

            farm["name"] = farm["farm_name"]
            farm["crop_type"] = farm["main_crop"]

            if farm.get("area") is not None:
                farm["area"] = float(
                    farm["area"]
                )

            if farm.get("created_at"):
                farm["created_at"] = (
                    farm["created_at"].isoformat()
                )

            if farm.get("updated_at"):
                farm["updated_at"] = (
                    farm["updated_at"].isoformat()
                )

        return jsonify({
            "success": True,
            "farms": farms,
        })

    except Exception as e:

        print(
            "GET FARMS ERROR:",
            repr(e),
        )

        return jsonify({
            "success": False,
            "error": str(e),
        }), 500

    finally:

        close_db(connection, cursor)


# ============================================================
# CREATE CROP
# ============================================================

@app.route("/api/crops", methods=["POST"])
def create_crop():

    connection = None
    cursor = None

    try:

        data = request.get_json(silent=True) or {}

        user_id = data.get("user_id")
        farm_id = data.get("farm_id")

        crop_name = str(
            data.get(
                "crop_name",
                "",
            )
        ).strip()

        variety = str(
            data.get(
                "variety",
                "",
            )
        ).strip()

        area = data.get("area")

        sowing_date = data.get(
            "sowing_date"
        )

        if not user_id or not farm_id:
            return jsonify({
                "success": False,
                "error":
                    "user_id and farm_id are required.",
            }), 400

        try:
            user_id = int(user_id)
            farm_id = int(farm_id)
        except Exception:
            return jsonify({
                "success": False,
                "error": "Invalid user_id or farm_id.",
            }), 400

        if not user_exists(user_id):
            return jsonify({
                "success": False,
                "error": "User does not exist.",
            }), 404

        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT id
            FROM farms
            WHERE id = %s
              AND user_id = %s
            """,
            (
                farm_id,
                user_id,
            ),
        )

        farm = cursor.fetchone()

        if not farm:
            return jsonify({
                "success": False,
                "error":
                    "Farm does not belong to this user.",
            }), 403

        cursor.execute(
            """
            INSERT INTO crops
            (
                user_id,
                farm_id,
                crop_name,
                variety,
                area,
                sowing_date
            )
            VALUES
            (
                %s,
                %s,
                %s,
                %s,
                %s,
                %s
            )
            """,
            (
                user_id,
                farm_id,
                crop_name,
                variety,
                area,
                sowing_date,
            ),
        )

        connection.commit()

        crop_id = cursor.lastrowid

        return jsonify({
            "success": True,
            "crop": {
                "id": crop_id,
                "user_id": user_id,
                "farm_id": farm_id,
                "crop_name": crop_name,
                "variety": variety,
                "area": area,
                "sowing_date": sowing_date,
            },
        }), 201

    except Exception as e:

        if connection:
            connection.rollback()

        return jsonify({
            "success": False,
            "error": str(e),
        }), 500

    finally:

        close_db(connection, cursor)


# ============================================================
# GET CROPS
# ============================================================

@app.route("/api/crops", methods=["GET"])
def get_crops():

    connection = None
    cursor = None

    try:

        user_id = request.args.get(
            "user_id"
        )

        farm_id = request.args.get(
            "farm_id"
        )

        if not user_id or not farm_id:
            return jsonify({
                "success": False,
                "error":
                    "user_id and farm_id are required.",
            }), 400

        try:
            user_id = int(user_id)
            farm_id = int(farm_id)
        except Exception:
            return jsonify({
                "success": False,
                "error": "Invalid user_id or farm_id.",
            }), 400

        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT
                id,
                user_id,
                farm_id,
                crop_name,
                variety,
                area,
                sowing_date,
                created_at
            FROM crops
            WHERE user_id = %s
              AND farm_id = %s
            ORDER BY id DESC
            """,
            (
                user_id,
                farm_id,
            ),
        )

        crops = cursor.fetchall()

        for crop in crops:

            if crop.get("area") is not None:
                crop["area"] = float(
                    crop["area"]
                )

            if crop.get("sowing_date"):
                crop["sowing_date"] = str(
                    crop["sowing_date"]
                )

            if crop.get("created_at"):
                crop["created_at"] = (
                    crop["created_at"].isoformat()
                )

        return jsonify({
            "success": True,
            "crops": crops,
        })

    except Exception as e:

        return jsonify({
            "success": False,
            "error": str(e),
        }), 500

    finally:

        close_db(connection, cursor)


# ============================================================
# CROP DOCTOR HELPERS
# ============================================================

ALLOWED_IMAGE_MIME_TYPES = {
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/heic",
    "image/heif",
}


def get_image_mime_type(uploaded_file):

    mime_type = (
        uploaded_file.mimetype or ""
    ).lower().strip()

    if mime_type in ALLOWED_IMAGE_MIME_TYPES:
        return mime_type

    guessed_type = mimetypes.guess_type(
        uploaded_file.filename or ""
    )[0]

    if guessed_type:
        guessed_type = guessed_type.lower()

    if guessed_type in ALLOWED_IMAGE_MIME_TYPES:
        return guessed_type

    return None


def extract_json_from_ai(text):

    if not text:
        raise ValueError(
            "Gemini returned an empty response."
        )

    cleaned = text.strip()

    if cleaned.startswith("```"):

        cleaned = re.sub(
            r"^```(?:json)?",
            "",
            cleaned,
            flags=re.IGNORECASE,
        )

        cleaned = re.sub(
            r"```$",
            "",
            cleaned,
        ).strip()

    try:
        return json.loads(cleaned)

    except json.JSONDecodeError:
        pass

    start = cleaned.find("{")
    end = cleaned.rfind("}")

    if start == -1 or end == -1 or end <= start:
        raise ValueError(
            "Gemini did not return valid JSON."
        )

    possible_json = cleaned[
        start:end + 1
    ]

    return json.loads(
        possible_json
    )


def normalize_list(value):

    if value is None:
        return []

    if isinstance(value, list):

        return [
            str(item).strip()
            for item in value
            if str(item).strip()
        ]

    if isinstance(value, str):

        text = value.strip()

        if not text:
            return []

        lines = [
            line.strip(" -*•\t")
            for line in text.splitlines()
        ]

        lines = [
            line
            for line in lines
            if line
        ]

        if lines:
            return lines

        return [text]

    return [
        str(value).strip()
    ]


def safe_confidence(value):

    if value is None:
        return None

    try:
        confidence = float(value)
    except Exception:
        return None

    if confidence < 0:
        confidence = 0

    if confidence > 100:
        confidence = 100

    return round(
        confidence,
        2,
    )


def serialize_datetime(value):

    if isinstance(value, datetime):
        return value.isoformat()

    return value


def build_crop_doctor_response(row, include_raw=False):

    treatment = normalize_list(row.get("treatment"))
    prevention = normalize_list(row.get("prevention"))
    diagnosis = row.get("diagnosis") or "No diagnosis available."

    result = {
        "id": row.get("id"),
        "user_id": row.get("user_id"),
        "crop_type": row.get("crop_type"),
        "diagnosis": diagnosis,
        "confidence": (
            float(row["confidence"])
            if row.get("confidence") is not None
            else None
        ),
        # These fields are returned for Flutter compatibility.
        # They are not database columns in the current schema.
        "severity": "unknown",
        "symptoms": [],
        "treatment": treatment,
        "prevention": prevention,
        "english_result": diagnosis,
        "telugu_result": diagnosis,
        "image_path": row.get("image_path"),
        "created_at": serialize_datetime(row.get("created_at")),
    }

    if include_raw:
        result["ai_raw_response"] = row.get("ai_raw_response")

    return result


# ============================================================
# AI CROP DOCTOR ANALYZE
# ============================================================

@app.route(
    "/api/crop-doctor/analyze",
    methods=["POST"],
)
def crop_doctor_analyze():

    connection = None
    cursor = None

    try:
        user_id = request.form.get("user_id", "").strip()
        crop_type = request.form.get("crop_type", "").strip()
        image_file = request.files.get("image")

        if not user_id:
            return jsonify({"success": False, "error": "user_id is required."}), 400

        try:
            user_id = int(user_id)
        except ValueError:
            return jsonify({"success": False, "error": "Invalid user_id."}), 400

        if not user_exists(user_id):
            return jsonify({"success": False, "error": "User does not exist."}), 404

        if not crop_type:
            return jsonify({"success": False, "error": "crop_type is required."}), 400

        if image_file is None or not image_file.filename:
            return jsonify({"success": False, "error": "Crop image is required."}), 400

        mime_type = get_image_mime_type(image_file)
        if not mime_type:
            return jsonify({
                "success": False,
                "error": "Unsupported image type. Use JPEG, PNG, WebP, HEIC or HEIF.",
            }), 400

        image_bytes = image_file.read()
        if not image_bytes:
            return jsonify({"success": False, "error": "The uploaded image is empty."}), 400

        if len(image_bytes) > 8 * 1024 * 1024:
            return jsonify({"success": False, "error": "Image is larger than 8 MB."}), 413

        original_name = secure_filename(image_file.filename) or "crop_image"
        extension = os.path.splitext(original_name)[1].lower()
        if not extension:
            extension = mimetypes.guess_extension(mime_type) or ".jpg"

        unique_name = f"{user_id}_{int(datetime.now().timestamp() * 1000)}_{random.randint(1000, 9999)}{extension}"
        image_path = os.path.join(CROP_DOCTOR_UPLOAD_DIR, unique_name)

        with open(image_path, "wb") as image_out:
            image_out.write(image_bytes)

        prompt = f"""
You are CropNexa AI Crop Doctor.

Analyze the uploaded plant/crop image together with the farmer-provided crop type.

Farmer-provided crop type:
{crop_type}

Rules:
1. Analyze only what can reasonably be determined from the image.
2. Do not invent symptoms, diseases, pests or visual findings.
3. If the image is unclear, blurry, too dark, or not a recognizable crop/plant, say it cannot be reliably analyzed.
4. Do not claim certainty when the image is ambiguous.
5. Confidence must represent visual-analysis confidence from 0 to 100.
6. If the plant appears healthy, say so instead of inventing a disease.
7. Treatment and prevention must correspond to the identified problem.
8. Do not invent exact pesticide doses or chemical schedules.
9. Give practical farmer-friendly advice.
10. Generate both English and Telugu explanations.
11. Return ONLY valid JSON.

Return exactly:
{{
  "is_crop_image": true,
  "crop": "{crop_type}",
  "diagnosis": "most likely diagnosis or clearly stated inability to diagnose",
  "confidence": 0,
  "severity": "low, moderate, high, healthy, or unknown",
  "symptoms": [],
  "treatment": [],
  "prevention": [],
  "english_result": "clear farmer-friendly English explanation",
  "telugu_result": "స్పష్టమైన రైతు స్నేహపూర్వక తెలుగు వివరణ"
}}
"""

        image_part = types.Part.from_bytes(
            data=image_bytes,
            mime_type=mime_type,
        )

        response = client.models.generate_content(
            model=CROP_DOCTOR_MODEL,
            contents=[image_part, prompt],
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
            ),
        )

        raw_response = response.text or ""
        ai_data = extract_json_from_ai(raw_response)

        is_crop_image = bool(ai_data.get("is_crop_image", False))
        diagnosis = str(ai_data.get("diagnosis", "")).strip()
        confidence = safe_confidence(ai_data.get("confidence"))
        treatment = normalize_list(ai_data.get("treatment"))
        prevention = normalize_list(ai_data.get("prevention"))
        english_result = str(ai_data.get("english_result", "")).strip()
        telugu_result = str(ai_data.get("telugu_result", "")).strip()

        if not diagnosis:
            raise ValueError("Gemini returned no diagnosis.")
        if not english_result:
            english_result = diagnosis
        if not telugu_result:
            telugu_result = english_result

        # The current MySQL table stores treatment/prevention as TEXT,
        # so JSON is used to preserve multiple items safely.
        treatment_text = json.dumps(treatment, ensure_ascii=False)
        prevention_text = json.dumps(prevention, ensure_ascii=False)

        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute(
            """
            INSERT INTO crop_doctor_analyses
            (
                user_id,
                crop_type,
                image_path,
                diagnosis,
                confidence,
                treatment,
                prevention,
                analysis_language
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (
                user_id,
                crop_type,
                os.path.join("uploads", "crop_doctor", unique_name).replace("\\", "/"),
                diagnosis,
                confidence,
                treatment_text,
                prevention_text,
                "English",
            ),
        )

        connection.commit()
        analysis_id = cursor.lastrowid

        cursor.execute(
            """
            SELECT
                id, user_id, crop_type, image_path, diagnosis, confidence,
                treatment, prevention, analysis_language, created_at
            FROM crop_doctor_analyses
            WHERE id = %s AND user_id = %s
            """,
            (analysis_id, user_id),
        )

        saved_row = cursor.fetchone()
        if not saved_row:
            raise RuntimeError("Analysis was saved but could not be retrieved.")

        result = build_crop_doctor_response(saved_row)
        result["is_crop_image"] = is_crop_image
        result["severity"] = str(ai_data.get("severity", "unknown")).strip() or "unknown"
        result["symptoms"] = normalize_list(ai_data.get("symptoms"))
        result["english_result"] = english_result
        result["telugu_result"] = telugu_result

        return jsonify({
            "success": True,
            "message": "Crop image analyzed successfully.",
            "analysis": result,
        }), 200

    except ValueError as e:
        if connection:
            connection.rollback()
        if 'image_path' in locals() and os.path.exists(image_path):
            try:
                os.remove(image_path)
            except OSError:
                pass
        return jsonify({"success": False, "error": str(e)}), 502

    except Exception as e:
        if connection:
            connection.rollback()
        if 'image_path' in locals() and os.path.exists(image_path):
            try:
                os.remove(image_path)
            except OSError:
                pass
        print("CROP DOCTOR ERROR:", repr(e))
        return jsonify({"success": False, "error": str(e)}), 500

    finally:
        close_db(connection, cursor)


# ============================================================
# CROP DOCTOR HISTORY
# ============================================================

@app.route("/api/crop-doctor/history", methods=["GET"])
def crop_doctor_history():
    connection = None
    cursor = None
    try:
        user_id = request.args.get("user_id", "").strip()
        if not user_id:
            return jsonify({"success": False, "error": "user_id is required."}), 400
        try:
            user_id = int(user_id)
        except ValueError:
            return jsonify({"success": False, "error": "Invalid user_id."}), 400

        if not user_exists(user_id):
            return jsonify({"success": False, "error": "User does not exist."}), 404

        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)
        cursor.execute(
            """
            SELECT id, user_id, crop_type, image_path, diagnosis, confidence,
                   treatment, prevention, analysis_language, created_at
            FROM crop_doctor_analyses
            WHERE user_id = %s
            ORDER BY created_at DESC, id DESC
            """,
            (user_id,),
        )
        rows = cursor.fetchall()
        analyses = [build_crop_doctor_response(row) for row in rows]
        return jsonify({"success": True, "count": len(analyses), "analyses": analyses}), 200
    except Exception as e:
        print("CROP DOCTOR HISTORY ERROR:", repr(e))
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        close_db(connection, cursor)


# ============================================================
# CROP DOCTOR ANALYSIS DETAIL
# ============================================================

@app.route("/api/crop-doctor/analysis/<int:analysis_id>", methods=["GET"])
def crop_doctor_analysis_detail(analysis_id):
    connection = None
    cursor = None
    try:
        user_id = request.args.get("user_id", "").strip()
        if not user_id:
            return jsonify({"success": False, "error": "user_id is required."}), 400
        try:
            user_id = int(user_id)
        except ValueError:
            return jsonify({"success": False, "error": "Invalid user_id."}), 400

        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)
        cursor.execute(
            """
            SELECT id, user_id, crop_type, image_path, diagnosis, confidence,
                   treatment, prevention, analysis_language, created_at
            FROM crop_doctor_analyses
            WHERE id = %s AND user_id = %s
            """,
            (analysis_id, user_id),
        )
        row = cursor.fetchone()
        if not row:
            return jsonify({"success": False, "error": "Analysis not found."}), 404
        return jsonify({"success": True, "analysis": build_crop_doctor_response(row)}), 200
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        close_db(connection, cursor)


# ============================================================
# CROP DOCTOR IMAGE
# ============================================================

@app.route("/api/crop-doctor/image/<int:analysis_id>", methods=["GET"])
def crop_doctor_image(analysis_id):
    connection = None
    cursor = None
    try:
        user_id = request.args.get("user_id", "").strip()
        if not user_id:
            return jsonify({"success": False, "error": "user_id is required."}), 400
        try:
            user_id = int(user_id)
        except ValueError:
            return jsonify({"success": False, "error": "Invalid user_id."}), 400

        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)
        cursor.execute(
            """
            SELECT image_path
            FROM crop_doctor_analyses
            WHERE id = %s AND user_id = %s
            """,
            (analysis_id, user_id),
        )
        row = cursor.fetchone()
        if not row:
            return jsonify({"success": False, "error": "Analysis image not found."}), 404

        filename = os.path.basename(row["image_path"] or "")
        if not filename:
            return jsonify({"success": False, "error": "Analysis image path is empty."}), 404

        response = send_from_directory(
            CROP_DOCTOR_UPLOAD_DIR,
            filename,
            as_attachment=False,
            max_age=0,
        )
        response.headers["Cache-Control"] = "private, no-store"
        return response

    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        close_db(connection, cursor)


# ============================================================
# DELETE CROP DOCTOR ANALYSIS
# ============================================================

@app.route(
    "/api/crop-doctor/analysis/<int:analysis_id>",
    methods=["DELETE"],
)
def delete_crop_doctor_analysis(
    analysis_id
):

    connection = None
    cursor = None

    try:

        user_id = request.args.get(
            "user_id",
            "",
        ).strip()

        if not user_id:
            return jsonify({
                "success": False,
                "error": "user_id is required.",
            }), 400

        try:
            user_id = int(user_id)
        except ValueError:

            return jsonify({
                "success": False,
                "error": "Invalid user_id.",
            }), 400

        connection = get_db_connection()

        cursor = connection.cursor()

        cursor.execute(
            """
            DELETE FROM crop_doctor_analyses
            WHERE id = %s
              AND user_id = %s
            """,
            (
                analysis_id,
                user_id,
            ),
        )

        connection.commit()

        if cursor.rowcount == 0:
            return jsonify({
                "success": False,
                "error": "Analysis not found.",
            }), 404

        return jsonify({
            "success": True,
            "message":
                "Crop Doctor analysis deleted.",
        })

    except Exception as e:

        if connection:
            connection.rollback()

        return jsonify({
            "success": False,
            "error": str(e),
        }), 500

    finally:

        close_db(connection, cursor)


# ============================================================
# ERROR HANDLERS
# ============================================================

@app.errorhandler(413)
def request_too_large(error):

    return jsonify({
        "success": False,
        "error":
            "Uploaded image is too large. Maximum size is 8 MB.",
    }), 413


@app.errorhandler(404)
def not_found(error):

    return jsonify({
        "success": False,
        "error": "API endpoint not found.",
    }), 404


# ============================================================
# DATABASE INITIALIZATION
# ============================================================

init_auth_db()
init_crop_doctor_db()


# ============================================================
# START SERVER
# ============================================================

if __name__ == "__main__":

    print()
    print("=" * 60)
    print("CROPNEXA BACKEND")
    print("=" * 60)
    print("Server: http://0.0.0.0:5000")
    print("AI Chat:", CHAT_MODEL)
    print("AI Crop Doctor:", CROP_DOCTOR_MODEL)
    print("Crop Doctor database: READY")
    print("=" * 60)
    print()

    app.run(
        host="0.0.0.0",
        port=5000,
        debug=True,
    )