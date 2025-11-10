#!/usr/bin/env python3
"""
Sample Web Application with PostgreSQL Connection
Reads database credentials from environment variables (K8s secrets)
"""

import os
import psycopg2
from flask import Flask, jsonify
from psycopg2.extras import RealDictCursor

app = Flask(__name__)

# Database configuration from K8s secrets (environment variables)
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': int(os.getenv('DB_PORT', '5432')),
    'database': os.getenv('DB_NAME', 'myapp-db'),
    'user': os.getenv('DB_USERNAME'),
    'password': os.getenv('DB_PASSWORD')
}

def get_db_connection():
    """Create database connection using credentials from K8s secrets"""
    try:
        conn = psycopg2.connect(
            host=DB_CONFIG['host'],
            port=DB_CONFIG['port'],
            database=DB_CONFIG['database'],
            user=DB_CONFIG['user'],
            password=DB_CONFIG['password']
        )
        return conn
    except Exception as e:
        print(f"Error connecting to database: {str(e)}")
        raise

@app.route('/')
def home():
    """Home endpoint"""
    return jsonify({
        'message': 'Welcome to MyApp API',
        'status': 'running',
        'database': 'PostgreSQL'
    })

@app.route('/health')
def health():
    """Health check endpoint"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute('SELECT version();')
        version = cursor.fetchone()[0]
        cursor.close()
        conn.close()
        
        return jsonify({
            'status': 'healthy',
            'database': 'connected',
            'postgres_version': version
        })
    except Exception as e:
        return jsonify({
            'status': 'unhealthy',
            'database': 'disconnected',
            'error': str(e)
        }), 503

@app.route('/init-db')
def init_db():
    """Initialize database with sample table"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Create a sample table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                username VARCHAR(50) UNIQUE NOT NULL,
                email VARCHAR(100) UNIQUE NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        ''')
        
        # Insert sample data
        cursor.execute('''
            INSERT INTO users (username, email) 
            VALUES ('admin', 'admin@example.com')
            ON CONFLICT (username) DO NOTHING;
        ''')
        
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({
            'status': 'success',
            'message': 'Database initialized successfully'
        })
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/users')
def get_users():
    """Get all users from database"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        cursor.execute('SELECT id, username, email, created_at FROM users;')
        users = cursor.fetchall()
        cursor.close()
        conn.close()
        
        return jsonify({
            'status': 'success',
            'count': len(users),
            'users': users
        })
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/config')
def config():
    """Show current configuration (without sensitive data)"""
    return jsonify({
        'db_host': DB_CONFIG['host'],
        'db_port': DB_CONFIG['port'],
        'db_name': DB_CONFIG['database'],
        'db_user': DB_CONFIG['user'],
        'db_password': '***' if DB_CONFIG['password'] else 'NOT_SET'
    })

if __name__ == '__main__':
    # Validate required environment variables
    required_vars = ['DB_USERNAME', 'DB_PASSWORD']
    missing_vars = [var for var in required_vars if not os.getenv(var)]
    
    if missing_vars:
        print(f"ERROR: Missing required environment variables: {', '.join(missing_vars)}")
        print("These should be provided by K8s secrets")
        exit(1)
    
    print("Starting application...")
    print(f"Database Host: {DB_CONFIG['host']}")
    print(f"Database Name: {DB_CONFIG['database']}")
    print(f"Database User: {DB_CONFIG['user']}")
    
    app.run(host='0.0.0.0', port=8080, debug=False)
