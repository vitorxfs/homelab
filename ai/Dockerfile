FROM alpine:3.21

RUN apk add --no-cache nodejs npm git bash

RUN npm install -g @anthropic-ai/claude-code

WORKDIR /workspace

ENTRYPOINT ["claude"]
