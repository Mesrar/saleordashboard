# Sets node:alpine as the builder.
FROM node:latest as builder

# Updates and installs required Linux dependencies.
RUN set -eux; \
    apt-get -y update; \
    apt-get -y upgrade; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# Installs required Node dependencies.
COPY package*.json /dashboard/
WORKDIR /dashboard
RUN npm install

# Copies the source code from the host into the container.
COPY . /dashboard
WORKDIR /dashboard

# Defines URI at which the Dashboard app will be mounted.
ARG APP_MOUNT_URI
ENV APP_MOUNT_URI ${APP_MOUNT_URI:-/dashboard/}

# Defines URL where the static files are located.
ARG STATIC_URL
ENV STATIC_URL ${STATIC_URL:-/dashboard/}

# Defines URI of a running instance of the Saleor GraphQL API.
ARG API_URI
ENV API_URI ${API_URI:-http://localhost:8000/graphql/}

# Executes npm build script.
RUN STATIC_URL=${STATIC_URL} API_URI=${API_URI} APP_MOUNT_URI=${APP_MOUNT_URI} npm run build

# Sets node:alpine as the release image.
FROM nginx:alpine as release

# Defines new group and user for security reasons.
RUN addgroup -S saleor && adduser -S -G saleor saleor

# Adds the new user to the Nginx group, for permissions in the server.
RUN adduser nginx saleor

# Updates and installs required Linux dependencies.
RUN set -eux; \
    apk update; \
    apk upgrade; \
    apk add --no-cache \
        nano \
    ; \
  rm -rf /var/cache/apk/*

# Copies the build files from the main builder.
COPY --from=builder --chown=saleor:saleor /dashboard/build/ /dashboard/

# todo: delete from here, and control with ConfigMap in k8s.
COPY ./nginx/default.conf /etc/nginx/conf.d/default.conf

# Removes the demand for a specific user from the basic Nginx configuration file.
RUN sed -i "2,2d;" /etc/nginx/nginx.conf

# Changes the ownership of the required directories and files.
RUN chown -R saleor:saleor /etc/nginx/ \
    && chown -R saleor:saleor /var/cache/nginx \
    && chown -R saleor:saleor /var/log/nginx \
    && chown -R saleor:saleor /var/run/nginx.pid

# Expose the deafult port for Salor Dashboard.
EXPOSE 9000

# Change to the new user for security reasons.
USER saleor
