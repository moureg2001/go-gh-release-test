FROM golang:1.24 AS builder
WORKDIR /app
COPY go.mod ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o app .

FROM gcr.io/distroless/static:nonroot
COPY --from=builder /app/app /app
ENTRYPOINT ["/app"]
