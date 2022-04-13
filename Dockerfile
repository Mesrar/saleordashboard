# Sets node:alpine as the builder.
FROM node:14 as builder

# Updates and installs required Linux dependencies.
RUN set -eux \
    && apt-get -y update \
    && apt-get -y upgrade \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Updates and installs required Node dependencies.
COPY package*.json /dashboard/
WORKDIR /dashboard
RUN npm -g install npm@latest \
    && npm install

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
ENV API_URI ${API_URI:-http://localhost:30080/graphql/}

# Executes npm build script.
RUN STATIC_URL=${STATIC_URL} API_URI=${API_URI} APP_MOUNT_URI=${APP_MOUNT_URI} npm run build

# Sets nginx:alpine as the release image.
FROM nginx:alpine as release

# Defines new group and user for security reasons.
RUN addgroup -S saleor \
    && adduser -S -G saleor saleor

# Updates and installs required Linux dependencies.
RUN set -eux \
    && apk update \
    && apk upgrade \
    && apk add --no-cache \
        nano \
    \
    && rm -rf /var/cache/apk/*

# Copies the build files from the main builder.
COPY --from=builder --chown=saleor:saleor /dashboard/build/ /dashboard/

# Removes the demand for a specific user from the basic Nginx configuration file.
RUN sed -i "/user  nginx;/d" /etc/nginx/nginx.conf

# Changes the ownership of the required directories and files.
RUN chown -R saleor:saleor /etc/nginx/ \
    && chown -R saleor:saleor /var/cache/nginx \
    && chown -R saleor:saleor /var/log/nginx \
    && chown -R saleor:saleor /var/run/

# Exposes the deafult port for Salor Dashboard.
EXPOSE 9000

# Changes to the new user for security reasons.
USER saleor
