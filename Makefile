build:
	docker build -t kafka-producer -f ./producer/Dockerfile ./producer && \
	docker-compose -f ./docker-compose-kafka.yml build && \
	docker-compose -f ./docker-compose-consumer.yml build && \
	docker-compose -f ./docker-compose-o11y.yml build

clean:
	docker-compose -f ./docker-compose-consumer.yml down -v && \
	docker-compose -f ./docker-compose-kafka.yml down -v && \
	docker-compose -f ./docker-compose-o11y.yml down -v

# kafka + jmx-exporter

build-kafka:
	docker-compose -f ./docker-compose-kafka.yml build

deploy-kafka:
	docker-compose -f ./docker-compose-kafka.yml up -d

down-kafka:
	docker-compose -f ./docker-compose-kafka.yml down

clean-kafka:
	docker-compose -f ./docker-compose-producer.yml down -v && \
	docker-compose -f ./docker-compose-consumer.yml down -v && \
	docker-compose -f ./docker-compose-kafka.yml down -v

logs-kafka:
	docker-compose -f ./docker-compose-kafka.yml logs -f --tail 200

# prometheus + grafana

build-o11y:
	docker-compose -f ./docker-compose-o11y.yml build

deploy-o11y:
	docker-compose -f ./docker-compose-o11y.yml up -d

down-o11y:
	docker-compose -f ./docker-compose-o11y.yml down

clean-o11y:
	docker-compose -f ./docker-compose-o11y.yml down -v

logs-o11y:
	docker-compose -f ./docker-compose-o11y.yml logs -f --tail 200

# grafana

deploy-grafana:
	docker-compose -f ./docker-compose-o11y.yml up -d grafana

down-grafana:
	docker-compose -f ./docker-compose-o11y.yml rm --stop grafana

clean-grafana:
	docker-compose -f ./docker-compose-o11y.yml rm --stop -v grafana

# consumer

build-consumer:
	docker-compose -f ./docker-compose-consumer.yml build

deploy-consumer:
	docker-compose -f ./docker-compose-consumer.yml up -d

down-consumer:
	docker-compose -f ./docker-compose-consumer.yml down

logs-consumer:
	docker-compose -f ./docker-compose-consumer.yml logs -f --tail 200

# producer

build-producer:
	docker build -t kafka-producer -f ./producer/Dockerfile ./producer
