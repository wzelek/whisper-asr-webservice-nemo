FROM onerahmet/ffmpeg:n7.1 AS ffmpeg

FROM swaggerapi/swagger-ui:v5.9.1 AS swagger-ui

FROM python:3.13-bookworm

RUN apt-get update && apt-get install -y wget unzip && rm -rf /var/lib/apt/lists/* 

RUN wget --content-disposition https://api.ngc.nvidia.com/v2/resources/nvidia/ngc-apps/ngc_cli/versions/4.13.0/files/ngccli_linux.zip -O ngccli_linux.zip && \ 
    unzip ngccli_linux.zip && \ 
    chmod +x ngc-cli/ngc && \ 
    rm ngccli_linux.zip 

WORKDIR /models 

RUN /ngc-cli/ngc registry model download-version "nvidia/nemo/titanet_large"
RUN /ngc-cli/ngc registry model download-version "nvidia/nemo/vad_multilingual_marblenet"

FROM python:3.13-bookworm

ENV POETRY_VENV=/app/.venv

RUN python -m venv $POETRY_VENV \
    && $POETRY_VENV/bin/pip install -U pip setuptools \
    && $POETRY_VENV/bin/pip install poetry

ENV PATH="${PATH}:${POETRY_VENV}/bin"

WORKDIR /app

COPY . .
COPY --from=ffmpeg /usr/local/bin/ffmpeg /usr/local/bin/ffmpeg
COPY --from=swagger-ui /usr/share/nginx/html/swagger-ui.css swagger-ui-assets/swagger-ui.css
COPY --from=swagger-ui /usr/share/nginx/html/swagger-ui-bundle.js swagger-ui-assets/swagger-ui-bundle.js
COPY --from=models /models /app/models

RUN poetry config virtualenvs.in-project true
RUN poetry install --extras cpu

EXPOSE 9000

ENV CUSTOM_SPEAKER_EMBEDDINGS_MODEL_PATH=/app/models/titanet_large/titanet-l.nemo
ENV CUSTOM_VAD_MODEL_PATH=/app/models/vad_multilingual_marblenet/vad_multilingual_marblenet.nemo
#ENV NVIDIA_NEMO_CONFIG=""

ENTRYPOINT ["whisper-asr-webservice"]
