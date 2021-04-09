FROM docker.io/ubuntu:latest

ENV VOLUME_PATH=/var/www/html/themes

ENV APP_ROOT=/opt/app-root
WORKDIR ${APP_ROOT}

RUN mkdir ${APP_ROOT}/themes 

COPY themes ${APP_ROOT}/themes

RUN chgrp -R 0 ${APP_ROOT}/themes && \
    chmod -R g=u ${APP_ROOT}/themes
COPY entrypoint.sh ${APP_ROOT}

RUN echo "finished copying" && ls -l ${APP_ROOT}/themes
CMD ["bash", "-c", "./entrypoint.sh"]
