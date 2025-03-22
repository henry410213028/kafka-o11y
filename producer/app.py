import json
import time
import logging
import os
from kafka import KafkaProducer

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)


def send_to_kafka(producer: KafkaProducer, topic: str, data: str):
    try:
        producer.send(topic, value=data.encode("utf-8"))
        producer.flush()
        logging.debug("Sent data to Kafka")
    except Exception:
        logging.error("Error sending to Kafka", exc_info=True)


def main():
    kafka_bootstrap_servers_str = os.environ.get("KAFKA_BOOTSTRAP_SERVERS")
    kafka_topic = os.environ.get("KAFKA_TOPIC", "system-metrics")

    if kafka_bootstrap_servers_str:
        kafka_bootstrap_servers = kafka_bootstrap_servers_str.split(",")
    else:
        kafka_bootstrap_servers = ["kafka-0:9092", "kafka-1:9092", "kafka-2:9092"]

    try:
        producer = KafkaProducer(bootstrap_servers=kafka_bootstrap_servers)
        logging.info("KafkaProducer initialized")
    except Exception:
        logging.error("Failed to connect to Kafka", exc_info=True)
        return

    count = 0
    last_time = time.time()
    while True:
        try:
            line = input()
            if not line:
                continue

            data = json.dumps({"timestamp": time.time(), "top_line": line})
            send_to_kafka(producer, kafka_topic, data)
            count += 1

            curr_time = time.time()
            if curr_time - last_time >= 1:  # print every 1 seconds
                logging.info("Total messages sent: %d", count)
                last_time = curr_time
        except EOFError:
            break
        except KeyboardInterrupt:
            break

    producer.close()


if __name__ == "__main__":
    main()
