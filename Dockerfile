FROM registry.access.redhat.com/ubi9/nodejs-24-minimal:latest

# The base image runs as non-root by default. Switch to root briefly so
# /app can be created and handed to the unprivileged user.
USER 0

WORKDIR /app

# Give the non-root user (UID 1001, group 0) ownership of /app.
# Group permissions match owner permissions, so the app also works on OpenShift
# when it runs under an arbitrary UID.
RUN chown 1001:0 /app && chmod g=u /app

# The app needs no extra OS packages. If it later needs some, install them here
# with microdnf (UBI minimal) and not apk or apt, and clean the cache afterwards:
# RUN microdnf install -y <package> && microdnf clean all

# Run everything below as the non-root user.
USER 1001

# Copy files with the right ownership so the non-root user can read and write them.
COPY --chown=1001:0 package.json .

RUN npm install

COPY --chown=1001:0 . .

# Port 3000 is above 1024, so a non-root user can bind to it.
EXPOSE 3000

# The container runs as non-root (USER 1001).
CMD ["node", "app.js"]
