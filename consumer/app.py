import json
import logging
import re
import os
from kafka import KafkaConsumer
from collections import deque
from typing import Optional
import heapq

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)

regex_end = re.compile(r"\s{20,}.*$")

regex_process = re.compile(
    r"\s*(\d+)\s+([\w\-\+ ]+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+([RSDZTWIl\+<nsNL]+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+([\d:]+\.\d+)\s+(.+)"
)


def parse_top_line(line: str) -> Optional[dict]:
    line_trimmed = re.sub(regex_end, "", line)
    match_process = re.search(regex_process, line_trimmed)
    if match_process:
        pid, user, pr, ni, virt, res, shr, s, cpu, mem, time, command = (
            match_process.groups()
        )
        process_data = {
            "PID": int(pid),
            "USER": user,
            "PR": int(pr),
            "NI": int(ni),
            "VIRT": int(virt),
            "RES": int(res),
            "SHR": int(shr),
            "S": s,
            "CPU": float(cpu),
            "MEM": float(mem),
            "TIME": time,
            "COMMAND": command.strip(),
        }
        return process_data


def main():
    kafka_bootstrap_servers_str = os.environ.get("KAFKA_BOOTSTRAP_SERVERS")
    kafka_topic = os.environ.get("KAFKA_TOPIC", "system-metrics")

    if kafka_bootstrap_servers_str:
        kafka_bootstrap_servers = kafka_bootstrap_servers_str.split(",")
    else:
        kafka_bootstrap_servers = ["kafka-0:9092", "kafka-1:9092", "kafka-2:9092"]

    consumer = KafkaConsumer(
        kafka_topic,
        bootstrap_servers=kafka_bootstrap_servers,
        group_id="python-consumer-group",
        auto_offset_reset="latest",
    )
    logging.info("KafkaConsumer initialized")

    command_data = {}

    try:
        for message in consumer:
            try:
                top_line = json.loads(message.value.decode("utf-8"))["top_line"]
                logging.debug(f"Received message: {top_line}")
                parsed_data = parse_top_line(top_line)

                if parsed_data:
                    command = parsed_data["COMMAND"]
                    cpu = parsed_data["CPU"]
                    mem = parsed_data["MEM"]

                    # save top 50 cpu and mem usage for each command
                    if command not in command_data:
                        command_data[command] = {
                            "cpu": deque(maxlen=50),
                            "mem": deque(maxlen=50),
                        }

                    command_data[command]["cpu"].append(cpu)
                    command_data[command]["mem"].append(mem)

                    # print top 5 commands with highest average cpu usage
                    top_commands = heapq.nlargest(
                        5,
                        command_data.items(),
                        key=lambda item: (
                            sum(item[1]["cpu"]) / len(item[1]["cpu"])
                            if item[1]["cpu"]
                            else 0
                        ),
                    )

                    for i, (cmd, data) in enumerate(top_commands):
                        cpu_avg_top = (
                            sum(data["cpu"]) / len(data["cpu"]) if data["cpu"] else 0
                        )
                        mem_avg_top = (
                            sum(data["mem"]) / len(data["mem"]) if data["mem"] else 0
                        )
                        logging.info(
                            f"Top {i+1} Command: {cmd}, Avg CPU: {cpu_avg_top:.2f}, Avg MEM: {mem_avg_top:.2f}"
                        )

            except Exception:
                error_msg = (
                    f"Error processing data, raw Data: {message.value.decode('utf-8')}"
                )
                logging.error(error_msg, exc_info=True)

    except KeyboardInterrupt:
        logging.info("Consumer stopped by user.")
    finally:
        consumer.close()


if __name__ == "__main__":
    main()
