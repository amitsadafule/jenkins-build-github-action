FROM alpine:3.18.4

RUN apk add --no-cache curl jq bash

COPY main.sh main.sh

CMD ["./main.sh"]