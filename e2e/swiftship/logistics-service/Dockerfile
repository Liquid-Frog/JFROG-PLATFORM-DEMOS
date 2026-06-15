FROM golang:1.23-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /logistics-service ./cmd/

FROM scratch
COPY --from=build /logistics-service /logistics-service
EXPOSE 8084
ENTRYPOINT ["/logistics-service"]
