from flask import Flask
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import random
from flask import Flask, jsonify, request
import time

app = Flask(__name__)

TRANSACTIONS_TOTAL = Counter(
    'novapay_transactions_total',
    'Total number of payment transactions',
    ['status', 'payment_method']
)

TRANSACTION_DURATION = Histogram(
    'novapay_transaction_duration_seconds',
    'Payment transaction processing duration',
    ['payment_method'],
    buckets=[0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.0]
)

TRANSACTION_AMOUNT = Histogram(
    'novapay_transaction_amount_usd',
    'Payment transaction amount in USD',
    buckets=[10, 50, 100, 500, 1000, 5000]
)

@app.route('/health')
def health():
    return {"status": "healthy", "service": "payment-gateway"}


@app.route('/api/v1/payment', methods=['POST'])
def process_payment():
    payment_method = request.json.get('payment_method', 'card')
    amount = request.json.get('amount', 100)

    start_time = time.time()

    # Simulate processing time
    time.sleep(random.uniform(0.01, 0.5))

    # Simulate 90% success, 10% failure
    success = random.random() > 0.1
    status = 'success' if success else 'failed'
    duration = time.time() - start_time

    # Record metrics
    TRANSACTIONS_TOTAL.labels(status=status, payment_method=payment_method).inc()
    TRANSACTION_DURATION.labels(payment_method=payment_method).observe(duration)
    TRANSACTION_AMOUNT.observe(amount)

    if success:
        return jsonify({
            "transaction_id": f"txn_{random.randint(100000, 999999)}",
            "status": "success",
            "amount": amount,
            "processing_time_ms": round(duration * 1000, 2)
        })
    else:
        return jsonify({"status": "failed", "reason": "insufficient_funds"}), 402

@app.route('/metrics')
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}


@app.route('/version')
def version():
    return {"version": "1.0.0", "service": "payment-gateway"}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)