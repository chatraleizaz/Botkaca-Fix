FROM alpine:latest AS prepare_env
WORKDIR /app

# Install build dependencies
RUN apk --no-cache -q add \
    python3 python3-dev py3-pip libffi libffi-dev musl-dev gcc aria2

# Create virtual environment and set PATH early
RUN python3 -m venv /app/venv
ENV PATH="/app/venv/bin:$PATH" VIRTUAL_ENV="/app/venv"

# Install distlib and pipenv in the virtual environment
RUN pip3 install -q --ignore-installed distlib pipenv

# Copy and install requirements
COPY requirements.txt .
RUN pip3 install -q -r requirements.txt

FROM alpine:latest AS execute
WORKDIR /app

# Install runtime dependencies, including curl for HTTP-based time sync
RUN apk --no-cache -q add \
    python3 libffi aria2 ffmpeg curl

# Copy virtual environment from prepare_env
COPY --from=prepare_env /app/venv /app/venv

# Set virtual environment PATH
ENV PATH="/app/venv/bin:$PATH" VIRTUAL_ENV="/app/venv"

# Copy application code
COPY bot bot

# Create an entrypoint script to sync time via HTTP and run the bot
RUN echo -e '#!/bin/sh\n\
echo "Current container time before sync: $(date)"\n\
TIME=$(curl -s --head http://google.com | grep "^Date:" | awk '\''{print $3" "$4" "$5" "$6}'\'')\n\
if [ -n "$TIME" ]; then\n\
  date -s "$TIME"\n\
  echo "Time synchronized to: $TIME"\n\
else\n\
  echo "Failed to fetch time from HTTP server"\n\
fi\n\
echo "Current container time after sync: $(date)"\n\
exec python3 -m bot' > /entrypoint.sh && \
chmod +x /entrypoint.sh

# Use the entrypoint to ensure time sync before running the bot
ENTRYPOINT ["/entrypoint.sh"]
