import os
import json
import socket
import logging
from flask import Flask, jsonify, request
import pymysql
import redis

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Service configuration using container/service names
MYSQL_HOST = os.getenv('MYSQL_HOST', 'mysql')
MYSQL_PORT = int(os.getenv('MYSQL_PORT', 3306))
MYSQL_USER = os.getenv('MYSQL_USER', 'order_user')
MYSQL_PASSWORD = os.getenv('MYSQL_PASSWORD', 'order_pass123')
MYSQL_DB = os.getenv('MYSQL_DB', 'food_delivery_db')

REDIS_HOST = os.getenv('REDIS_HOST', 'redis')
REDIS_PORT = int(os.getenv('REDIS_PORT', 6379))
PORT = int(os.getenv('PORT', 5000))

# Helper to get MySQL connection
def get_db_connection():
    return pymysql.connect(
        host=MYSQL_HOST,
        port=MYSQL_PORT,
        user=MYSQL_USER,
        password=MYSQL_PASSWORD,
        database=MYSQL_DB,
        cursorclass=pymysql.cursors.DictCursor,
        connect_timeout=5
    )

# Helper to get Redis client
def get_redis_client():
    return redis.Redis(
        host=REDIS_HOST,
        port=REDIS_PORT,
        decode_responses=True,
        socket_connect_timeout=3
    )

@app.route('/', methods=['GET'])
def index():
    """Service metadata and architecture information."""
    container_hostname = socket.gethostname()
    return jsonify({
        "service": "Food Delivery Platform - Order Service",
        "container_hostname": container_hostname,
        "network": "food-delivery-net",
        "configured_dependencies": {
            "mysql_host": MYSQL_HOST,
            "mysql_port": MYSQL_PORT,
            "redis_host": REDIS_HOST,
            "redis_port": REDIS_PORT
        },
        "endpoints": {
            "health": "/health",
            "get_all_orders": "/orders",
            "get_single_order": "/orders/<order_id>",
            "create_order": "POST /orders",
            "security_test": "/restricted-test"
        }
    }), 200

@app.route('/health', methods=['GET'])
def health():
    """Verify internal connectivity to MySQL and Redis using service names."""
    health_status = {
        "status": "UP",
        "mysql": {"status": "UNKNOWN", "target": f"{MYSQL_HOST}:{MYSQL_PORT}"},
        "redis": {"status": "UNKNOWN", "target": f"{REDIS_HOST}:{REDIS_PORT}"}
    }
    status_code = 200

    # 1. Test MySQL connectivity
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            cursor.execute("SELECT 1 AS ping;")
            res = cursor.fetchone()
        conn.close()
        health_status["mysql"]["status"] = "CONNECTED"
        health_status["mysql"]["resolved_ip"] = socket.gethostbyname(MYSQL_HOST)
    except Exception as e:
        logger.error(f"MySQL connection error to {MYSQL_HOST}: {e}")
        health_status["mysql"]["status"] = "FAILED"
        health_status["mysql"]["error"] = str(e)
        health_status["status"] = "DEGRADED"
        status_code = 503

    # 2. Test Redis connectivity
    try:
        r = get_redis_client()
        r.ping()
        health_status["redis"]["status"] = "CONNECTED"
        health_status["redis"]["resolved_ip"] = socket.gethostbyname(REDIS_HOST)
    except Exception as e:
        logger.error(f"Redis connection error to {REDIS_HOST}: {e}")
        health_status["redis"]["status"] = "FAILED"
        health_status["redis"]["error"] = str(e)
        health_status["status"] = "DEGRADED"
        status_code = 503

    return jsonify(health_status), status_code

@app.route('/orders', methods=['GET'])
def get_orders():
    """Return all orders, demonstrating Redis caching over MySQL queries."""
    cache_key = "cache:all_orders"

    # Step 1: Check Redis cache first
    try:
        r = get_redis_client()
        cached_data = r.get(cache_key)
        if cached_data:
            logger.info("Serving orders from Redis cache")
            orders = json.loads(cached_data)
            return jsonify({
                "source": "Redis Cache (Internal Service Communication)",
                "cached": True,
                "count": len(orders),
                "orders": orders
            }), 200
    except Exception as e:
        logger.warning(f"Cache lookup failed (falling back to database): {e}")
        r = None

    # Step 2: Query MySQL Database on cache miss
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            cursor.execute("SELECT order_id, customer_name, restaurant_name, items, CAST(total_amount AS CHAR) AS total_amount, order_status, created_at FROM orders ORDER BY order_id ASC;")
            orders = cursor.fetchall()
            # Convert timestamp to string for JSON serialization
            for order in orders:
                if 'created_at' in order and order['created_at']:
                    order['created_at'] = str(order['created_at'])
        conn.close()

        # Step 3: Populate Redis cache with 60s TTL
        if r:
            try:
                r.setex(cache_key, 60, json.dumps(orders))
                logger.info("Cached orders in Redis with 60s TTL")
            except Exception as e:
                logger.warning(f"Failed to cache orders in Redis: {e}")

        return jsonify({
            "source": "MySQL Database (Internal Service Communication)",
            "cached": False,
            "count": len(orders),
            "orders": orders
        }), 200

    except Exception as e:
        logger.error(f"Failed to retrieve orders from database: {e}")
        return jsonify({
            "error": "Database query failed",
            "details": str(e)
        }), 500

@app.route('/orders/<int:order_id>', methods=['GET'])
def get_order_by_id(order_id):
    """Return specific order details by ID."""
    cache_key = f"cache:order:{order_id}"

    # Try cache
    try:
        r = get_redis_client()
        cached = r.get(cache_key)
        if cached:
            return jsonify({
                "source": "Redis Cache",
                "cached": True,
                "order": json.loads(cached)
            }), 200
    except Exception:
        r = None

    # Query DB
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT order_id, customer_name, restaurant_name, items, CAST(total_amount AS CHAR) AS total_amount, order_status, created_at FROM orders WHERE order_id = %s;",
                (order_id,)
            )
            order = cursor.fetchone()
            if order and 'created_at' in order and order['created_at']:
                order['created_at'] = str(order['created_at'])
        conn.close()

        if not order:
            return jsonify({"error": f"Order {order_id} not found"}), 404

        if r:
            r.setex(cache_key, 60, json.dumps(order))

        return jsonify({
            "source": "MySQL Database",
            "cached": False,
            "order": order
        }), 200

    except Exception as e:
        return jsonify({"error": "Failed to fetch order", "details": str(e)}), 500

@app.route('/orders', methods=['POST'])
def create_order():
    """Create a new food delivery order and invalidate Redis cache."""
    data = request.get_json(force=True, silent=True)
    if not data:
        return jsonify({"error": "JSON body required"}), 400

    customer_name = data.get('customer_name')
    restaurant_name = data.get('restaurant_name')
    items = data.get('items')
    total_amount = data.get('total_amount', 0.0)

    if not customer_name or not restaurant_name or not items:
        return jsonify({"error": "Fields 'customer_name', 'restaurant_name', and 'items' are required"}), 400

    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            cursor.execute(
                "INSERT INTO orders (customer_name, restaurant_name, items, total_amount, order_status) VALUES (%s, %s, %s, %s, 'Placed');",
                (customer_name, restaurant_name, items, total_amount)
            )
            new_id = cursor.lastrowid
        conn.commit()
        conn.close()

        # Invalidate cache
        try:
            r = get_redis_client()
            r.delete("cache:all_orders")
            logger.info("Invalidated Redis all_orders cache following new order insertion")
        except Exception as e:
            logger.warning(f"Failed to invalidate cache: {e}")

        return jsonify({
            "message": "Order placed successfully",
            "order_id": new_id,
            "customer_name": customer_name,
            "restaurant_name": restaurant_name,
            "items": items,
            "total_amount": total_amount,
            "order_status": "Placed"
        }), 201

    except Exception as e:
        logger.error(f"Order creation failed: {e}")
        return jsonify({"error": "Order creation failed", "details": str(e)}), 500

@app.route('/restricted-test', methods=['GET'])
def restricted_test():
    """
    Demonstrates security confinement.
    Attempts to read sensitive system file /etc/shadow or /etc/passwd.
    Under AppArmor enforcement, this will be blocked with PermissionDenied (EACCES).
    """
    results = {}
    
    # Test sensitive read: /etc/shadow
    try:
        with open("/etc/shadow", "r") as f:
            results["/etc/shadow"] = f.read()[:50]
    except PermissionError as e:
        results["/etc/shadow"] = f"BLOCKED by Security Confinement (PermissionError: {e})"
    except FileNotFoundError:
        results["/etc/shadow"] = "FILE_NOT_FOUND (non-existent)"
    except Exception as e:
        results["/etc/shadow"] = f"ERROR: {e}"

    # Test sensitive read: /etc/passwd
    try:
        with open("/etc/passwd", "r") as f:
            content = f.read(50)
            results["/etc/passwd"] = f"ALLOWED: {content.strip()}..."
    except PermissionError as e:
        results["/etc/passwd"] = f"BLOCKED by Security Confinement (PermissionError: {e})"
    except Exception as e:
        results["/etc/passwd"] = f"ERROR: {e}"

    return jsonify({
        "security_confinement_test": results,
        "note": "When AppArmor profile is applied, access to /etc/** and /var/** is denied by the kernel LSM."
    }), 200

if __name__ == '__main__':
    logger.info(f"Starting Food Delivery Flask Service on port {PORT}...")
    app.run(host='0.0.0.0', port=PORT, debug=True)
