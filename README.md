# Observability for Apache Kafka

## Introduction

Apache Kafka is a distributed event streaming platform, it is widely used in the industry for building real-time data pipelines and streaming applications.

This project is a demonstration of how to implement observability for Apache Kafka cluster using Prometheus and Grafana.

## Architecture

```mermaid
graph TD
    subgraph kafka-cluster
        kafka-0
        kafka-1
        kafka-2
    end
    producer -->|send| kafka-cluster
    kafka-cluster -->|retrieve| consumer

    kafka-0 -->|expose| jmx-exporter-0
    kafka-1 -->|expose| jmx-exporter-1
    kafka-2 -->|expose| jmx-exporter-2

    jmx-exporter-0 -->|scrape| prometheus
    jmx-exporter-1 -->|scrape| prometheus
    jmx-exporter-2 -->|scrape| prometheus

    prometheus -->|search| grafana
```

## Setup

In this section, we will setup all the components, including Apache Kafka, Prometheus, Grafana, and JMX Exporter.

Requirements:

- Linux (Ubuntu)
- Docker
- Docker Compose
- Discord webhook (optional)

1. (Optional) Create a `.env` file in the root directory, you can copy the file from `.env.sample`, and set the `DISCORD_WEBHOOK_URL` variable. This is used to send alert notifications to Discord. And you can set the `GF_SERVER_ROOT_URL` variable to you host machine IP address and port, if you want to access Grafana alerting from outside of the docker network.

Before creating a webhook, you need to have a Discord server and a channel.

[This documentation](https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks) will help you to create a Discord webhook.

2. Create a new docker network for this stack.

```bash
docker network create kafka-o11y
```

3. Pull and build required docker images.

```bash
make build
```

4. Setup Kafka cluster and all the exporters. This project use KRaft mode, so that we don't need Zookeeper.

```bash
make deploy-kafka
```

5. Setup Prometheus and Grafana, configuration file has been provided in `./prometheus` and `./grafana` directories and auto-loaded by the services.

```bash
make deploy-o11y
```

6. Setup the Kafka consumer.

Consumer receives the top command output from kafka and print the 5 processes with the highest CPU usage.

```bash
make deploy-consumer
```

7. Send top command output to Kafka.

>> WARNING: Linux only, because the top command output is different on macOS.

You can press `space` to accerlate the output, and `ctrl+c` to stop the producer.

```bash
top | docker run --rm -i --network kafka-o11y kafka-producer python app.py
```

8. Clean up the stack.

This command will stop and remove all the services, including all the volumes (docker network is not removed).

```bash
make clean
```

## Usage

Access the Grafana dashboard at `http://localhost:3001`, and login with `admin` and default password `admin`.

Check the prometheus scrape targets at `http://localhost:9090/targets`.

![prometheus-targets](images/prometheus-targets.png)

### Dashboard

There are four dashboards provided in this project, `Kafka Core`, `Kafka Cluster`, `Kafka Topics`, and `KRaft`.

![grafana-dashboards](images/grafana-dashboards.png)

#### Kafka Core

`Kafka Core` dashboard shows some core metrics of Kafka, including the number of controllers, brokers, partitions. It gives us a high-level overview of the cluster's health and operational status.

This dashboard provides the following metrics:

- **Active Controllers**: Shows the number of active controllers in the cluster, which is usually 1. If it is lower than 1, it indicates that the cluster has no active controller, and if it is greater than 1, it indicates that there are multiple active controllers, which is not normal.

- **Brokers Online**: Shows the number of online brokers in the cluster, which is usually equal to the number of brokers in the cluster. If it is lower than the number of brokers, it indicates that some brokers are offline.

- **Unclean Leader Election Rate**: Shows the rate of unclean leader elections, which is the number of times a broker has been elected as a leader for a partition without being in sync with the other replicas. This can lead to data loss, so it should be monitored closely.

- **Under Replicated Partitions**: Shows the number of under-replicated partitions, which are partitions that have fewer replicas than the configured replication factor. This can lead to data loss if the leader broker goes down.

- **Under Min ISR Partitions**: Shows the number of partitions that have fewer in-sync replicas than the configured minimum in-sync replicas. This can lead to data loss if the leader broker goes down.

- **Offline Partitions Count**: Shows the number of offline partitions, which are partitions that have no leader broker. This can lead to data loss if the leader broker goes down.

- **Errors**: Shows the number of errors encountered in the Kafka cluster, which can indicate issues with message production or consumption, and should be monitored closely.

![kafka-core](images/kafka-core-normal.png)

#### Kafka Cluster

`Kafka Cluster` dashboard shows some aspects of the Kafka cluster, including Network, Disk, Connection, Producer, and Consumer etc. I choose some important sections to show here.

`Overview` section provides a high-level overview of the cluster's health and operational status, including the number of online controller, brokers and partitions.

If `Unclean Leader Election Rate`, `Under Replicated Partitions` and `Under Min ISR Partitions` metrics greater than zero, it indicates potential availability and data loss, because ISR (In-Sync Replicas) is not enough, the data is not replicated to the required number of replicas.

![kafka-cluster-overview](images/kafka-cluster-overview.png)

`Request rate` section shows the number of requests, including produce, fetch, and fetch consumer requests. It helps us to understand the cluster's workload.

If the request rate is too high, it may cause the broker to be overloaded, and the request rate is too low, it may indicate that the producer or consumer is not working properly.

![kafka-cluster-request-rate](images/kafka-cluster-request-rate.png)

`System` section shows the Disk read/write bytes. It helps us to understand the disk usage.

If some brokers have a high disk read/write bytes, it may indicate that the broker is overloaded.

![kafka-cluster-system](images/kafka-cluster-system.png)

`Throughput In/Out` section shows the number of bytes read/written per second, while broker goes down, we can quickly identify the issue.

![kafka-cluster-throughput](images/kafka-cluster-throughput.png)

`Logs size` section shows the size of the log files. If the log size is too large, it may indicate that disk space is insufficient.

![kafka-cluster-logs-size](images/kafka-cluster-logs-size.png)

`Isr Shrinks / Expands` section shows the number of ISR shrinks and expands, it helps us to understand the ISR status.

ISR shrinks means that some replicas are not in sync with the leader, frequent ISR shrinks and expands may indicate network issues.

![kafka-cluster-isr](images/kafka-cluster-isr.png)

#### Kafka Topics

This dashboard shows the metrics of Kafka topics, including total number of partitions, the number of bytes Read/Write, data produced/consumed per topic.

![kafka-topics](images/kafka-topics.png)

#### KRaft

This dashboard shows the metrics of KRaft mode, including the record append/fetch rate by the leader of the raft quorum, time spent to commit a record.

If the latency of the raft commit is increasing, it may indicate that the cluster metadata synchronization issue.

![kraft](images/kraft.png)

### Alerting

This project also provides some alerting rules on Grafana, these rules are based on the core metrics in the `Kafka Core` dashboard.

![grafana-alert-normal](images/grafana-alert-normal.png)

Let's try to trigger the alert by stopping the Kafka broker.

```bash
docker stop kafka-1
```

You can see some core metrics are changed, including the number of active brokers, partitions and under replicated partitions.

![kafka-core-abnormal](images/kafka-core-abnormal.png)

About a minute later, you will see the alert is triggered, and you will receive a notification on Discord. (If you set the `DISCORD_WEBHOOK_URL` variable in `.env` file)

![grafana-alert-abnormal](images/grafana-alert-abnormal.png)

Notify message contains the alert name, state, summary and some service labels. You can click the link to view the alert in Grafana. (If you set the `GF_SERVER_ROOT_URL` variable in `.env` file)

![discord-firing](images/discord-firing.png)

Then, let's restart the Kafka broker, and see the alert is resolved.

```bash
docker start kafka-1
```

About a minute later, you will see the alert is resolved, and you will receive a resolved notification on Discord.

![discord-resolved](images/discord-resolved.png)

## References

[Monitoring Kafka with JMX | Confluent Documentation](https://docs.confluent.io/platform/current/kafka/monitoring.html)

[confluentinc/jmx-monitoring-stacks: 📊 Monitoring examples for Confluent Cloud and Confluent Platform](https://github.com/confluentinc/jmx-monitoring-stacks)

[prometheus/jmx_exporter: A process for collecting metrics using JMX MBeans for Prometheus consumption](https://github.com/prometheus/jmx_exporter)
