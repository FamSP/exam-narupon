from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/api/hello', methods=['GET'])
def hello():
    return jsonify({"message": "Hello from Flask API!"})

@app.route('/api/goodbye', methods=['GET'])
def goodbye():
    return jsonify({"message": "Goodbye from Flask API!"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
