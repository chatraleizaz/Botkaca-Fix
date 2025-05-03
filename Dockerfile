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

# Install runtime dependencies, including openntpd for time synchronization
RUN apk --no-cache -q add \
    python3 libffi aria2 ffmpeg openntpd

# Copy virtual environment from prepare_env
COPY --from=prepare_env /app/venv /app/venv

# Set virtual environment PATH
ENV PATH="/app/venv/bin:$PATH" VIRTUAL_ENV="/app/venv"

# Copy application code
COPY bot bot

# Ensure time synchronization at container startup
RUN ntpd -s -d || true

# Run the application
CMD ["python3", "-m", "bot"]
