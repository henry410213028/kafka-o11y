mkdir -p '/home/henry/Dropbox/project/kafka-flink-monitoring/producer'
touch '/home/henry/Dropbox/project/kafka-flink-monitoring/producer/app.py'
cat > '/home/henry/Dropbox/project/kafka-flink-monitoring/producer/app.py' << EOF
import subprocess
import time
import json
from kafka import KafkaProducer

def get_top_info():
    """ 執行 top 命令並取得輸出 """
    try:
        # 執行 top -b -n 1 (批次模式，一次迭代)
        result = subprocess.run(['top', '-b', '-n', '1'], capture_output=True, text=True, check=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"Error running top: \{e}")
        return None

def send_to_kafka(producer, topic, data):
    """ 將資料發送到 Kafka """
    try:
        producer.send(topic, value=data.encode('utf-8'))
        producer.flush()  # 確保訊息已送出
        print("Sent data to Kafka")
    except Exception as e:
        print(f"Error sending to Kafka: \{e}")

def main():
    kafka_bootstrap_servers = 'kafka-service:9092'  # 假設 Kafka service 名稱為 kafka-service
    topic = 'system-metrics'

    try:
        producer = KafkaProducer(bootstrap_servers=kafka_bootstrap_servers)
    except Exception as e:
        print(f"Failed to connect to Kafka: \{e}")
        return

    while True:
        top_output = get_top_info()
        if top_output:
            # 將 top 輸出轉換為 JSON (這裡只是一個簡單的範例，你可能需要更複雜的解析)
            data = json.dumps({'timestamp': time.time(), 'top_output': top_output})
            send_to_kafka(producer, topic, data)

        # 檢查是否按下空白鍵 (這裡需要非阻塞式輸入，比較複雜，可能需要 curses 或其他庫)
        # 這裡先用簡單的 sleep 模擬，實際應用中需要修改
        time.sleep(1)
        # (在實際應用中，這裡應該有一個檢查鍵盤輸入的機制)
        # if check_for_space_key_press():  # 假設這是檢查是否按下空白鍵的函數
        #     print("Space key pressed. Refreshing...")
        #     continue  # 重新取得 top 資訊並發送


if __name__ == "__main__":
    main()
EOF

mkdir -p '/home/henry/Dropbox/project/kafka-flink-monitoring/producer'
touch '/home/henry/Dropbox/project/kafka-flink-monitoring/producer/requirements.txt'
cat > '/home/henry/Dropbox/project/kafka-flink-monitoring/producer/requirements.txt' << EOF
kafka-python
EOF


mkdir -p '/home/henry/Dropbox/project/kafka-flink-monitoring/producer'
touch '/home/henry/Dropbox/project/kafka-flink-monitoring/producer/Dockerfile'
cat > '/home/henry/Dropbox/project/kafka-flink-monitoring/producer/Dockerfile' << EOF
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

CMD ["python", "app.py"]
EOF

mkdir -p '/home/henry/Dropbox/project/kafka-flink-monitoring/flink'
touch '/home/henry/Dropbox/project/kafka-flink-monitoring/flink/job.py'
cat > '/home/henry/Dropbox/project/kafka-flink-monitoring/flink/job.py' << EOF
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.datastream.connectors import FlinkKafkaConsumer
from pyflink.common.serialization import SimpleStringSchema
import json
import re

def calculate_load(data):
    """ 從 top 輸出中提取系統負載量 (簡化範例) """
    try:
        top_output = json.loads(data)['top_output']
        # 使用正規表示式從 top 輸出中找到 load average
        match = re.search(r'load average: (\d+\.\d+), (\d+\.\d+), (\d+\.\d+)', top_output)
        if match:
            load1, load5, load15 = map(float, match.groups())
            return f"Load Average (1min, 5min, 15min): \{load1}, \{load5}, \{load15}"
        else:
            return "Could not parse load average"
    except Exception as e:
        return f"Error processing data: \{e}"

def main():
    env = StreamExecutionEnvironment.get_execution_environment()
    env.set_parallelism(1)  # 簡化範例，設置 parallelism 為 1

    kafka_bootstrap_servers = 'kafka-service:9092'
    topic = 'system-metrics'

    # Kafka Consumer
    kafka_consumer = FlinkKafkaConsumer(
        topic,
        SimpleStringSchema(),
        {'bootstrap.servers': kafka_bootstrap_servers, 'group.id': 'flink-consumer-group'}
    )

    # 建立資料串流
    data_stream = env.add_source(kafka_consumer)

    # 處理資料並計算負載
    load_stream = data_stream.map(calculate_load)

    # 將結果輸出 (這裡只是印到 console，你可以輸出到其他地方)
    load_stream.print()

    env.execute("System Load Calculation")

if __name__ == '__main__':
    main()
EOF

mkdir -p '/home/henry/Dropbox/project/kafka-flink-monitoring/prometheus'
touch '/home/henry/Dropbox/project/kafka-flink-monitoring/prometheus/prometheus.yml'
cat > '/home/henry/Dropbox/project/kafka-flink-monitoring/prometheus/prometheus.yml' << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']  # Prometheus 自身

  - job_name: 'kafka-exporter'
    static_configs:
      - targets: ['kafka-exporter-service:9308']  # Kafka Exporter Service
EOF

mkdir -p '/home/henry/Dropbox/project/kafka-flink-monitoring/grafana/provisioning/datasources'
touch '/home/henry/Dropbox/project/kafka-flink-monitoring/grafana/provisioning/datasources/datasource.yml'
cat > '/home/henry/Dropbox/project/kafka-flink-monitoring/grafana/provisioning/datasources/datasource.yml' << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus-service:9090  # Prometheus Service
    isDefault: true
EOF

mkdir -p '/home/henry/Dropbox/project/kafka-flink-monitoring/k8s'
touch '/home/henry/Dropbox/project/kafka-flink-monitoring/k8s/namespace.yaml'
cat > '/home/henry/Dropbox/project/kafka-flink-monitoring/k8s/namespace.yaml' << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
EOF

mkdir -p '/home/henry/Dropbox/project/kafka-flink-monitoring/k8s'
touch '/home/henry/Dropbox/project/kafka-flink-monitoring/k8s/kafka.yaml'
cat > '/home/henry/Dropbox/project/kafka-flink-monitoring/k8s/kafka.yaml' << EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: kafka
  namespace: monitoring
spec:
  serviceName: "kafka-service"
  replicas: 3  # Kafka 副本數
  selector:
    matchLabels:
      app: kafka
  template:
    metadata:
      labels:
        app: kafka
    spec:
      containers:
      - name: kafka
        image: bitnami/kafka:latest  # 使用 Bitnami Kafka 映像
        ports:
        - containerPort: 9092
        env:
        - name: KAFKA_CFG_ZOOKEEPER_CONNECT
          value: "zookeeper-service:2181"  # 假設 Zookeeper Service 名稱為 zookeeper-service
        - name: KAFKA_CFG_ADVERTISED_LISTENERS
          value: "PLAINTEXT://kafka-service:9092"
# ... 其他 Kafka 配置 ...

---
apiVersion: v1
kind: Service
metadata:
  name: kafka-service
  namespace: monitoring
spec:
  ports:
  - port: 9092
    targetPort: 9092
  selector:
    app: kafka
  clusterIP: None  # Headless Service
EOF

mkdir -p '/home/henry/Dropbox/project/kafka-flink-monitoring/k8s'
touch '/home/henry/Dropbox/project/kafka-flink-monitoring/k8s/producer.yaml'
cat > '/home/henry/Dropbox/project/kafka-flink-monitoring/k8s/producer.yaml' << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: top-producer
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: top-producer
  template:
    metadata:
      labels:
        app: top-producer
    spec:
      containers:
      - name: producer
        image: your-docker-hub-account/top-producer:latest  # 替換成你的 Docker Hub 帳號和映像名稱
        imagePullPolicy: Always # 每次都拉image
        env:
          - name: KAFKA_BOOTSTRAP_SERVERS
            value: "kafka-service:9092"
EOF

mkdir -p '/home/henry/Dropbox/project/kafka-flink-monitoring/k8s'
touch '/home/henry/Dropbox/project/kafka-flink-monitoring/k8s/flink.yaml'
cat > '/home/henry/Dropbox/project/kafka-flink-monitoring/k8s/flink.yaml' << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flink-job
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: flink-job
  template:
    metadata:
      labels:
        app: flink-job
    spec:
      containers:
        - name: flink-job
          image: your-docker-hub-account/flink-job:latest # 替換成你的 image
          imagePullPolicy: Always
          env:
            - name: KAFKA_BOOTSTRAP_SERVERS
              value: "kafka-service:9092"
EOF

mkdir -p '/home/henry/Dropbox/project/kafka-flink-monitoring/k8s'
touch '/home/henry/Dropbox/project/kafka-flink-monitoring/k8s/prometheus.yaml'
cat > '/home/henry/Dropbox/project/kafka-flink-monitoring/k8s/prometheus.yaml' << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s

    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']

      - job_name: 'kafka-exporter'
        static_configs:
          - targets: ['kafka-exporter-service:9308']
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: prometheus-config-volume
          mountPath: /etc/prometheus/
      volumes:
      - name: prometheus-config-volume
        configMap:
          name: prometheus-config

---
apiVersion: v1
kind: Service
metadata:
  name: prometheus-service
  namespace: monitoring
spec:
  selector:
    app: prometheus
  ports:
    - protocol: TCP
      port: 9090
      targetPort: 9090
EOF

mkdir -p '/home/henry/Dropbox/project/kafka-flink-monitoring/k8s'
touch '/home/henry/Dropbox/project/kafka-flink-monitoring/k8s/grafana.yaml'
cat > '/home/henry/Dropbox/project/kafka-flink-monitoring/k8s/grafana.yaml' << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: monitoring
data:
  datasource.yml: |
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://prometheus-service:9090
        isDefault: true
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        ports:
        - containerPort: 3000
        volumeMounts:
        - name: grafana-datasources
          mountPath: /etc/grafana/provisioning/datasources
          readOnly: false
        # 你可以在這裡添加 Grafana 儀表板的 volumeMount (如果需要)
      volumes:
      - name: grafana-datasources
        configMap:
          name: grafana-datasources
---
apiVersion: v1
kind: Service
metadata:
  name: grafana-service
  namespace: monitoring
spec:
  selector:
    app: grafana
  ports:
    - protocol: TCP
      port: 3000
      targetPort: 3000
EOF

mkdir -p '/home/henry/Dropbox/project/kafka-flink-monitoring/k8s'
touch '/home/henry/Dropbox/project/kafka-flink-monitoring/k8s/kafka-exporter.yaml'
cat > '/home/henry/Dropbox/project/kafka-flink-monitoring/k8s/kafka-exporter.yaml' << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kafka-exporter
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kafka-exporter
  template:
    metadata:
      labels:
        app: kafka-exporter
    spec:
      containers:
      - name: kafka-exporter
        image: danielqsj/kafka-exporter:latest  # 官方 Kafka Exporter 映像
        ports:
        - containerPort: 9308
        env:
          - name: KAFKA_BOOTSTRAP_SERVERS
            value: "kafka-service:9092"
---
apiVersion: v1
kind: Service
metadata:
  name: kafka-exporter-service
  namespace: monitoring
spec:
  selector:
    app: kafka-exporter
  ports:
    - protocol: TCP
      port: 9308
      targetPort: 9308
EOF
